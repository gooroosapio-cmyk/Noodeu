-- Catégories 1 et 2 (Se découvrir, Mieux se comprendre) sur le moteur plateau.
-- « pack_conversation » : même carte pour les deux, réponse privée puis choix partager / garder pour soi / passer ;
--   rien n'est révélé avant que les deux aient terminé ; la séance suivante reprend à la carte suivante.
-- « test_form » : questionnaire individuel ; réponses brutes privées, calcul sur le serveur d'après la clé de
--   cotation de la source ; une réponse passée vaut null (jamais 0) et empêche le calcul ; partage du seul résultat.
-- Les versions de banques (4.0.0 pour Aron et C02, 5.0.0 pour les autres packs C01) sont lues telles quelles.

create table if not exists private.pack_progress (
  couple_id uuid not null references public.couples (id) on delete cascade,
  game_id text not null,
  next_index int not null default 0,
  cards_done int not null default 0,
  updated_at timestamptz not null default now(),
  primary key (couple_id, game_id)
);
alter table private.pack_progress enable row level security;

create or replace function private.board_route5() returns text[]
language sql immutable set search_path = '' as $$ select array['pack_conversation', 'test_form'] $$;

-- Valeur autorisée pour un item de test : booléen pour une case à cocher, valeur de l'échelle sinon ; null = passé.
create or replace function private.test_value_ok(t jsonb, it jsonb, v jsonb) returns boolean
language sql immutable set search_path = '' as $$
  select case
    when v is null or v = 'null'::jsonb then true
    when it ->> 'response_type' = 'checkbox' then jsonb_typeof(v) = 'boolean'
    else jsonb_typeof(v) = 'number' and exists (select 1 from jsonb_array_elements(t -> 'scales' -> (it ->> 'scale_id')) o
                                                 where (o ->> 'value')::numeric = (v #>> '{}')::numeric)
  end
$$;

-- Calcul d'après les sorties de la clé de cotation ; toute réponse manquante d'une sortie requise : pas de score.
create or replace function private.test_scores(t jsonb, items jsonb, answers jsonb) returns jsonb
language plpgsql immutable set search_path = '' as $$
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
      else acc end);
  end loop;
  return jsonb_build_object('status', 'complete', 'answered', answered, 'total', jsonb_array_length(items), 'scores', scores);
end $$;

create or replace function private.bank_items(p_bank text) returns jsonb
language sql stable security definer set search_path = '' as $$
  select coalesce(jsonb_agg(value order by idx), '[]') from public.content_banks where bank = p_bank
$$;

-- ===========================================================================
-- Tirage
-- ===========================================================================
create or replace function private.board_setup5(s public.game_sessions, cfg jsonb) returns jsonb
language plpgsql volatile security definer set search_path = '' as $$
declare
  m text := cfg ->> 'mechanic';
  p jsonb := cfg -> 'pack';
  t jsonb := cfg -> 'test';
  n int;
  ci int;
  set_size int;
  it jsonb;
  items jsonb;
begin
  if m = 'pack_conversation' then
    n := (p ->> 'count')::int;
    set_size := (p ->> 'set_size')::int;
    if s.current_round <= 1 then
      select next_index into ci from private.pack_progress where couple_id = s.couple_id and game_id = s.game_id;
      ci := coalesce(ci, 0);
      if ci >= n then ci := 0; end if;
      -- Séance : jusqu'à la fin de la série (Aron, séries de 12) ou du pack.
      -- 50 cartes au plus par séance (limite des parties) ; la suivante reprend après.
      update public.game_sessions set total_rounds = least(50, case when set_size is null then n - ci else (ci / set_size + 1) * set_size - ci end)
        where id = s.id;
    else
      select (card ->> 'index')::int + 1 into ci from public.session_rounds where session_id = s.id and round_no = s.current_round - 1;
    end if;
    select value into it from public.content_banks where bank = cfg ->> 'bank' and content_banks.idx = ci;
    if it is null then raise exception 'bank_missing'; end if;
    return jsonb_build_object('mech', m, 'index', ci, 'count', n,
      'set_no', case when set_size is null then null else ci / set_size + 1 end, 'set_size', set_size,
      'first', 1 + ci % 2, 'response', p ->> 'response', 'scales', p -> 'scales',
      'item', jsonb_build_object('id', it ->> 'id', 'text', it ->> 'text_fr', 'kind', it ->> 'kind',
                                 'response', it ->> 'response_type', 'position', it -> 'source_position',
                                 'options', it -> 'options_ordered'),
      'status', '{}'::jsonb, 'answers', null, 'done', false,
      '_secret', jsonb_build_object('seats', '{}'::jsonb));
  elsif m = 'test_form' then
    items := private.bank_items(cfg ->> 'bank');
    if jsonb_array_length(items) <> (t ->> 'count')::int then raise exception 'bank_missing'; end if;
    return jsonb_build_object('mech', m, 'count', jsonb_array_length(items), 'input', t ->> 'input', 'scales', t -> 'scales',
      'page_size', t -> 'page_size', 'axes', t -> 'axes', 'reserves', t -> 'reserves',
      'items', (select jsonb_agg(jsonb_build_object('id', i ->> 'id', 'text', i ->> 'text_fr', 'position', i -> 'source_position',
                                                    'scale', i ->> 'scale_id', 'response', i ->> 'response_type',
                                                    'kind', i ->> 'kind', 'note', i -> 'note') order by o)
                from jsonb_array_elements(items) with ordinality e(i, o)),
      'completed', '{}'::jsonb, 'declined', '{}'::jsonb, 'shared', '{}'::jsonb, 'done', false,
      '_secret', jsonb_build_object('seats', '{}'::jsonb));
  end if;
  raise exception 'unknown_mechanic';
end $$;

-- ===========================================================================
-- Coups
-- ===========================================================================
create or replace function private.board_apply5(m text, c jsonb, sec jsonb, seat int, typ text, p jsonb, p_session uuid) returns jsonb
language plpgsql volatile security definer set search_path = '' as $$
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
      insert into private.pack_progress (couple_id, game_id, next_index, cards_done)
        values (s.couple_id, s.game_id, (c ->> 'index')::int + 1, 1)
        on conflict (couple_id, game_id) do update set next_index = excluded.next_index,
          cards_done = pack_progress.cards_done + 1, updated_at = now();
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
        c := jsonb_set(c, array['shared', me], res -> 'scores');
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
end $$;

create or replace function private.pack_public(a jsonb) returns jsonb
language sql immutable set search_path = '' as $$
  select case when a is null then null when a ->> 'choice' = 'share' then a else jsonb_build_object('choice', a ->> 'choice') end
$$;

-- Partage révocable après la révélation (réponse d'une carte ou résultat d'un test).
create or replace function public.set_answer_shared(p_session uuid, p_round int, p_share boolean) returns jsonb
language plpgsql security definer set search_path = '' as $$
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
    update public.session_rounds set card = case when p_share then jsonb_set(card, array['shared', me], a -> 'scores')
                                                 else jsonb_set(card, '{shared}', (card -> 'shared') - me) end
      where session_id = p_session and round_no = p_round;
  else
    return jsonb_build_object('ok', false, 'error', 'not_allowed');
  end if;
  perform private.bump_session(p_session, 'move');
  return jsonb_build_object('ok', true);
end $$;

-- Fin de séance à tout moment (conversation) : la carte en cours sera reprise la prochaine fois.
create or replace function public.end_pack_session(p_session uuid) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  r record;
  cfg jsonb;
begin
  select * into r from private.lock_session(p_session);
  cfg := private.version_config(r.s);
  if cfg ->> 'mechanic' is distinct from 'pack_conversation' then return jsonb_build_object('ok', false, 'error', 'not_allowed'); end if;
  if (r.s).status not in ('playing', 'paused') then return jsonb_build_object('ok', true, 'repeated', true); end if;
  update public.game_sessions set status = 'ended', ended_at = now(),
    total_rounds = greatest(1, (r.s).current_round),
    result = jsonb_build_object('cards', (select count(*) from public.session_rounds where session_id = p_session and revealed_at is not null))
    where id = p_session;
  perform private.bump_session(p_session, 'ended');
  return jsonb_build_object('ok', true);
end $$;

grant execute on function public.set_answer_shared(uuid, int, boolean), public.end_pack_session(uuid) to authenticated;

-- ===========================================================================
-- Partenaire automatique de test (temporaire)
-- ===========================================================================
create or replace function private.board_bot5(m text, c jsonb, sec jsonb, seat int) returns jsonb
language plpgsql volatile security definer set search_path = '' as $$
declare
  me text := seat::text;
  ans jsonb := '{}';
  it jsonb;
  t jsonb := c -> 'scales';
begin
  if coalesce((c ->> 'done')::boolean, false) then return null; end if;
  if m = 'pack_conversation' then
    if c -> 'status' ? me then return null; end if;
    if c ->> 'response' = 'true_false' then
      return jsonb_build_object('type', 'answer', 'payload', jsonb_build_object('choice', 'share', 'value', 1 - private.rnd(2),
        'text', 'Réponse du partenaire automatique de test.'));
    end if;
    return jsonb_build_object('type', 'answer', 'payload', jsonb_build_object('choice', 'share', 'text', 'Réponse du partenaire automatique de test.'));
  elsif m = 'test_form' then
    if c -> 'completed' ? me or c -> 'declined' ? me then return null; end if;
    for it in select * from jsonb_array_elements(c -> 'items') loop
      ans := ans || jsonb_build_object(it ->> 'id', case when it ->> 'response' = 'checkbox' then to_jsonb(private.rnd(2) = 1)
        else (select o -> 'value' from jsonb_array_elements(t -> (it ->> 'scale')) o order by random() limit 1) end);
    end loop;
    return jsonb_build_object('type', 'complete', 'payload', jsonb_build_object('answers', ans, 'share', true));
  end if;
  return null;
end $$;

-- Aiguillage : la famille 5 (questionnaires) rejoint les familles 2 à 4.
create or replace function private.board_setup_any(s public.game_sessions, cfg jsonb) returns jsonb
language plpgsql volatile security definer set search_path = '' as $$
begin
  if cfg ->> 'mechanic' = any(private.board_route5()) then return private.board_setup5(s, cfg); end if;
  if cfg ->> 'mechanic' = any(private.board_route4()) then return private.board_setup4(s, cfg); end if;
  if cfg ->> 'mechanic' = any(private.board_route3()) then return private.board_setup3(s, cfg); end if;
  return private.board_setup(s, cfg);
end $$;

create or replace function private.board_apply_any(m text, c jsonb, sec jsonb, seat int, typ text, p jsonb, p_session uuid) returns jsonb
language plpgsql volatile security definer set search_path = '' as $$
begin
  if m = any(private.board_route5()) then return private.board_apply5(m, c, sec, seat, typ, p, p_session); end if;
  if m = any(private.board_route3()) or m = any(private.board_route4()) then
    if typ = 'giveup' then return private.res(c || '{"done": true, "gave_up": true}', sec); end if;
    if m = any(private.board_route4()) then return private.board_apply4(m, c, sec, seat, typ, p, p_session); end if;
    return private.board_apply3(m, c, sec, seat, typ, p, p_session);
  end if;
  return private.board_apply(m, c, sec, seat, typ, p, p_session);
end $$;

create or replace function private.board_bot_any(m text, c jsonb, sec jsonb, seat int) returns jsonb
language plpgsql volatile security definer set search_path = '' as $$
begin
  if m = any(private.board_route5()) then return private.board_bot5(m, c, sec, seat); end if;
  if m = any(private.board_route4()) then return private.board_bot4(m, c, sec, seat); end if;
  if m = any(private.board_route3()) then return private.board_bot3(m, c, sec, seat); end if;
  return private.board_bot(m, c, sec, seat);
end $$;

-- Salon : un contenu « À huis clos » ne démarre qu'avec l'accès adulte activé et l'accord de chacun.
create or replace function public.set_ready(p_session uuid, p_ready boolean) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  r record;
  all_ready boolean;
  cfg jsonb;
  wanted int;
  sess public.game_sessions;
  intimate boolean;
begin
  select * into r from private.lock_session(p_session);
  if (r.s).status <> 'lobby' then
    return jsonb_build_object('ok', true, 'status', (r.s).status);
  end if;
  -- Contenu « À huis clos » : chacun active l'accès adulte dans son profil, puis donne son accord dans le salon.
  intimate := (select content_level = 'intime' from public.games where id = (r.s).game_id);
  if p_ready and intimate and not exists (
      select 1 from public.session_prefs sp join public.profiles pr on pr.id = sp.user_id
      where sp.session_id = p_session and sp.seat = r.seat and sp.adult and pr.intimate_opt_in) then
    return jsonb_build_object('ok', false, 'error', 'adult_consent_required');
  end if;
  update public.session_players set ready_at = case when p_ready then coalesce(ready_at, now()) end
    where session_id = p_session and seat = r.seat;
  select count(*) = 2 and bool_and(ready_at is not null) into all_ready
    from public.session_players where session_id = p_session and user_id is not null;
  if all_ready and intimate and not private.adult_allowed(p_session) then
    update public.session_players set ready_at = null where session_id = p_session;
    perform private.bump_session(p_session, 'ready');
    return jsonb_build_object('ok', false, 'error', 'adult_consent_required');
  end if;
  if all_ready then
    cfg := private.version_config(r.s);
    wanted := coalesce(((r.s).settings ->> (cfg ->> 'rounds_setting'))::int, (cfg ->> 'rounds')::int, 1);
    -- Banque filtrée trop petite : on réduit le nombre de cartes (jamais d'élargissement silencieux des thèmes).
    if cfg #>> '{draw,deck}' = 'true' then
      wanted := least(wanted, private.deck_available(r.s));
      if wanted < 1 then
        update public.session_players set ready_at = null where session_id = p_session;
        perform private.bump_session(p_session, 'ready');
        return jsonb_build_object('ok', false, 'error', 'not_enough_cards');
      end if;
    end if;
    update public.game_sessions set status = 'playing', started_at = now(), current_round = 1, total_rounds = wanted
      where id = p_session returning * into sess;
    insert into public.session_rounds (session_id, round_no, card) values (p_session, 1, private.draw_round_card(sess, cfg));
  end if;
  perform private.bump_session(p_session, case when all_ready then 'started' else 'ready' end);
  return jsonb_build_object('ok', true, 'status', case when all_ready then 'playing' else 'lobby' end);
end $$;
