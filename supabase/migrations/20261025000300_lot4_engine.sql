-- Lot 4 (kit C03/C04 V1, catégorie 4) : Le Pendu (M09), Petit bac (M16), Cite trois en 10 secondes (G07).
-- Famille 8 du moteur plateau. Tout se décide au serveur : mot secret du donneur, lettre et brouillons du Petit bac,
-- consigne de Cite trois retenue jusqu'au départ commun ; échéances comparées à l'heure du serveur.
-- Entre deux manches, « Continuer » des deux (public.round_after), comme les jeux de conversation.

-- Cite trois n'a pas de plafond de manches (fin à 30 points ou pile épuisée) : la limite technique passe à 200,
-- au-delà des 100 consignes de la banque.
alter table public.game_sessions drop constraint game_sessions_total_rounds_check;
alter table public.game_sessions add constraint game_sessions_total_rounds_check check (total_rounds between 1 and 200);

create or replace function private.board_route8() returns text[]
language sql immutable set search_path = '' as $$
  select array['nd_hangman', 'nd_categories_stop', 'nd_name_three_call'] $$;

-- Normalisation commune : casse, accents, ligatures, apostrophes et espaces.
create or replace function private.nd_norm(t text) returns text
language sql immutable set search_path = '' as $$
  select upper(regexp_replace(btrim(translate(
    replace(replace(replace(replace(lower(coalesce(t, '')), 'œ', 'oe'), 'æ', 'ae'), '’', ''''), 'ʼ', ''''),
    'àâäáãåçéèêëíìîïñóòôöõúùûüýÿ', 'aaaaaaceeeeiiiinooooouuuuyy')), '\s+', ' ', 'g')) $$;

-- Initiales jouables au Petit bac : chaque catégorie a au moins une réponse validée dans l'index.
create or replace function private.pb_letters(p_bank text) returns text[]
language sql stable security definer set search_path = '' as $$
  select coalesce(array_agg(l order by l), '{}') from (
    select left(a.x, 1) l from public.content_banks cb, jsonb_array_elements_text(cb.value -> 'aliases') a(x)
    where cb.bank = p_bank group by 1 having count(distinct cb.value ->> 'cat') = 4) t $$;

create or replace function private.board_setup8(s public.game_sessions, cfg jsonb) returns jsonb
language plpgsql volatile security definer set search_path = '' as $$
declare
  m text := cfg ->> 'mechanic';
  first int := private.first_seat(s);
  item jsonb;
  choices jsonb;
  diff text;
  letter text;
begin
  if m = 'nd_hangman' then
    diff := coalesce(s.settings ->> 'difficulte', cfg #>> '{settings,difficulte,default}', 'standard');
    select jsonb_agg(jsonb_build_object('id', x.value ->> 'id', 'text', x.value ->> 'text')) into choices
      from (select value from public.content_banks
            where bank = cfg ->> 'bank' and value ->> 'difficulty' = diff
              and not ((value ->> 'id') = any(private.conv_seen(s.id)))
            order by random() limit 8) x;
    if choices is null then raise exception 'not_enough_cards'; end if;
    return jsonb_build_object('mech', m, 'first', first, 'giver', first, 'guesser', 3 - first, 'phase', 'choose',
      'difficulty', diff, 'continue', '{}'::jsonb, 'done', false,
      '_secret', jsonb_build_object('seats', jsonb_build_object(first::text, jsonb_build_object('choices', choices))));
  elsif m = 'nd_categories_stop' then
    select l into letter from unnest(private.pb_letters(cfg ->> 'bank')) l
      where not exists (select 1 from private.round_secrets rs where rs.session_id = s.id and rs.secret ->> 'letter' = l)
      order by random() limit 1;
    if letter is null then raise exception 'not_enough_cards'; end if;
    return jsonb_build_object('mech', m, 'first', first, 'phase', 'loaded', 'categories', cfg -> 'categories',
      'loaded', '{}'::jsonb, 'confirmed', '{}'::jsonb, 'continue', '{}'::jsonb, 'done', false,
      '_secret', jsonb_build_object('letter', letter, 'seats', '{}'::jsonb));
  elsif m = 'nd_name_three_call' then
    item := private.conv_draw(s.id, cfg ->> 'bank');
    if item is null then raise exception 'not_enough_cards'; end if;
    return jsonb_build_object('mech', m, 'first', first, 'phase', 'loading', 'card_id', item ->> 'id',
      'adult', coalesce((item ->> 'adult')::boolean, false), 'theme', item ->> 'theme',
      'need_call', s.current_round <= 1, 'loaded', '{}'::jsonb, 'acks', '{}'::jsonb, 'void_votes', '{}'::jsonb,
      'continue', '{}'::jsonb, 'done', false,
      '_secret', jsonb_build_object('text', item ->> 'text', 'respondent', 1 + private.rnd(2), 'seats', '{}'::jsonb));
  end if;
  raise exception 'unknown_mechanic';
end $$;

-- Petit bac : classement d'une réponse à la clôture des saisies (index de la bonne catégorie, jamais le lexique seul).
create or replace function private.pb_classify(p_bank text, p_cat text, p_letter text, p_text text) returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare n text := private.nd_norm(p_text); acc text;
begin
  if n = '' then return jsonb_build_object('text', '', 'status', 'empty'); end if;
  if left(n, 1) <> p_letter then return jsonb_build_object('text', btrim(p_text), 'status', 'invalid', 'norm', n); end if;
  select value ->> 'acc' into acc from public.content_banks
    where bank = p_bank and value ->> 'cat' = p_cat and value -> 'aliases' ? n limit 1;
  if acc is not null then
    return jsonb_build_object('text', btrim(p_text), 'status', 'valid', 'acc', acc, 'norm', n);
  end if;
  return jsonb_build_object('text', btrim(p_text), 'status', 'unknown', 'norm', n);
end $$;

create or replace function private.pb_freeze(c jsonb, sec jsonb, p_bank text, p_stopped_by int) returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare
  answers jsonb := '{}';
  st int;
  cat text;
begin
  for st in 1..2 loop
    answers := answers || jsonb_build_object(st::text, '{}'::jsonb);
    for cat in select jsonb_array_elements_text(c -> 'categories') loop
      answers := jsonb_set(answers, array[st::text, cat],
        private.pb_classify(p_bank, cat, c ->> 'letter', coalesce(sec #>> array['seats', st::text, 'drafts', cat, 'text'], '')));
    end loop;
  end loop;
  return c || jsonb_build_object('phase', 'validation', 'answers', answers, 'stopped_by', p_stopped_by,
    'frozen_at', now(), 'validation_deadline', now() + interval '60 seconds', 'confirmed', '{}'::jsonb);
end $$;

-- Clôture de l'arbitrage : statuts figés, barème 5 / 10 / 15, cases non tranchées à 0 sans être déclarées fausses.
create or replace function private.pb_close(c jsonb, sec jsonb) returns jsonb
language plpgsql immutable set search_path = '' as $$
declare
  cat text;
  st int;
  e jsonb;
  v1 text;
  v2 text;
  fin jsonb := '{}';
  ok1 boolean;
  ok2 boolean;
  same boolean;
  i1 text;
  i2 text;
  p1 int;
  p2 int;
  tot1 int := 0;
  tot2 int := 0;
  ident jsonb := '{}';
begin
  for st in 1..2 loop fin := fin || jsonb_build_object(st::text, '{}'::jsonb); end loop;
  for cat in select jsonb_array_elements_text(c -> 'categories') loop
    for st in 1..2 loop
      e := c #> array['answers', st::text, cat];
      v1 := sec #>> array['seats', '1', 'votes', st::text || ':' || cat];
      v2 := sec #>> array['seats', '2', 'votes', st::text || ':' || cat];
      if e ->> 'status' = 'valid' then
        e := e || jsonb_build_object('final', case
          when coalesce(v1, 'accept') = 'accept' and coalesce(v2, 'accept') = 'accept' then 'valid'
          when v1 = 'reject' and v2 = 'reject' then 'rejected' else 'contested' end);
      elsif e ->> 'status' = 'unknown' then
        e := e || jsonb_build_object('final', case
          when v1 = 'accept' and v2 = 'accept' then 'accepted'
          when v1 = 'reject' and v2 = 'reject' then 'rejected' else 'contested' end);
      else
        e := e || jsonb_build_object('final', e ->> 'status');
      end if;
      fin := jsonb_set(fin, array[st::text, cat], e);
    end loop;
    ok1 := fin #>> array['1', cat, 'final'] in ('valid', 'accepted');
    ok2 := fin #>> array['2', cat, 'final'] in ('valid', 'accepted');
    p1 := 0; p2 := 0;
    if ok1 and ok2 then
      if fin #>> array['1', cat, 'norm'] = fin #>> array['2', cat, 'norm'] then
        same := true;
      elsif fin #> array['1', cat, 'acc'] is not null and fin #> array['2', cat, 'acc'] is not null then
        same := fin #>> array['1', cat, 'acc'] = fin #>> array['2', cat, 'acc'];
      else
        i1 := sec #>> array['seats', '1', 'same', cat];
        i2 := sec #>> array['seats', '2', 'same', cat];
        same := case when i1 = i2 then i1::boolean end;
      end if;
      ident := ident || jsonb_build_object(cat, coalesce(to_jsonb(same), '"contested"'));
      if same is true then p1 := 5; p2 := 5; elsif same is false then p1 := 10; p2 := 10; end if;
    elsif ok1 then p1 := 15;
    elsif ok2 then p2 := 15;
    end if;
    fin := jsonb_set(fin, array['1', cat, 'points'], to_jsonb(p1));
    fin := jsonb_set(fin, array['2', cat, 'points'], to_jsonb(p2));
    tot1 := tot1 + p1; tot2 := tot2 + p2;
  end loop;
  return c || jsonb_build_object('phase', 'result', 'done', true, 'answers', fin, 'identity', ident,
    'scores', jsonb_build_object('1', tot1, '2', tot2));
end $$;

-- Pendu : masque public (lettres découvertes sous leur forme d'origine, ligature dépliée en deux unités).
create or replace function private.hm_mask(units jsonb, display jsonb, guessed jsonb) returns jsonb
language sql immutable set search_path = '' as $$
  select coalesce(jsonb_agg(case when guessed ? (u.value #>> '{}') then display -> (u.ord::int - 1) else 'null'::jsonb end
                            order by u.ord), '[]')
  from jsonb_array_elements(units) with ordinality u(value, ord) $$;

create or replace function private.board_apply8(m text, c jsonb, sec jsonb, seat int, typ text, p jsonb, p_session uuid) returns jsonb
language plpgsql volatile security definer set search_path = '' as $$
declare
  me text := seat::text;
  oth text := (3 - seat)::text;
  cfg jsonb;
  item jsonb;
  t text;
  rev int;
  cat text;
  d jsonb;
  guessed jsonb;
  drafts jsonb;
  mask jsonb;
  hit boolean;
  found boolean;
  info jsonb := jsonb_build_object('now', now());
  resp int;
begin
  select private.version_config(g) into cfg from public.game_sessions g where g.id = p_session;

  if m = 'nd_hangman' then
    if typ = 'choose_word' then
      if c ->> 'phase' <> 'choose' then perform private.mv('phase'); end if;
      if (c ->> 'giver')::int <> seat then perform private.mv('not_your_turn'); end if;
      if not exists (select 1 from jsonb_array_elements(sec #> array['seats', me, 'choices']) x where x ->> 'id' = p ->> 'word_id') then
        perform private.mv('invalid_move');
      end if;
      if (p ->> 'word_id') = any(private.conv_seen(p_session)) then perform private.mv('seen'); end if;
      select value into item from public.content_banks where bank = cfg ->> 'bank' and value ->> 'id' = p ->> 'word_id';
      if item is null then perform private.mv('invalid_move'); end if;
      sec := sec || jsonb_build_object('word', jsonb_build_object('text', item ->> 'text', 'units', item -> 'units', 'display', item -> 'display'));
      sec := jsonb_set(sec, array['seats', me, 'word'], jsonb_build_object('text', item ->> 'text'));
      return private.res(c || jsonb_build_object('phase', 'guess', 'card_id', item ->> 'id', 'length', jsonb_array_length(item -> 'units'),
        'mask', private.hm_mask(item -> 'units', item -> 'display', '[]'), 'guessed', '[]'::jsonb, 'misses', '[]'::jsonb,
        'errors', 0, 'max_errors', 6), sec, info);
    elsif typ = 'guess_letter' then
      if c ->> 'phase' <> 'guess' then perform private.mv('phase'); end if;
      if (c ->> 'guesser')::int <> seat then perform private.mv('not_your_turn'); end if;
      t := upper(coalesce(p ->> 'letter', ''));
      if t !~ '^[A-Z]$' then perform private.mv('invalid_move'); end if;
      if c -> 'guessed' ? t then perform private.mv('repeated'); end if;
      guessed := (c -> 'guessed') || to_jsonb(t);
      hit := (sec #> '{word,units}') ? t;
      mask := private.hm_mask(sec #> '{word,units}', sec #> '{word,display}', guessed);
      c := c || jsonb_build_object('guessed', guessed, 'mask', mask,
        'errors', (c ->> 'errors')::int + case when hit then 0 else 1 end,
        'misses', case when hit then c -> 'misses' else (c -> 'misses') || to_jsonb(t) end);
      found := not exists (select 1 from jsonb_array_elements(mask) x where x = 'null'::jsonb);
      if found or (c ->> 'errors')::int >= 6 then
        c := c || jsonb_build_object('phase', 'reveal', 'done', true, 'found', found, 'text', sec #>> '{word,text}',
          'mask', sec #> '{word,display}',
          'scores', jsonb_build_object(c ->> 'guesser', case when found then 1 else 0 end, c ->> 'giver', 0));
      end if;
      return private.res(c, sec, info);
    end if;
    perform private.mv('invalid_move');

  elsif m = 'nd_categories_stop' then
    if typ = 'round_loaded' then
      if c ->> 'phase' <> 'loaded' then perform private.mv('phase'); end if;
      c := jsonb_set(c, array['loaded', me], 'true');
      if c -> 'loaded' ? oth then
        c := c || jsonb_build_object('phase', 'write', 'letter', sec ->> 'letter', 'started_at', now(),
          'stop_after', now() + interval '10 seconds', 'deadline_at', now() + interval '120 seconds');
      end if;
      return private.res(c, sec, info);
    elsif typ in ('save_field', 'stop') then
      if c ->> 'phase' <> 'write' then perform private.mv('phase'); end if;
      if now() >= (c ->> 'deadline_at')::timestamptz then perform private.mv('time_up'); end if;
      drafts := case when typ = 'save_field' then jsonb_build_object(coalesce(p ->> 'category_id', ''), p) else p -> 'drafts' end;
      if jsonb_typeof(drafts) is distinct from 'object' then perform private.mv('invalid_move'); end if;
      for cat, d in select key, value from jsonb_each(drafts) loop
        if not (c -> 'categories' ? cat) or jsonb_typeof(d) <> 'object' then perform private.mv('invalid_move'); end if;
        t := coalesce(d ->> 'text', '');
        if char_length(t) > 80 then perform private.mv('invalid_text'); end if;
        if jsonb_typeof(d -> 'draft_revision') is distinct from 'number' then perform private.mv('invalid_move'); end if;
        rev := (d ->> 'draft_revision')::int;
        if rev > coalesce((sec #>> array['seats', me, 'drafts', cat, 'rev'])::int, 0) then
          sec := jsonb_set(sec, '{seats}', coalesce(sec -> 'seats', '{}') || jsonb_build_object(me,
            coalesce(sec #> array['seats', me], '{}') || jsonb_build_object('drafts',
              coalesce(sec #> array['seats', me, 'drafts'], '{}') || jsonb_build_object(cat, jsonb_build_object('text', t, 'rev', rev)))));
        elsif typ = 'save_field' then
          perform private.mv('stale_draft');
        end if;
      end loop;
      if typ = 'save_field' then return private.res(c, sec, info); end if;
      if now() < (c ->> 'stop_after')::timestamptz then perform private.mv('too_early'); end if;
      if exists (select 1 from jsonb_array_elements_text(c -> 'categories') k
                 where btrim(coalesce(sec #>> array['seats', me, 'drafts', k, 'text'], '')) = '') then
        perform private.mv('fields_missing');
      end if;
      return private.res(private.pb_freeze(c, sec, cfg ->> 'bank', seat), sec, info);
    elsif typ = 'expire' then
      if c ->> 'phase' = 'write' and now() >= (c ->> 'deadline_at')::timestamptz then
        return private.res(private.pb_freeze(c, sec, cfg ->> 'bank', null), sec, info);
      elsif c ->> 'phase' = 'validation' and now() >= (c ->> 'validation_deadline')::timestamptz then
        return private.res(private.pb_close(c, sec), sec, info);
      end if;
      perform private.mv('too_early');
    elsif typ in ('judge_entry', 'judge_identity', 'confirm_validation') then
      if c ->> 'phase' <> 'validation' then perform private.mv('phase'); end if;
      if now() >= (c ->> 'validation_deadline')::timestamptz then
        return private.res(private.pb_close(c, sec), sec, info);
      end if;
      if typ = 'confirm_validation' then
        c := jsonb_set(c, array['confirmed', me], 'true');
        if c -> 'confirmed' ? oth then return private.res(private.pb_close(c, sec), sec, info); end if;
        return private.res(c, sec, info);
      end if;
      cat := p ->> 'category_id';
      if not (c -> 'categories' ? coalesce(cat, '')) then perform private.mv('invalid_move'); end if;
      if typ = 'judge_entry' then
        if coalesce(p ->> 'seat', '') not in ('1', '2') or coalesce(p ->> 'verdict', '') not in ('accept', 'reject', 'unresolved') then
          perform private.mv('invalid_move');
        end if;
        if c #>> array['answers', p ->> 'seat', cat, 'status'] not in ('valid', 'unknown') then perform private.mv('invalid_move'); end if;
        d := jsonb_build_object('votes', coalesce(sec #> array['seats', me, 'votes'], '{}')
                                         || jsonb_build_object((p ->> 'seat') || ':' || cat, p ->> 'verdict'));
      else
        if jsonb_typeof(p -> 'same') <> 'boolean' then perform private.mv('invalid_move'); end if;
        d := jsonb_build_object('same', coalesce(sec #> array['seats', me, 'same'], '{}') || jsonb_build_object(cat, p -> 'same'));
      end if;
      sec := jsonb_set(sec, '{seats}', coalesce(sec -> 'seats', '{}')
                       || jsonb_build_object(me, coalesce(sec #> array['seats', me], '{}') || d));
      -- Un vote modifié remet à zéro les confirmations : chacun revoit l'arbitrage.
      return private.res(c || jsonb_build_object('confirmed', '{}'::jsonb), sec, info);
    end if;
    perform private.mv('invalid_move');

  elsif m = 'nd_name_three_call' then
    if typ = 'pass_round' then
      if c ->> 'phase' not in ('loading', 'live') then perform private.mv('phase'); end if;
      return private.res(c || jsonb_build_object('done', true, 'skipped', true, 'skipped_by', seat, 'phase', 'result'),
                         jsonb_build_object('seats', '{}'::jsonb), info);
    elsif typ = 'round_loaded' then
      if c ->> 'phase' <> 'loading' then perform private.mv('phase'); end if;
      if coalesce((c ->> 'need_call')::boolean, false) and coalesce((p ->> 'call')::boolean, false) is not true then
        perform private.mv('call_required');
      end if;
      c := jsonb_set(c, array['loaded', me], 'true');
      if c -> 'loaded' ? oth then
        c := c || jsonb_build_object('phase', 'live', 'starts_at', now() + interval '1500 milliseconds',
                                     'deadline_at', now() + interval '11500 milliseconds');
      end if;
      return private.res(c, sec, info);
    end if;
    if c ->> 'phase' <> 'live' then perform private.mv('phase'); end if;
    -- Accusé de réception manquant 750 ms après le départ : manche annulée sans point, nouvelle consigne ensuite.
    if now() > (c ->> 'starts_at')::timestamptz + interval '750 milliseconds' and not (c -> 'acks' ? '1' and c -> 'acks' ? '2')
       and typ in ('prompt_received', 'tick', 'verdict', 'interrupt', 'void_vote') then
      return private.res(c - 'text' || jsonb_build_object('done', true, 'void', 'loading', 'phase', 'result'),
                         jsonb_build_object('seats', '{}'::jsonb), info);
    end if;
    if typ = 'prompt_received' then
      if now() < (c ->> 'starts_at')::timestamptz then perform private.mv('too_early'); end if;
      if c -> 'acks' ? me then perform private.mv('repeated'); end if;
      resp := (sec ->> 'respondent')::int;
      c := jsonb_set(c, array['acks', me], 'true') || jsonb_build_object('text', sec ->> 'text', 'respondent', resp, 'judge', 3 - resp);
      return private.res(c, sec, info);
    elsif typ = 'verdict' then
      if not (c ? 'judge') or (c ->> 'judge')::int <> seat then perform private.mv('not_your_turn'); end if;
      if not (c -> 'acks' ? '1' and c -> 'acks' ? '2') then perform private.mv('waiting_ack'); end if;
      if jsonb_typeof(p -> 'success') <> 'boolean' then perform private.mv('invalid_move'); end if;
      return private.res(c || jsonb_build_object('done', true, 'phase', 'result', 'verdict', p -> 'success', 'judged_at', now(),
        'scores', jsonb_build_object(c ->> 'respondent', case when (p ->> 'success')::boolean then 3 else 0 end, c ->> 'judge', 0)),
        jsonb_build_object('seats', '{}'::jsonb), info);
    elsif typ = 'interrupt' then
      if now() >= (c ->> 'deadline_at')::timestamptz then perform private.mv('too_late'); end if;
      return private.res(c || jsonb_build_object('done', true, 'void', 'interrupted', 'phase', 'result'),
                         jsonb_build_object('seats', '{}'::jsonb), info);
    elsif typ = 'void_vote' then
      if now() < (c ->> 'deadline_at')::timestamptz + interval '120 seconds' then perform private.mv('too_early'); end if;
      if jsonb_typeof(p -> 'accept') <> 'boolean' then perform private.mv('invalid_move'); end if;
      c := jsonb_set(c, array['void_votes', me], p -> 'accept');
      if c #>> array['void_votes', me] = 'true' and c #>> array['void_votes', oth] = 'true' then
        return private.res(c || jsonb_build_object('done', true, 'void', 'unjudged', 'phase', 'result'),
                           jsonb_build_object('seats', '{}'::jsonb), info);
      end if;
      return private.res(c, sec, info);
    elsif typ = 'tick' then
      perform private.mv('nothing');
    end if;
    perform private.mv('invalid_move');
  end if;
  perform private.mv('invalid_move');
  return null;
end $$;

-- ---------------------------------------------------------------------------
-- Après la manche : corrections consensuelles (Cite trois), « Continuer » des deux, fin à 30 points.
-- ---------------------------------------------------------------------------
create or replace function public.round_after(p_session uuid, p_round int, p_type text, p_payload jsonb default '{}') returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  r record;
  cfg jsonb;
  rd public.session_rounds;
  c jsonb;
  me text;
  sess public.game_sessions;
  next_card jsonb;
begin
  select * into r from private.lock_session(p_session);
  me := r.seat::text;
  if (r.s).status <> 'playing' then return jsonb_build_object('ok', false, 'error', 'not_playing'); end if;
  cfg := private.version_config(r.s);
  if not (cfg ->> 'mechanic' = any(private.board_route7() || private.board_route8())) then return jsonb_build_object('ok', false, 'error', 'not_allowed'); end if;
  if p_round <> (r.s).current_round then return jsonb_build_object('ok', true, 'repeated', true); end if;
  select * into rd from public.session_rounds where session_id = p_session and round_no = p_round;
  c := rd.card;
  if not coalesce((c ->> 'done')::boolean, false) then return jsonb_build_object('ok', false, 'error', 'phase'); end if;

  if p_type = 'verdict' then
    -- Seul le sujet décide de la concordance ; une correction applique seulement la différence ;
    -- modifier le verdict remet à zéro les « Continuer » pour que chacun revoie le résultat.
    if c ->> 'mech' <> 'nd_predict' or coalesce((c ->> 'skipped')::boolean, false) or c ->> 'redacted' = 'true' then
      return jsonb_build_object('ok', false, 'error', 'not_allowed');
    end if;
    if (c ->> 'subject')::int <> r.seat then return jsonb_build_object('ok', false, 'error', 'not_your_turn'); end if;
    if jsonb_typeof(p_payload -> 'matches') <> 'boolean' then return jsonb_build_object('ok', false, 'error', 'invalid_move'); end if;
    if c -> 'verdict' = p_payload -> 'matches' then return jsonb_build_object('ok', true, 'repeated', true); end if;
    c := c || jsonb_build_object('verdict', p_payload -> 'matches', 'continue', '{}'::jsonb,
      'scores', jsonb_build_object(c ->> 'predictor', case when (p_payload ->> 'matches')::boolean then 1 else 0 end, c ->> 'subject', 0));
    update public.session_rounds set card = c where session_id = p_session and round_no = p_round;
    perform private.bump_session(p_session, 'move');
    return jsonb_build_object('ok', true);
  elsif p_type = 'correction_request' then
    -- Cite trois : proposer le verdict inverse ; appliqué seulement avec l'accord des deux, une seule fois.
    if c ->> 'mech' <> 'nd_name_three_call' or jsonb_typeof(c -> 'verdict') is distinct from 'boolean' then
      return jsonb_build_object('ok', false, 'error', 'not_allowed');
    end if;
    if c ? 'correction' then return jsonb_build_object('ok', true, 'repeated', true); end if;
    c := c || jsonb_build_object('correction', jsonb_build_object('proposed', not (c ->> 'verdict')::boolean, 'by', r.seat,
                                                                   'votes', jsonb_build_object(me, true)),
                                 'continue', '{}'::jsonb);
    update public.session_rounds set card = c where session_id = p_session and round_no = p_round;
    perform private.bump_session(p_session, 'move');
    return jsonb_build_object('ok', true);
  elsif p_type = 'correction_vote' then
    if not (c ? 'correction') then return jsonb_build_object('ok', false, 'error', 'not_allowed'); end if;
    if jsonb_typeof(p_payload -> 'accept') is distinct from 'boolean' then
      return jsonb_build_object('ok', false, 'error', 'invalid_move');
    end if;
    if c #> array['correction', 'votes'] ? me then return jsonb_build_object('ok', true, 'repeated', true); end if;
    if (p_payload ->> 'accept')::boolean then
      c := (c - 'correction') || jsonb_build_object('verdict', c #> '{correction,proposed}', 'corrected', true,
        'scores', jsonb_build_object(c ->> 'respondent', case when (c #>> '{correction,proposed}')::boolean then 3 else 0 end,
                                     c ->> 'judge', 0));
    else
      c := (c - 'correction') || jsonb_build_object('correction_refused', true);
    end if;
    update public.session_rounds set card = c where session_id = p_session and round_no = p_round;
    perform private.bump_session(p_session, 'move');
    return jsonb_build_object('ok', true);
  elsif p_type <> 'continue' then
    return jsonb_build_object('ok', false, 'error', 'invalid_move');
  end if;
  if c ? 'correction' then return jsonb_build_object('ok', false, 'error', 'correction_pending'); end if;

  if c -> 'continue' ? me then return jsonb_build_object('ok', true, 'repeated', true); end if;
  c := jsonb_set(c, array['continue', me], 'true');
  update public.session_rounds set card = c where session_id = p_session and round_no = p_round;
  if not (c -> 'continue' ? (3 - r.seat)::text) then
    perform private.bump_session(p_session, 'move');
    return jsonb_build_object('ok', true, 'waiting', true);
  end if;

  -- Cite trois : bilan à 30 points confirmé par les deux, fin avec vainqueur.
  if cfg ->> 'mechanic' = 'nd_name_three_call' and (
       select greatest(coalesce(sum((card #>> '{scores,1}')::int), 0), coalesce(sum((card #>> '{scores,2}')::int), 0))
       from public.session_rounds where session_id = p_session) >= coalesce((cfg ->> 'target')::int, 30) then
    update public.game_sessions set status = 'ended', ended_at = now(), total_rounds = p_round,
      result = private.compute_result(r.s, cfg) || jsonb_build_object('target_reached', true)
      where id = p_session;
    perform private.bump_session(p_session, 'ended');
    return jsonb_build_object('ok', true, 'ended', true);
  end if;

  -- Deux accords : manche suivante, ou fin (nombre de manches atteint ou plus aucune carte autorisée).
  if p_round < (r.s).total_rounds then
    update public.game_sessions set current_round = p_round + 1 where id = p_session returning * into sess;
    begin
      next_card := private.draw_round_card(sess, cfg);
    exception when raise_exception then
      if sqlerrm <> 'not_enough_cards' then raise; end if;
      next_card := null;
    end;
    if next_card is not null then
      insert into public.session_rounds (session_id, round_no, card) values (p_session, p_round + 1, next_card);
      perform private.bump_session(p_session, 'round');
      return jsonb_build_object('ok', true);
    end if;
    update public.game_sessions set current_round = p_round where id = p_session;
  end if;
  update public.game_sessions set status = 'ended', ended_at = now(), total_rounds = p_round,
    result = private.compute_result(r.s, cfg) || jsonb_build_object('shortened', p_round < (r.s).total_rounds)
    where id = p_session;
  perform private.bump_session(p_session, 'ended');
  return jsonb_build_object('ok', true, 'ended', true);
end $$;

grant execute on function public.round_after(uuid, int, text, jsonb) to authenticated;

-- ---------------------------------------------------------------------------
-- Partenaire automatique de test (famille 8).
-- ---------------------------------------------------------------------------
create or replace function private.board_bot8(m text, c jsonb, sec jsonb, seat int) returns jsonb
language plpgsql volatile security definer set search_path = '' as $$
declare
  me text := seat::text;
  l text;
  cat text;
  w text;
  k record;
begin
  if coalesce((c ->> 'done')::boolean, false) then return null; end if;
  if m = 'nd_hangman' then
    if c ->> 'phase' = 'choose' and (c ->> 'giver')::int = seat then
      return jsonb_build_object('type', 'choose_word', 'payload', jsonb_build_object('word_id', sec #>> array['seats', me, 'choices', '0', 'id']));
    elsif c ->> 'phase' = 'guess' and (c ->> 'guesser')::int = seat then
      select x into l from unnest(string_to_array('E,A,S,R,I,N,T,U,L,O,M,D,P,C,F,B,V,H,G,J,Q,Z,Y,X,K,W', ',')) x
        where not (c -> 'guessed' ? x) limit 1;
      return jsonb_build_object('type', 'guess_letter', 'payload', jsonb_build_object('letter', l));
    end if;
    return null;
  elsif m = 'nd_categories_stop' then
    if c ->> 'phase' = 'loaded' and not (c -> 'loaded' ? me) then return '{"type": "round_loaded", "payload": {}}'; end if;
    if c ->> 'phase' = 'write' then
      select x into cat from jsonb_array_elements_text(c -> 'categories') x
        where sec #> array['seats', me, 'drafts', x] is null limit 1;
      if cat is null then return null; end if;
      select value ->> 'text' into w from public.content_banks
        where bank = 'petit_bac' and value ->> 'cat' = cat and left(value -> 'aliases' ->> 0, 1) = c ->> 'letter'
        order by random() limit 1;
      return jsonb_build_object('type', 'save_field', 'payload',
        jsonb_build_object('category_id', cat, 'text', coalesce(w, ''), 'draft_revision', 1));
    end if;
    if c ->> 'phase' = 'validation' and not (c -> 'confirmed' ? me) then
      for k in select s.key st, a.key cat from jsonb_each(c -> 'answers') s, jsonb_each(s.value) a
               where a.value ->> 'status' = 'unknown' and sec #> array['seats', me, 'votes', s.key || ':' || a.key] is null loop
        return jsonb_build_object('type', 'judge_entry', 'payload',
          jsonb_build_object('seat', k.st::int, 'category_id', k.cat, 'verdict', 'accept'));
      end loop;
      return '{"type": "confirm_validation", "payload": {}}';
    end if;
    return null;
  elsif m = 'nd_name_three_call' then
    if c ->> 'phase' = 'loading' and not (c -> 'loaded' ? me) then return '{"type": "round_loaded", "payload": {"call": true}}'; end if;
    if c ->> 'phase' = 'live' then
      if not (c -> 'acks' ? me) and now() >= (c ->> 'starts_at')::timestamptz then return '{"type": "prompt_received", "payload": {}}'; end if;
      if (c ->> 'judge')::int = seat and c -> 'acks' ? '1' and c -> 'acks' ? '2' then
        return jsonb_build_object('type', 'verdict', 'payload', jsonb_build_object('success', private.rnd(2) = 1));
      end if;
    end if;
    return null;
  end if;
  return null;
end $$;

create or replace function private.board_setup_any(s public.game_sessions, cfg jsonb) returns jsonb
language plpgsql volatile security definer set search_path = '' as $$
begin
  if cfg ->> 'mechanic' = any(private.board_route8()) then return private.board_setup8(s, cfg); end if;
  if cfg ->> 'mechanic' = any(private.board_route7()) then return private.board_setup7(s, cfg); end if;
  if cfg ->> 'mechanic' = any(private.board_route6()) then return private.board_setup6(s, cfg); end if;
  if cfg ->> 'mechanic' = any(private.board_route5()) then return private.board_setup5(s, cfg); end if;
  if cfg ->> 'mechanic' = any(private.board_route4()) then return private.board_setup4(s, cfg); end if;
  if cfg ->> 'mechanic' = any(private.board_route3()) then return private.board_setup3(s, cfg); end if;
  return private.board_setup(s, cfg);
end $$;

create or replace function private.board_apply_any(m text, c jsonb, sec jsonb, seat int, typ text, p jsonb, p_session uuid) returns jsonb
language plpgsql volatile security definer set search_path = '' as $$
begin
  if m = any(private.board_route8()) then return private.board_apply8(m, c, sec, seat, typ, p, p_session); end if;
  if m = any(private.board_route7()) then return private.board_apply7(m, c, sec, seat, typ, p, p_session); end if;
  if m = any(private.board_route6()) then return private.board_apply6(m, c, sec, seat, typ, p, p_session); end if;
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
  if m = any(private.board_route8()) then return private.board_bot8(m, c, sec, seat); end if;
  if m = any(private.board_route7()) then return private.board_bot7(m, c, sec, seat); end if;
  if m = any(private.board_route6()) then return private.board_bot6(m, c, sec, seat); end if;
  if m = any(private.board_route5()) then return private.board_bot5(m, c, sec, seat); end if;
  if m = any(private.board_route4()) then return private.board_bot4(m, c, sec, seat); end if;
  if m = any(private.board_route3()) then return private.board_bot3(m, c, sec, seat); end if;
  return private.board_bot(m, c, sec, seat);
end $$;

create or replace function private.bot_step(p_session uuid, p_seat int) returns boolean
language plpgsql security definer set search_path = '' as $$
declare
  s public.game_sessions;
  cfg jsonb;
  rnd public.session_rounds;
  st jsonb;
  p jsonb;
  res jsonb;
  list_key text;
  mv jsonb;
begin
  select * into s from public.game_sessions where id = p_session;
  if s.status = 'lobby' then
    update public.session_prefs b set adult = h.adult, excluded_topics = h.excluded_topics, updated_at = now()
      from public.session_prefs h
      where b.session_id = p_session and b.seat = p_seat and h.session_id = p_session and h.seat = 3 - p_seat
        and (b.adult, b.excluded_topics) is distinct from (h.adult, h.excluded_topics);
    if exists (select 1 from public.session_players where session_id = p_session and seat = p_seat and ready_at is null) then
      res := public.set_ready(p_session, true);
      return coalesce((res ->> 'ok')::boolean, false);
    end if;
    return false;
  end if;
  if s.status not in ('playing', 'ended') then return false; end if;
  cfg := private.version_config(s);
  select * into rnd from public.session_rounds where session_id = p_session and round_no = s.current_round;
  if rnd.session_id is null then return false; end if;

  if cfg ->> 'engine' = 'board' then
    if s.status <> 'playing' then return false; end if;
    if rnd.revealed_at is not null then
      if cfg ->> 'mechanic' = any(private.board_route7() || private.board_route8()) then return private.bot_after7(p_session, p_seat, rnd); end if;
      return false;
    end if;
    mv := private.board_bot_any(cfg ->> 'mechanic', rnd.card,
                            coalesce((select secret from private.round_secrets where session_id = p_session and round_no = rnd.round_no), '{}'),
                            p_seat);
    if mv is null then return false; end if;
    res := public.play_move(p_session, rnd.round_no, gen_random_uuid(), mv ->> 'type', coalesce(mv -> 'payload', '{}'));
    return coalesce((res ->> 'ok')::boolean, false);
  end if;
  if cfg ->> 'engine' is distinct from 'rounds' then return false; end if;

  if rnd.revealed_at is null then
    if s.status <> 'playing' then return false; end if;
    list_key := 'steps';
  elsif rnd.revealed_at <= now() then
    list_key := 'after';
  else
    return false;
  end if;

  for st in select e.value from jsonb_array_elements(coalesce(cfg -> list_key, '[]')) e loop
    if not (p_seat = any(private.step_seats(st, rnd.card))) then continue; end if;
    if exists (select 1 from public.session_answers a where a.session_id = p_session and a.round_no = rnd.round_no
               and a.step = st ->> 'key' and a.seat = p_seat) then
      continue;
    end if;
    if st ? 'after' and not exists (select 1 from public.session_answers a where a.session_id = p_session
                                    and a.round_no = rnd.round_no and a.step = st ->> 'after') then
      return false;
    end if;
    p := private.bot_payload(st, rnd.card, p_session, rnd.round_no, p_seat);
    res := case when p is null then null else public.submit_answer(p_session, rnd.round_no, st ->> 'key', p, false) end;
    if coalesce((res ->> 'ok')::boolean, false) then return true; end if;
    if coalesce((st ->> 'skippable')::boolean, false) then
      res := public.submit_answer(p_session, rnd.round_no, st ->> 'key', null, true);
      return coalesce((res ->> 'ok')::boolean, false);
    end if;
    return false;
  end loop;
  return false;
end $$;

-- Retrait d'un accord +18 : Cite trois suit la même purge que les jeux de conversation.
create or replace function public.set_session_prefs(p_session uuid, p_adult boolean, p_excluded text[]) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  r record;
  cfg jsonb;
  cleaned text[];
  prev public.session_prefs;
  rd public.session_rounds;
begin
  select * into r from private.lock_session(p_session);
  if (r.s).status not in ('lobby', 'playing', 'paused') then return jsonb_build_object('ok', false, 'error', 'not_playing'); end if;
  select coalesce(array_agg(distinct t order by t), '{}') into cleaned
    from unnest(coalesce(p_excluded, '{}')) t where t in ('passe', 'sante_sexuelle', 'numerique', 'desir');
  if p_adult and not coalesce((select intimate_opt_in from public.profiles where id = auth.uid()), false) then
    return jsonb_build_object('ok', false, 'error', 'content_not_enabled');
  end if;
  select * into prev from public.session_prefs where session_id = p_session and seat = r.seat;
  if prev.adult = coalesce(p_adult, false) and prev.excluded_topics = cleaned then
    return jsonb_build_object('ok', true, 'repeated', true);
  end if;
  insert into public.session_prefs (session_id, seat, user_id, adult, excluded_topics, updated_at)
    values (p_session, r.seat, auth.uid(), coalesce(p_adult, false), cleaned, now())
    on conflict (session_id, seat) do update set adult = excluded.adult, excluded_topics = excluded.excluded_topics,
      user_id = excluded.user_id, updated_at = now();

  cfg := private.version_config(r.s);
  if (r.s).status = 'lobby' then
    update public.session_players set ready_at = null where session_id = p_session;
  elsif cfg ->> 'mechanic' = any(private.board_route7()) or cfg ->> 'mechanic' = 'nd_name_three_call' then
    if not private.adult_allowed(p_session) then perform private.conv_redact_adult(p_session); end if;
  elsif cfg ->> 'engine' = 'rounds' then
    -- Carte en cours devenue inéligible et non révélée : elle est remplacée, ses réponses effacées.
    select * into rd from public.session_rounds where session_id = p_session and round_no = (r.s).current_round;
    if rd.revealed_at is null and rd.card ? 'id'
       and exists (select 1 from public.game_cards c where c.id = rd.card ->> 'id'
                   and ((c.adult and not private.adult_allowed(p_session)) or c.topic_tags && private.excluded_tags(p_session))) then
      delete from public.session_answers where session_id = p_session and round_no = rd.round_no;
      if private.deck_available(r.s) > 0 then
        update public.session_rounds set card = private.draw_round_card(r.s, cfg), started_at = now()
          where session_id = p_session and round_no = rd.round_no;
      else
        -- Plus aucune carte possible : la partie s'arrête ici, sans rien révéler.
        delete from public.session_rounds where session_id = p_session and round_no = rd.round_no;
        update public.game_sessions set status = 'ended', ended_at = now(), current_round = rd.round_no - 1,
          total_rounds = greatest(rd.round_no - 1, 1) where id = p_session;
      end if;
    end if;
  end if;
  perform private.bump_session(p_session, 'prefs');
  return jsonb_build_object('ok', true);
end $$;
