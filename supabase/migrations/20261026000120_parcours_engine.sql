-- Parcours (suite) : classement des activités, tirage plafonné par les préférences des deux, création de partie
-- filtrée, état de partie avec la pause partagée, partenaire de test compatible avec la reprise à deux.

update public.games g set intensity = x.i, formats = x.f, duration_kind = x.d, updated_at = now()
from (values
  ('nd-action-verite', 'moyen', array['duo', 'jeu', 'defi'], 'rapide'),
  ('N2-003', 'soft', array['duo', 'jeu'], 'rapide'),
  ('N2-002', 'soft', array['duo', 'jeu'], 'rapide'),
  ('nd-qui-de-nous-deux', 'soft', array['duo', 'jeu'], 'rapide'),
  ('N2-004', 'soft', array['duo', 'jeu'], 'rapide'),
  ('nd-complete-phrase', 'soft', array['duo', 'jeu'], 'rapide'),
  ('nd-accord-desaccord', 'soft', array['duo', 'jeu'], 'rapide'),
  ('nd-deux-verites-mensonge', 'soft', array['duo', 'jeu'], 'rapide'),
  ('ND-Q-011', 'hot', array['solo', 'duo'], 'discussion'),
  ('ND-Q-012', 'soft', array['solo', 'duo'], 'discussion'),
  ('ND-Q-021', 'moyen', array['solo', 'duo'], 'rapide'),
  ('ND-Q-022', 'moyen', array['solo', 'duo'], 'rapide'),
  ('ND-Q-024', 'soft', array['solo', 'duo'], 'rapide'),
  ('ND-Q-025', 'hot', array['solo', 'duo'], 'rapide'),
  ('ND-Q-027', 'hot', array['solo', 'duo'], 'rapide'),
  ('N2-076', 'soft', array['duo', 'jeu'], 'rapide'),
  ('N2-079', 'soft', array['duo', 'jeu'], 'discussion'),
  ('N2-078', 'soft', array['duo', 'jeu'], 'discussion'),
  ('N2-023', 'soft', array['duo', 'jeu'], 'discussion'),
  ('N2-083', 'soft', array['duo', 'jeu'], 'rapide'),
  ('nd-de-chanceux', 'soft', array['duo', 'jeu'], 'discussion'),
  ('N2-018', 'soft', array['duo', 'jeu'], 'discussion'),
  ('nd-cite-trois', 'soft', array['duo', 'jeu', 'defi'], 'discussion'),
  ('ND-Q-P01', 'moyen', array['duo'], 'discussion'),
  ('ND-Q-P03', 'soft', array['duo'], 'discussion'),
  ('ND-Q-P15', 'moyen', array['duo'], 'discussion'),
  ('ND-Q-P11', 'soft', array['duo', 'rituel'], 'discussion'),
  ('ND-Q-P12', 'soft', array['duo'], 'discussion'),
  ('ND-Q-P13', 'soft', array['duo'], 'discussion'),
  ('ND-Q-P14', 'moyen', array['duo'], 'discussion')
) as x(id, i, f, d)
where g.id = x.id and (g.intensity, g.formats, g.duration_kind) is distinct from (x.i, x.f, x.d);

create or replace function private.conv_draw(p_session uuid, p_bank text, p_kind text default null, p_extra_seen text[] default '{}')
returns jsonb
language sql volatile security definer set search_path = '' as $$
  select cb.value from public.content_banks cb
  left join public.content_meta m on m.bank = cb.bank and m.item_id = cb.value ->> 'id'
  where cb.bank = p_bank
    and not ((cb.value ->> 'id') = any(private.conv_seen(p_session) || p_extra_seen))
    and (not coalesce((cb.value ->> 'adult')::boolean, true) or private.adult_allowed(p_session))
    and (p_kind is null or cb.value ->> 'kind' = p_kind)
    -- Intensité : jamais au-delà de ce que les deux acceptent.
    and private.intensity_rank(coalesce(m.intensity, 'soft')) <= private.session_cap(p_session)
  order by random() limit 1 $$;

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

  -- Préférences des deux : une activité plus intense que le plafond commun ne se lance pas.
  if private.intensity_rank(coalesce(g.intensity, 'soft')) > private.couple_cap(c) then
    return jsonb_build_object('ok', false, 'error', 'filtered_out');
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
      'paused_by', s.paused_by, 'pause_state', s.pause_state, 'server_now', now(), 'state_version', s.state_version, 'created_at', s.created_at,
      'started_at', s.started_at, 'ended_at', s.ended_at, 'closed_at', s.closed_at, 'result', s.result,
      'read_only', not private.is_member(s.couple_id)),
    'my_seat', my_seat,
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
                 'private', (select rs.secret -> 'seats' -> my_seat::text from private.round_secrets rs
                             where rs.session_id = s.id and rs.round_no = rd.round_no),
                 'solution', (select rs.secret -> 'solution' from private.round_secrets rs
                              where rs.session_id = s.id and rs.round_no = rd.round_no
                                and rd.revealed_at is not null and rd.revealed_at <= now()),
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
  -- Pause : le partenaire de test accepte la reprise dès que l'autre l'a demandée.
  if s.status = 'paused' and jsonb_array_length(coalesce(s.pause_state -> 'resume', '[]')) > 0
     and not (s.pause_state -> 'resume' ? p_seat::text) then
    res := public.set_paused(p_session, false);
    return coalesce((res ->> 'ok')::boolean, false);
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
