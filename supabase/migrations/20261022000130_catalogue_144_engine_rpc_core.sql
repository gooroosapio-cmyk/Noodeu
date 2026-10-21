create or replace function public.create_session(p_game text) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  me uuid := auth.uid();
  c uuid := private.my_couple_id();
  g public.games;
  v public.game_versions;
  existing public.game_sessions;
  new_id uuid;
  ended record;
begin
  if c is null then return jsonb_build_object('ok', false, 'error', 'no_couple'); end if;
  select * into g from public.games where id = p_game and status = 'published';
  if g.id is null or g.implementation <> 'playable' then return jsonb_build_object('ok', false, 'error', 'game_unavailable'); end if;
  if g.content_level = 'intime' and exists (
      select 1 from public.couple_members cm join public.profiles p on p.id = cm.user_id
      where cm.couple_id = c and cm.left_at is null and not p.intimate_opt_in) then
    return jsonb_build_object('ok', false, 'error', 'content_not_enabled');
  end if;

  perform pg_advisory_xact_lock(hashtext('couple-session:' || c::text));
  for ended in select id from public.game_sessions where couple_id = c and status = 'ended' loop
    perform public.close_session(ended.id);
  end loop;

  select * into existing from public.game_sessions where couple_id = c and status in ('lobby', 'playing', 'paused');
  if existing.id is not null then
    if existing.game_id = p_game then
      return jsonb_build_object('ok', true, 'session_id', existing.id, 'existing', true);
    end if;
    return jsonb_build_object('ok', false, 'error', 'session_in_progress', 'session_id', existing.id, 'game_id', existing.game_id);
  end if;

  select * into v from public.game_versions where game_id = g.id and version = g.current_version and published_at is not null;
  if v.game_id is null then return jsonb_build_object('ok', false, 'error', 'game_unavailable'); end if;

  insert into public.game_sessions (couple_id, game_id, game_version, created_by, total_rounds, settings)
    values (c, g.id, v.version, me, coalesce((v.config ->> 'rounds')::int, 1),
            coalesce((select jsonb_object_agg(k, val -> 'default') from jsonb_each(v.config -> 'settings') as e(k, val)), '{}'))
    returning id into new_id;
  insert into public.session_players (session_id, user_id, seat)
    select new_id, cm.user_id, case when cm.user_id = me then 1 else 2 end
    from public.couple_members cm where cm.couple_id = c and cm.left_at is null;
  insert into public.session_prefs (session_id, seat, user_id)
    select session_id, seat, user_id from public.session_players where session_id = new_id;
  perform private.bump_session(new_id, 'created');
  return jsonb_build_object('ok', true, 'session_id', new_id, 'existing', false);
end $$;

create or replace function public.set_ready(p_session uuid, p_ready boolean) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  r record;
  all_ready boolean;
  cfg jsonb;
  wanted int;
  sess public.game_sessions;
begin
  select * into r from private.lock_session(p_session);
  if (r.s).status <> 'lobby' then
    return jsonb_build_object('ok', true, 'status', (r.s).status);
  end if;
  update public.session_players set ready_at = case when p_ready then coalesce(ready_at, now()) end
    where session_id = p_session and seat = r.seat;
  select count(*) = 2 and bool_and(ready_at is not null) into all_ready
    from public.session_players where session_id = p_session and user_id is not null;
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

create or replace function public.reroll_round(p_session uuid, p_round int) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  r record;
  cfg jsonb;
  rd public.session_rounds;
begin
  select * into r from private.lock_session(p_session);
  cfg := private.version_config(r.s);
  if (r.s).status <> 'playing' or (r.s).current_round <> p_round then return jsonb_build_object('ok', false, 'error', 'stale_round'); end if;
  if coalesce((cfg ->> 'rerolls')::int, 0) < 1 then return jsonb_build_object('ok', false, 'error', 'not_allowed'); end if;
  select * into rd from public.session_rounds where session_id = p_session and round_no = p_round;
  if coalesce((rd.card ->> 'rerolled')::int, 0) >= (cfg ->> 'rerolls')::int
     or exists (select 1 from public.session_answers where session_id = p_session and round_no = p_round) then
    return jsonb_build_object('ok', false, 'error', 'not_allowed');
  end if;
  update public.session_rounds
    set card = private.draw_round_card(r.s, cfg) || jsonb_build_object('rerolled', coalesce((rd.card ->> 'rerolled')::int, 0) + 1)
    where session_id = p_session and round_no = p_round;
  perform private.bump_session(p_session, 'reroll');
  return jsonb_build_object('ok', true);
end $$;

create or replace function public.submit_answer(p_session uuid, p_round int, p_step text, p_payload jsonb, p_skip boolean default false)
returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  r record;
  cfg jsonb;
  steps jsonb;
  cur_step jsonb;
  step_index int;
  is_after boolean := false;
  rnd public.session_rounds;
  normalized jsonb;
  prev public.session_answers;
  revealed boolean := false;
  done_count int;
  max_rev int;
begin
  select * into r from private.lock_session(p_session);
  if (r.s).status = 'paused' then return jsonb_build_object('ok', false, 'error', 'paused'); end if;
  cfg := private.version_config(r.s);

  -- Ancienne démo : comportement d'origine conservé.
  if cfg ->> 'mechanic' = 'portrait_words' then
    if (r.s).status <> 'playing' then return jsonb_build_object('ok', false, 'error', 'not_playing'); end if;
    if p_round <> (r.s).current_round then return jsonb_build_object('ok', false, 'error', 'stale_round'); end if;
    steps := cfg -> 'steps';
    select e.value, e.ordinality - 1 into cur_step, step_index
      from jsonb_array_elements(steps) with ordinality e where e.value ->> 'key' = p_step;
    if cur_step is null then return jsonb_build_object('ok', false, 'error', 'unknown_step'); end if;
    select * into rnd from public.session_rounds where session_id = p_session and round_no = p_round;
    if rnd.revealed_at is not null then return jsonb_build_object('ok', false, 'error', 'already_revealed'); end if;
    if step_index > 0 and not exists (
        select 1 from public.session_answers a where a.session_id = p_session and a.round_no = p_round
          and a.seat = r.seat and a.step = steps -> (step_index - 1) ->> 'key') then
      return jsonb_build_object('ok', false, 'error', 'previous_step_missing');
    end if;
    normalized := case when p_skip then null else private.validate_payload(cfg, cur_step, rnd.card, p_payload) end;
    select * into prev from public.session_answers a
      where a.session_id = p_session and a.round_no = p_round and a.step = p_step and a.seat = r.seat;
    if prev.id is not null then
      if prev.skipped = p_skip and prev.payload is not distinct from normalized then
        return jsonb_build_object('ok', true, 'repeated', true);
      end if;
      return jsonb_build_object('ok', false, 'error', 'already_submitted');
    end if;
    insert into public.session_answers (session_id, round_no, step, user_id, seat, payload, skipped)
      values (p_session, p_round, p_step, auth.uid(), r.seat, normalized, p_skip);
    select count(*) into done_count from public.session_answers where session_id = p_session and round_no = p_round;
    if done_count >= 2 * jsonb_array_length(steps) then
      revealed := true;
      update public.session_rounds set revealed_at = now() where session_id = p_session and round_no = p_round;
      if p_round >= (r.s).total_rounds then
        update public.game_sessions set status = 'ended', ended_at = now() where id = p_session;
      end if;
    end if;
    perform private.bump_session(p_session, case when revealed then 'revealed' else 'answer' end);
    return jsonb_build_object('ok', true, 'revealed', revealed);
  end if;

  select * into rnd from public.session_rounds where session_id = p_session and round_no = p_round;
  if rnd.session_id is null then return jsonb_build_object('ok', false, 'error', 'stale_round'); end if;

  select e.value into cur_step from jsonb_array_elements(cfg -> 'steps') e where e.value ->> 'key' = p_step;
  if cur_step is null then
    select e.value into cur_step from jsonb_array_elements(coalesce(cfg -> 'after', '[]')) e where e.value ->> 'key' = p_step;
    is_after := cur_step is not null;
  end if;
  if cur_step is null then return jsonb_build_object('ok', false, 'error', 'unknown_step'); end if;
  if not (r.seat = any(private.step_seats(cur_step, rnd.card))) then return jsonb_build_object('ok', false, 'error', 'not_your_turn'); end if;

  if p_skip then
    if not coalesce((cur_step ->> 'skippable')::boolean, false) then return jsonb_build_object('ok', false, 'error', 'invalid_answer'); end if;
    normalized := null;
  else
    begin
      normalized := private.validate_step(cur_step, rnd.card, p_payload, p_session, p_round, r.seat);
    exception when raise_exception then
      return jsonb_build_object('ok', false, 'error', 'invalid_answer');
    end;
  end if;

  -- La même réponse renvoyée (double clic, réseau) n'a qu'un effet, quel que soit l'état de la partie.
  select * into prev from public.session_answers a
    where a.session_id = p_session and a.round_no = p_round and a.step = p_step and a.seat = r.seat;
  if prev.id is not null and prev.skipped = p_skip and prev.payload is not distinct from normalized then
    return jsonb_build_object('ok', true, 'repeated', true);
  end if;

  if is_after then
    -- Étapes après révélation (réaction, combinaison commune…) : possibles aussi sur l'écran de fin.
    if (r.s).status not in ('playing', 'ended') or rnd.revealed_at is null or rnd.revealed_at > now() then
      return jsonb_build_object('ok', false, 'error', 'not_revealed');
    end if;
  else
    if (r.s).status <> 'playing' then return jsonb_build_object('ok', false, 'error', 'not_playing'); end if;
    if p_round <> (r.s).current_round then return jsonb_build_object('ok', false, 'error', 'stale_round'); end if;
    if rnd.revealed_at is not null then return jsonb_build_object('ok', false, 'error', 'already_revealed'); end if;
  end if;

  -- Ordre : une étape peut dépendre d'une autre (écoute : reformuler après le récit) ;
  -- sinon, chacun suit l'ordre des étapes communes.
  if cur_step ? 'after' then
    if not exists (select 1 from public.session_answers a where a.session_id = p_session and a.round_no = p_round
                   and a.step = cur_step ->> 'after') then
      return jsonb_build_object('ok', false, 'error', 'previous_step_missing');
    end if;
  elsif not is_after then
    select e.ordinality - 1 into step_index from jsonb_array_elements(cfg -> 'steps') with ordinality e
      where e.value ->> 'key' = p_step;
    if step_index > 0 and coalesce(cfg -> 'steps' -> (step_index - 1) ->> 'who', 'both') = 'both'
       and coalesce(cur_step ->> 'who', 'both') = 'both'
       and not exists (select 1 from public.session_answers a where a.session_id = p_session and a.round_no = p_round
                       and a.seat = r.seat and a.step = cfg -> 'steps' -> (step_index - 1) ->> 'key') then
      return jsonb_build_object('ok', false, 'error', 'previous_step_missing');
    end if;
  end if;

  if prev.id is not null then
    -- Seules certaines étapes après révélation acceptent une révision (ex. : combinaison commune, révision = 1).
    max_rev := coalesce((cur_step ->> 'revisions')::int, 0);
    if not is_after or prev.revision >= max_rev then
      return jsonb_build_object('ok', false, 'error', 'already_submitted');
    end if;
    update public.session_answers set payload = normalized, skipped = p_skip, revision = revision + 1, updated_at = now()
      where id = prev.id;
  else
    insert into public.session_answers (session_id, round_no, step, user_id, seat, payload, skipped)
      values (p_session, p_round, p_step, auth.uid(), r.seat, normalized, p_skip);
  end if;

  if not is_after and private.round_complete(p_session, p_round, cfg, rnd.card) then
    revealed := true;
    update public.session_rounds
      set revealed_at = case when cfg ->> 'reveal' = 'capsule'
                             then now() + make_interval(days => coalesce(((r.s).settings ->> 'delai')::int, 7))
                             else now() end
      where session_id = p_session and round_no = p_round;
    if p_round >= (r.s).total_rounds then
      update public.game_sessions set status = 'ended', ended_at = now(), result = private.compute_result(r.s, cfg)
        where id = p_session;
    end if;
  end if;
  perform private.bump_session(p_session, case when revealed then 'revealed' else 'answer' end);
  return jsonb_build_object('ok', true, 'revealed', revealed);
end $$;

create or replace function public.next_round(p_session uuid, p_from_round int) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  r record;
  cfg jsonb;
  sess public.game_sessions;
begin
  select * into r from private.lock_session(p_session);
  if (r.s).status <> 'playing' or (r.s).current_round <> p_from_round then
    return jsonb_build_object('ok', true, 'repeated', true);
  end if;
  if not exists (select 1 from public.session_rounds where session_id = p_session and round_no = p_from_round and revealed_at is not null) then
    return jsonb_build_object('ok', false, 'error', 'not_revealed');
  end if;
  cfg := private.version_config(r.s);
  if cfg #>> '{draw,deck}' = 'true' and private.deck_available(r.s) < 1 then
    -- Banque filtrée épuisée : la partie se termine proprement au lieu d'élargir les thèmes.
    update public.game_sessions set status = 'ended', ended_at = now(), total_rounds = p_from_round,
      result = private.compute_result(r.s, cfg) where id = p_session;
    perform private.bump_session(p_session, 'ended');
    return jsonb_build_object('ok', true, 'ended', true);
  end if;
  update public.game_sessions set current_round = p_from_round + 1 where id = p_session returning * into sess;
  insert into public.session_rounds (session_id, round_no, card) values (p_session, p_from_round + 1, private.draw_round_card(sess, cfg));
  perform private.bump_session(p_session, 'round');
  return jsonb_build_object('ok', true);
end $$;

create or replace function public.close_session(p_session uuid) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  r record;
  keep boolean;
begin
  select * into r from private.lock_session(p_session);
  if (r.s).status <> 'ended' then return jsonb_build_object('ok', true, 'repeated', true); end if;
  select count(*) = 2 and bool_and(keep_memory) into keep from public.session_players where session_id = p_session;
  keep := keep or private.version_config(r.s) ->> 'reveal' = 'capsule';
  perform private.purge_session(p_session, keep);
  update public.game_sessions set status = 'closed', closed_at = now() where id = p_session;
  perform private.bump_session(p_session, 'closed');
  return jsonb_build_object('ok', true, 'kept', keep);
end $$;

create or replace function public.get_session_state(p_session uuid) returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare
  s public.game_sessions;
  me uuid := auth.uid();
  my_seat int;
  cfg jsonb;
begin
  select * into s from public.game_sessions where id = p_session;
  if s.id is null or not private.is_member(s.couple_id, true) then
    return jsonb_build_object('ok', false, 'error', 'session_not_found');
  end if;
  select seat into my_seat from public.session_players where session_id = p_session and user_id = me;
  cfg := private.version_config(s);

  return jsonb_build_object(
    'ok', true,
    'session', jsonb_build_object(
      'id', s.id, 'game_id', s.game_id, 'game_version', s.game_version, 'status', s.status,
      'settings', s.settings, 'current_round', s.current_round, 'total_rounds', s.total_rounds,
      'paused_by', s.paused_by, 'state_version', s.state_version, 'created_at', s.created_at,
      'started_at', s.started_at, 'ended_at', s.ended_at, 'closed_at', s.closed_at, 'result', s.result,
      'read_only', not private.is_member(s.couple_id)),
    'my_seat', my_seat,
    -- Mes préférences uniquement ; celles de l'autre ne sortent jamais.
    'my_prefs', (select jsonb_build_object('adult', sp.adult, 'excluded_topics', to_jsonb(sp.excluded_topics))
                 from public.session_prefs sp where sp.session_id = s.id and sp.user_id = me),
    'game', (select jsonb_build_object('title', g.title, 'mechanic', g.mechanic, 'rules', v.rules, 'config', v.config,
                                       'adult_available', g.adult_available, 'thumbnail', g.thumbnail)
             from public.games g join public.game_versions v on v.game_id = g.id and v.version = s.game_version
             where g.id = s.game_id),
    'players', (select coalesce(jsonb_agg(jsonb_build_object(
                  'seat', sp.seat, 'user_id', sp.user_id, 'is_me', sp.user_id = me,
                  'display_name', coalesce(nullif(pr.display_name, ''), cm.display_name_snapshot, ''),
                  'word_form', coalesce(pr.word_form, 'n'), 'avatar_path', pr.avatar_path,
                  'ready', sp.ready_at is not null, 'keep_memory', sp.keep_memory) order by sp.seat), '[]')
                from public.session_players sp
                left join public.profiles pr on pr.id = sp.user_id
                left join public.couple_members cm on cm.couple_id = s.couple_id and cm.user_id = sp.user_id
                where sp.session_id = s.id),
    'rounds', (select coalesce(jsonb_agg(jsonb_build_object(
                 'round_no', rd.round_no, 'card', rd.card,
                 'revealed', rd.revealed_at is not null and rd.revealed_at <= now(),
                 'reveal_at', case when rd.revealed_at > now() then rd.revealed_at end,
                 'answers', (select coalesce(jsonb_agg(jsonb_build_object(
                                'step', a.step, 'seat', a.seat, 'skipped', a.skipped, 'revision', a.revision,
                                'payload', case
                                  when a.seat = my_seat then a.payload
                                  when (rd.revealed_at <= now())
                                       or exists (select 1 from jsonb_array_elements(coalesce(cfg -> 'steps', '[]')) st
                                                  where st ->> 'key' = a.step and st ->> 'visible' = 'immediate')
                                    then private.public_payload(
                                      (select st from jsonb_array_elements(coalesce(cfg -> 'steps', '[]') || coalesce(cfg -> 'after', '[]')) st
                                       where st ->> 'key' = a.step limit 1), a.payload)
                                end)
                              order by a.seat, a.created_at), '[]')
                             from public.session_answers a
                             where a.session_id = s.id and a.round_no = rd.round_no)
               ) order by rd.round_no), '[]')
               from public.session_rounds rd where rd.session_id = s.id)
  );
end $$;

grant execute on function public.reroll_round(uuid, int), public.create_session(text), public.set_ready(uuid, boolean),
  public.submit_answer(uuid, int, text, jsonb, boolean), public.next_round(uuid, int), public.close_session(uuid),
  public.get_session_state(uuid) to authenticated;
