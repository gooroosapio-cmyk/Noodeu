-- Jeux de conversation (catégorie 3, kit C03/C04 V1, espace noodeu_c34_v1) : Je n'ai jamais (G02), Tu préfères (G03),
-- Qui de nous deux ? (G04), Devine ma réponse (G05), Complète la phrase (G09), D'accord ou pas d'accord ? (G10),
-- Action ou Vérité (G01), Deux vérités et un mensonge (G08).
-- Cartes tirées sans remise dans content_banks, côté serveur, filtre +18 appliqué avant tout tirage ; réponses scellées
-- dans private.round_secrets jusqu'à la révélation commune ; un passage clôt la manche sans rien révéler ;
-- la manche suivante exige « Continuer » des deux (public.round_after).

create or replace function private.board_route7() returns text[]
language sql immutable set search_path = '' as $$
  select array['nd_never', 'nd_dilemma', 'nd_duo_target', 'nd_opinion', 'nd_sentence', 'nd_predict', 'nd_truth_dare', 'nd_two_truths'] $$;

-- Identifiants de cartes déjà vues pendant la partie (cartes tirées et cartes remplacées).
create or replace function private.conv_seen(p_session uuid) returns text[]
language sql stable security definer set search_path = '' as $$
  select coalesce(array_agg(x), '{}') from (
    select card ->> 'card_id' x from public.session_rounds where session_id = p_session and card ? 'card_id'
    union all
    select jsonb_array_elements_text(coalesce(card -> 'seen', '[]')) from public.session_rounds where session_id = p_session) t
  where x is not null $$;

-- Tirage d'une carte autorisée : jamais vue, et adulte seulement si les deux accords sont actifs.
create or replace function private.conv_draw(p_session uuid, p_bank text, p_kind text default null, p_extra_seen text[] default '{}')
returns jsonb
language sql volatile security definer set search_path = '' as $$
  select value from public.content_banks
  where bank = p_bank
    and not ((value ->> 'id') = any(private.conv_seen(p_session) || p_extra_seen))
    and (not coalesce((value ->> 'adult')::boolean, true) or private.adult_allowed(p_session))
    and (p_kind is null or value ->> 'kind' = p_kind)
  order by random() limit 1 $$;

-- Carte publique : texte et options seulement (jamais de note éditoriale).
create or replace function private.conv_card(item jsonb) returns jsonb
language sql immutable set search_path = '' as $$
  select jsonb_strip_nulls(jsonb_build_object('card_id', item ->> 'id', 'text', item ->> 'text', 'prompt', item ->> 'prompt',
    'options', item -> 'options', 'prefix', item ->> 'prefix', 'kind', item ->> 'kind',
    'adult', coalesce((item ->> 'adult')::boolean, false), 'theme', item ->> 'theme')) $$;

create or replace function private.board_setup7(s public.game_sessions, cfg jsonb) returns jsonb
language plpgsql volatile security definer set search_path = '' as $$
declare
  m text := cfg ->> 'mechanic';
  first int := private.first_seat(s);
  item jsonb;
  base jsonb;
begin
  base := jsonb_build_object('mech', m, 'first', first, 'locked', '{}'::jsonb, 'continue', '{}'::jsonb, 'done', false,
                             '_secret', '{"seats": {}}'::jsonb);
  if m = 'nd_truth_dare' then
    return base || jsonb_build_object('active', first, 'phase', 'choice');
  elsif m = 'nd_two_truths' then
    return base || jsonb_build_object('author', first, 'guesser', 3 - first, 'phase', 'write');
  end if;
  item := private.conv_draw(s.id, cfg ->> 'bank');
  if item is null then raise exception 'not_enough_cards'; end if;
  base := base || private.conv_card(item);
  if m = 'nd_predict' then
    base := base || jsonb_build_object('subject', first, 'predictor', 3 - first);
  end if;
  return base;
end $$;

-- Réponse scellée valide pour une carte simultanée ; lève move:invalid_move sinon.
create or replace function private.conv_answer(m text, c jsonb, p jsonb) returns jsonb
language plpgsql immutable set search_path = '' as $$
declare v text; t text;
begin
  if m in ('nd_never', 'nd_opinion', 'nd_dilemma') then
    v := p ->> 'choice';
    if v is null or not exists (select 1 from jsonb_array_elements(c -> 'options') o where o ->> 'id' = v) then
      perform private.mv('invalid_move');
    end if;
    return jsonb_build_object('choice', v);
  elsif m = 'nd_duo_target' then
    if jsonb_typeof(p -> 'seat') <> 'number' or (p ->> 'seat') not in ('1', '2') then perform private.mv('invalid_move'); end if;
    return jsonb_build_object('seat', (p ->> 'seat')::int);
  elsif m in ('nd_sentence', 'nd_predict') then
    t := btrim(coalesce(p ->> 'text', ''));
    if t = '' or char_length(t) > 1000 then perform private.mv('invalid_text'); end if;
    return jsonb_build_object('text', t);
  end if;
  perform private.mv('invalid_move');
  return null;
end $$;

create or replace function private.board_apply7(m text, c jsonb, sec jsonb, seat int, typ text, p jsonb, p_session uuid) returns jsonb
language plpgsql volatile security definer set search_path = '' as $$
declare
  me text := seat::text;
  oth int := 3 - seat;
  cfg jsonb;
  item jsonb;
  t text;
  st jsonb;
  ids text[];
  lie text;
  guess text;
begin
  select private.version_config(g) into cfg from public.game_sessions g where g.id = p_session;

  -- Passer : la manche se clôt sans pénalité et sans révéler aucune réponse scellée.
  if typ = 'skip_round' then
    return private.res(c || jsonb_build_object('done', true, 'skipped', true, 'skipped_by', seat, 'locked', '{}'::jsonb),
                       '{"seats": {}}'::jsonb);
  end if;

  if m = 'nd_truth_dare' then
    if (c ->> 'active')::int <> seat then perform private.mv('not_your_turn'); end if;
    if typ = 'choose_kind' then
      if c ->> 'phase' <> 'choice' then perform private.mv('phase'); end if;
      if coalesce(p ->> 'kind', '') not in ('truth', 'dare') then perform private.mv('invalid_move'); end if;
      item := private.conv_draw(p_session, cfg ->> 'bank', p ->> 'kind');
      if item is null then perform private.mv('no_cards'); end if;
      return private.res(c || private.conv_card(item) || jsonb_build_object('phase', 'respond'), sec);
    elsif typ = 'replace_card' then
      if c ->> 'phase' <> 'respond' then perform private.mv('phase'); end if;
      item := private.conv_draw(p_session, cfg ->> 'bank', c ->> 'kind', array[c ->> 'card_id']);
      if item is null then perform private.mv('no_cards'); end if;
      c := c || jsonb_build_object('seen', coalesce(c -> 'seen', '[]') || to_jsonb(c ->> 'card_id'));
      return private.res(c - 'prompt' || private.conv_card(item), sec);
    elsif typ = 'submit_text' then
      if c ->> 'phase' <> 'respond' or c ->> 'kind' <> 'truth' then perform private.mv('phase'); end if;
      t := btrim(coalesce(p ->> 'text', ''));
      if t = '' or char_length(t) > 1000 then perform private.mv('invalid_text'); end if;
      return private.res(c || jsonb_build_object('done', true, 'phase', 'reveal', 'response', jsonb_build_object('text', t)), sec);
    elsif typ = 'submit_action' then
      if c ->> 'phase' <> 'respond' or c ->> 'kind' <> 'dare' then perform private.mv('phase'); end if;
      t := nullif(btrim(coalesce(p ->> 'text', '')), '');
      if t is not null and char_length(t) > 1000 then perform private.mv('invalid_text'); end if;
      -- Action marquée faite, sans preuve ; un texte n'est partagé que si la personne le choisit.
      return private.res(c || jsonb_build_object('done', true, 'phase', 'reveal',
        'response', jsonb_strip_nulls(jsonb_build_object('status', 'done', 'text', t))), sec);
    end if;
    perform private.mv('invalid_move');

  elsif m = 'nd_two_truths' then
    if typ = 'publish_three' then
      if c ->> 'phase' <> 'write' then perform private.mv('phase'); end if;
      if (c ->> 'author')::int <> seat then perform private.mv('not_your_turn'); end if;
      if coalesce((p ->> 'confirmed_truths')::boolean, false) is not true then perform private.mv('invalid_move'); end if;
      if jsonb_typeof(p -> 'statements') <> 'array' or jsonb_array_length(p -> 'statements') <> 3 then perform private.mv('invalid_move'); end if;
      select array_agg(x ->> 'id' order by x ->> 'id') into ids from jsonb_array_elements(p -> 'statements') x;
      if ids is distinct from array['s1', 's2', 's3'] then perform private.mv('invalid_move'); end if;
      if exists (select 1 from jsonb_array_elements(p -> 'statements') x
                 where btrim(coalesce(x ->> 'text', '')) = '' or char_length(btrim(x ->> 'text')) > 240) then
        perform private.mv('invalid_text');
      end if;
      if (select count(distinct lower(btrim(x ->> 'text'))) from jsonb_array_elements(p -> 'statements') x) <> 3 then
        perform private.mv('duplicate_text');
      end if;
      lie := p ->> 'lie_statement_id';
      if lie is null or lie not in ('s1', 's2', 's3') then perform private.mv('invalid_move'); end if;
      sec := jsonb_set(sec, '{seats}', coalesce(sec -> 'seats', '{}') || jsonb_build_object(me, jsonb_build_object('lie', lie)));
      return private.res(c || jsonb_build_object('phase', 'guess', 'statements',
        (select jsonb_agg(jsonb_build_object('id', x ->> 'id', 'text', btrim(x ->> 'text')) order by x ->> 'id')
         from jsonb_array_elements(p -> 'statements') x)), sec);
    elsif typ = 'lock_guess' then
      if c ->> 'phase' <> 'guess' then perform private.mv('phase'); end if;
      if (c ->> 'guesser')::int <> seat then perform private.mv('not_your_turn'); end if;
      guess := p ->> 'statement_id';
      if guess is null or guess not in ('s1', 's2', 's3') then perform private.mv('invalid_move'); end if;
      lie := sec #>> array['seats', c ->> 'author', 'lie'];
      return private.res(c || jsonb_build_object('done', true, 'phase', 'reveal', 'guess', guess, 'lie', lie, 'found', guess = lie,
        'scores', jsonb_build_object(me, case when guess = lie then 1 else 0 end, c ->> 'author', case when guess = lie then 0 else 1 end)),
        sec);
    end if;
    perform private.mv('invalid_move');
  end if;

  -- Cartes simultanées : chacun scelle sa réponse ; la seconde révèle les deux dans la même transaction.
  if typ <> 'lock' then perform private.mv('invalid_move'); end if;
  if c -> 'locked' ? me then perform private.mv('locked'); end if;
  st := private.conv_answer(m, c, p);
  sec := jsonb_set(sec, '{seats}', coalesce(sec -> 'seats', '{}') || jsonb_build_object(me, st));
  c := jsonb_set(c, array['locked', me], 'true');
  if c -> 'locked' ? oth::text then
    c := c || jsonb_build_object('done', true, 'answers', jsonb_build_object(me, st, oth::text, sec #> array['seats', oth::text]));
  end if;
  return private.res(c, sec);
end $$;

-- ---------------------------------------------------------------------------
-- Après la révélation : verdict du sujet (Devine ma réponse) et « Continuer » des deux.
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
  if not (cfg ->> 'mechanic' = any(private.board_route7())) then return jsonb_build_object('ok', false, 'error', 'not_allowed'); end if;
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
  elsif p_type <> 'continue' then
    return jsonb_build_object('ok', false, 'error', 'invalid_move');
  end if;

  if c -> 'continue' ? me then return jsonb_build_object('ok', true, 'repeated', true); end if;
  c := jsonb_set(c, array['continue', me], 'true');
  update public.session_rounds set card = c where session_id = p_session and round_no = p_round;
  if not (c -> 'continue' ? (3 - r.seat)::text) then
    perform private.bump_session(p_session, 'move');
    return jsonb_build_object('ok', true, 'waiting', true);
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
-- Partenaire automatique de test
-- ---------------------------------------------------------------------------
create or replace function private.board_bot7(m text, c jsonb, sec jsonb, seat int) returns jsonb
language plpgsql volatile security definer set search_path = '' as $$
declare me text := seat::text;
begin
  if coalesce((c ->> 'done')::boolean, false) then return null; end if;
  if m = 'nd_truth_dare' then
    if (c ->> 'active')::int <> seat then return null; end if;
    if c ->> 'phase' = 'choice' then return '{"type": "choose_kind", "payload": {"kind": "truth"}}'; end if;
    if c ->> 'kind' = 'truth' then return '{"type": "submit_text", "payload": {"text": "Réponse du partenaire automatique de test."}}'; end if;
    return '{"type": "submit_action", "payload": {"status": "done"}}';
  elsif m = 'nd_two_truths' then
    if c ->> 'phase' = 'write' and (c ->> 'author')::int = seat then
      return jsonb_build_object('type', 'publish_three', 'payload', jsonb_build_object('confirmed_truths', true,
        'lie_statement_id', 's' || (1 + private.rnd(3)), 'statements', '[{"id": "s1", "text": "Affirmation de test numéro un."},
          {"id": "s2", "text": "Affirmation de test numéro deux."}, {"id": "s3", "text": "Affirmation de test numéro trois."}]'::jsonb));
    elsif c ->> 'phase' = 'guess' and (c ->> 'guesser')::int = seat then
      return jsonb_build_object('type', 'lock_guess', 'payload', jsonb_build_object('statement_id', 's' || (1 + private.rnd(3))));
    end if;
    return null;
  end if;
  if c -> 'locked' ? me then return null; end if;
  if m in ('nd_never', 'nd_opinion', 'nd_dilemma') then
    return jsonb_build_object('type', 'lock', 'payload', jsonb_build_object('choice', c -> 'options' -> private.rnd(2) ->> 'id'));
  elsif m = 'nd_duo_target' then
    return jsonb_build_object('type', 'lock', 'payload', jsonb_build_object('seat', 1 + private.rnd(2)));
  end if;
  return '{"type": "lock", "payload": {"text": "Réponse du partenaire automatique de test."}}';
end $$;

-- ---------------------------------------------------------------------------
-- Aiguillage : la famille 7 rejoint les familles 2 à 6.
-- ---------------------------------------------------------------------------
create or replace function private.board_setup_any(s public.game_sessions, cfg jsonb) returns jsonb
language plpgsql volatile security definer set search_path = '' as $$
begin
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
  if m = any(private.board_route7()) then return private.board_bot7(m, c, sec, seat); end if;
  if m = any(private.board_route6()) then return private.board_bot6(m, c, sec, seat); end if;
  if m = any(private.board_route5()) then return private.board_bot5(m, c, sec, seat); end if;
  if m = any(private.board_route4()) then return private.board_bot4(m, c, sec, seat); end if;
  if m = any(private.board_route3()) then return private.board_bot3(m, c, sec, seat); end if;
  return private.board_bot(m, c, sec, seat);
end $$;

-- Partenaire automatique : après la révélation d'un jeu de conversation, il valide (sujet) puis continue.
create or replace function private.bot_after7(p_session uuid, p_seat int, rnd public.session_rounds) returns boolean
language plpgsql security definer set search_path = '' as $$
declare res jsonb;
begin
  if rnd.card ->> 'mech' = 'nd_predict' and (rnd.card ->> 'subject')::int = p_seat
     and not coalesce((rnd.card ->> 'skipped')::boolean, false) and not (rnd.card ? 'verdict') then
    res := public.round_after(p_session, rnd.round_no, 'verdict', jsonb_build_object('matches', private.rnd(2) = 1));
    return coalesce((res ->> 'ok')::boolean, false);
  end if;
  if rnd.card -> 'continue' ? p_seat::text then return false; end if;
  res := public.round_after(p_session, rnd.round_no, 'continue');
  return coalesce((res ->> 'ok')::boolean, false);
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
      if cfg ->> 'mechanic' = any(private.board_route7()) then return private.bot_after7(p_session, p_seat, rnd); end if;
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

-- ---------------------------------------------------------------------------
-- Accord +18 d'une partie (salon et en cours de partie). Retirer son accord est immédiat :
-- une carte adulte en cours est interrompue sans pénalité, ses réponses scellées effacées, et les cartes
-- adultes déjà jouées ne sont plus projetées (texte et réponses retirés de l'historique de la partie).
-- ---------------------------------------------------------------------------
create or replace function private.conv_redact_adult(p_session uuid) returns void
language plpgsql security definer set search_path = '' as $$
declare rd public.session_rounds;
begin
  for rd in select * from public.session_rounds where session_id = p_session and coalesce((card ->> 'adult')::boolean, false) loop
    update public.session_rounds set card = (card - 'text' - 'prompt' - 'options' - 'prefix' - 'answers' - 'response')
      || jsonb_build_object('redacted', true, 'done', true, 'interrupted', not coalesce((card ->> 'done')::boolean, false),
                            'locked', '{}'::jsonb),
      revealed_at = coalesce(revealed_at, now())
      where session_id = p_session and round_no = rd.round_no;
    update private.round_secrets set secret = '{"seats": {}}' where session_id = p_session and round_no = rd.round_no;
  end loop;
end $$;

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
  elsif cfg ->> 'mechanic' = any(private.board_route7()) then
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

grant execute on function public.set_session_prefs(uuid, boolean, text[]) to authenticated;
