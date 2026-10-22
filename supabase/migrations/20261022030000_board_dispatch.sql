-- Aiguillage du moteur plateau entre familles : chaque famille a ses fonctions de tirage, de règles et de robot.
-- Les familles suivantes n'auront qu'à compléter ces trois aiguillages.
create or replace function private.board_setup_any(s public.game_sessions, cfg jsonb) returns jsonb
language plpgsql volatile security definer set search_path = '' as $$
begin
  if cfg ->> 'mechanic' = any(private.board_route3()) then return private.board_setup3(s, cfg); end if;
  return private.board_setup(s, cfg);
end $$;

create or replace function private.board_apply_any(m text, c jsonb, sec jsonb, seat int, typ text, p jsonb, p_session uuid) returns jsonb
language plpgsql volatile security definer set search_path = '' as $$
begin
  if m = any(private.board_route3()) then
    if typ = 'giveup' then return private.res(c || '{"done": true, "gave_up": true}', sec); end if;
    return private.board_apply3(m, c, sec, seat, typ, p, p_session);
  end if;
  return private.board_apply(m, c, sec, seat, typ, p, p_session);
end $$;

create or replace function private.board_bot_any(m text, c jsonb, sec jsonb, seat int) returns jsonb
language plpgsql volatile security definer set search_path = '' as $$
begin
  if m = any(private.board_route3()) then return private.board_bot3(m, c, sec, seat); end if;
  return private.board_bot(m, c, sec, seat);
end $$;

create or replace function private.draw_round_card(s public.game_sessions, cfg jsonb) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  allow_intimate boolean;
  deck_size int;
  words jsonb;
  card jsonb := '{}';
  q public.game_cards;
  l jsonb;
  role_a int;
begin
  if cfg ->> 'mechanic' = 'portrait_words' then
    select bool_and(p.intimate_opt_in) into allow_intimate
      from public.session_players sp join public.profiles p on p.id = sp.user_id where sp.session_id = s.id;
    deck_size := coalesce((s.settings ->> 'deck_size')::int, (cfg #>> '{settings,deck_size,default}')::int, 12);
    select jsonb_agg(jsonb_build_object('id', c.id, 'f', c.content ->> 'f', 'm', c.content ->> 'm') order by random())
      into words
      from (select * from public.game_cards
            where game_id = s.game_id and status = 'published' and kind = 'word'
              and (content_level = 'standard' or coalesce(allow_intimate, false))
            order by random() limit deck_size) c;
    if words is null or jsonb_array_length(words) < (cfg ->> 'pick')::int then
      raise exception 'not_enough_cards';
    end if;
    return jsonb_build_object('words', words);
  end if;

  if cfg ->> 'engine' = 'board' then
    return private.board_setup_any(s, cfg);
  end if;
  if cfg ->> 'engine' <> 'rounds' then raise exception 'unknown_mechanic'; end if;

  if cfg #>> '{draw,deck}' = 'true' then
    select c.* into q from public.game_cards c
    where c.game_id = s.game_id and c.status = 'published' and c.kind = 'question'
      and (not c.adult or private.adult_allowed(s.id))
      and not (c.topic_tags && private.excluded_tags(s.id))
      and not exists (select 1 from public.session_rounds r where r.session_id = s.id and r.card ->> 'id' = c.id)
    order by exists (select 1 from public.session_rounds r join public.game_sessions gs on gs.id = r.session_id
                     where gs.couple_id = s.couple_id and gs.game_id = s.game_id
                       and gs.created_at > now() - interval '60 days' and r.card ->> 'id' = c.id),
             random()
    limit 1;
    if q.id is null then raise exception 'not_enough_cards'; end if;
    card := jsonb_build_object('id', q.id, 'text', q.content ->> 'text', 'choices', coalesce(q.content -> 'choices', '[]'),
                               'adult', q.adult, 'theme', q.theme, 'format', q.content ->> 'format');
  end if;

  for l in select * from jsonb_array_elements(coalesce(cfg #> '{draw,lists}', '[]')) loop
    card := card || jsonb_build_object(l ->> 'key', private.bank_sample(l ->> 'bank', (l ->> 'count')::int));
  end loop;
  card := card || coalesce(cfg #> '{draw,fixed}', '{}');

  role_a := case when cfg ->> 'roles' = 'alternate' then ((greatest(s.current_round, 1) - 1) % 2) + 1 else 1 end;
  return card || jsonb_build_object('role_a', role_a);
end $$;

create or replace function public.play_move(p_session uuid, p_round int, p_action uuid, p_type text, p_payload jsonb default '{}')
returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  r record;
  cfg jsonb;
  rd public.session_rounds;
  sec jsonb;
  res jsonb;
  new_card jsonb;
begin
  select * into r from private.lock_session(p_session);
  if p_action is null or p_type is null or char_length(p_type) > 20 then
    return jsonb_build_object('ok', false, 'error', 'invalid_move');
  end if;
  if exists (select 1 from private.board_moves where action_id = p_action) then
    return jsonb_build_object('ok', true, 'repeated', true);
  end if;
  if (r.s).status = 'paused' then return jsonb_build_object('ok', false, 'error', 'paused'); end if;
  if (r.s).status <> 'playing' then return jsonb_build_object('ok', false, 'error', 'not_playing'); end if;
  cfg := private.version_config(r.s);
  if cfg ->> 'engine' is distinct from 'board' then return jsonb_build_object('ok', false, 'error', 'not_allowed'); end if;
  if p_round <> (r.s).current_round then return jsonb_build_object('ok', false, 'error', 'stale_round'); end if;
  select * into rd from public.session_rounds where session_id = p_session and round_no = p_round;
  if rd.session_id is null then return jsonb_build_object('ok', false, 'error', 'stale_round'); end if;
  if rd.revealed_at is not null or coalesce((rd.card ->> 'done')::boolean, false) then
    return jsonb_build_object('ok', false, 'error', 'round_over');
  end if;
  select secret into sec from private.round_secrets where session_id = p_session and round_no = p_round;

  begin
    res := private.board_apply_any(cfg ->> 'mechanic', rd.card, coalesce(sec, '{}'), r.seat, p_type,
                               coalesce(p_payload, '{}'), p_session);
  exception when raise_exception then
    if sqlerrm like 'move:%' then
      return jsonb_build_object('ok', false, 'error', substr(sqlerrm, 6));
    end if;
    raise;
  end;

  new_card := (res -> 'card') || jsonb_build_object('rev', coalesce((rd.card ->> 'rev')::int, 0) + 1,
                                                    'last', jsonb_build_object('seat', r.seat, 'type', p_type));
  insert into private.board_moves (action_id, session_id, round_no, seat, type, payload)
    values (p_action, p_session, p_round, r.seat, p_type, p_payload);
  update public.session_rounds set card = new_card,
    revealed_at = case when coalesce((new_card ->> 'done')::boolean, false) then now() end
    where session_id = p_session and round_no = p_round;
  update private.round_secrets set secret = res -> 'secret' where session_id = p_session and round_no = p_round;
  if coalesce((new_card ->> 'done')::boolean, false) and p_round >= (r.s).total_rounds then
    update public.game_sessions set status = 'ended', ended_at = now(), result = private.compute_result(r.s, cfg)
      where id = p_session;
  end if;
  perform private.bump_session(p_session, case when (new_card ->> 'done')::boolean then 'revealed' else 'move' end);
  return jsonb_build_object('ok', true, 'info', res -> 'info');
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
    if s.status <> 'playing' or rnd.revealed_at is not null then return false; end if;
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
