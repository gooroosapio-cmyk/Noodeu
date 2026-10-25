-- Test de pureté (demande du propriétaire, 25/10/2026) : score sur un total, et « Montrer mes réponses à la fin »
-- activé par défaut. La banque validée compte 72 items (version allégée, pas l'original de 100) : on affiche
-- l'indice Noodeu sur 100 = arrondi(100 × Non / 72) et le nombre de Non sur 72, seulement si les 72 sont répondus.
-- Rien n'est partagé avant le clic final ; le partage reste réversible. Nouvelle version : les séances en cours gardent l'ancienne.

CREATE OR REPLACE FUNCTION private.test_scores(t jsonb, items jsonb, answers jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 IMMUTABLE
 SET search_path TO ''
AS $function$
declare
  o jsonb;
  pos int;
  it jsonb;
  v jsonb;
  x numeric;
  lo numeric;
  hi numeric;
  acc numeric;
  n int;
  scores jsonb := '{}';
  answered int;
begin
  select count(*) into answered from jsonb_array_elements(items) i
    where answers ? (i ->> 'id') and answers -> (i ->> 'id') <> 'null'::jsonb;
  for o in select * from jsonb_array_elements(t -> 'outputs') loop
    acc := 0; n := 0;
    for pos in select (p #>> '{}')::int from jsonb_array_elements(o -> 'positions') p loop
      select i into it from jsonb_array_elements(items) i where (i ->> 'source_position')::int = pos;
      v := answers -> (it ->> 'id');
      if it is null or v is null or v = 'null'::jsonb then
        if coalesce((o ->> 'optional')::boolean, false) then acc := null; exit; end if;
        return jsonb_build_object('status', 'incomplete', 'answered', answered, 'total', jsonb_array_length(items));
      end if;
      if o ->> 'operation' = '100_minus_checked_count' then
        acc := acc + case when v = 'true'::jsonb then 1 else 0 end;
      elsif o ->> 'operation' in ('count_value_0', 'percent_value_0') then
        acc := acc + case when (v #>> '{}')::numeric = 0 then 1 else 0 end;
      else
        x := (v #>> '{}')::numeric;
        if (o -> 'reverse_positions') @> to_jsonb(pos) then
          select min((e ->> 'value')::numeric), max((e ->> 'value')::numeric) into lo, hi
            from jsonb_array_elements(t -> 'scales' -> (it ->> 'scale_id')) e;
          x := lo + hi - x;
        end if;
        acc := acc + x;
      end if;
      n := n + 1;
    end loop;
    if acc is null then continue; end if;
    scores := scores || jsonb_build_object(o ->> 'name', case o ->> 'operation'
      when '100_minus_checked_count' then 100 - acc
      when 'mean' then round(acc / n, 2)
      when 'percent_value_0' then round(100 * acc / n)
      else acc end);
  end loop;
  return jsonb_build_object('status', 'complete', 'answered', answered, 'total', jsonb_array_length(items), 'scores', scores);
end $function$;

CREATE OR REPLACE FUNCTION private.board_apply5(m text, c jsonb, sec jsonb, seat integer, typ text, p jsonb, p_session uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  me text := seat::text;
  oth text := (3 - seat)::text;
  s public.game_sessions;
  cfg jsonb;
  choice text;
  txt text;
  val jsonb;
  ans jsonb;
  items jsonb;
  it jsonb;
  k text;
  merged jsonb;
  res jsonb;
begin
  select * into s from public.game_sessions where id = p_session;
  cfg := private.version_config(s);

  if m = 'pack_conversation' then
    if typ <> 'answer' then perform private.mv('invalid_move'); end if;
    choice := p ->> 'choice';
    if choice not in ('share', 'private', 'pass') then perform private.mv('invalid_move'); end if;
    txt := nullif(btrim(coalesce(p ->> 'text', '')), '');
    if txt is not null and char_length(txt) > 500 then perform private.mv('invalid_text'); end if;
    val := p -> 'value';
    if val = 'null'::jsonb then val := null; end if;
    if val is not null and not exists (select 1 from jsonb_array_elements(c -> 'item' -> 'options') o where o -> 'value' = val) then
      perform private.mv('invalid_move');
    end if;
    if choice = 'share' and txt is null and val is null then perform private.mv('empty_answer'); end if;
    ans := case when choice = 'pass' then jsonb_build_object('choice', 'pass')
                else jsonb_strip_nulls(jsonb_build_object('choice', choice, 'text', txt, 'value', val)) end;
    sec := jsonb_set(sec, '{seats}', coalesce(sec -> 'seats', '{}') || jsonb_build_object(me, jsonb_build_object('answer', ans)));
    c := jsonb_set(c, array['status', me], '"done"');
    if c -> 'status' ? oth then
      -- Révélation : seules les réponses partagées sont envoyées ; « gardé pour soi » et « passé » sans contenu.
      c := c || jsonb_build_object('done', true, 'answers', jsonb_build_object(
        '1', private.pack_public(sec #> '{seats,1,answer}'), '2', private.pack_public(sec #> '{seats,2,answer}')));
      if not coalesce((c ->> 'random')::boolean, false) then
      insert into private.pack_progress (couple_id, game_id, next_index, cards_done)
        values (s.couple_id, s.game_id, (c ->> 'index')::int + 1, 1)
        on conflict (couple_id, game_id) do update set next_index = excluded.next_index,
          cards_done = pack_progress.cards_done + 1, updated_at = now();
      end if;
    end if;
    return private.res(c, sec);

  elsif m = 'test_form' then
    if c -> 'completed' ? me or c -> 'declined' ? me then perform private.mv('already_submitted'); end if;
    items := private.bank_items(cfg ->> 'bank');
    if typ in ('save', 'complete') then
      if jsonb_typeof(coalesce(p -> 'answers', '{}')) <> 'object' then perform private.mv('invalid_move'); end if;
      merged := coalesce(sec #> array['seats', me, 'answers'], '{}');
      for k in select jsonb_object_keys(coalesce(p -> 'answers', '{}')) loop
        select i into it from jsonb_array_elements(items) i where i ->> 'id' = k;
        if it is null or not private.test_value_ok(cfg -> 'test', it, p -> 'answers' -> k) then perform private.mv('invalid_option'); end if;
        merged := merged || jsonb_build_object(k, p -> 'answers' -> k);
      end loop;
      sec := jsonb_set(sec, '{seats}', coalesce(sec -> 'seats', '{}') || jsonb_build_object(me,
        coalesce(sec #> array['seats', me], '{}') || jsonb_build_object('answers', merged, 'page', coalesce(p -> 'page', sec #> array['seats', me, 'page']))));
      if typ = 'save' then return private.res(c, sec); end if;
      res := private.test_scores(cfg -> 'test', items, merged);
      sec := jsonb_set(sec, array['seats', me, 'result'], res);
      c := jsonb_set(c, array['completed', me], 'true');
      if coalesce((p ->> 'share')::boolean, false) and res ->> 'status' = 'complete' then
        -- Test de pureté : « Montrer mes réponses à la fin » partage aussi les réponses, au seul clic final.
        c := jsonb_set(c, array['shared', me], (res -> 'scores')
          || case when coalesce((cfg #>> '{test,share_answers}')::boolean, false) then jsonb_build_object('answers', merged) else '{}'::jsonb end);
      end if;
    elsif typ = 'decline' then
      c := jsonb_set(c, array['declined', me], 'true');
    else
      perform private.mv('invalid_move');
    end if;
    if (c -> 'completed' ? oth or c -> 'declined' ? oth) then c := c || '{"done": true}'; end if;
    return private.res(c, sec);
  end if;
  perform private.mv('invalid_move');
  return null;
end $function$;

CREATE OR REPLACE FUNCTION public.set_answer_shared(p_session uuid, p_round integer, p_share boolean)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  r record;
  cfg jsonb;
  rd public.session_rounds;
  sec jsonb;
  me text;
  a jsonb;
begin
  select * into r from private.lock_session(p_session);
  me := r.seat::text;
  if p_share is null or (r.s).status not in ('playing', 'paused', 'ended') then return jsonb_build_object('ok', false, 'error', 'not_allowed'); end if;
  cfg := private.version_config(r.s);
  select * into rd from public.session_rounds where session_id = p_session and round_no = p_round;
  select secret into sec from private.round_secrets where session_id = p_session and round_no = p_round;
  if rd.session_id is null then return jsonb_build_object('ok', false, 'error', 'stale_round'); end if;
  if cfg ->> 'mechanic' = 'pack_conversation' then
    a := sec #> array['seats', me, 'answer'];
    if not coalesce((rd.card ->> 'done')::boolean, false) or a is null then return jsonb_build_object('ok', false, 'error', 'not_allowed'); end if;
    if p_share and a ->> 'text' is null and a -> 'value' is null then return jsonb_build_object('ok', false, 'error', 'empty_answer'); end if;
    update public.session_rounds set card = jsonb_set(card, array['answers', me],
      case when p_share then (a - 'choice') || '{"choice": "share"}' else '{"choice": "private"}'::jsonb end)
      where session_id = p_session and round_no = p_round;
  elsif cfg ->> 'mechanic' = 'test_form' then
    a := sec #> array['seats', me, 'result'];
    if a ->> 'status' is distinct from 'complete' then return jsonb_build_object('ok', false, 'error', 'not_allowed'); end if;
    update public.session_rounds set card = case when p_share then jsonb_set(card, array['shared', me], (a -> 'scores')
                                                   || case when coalesce((cfg #>> '{test,share_answers}')::boolean, false)
                                                      then jsonb_build_object('answers', sec #> array['seats', me, 'answers']) else '{}'::jsonb end)
                                                 else jsonb_set(card, '{shared}', (card -> 'shared') - me) end
      where session_id = p_session and round_no = p_round;
  else
    return jsonb_build_object('ok', false, 'error', 'not_allowed');
  end if;
  perform private.bump_session(p_session, 'move');
  return jsonb_build_object('ok', true);
end $function$;

with v as (select * from public.game_versions where game_id = 'ND-Q-011'
           and version = (select current_version from public.games where id = 'ND-Q-011'))
insert into public.game_versions (game_id, version, rules, config, published_at)
select 'ND-Q-011', v.version + 1,
  v.rules || jsonb_build_object(
    'how_to', jsonb_build_array(
      'Chacun répond seul, à son rythme, par Oui ou Non.',
      'Tu peux passer une question ; le résultat n''est calculé que si les 72 réponses sont données.',
      '« Montrer mes réponses à la fin » est activé par défaut : tu peux le désactiver avant de terminer. Rien n''est partagé avant ce clic final.'),
    'details', jsonb_build_array(
      'Version allégée et reformulée de 72 items : ce n''est pas le test de pureté original intégral.',
      'Indice Noodeu sur 100 : 100 × nombre de Non ÷ 72, arrondi. Exemple : 50 Non sur 72 donnent 69/100.',
      'Le score est celui de l''instrument : ni jugement, ni diagnostic, ni compatibilité.',
      'Source : catalogue éditorial consolidé Noodeu du 24/10/2026 (D07, D08).'),
    'privacy', 'Tes réponses restent privées pendant le test. Au clic final, si « Montrer mes réponses » est activé, ton résultat et tes réponses sont montrés à l''autre ; tu peux retirer ce partage ensuite.'),
  jsonb_set(v.config, '{test}', (v.config -> 'test') || jsonb_build_object(
    'axes', jsonb_build_object('indice', 'Indice Noodeu sur 100', 'non', 'Réponses « Non »'),
    'outputs', jsonb_build_array(
      jsonb_build_object('name', 'indice', 'operation', 'percent_value_0', 'positions', (select jsonb_agg(g) from generate_series(1, 72) g), 'reverse_positions', '[]'::jsonb),
      jsonb_build_object('name', 'non', 'operation', 'count_value_0', 'positions', (select jsonb_agg(g) from generate_series(1, 72) g), 'reverse_positions', '[]'::jsonb)),
    'score_max', jsonb_build_object('indice', 100, 'non', 72),
    'share_default', true, 'share_answers', true, 'algorithm_version', 'purete72-indice-1',
    'reserves', jsonb_build_array('Version allégée et reformulée de 72 items : ce n''est pas le test de pureté original intégral.'))),
  now()
from v where not coalesce((v.config #>> '{test,share_answers}')::boolean, false);
update public.games set current_version = (select max(version) from public.game_versions where game_id = 'ND-Q-011'), updated_at = now()
  where id = 'ND-Q-011';
