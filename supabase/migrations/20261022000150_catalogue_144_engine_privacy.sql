-- EN ATTENTE D'ACCORD sur Supabase (l'outil de migration demande une confirmation pour les instructions
-- « delete » et « revoke »). Appliquée et testée en local. Tant qu'elle n'est pas appliquée en ligne :
-- les options +18/thèmes privées et la sortie commune ne sont pas disponibles, et les réponses révélées
-- restent lisibles en direct par l'autre membre (hors capsule, voir migration 140).

-- Les manches et réponses ne se lisent plus en direct : uniquement via get_session_state().
revoke select on public.session_answers, public.session_rounds from authenticated;
revoke all on public.content_banks, public.catalogue_imports, public.session_prefs from anon;
revoke insert, update, delete on public.content_banks, public.catalogue_imports, public.session_prefs from authenticated;

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

  if (r.s).status = 'lobby' then
    update public.session_players set ready_at = null where session_id = p_session;
  else
    -- Carte en cours devenue inéligible et non révélée : elle est remplacée, ses réponses effacées.
    cfg := private.version_config(r.s);
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

create or replace function public.finish_session(p_session uuid) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  r record;
begin
  select * into r from private.lock_session(p_session);
  if (r.s).status not in ('playing', 'paused') then return jsonb_build_object('ok', true, 'repeated', true); end if;
  -- La manche non révélée est retirée : rien de privé n'est dévoilé.
  delete from public.session_rounds where session_id = p_session and revealed_at is null;
  update public.game_sessions set status = 'ended', ended_at = now(), paused_by = null,
    total_rounds = greatest((select count(*) from public.session_rounds where session_id = p_session), 1),
    result = private.compute_result(r.s, private.version_config(r.s))
    where id = p_session;
  perform private.bump_session(p_session, 'ended');
  return jsonb_build_object('ok', true);
end $$;

create or replace function private.purge_expired_sessions() returns int
language plpgsql security definer set search_path = '' as $$
declare
  s record;
  n int := 0;
  keep boolean;
begin
  for s in select gs.id, gs.game_id, gs.game_version, gs.status from public.game_sessions gs
           where gs.ended_at < now() - interval '24 hours' and gs.status in ('ended', 'closed')
             and exists (select 1 from public.session_answers a where a.session_id = gs.id)
           for update skip locked loop
    select count(*) = 2 and bool_and(keep_memory) into keep from public.session_players where session_id = s.id;
    keep := keep or exists (select 1 from public.game_versions v where v.game_id = s.game_id and v.version = s.game_version
                            and v.config ->> 'reveal' = 'capsule');
    if not keep then
      delete from public.session_answers where session_id = s.id;
      n := n + 1;
    end if;
    if s.status = 'ended' then
      update public.game_sessions set status = 'closed', closed_at = now() where id = s.id;
    end if;
  end loop;
  return n;
end $$;

revoke execute on all functions in schema public from public, anon;
grant execute on function public.set_session_prefs(uuid, boolean, text[]), public.finish_session(uuid) to authenticated;
revoke execute on function private.purge_expired_sessions(), private.adult_allowed(uuid), private.excluded_tags(uuid),
  private.deck_available(public.game_sessions), private.bank_sample(text, int),
  private.draw_round_card(public.game_sessions, jsonb), private.clean_text(jsonb, text, int, boolean),
  private.idx(jsonb, int), private.idx_list(jsonb, int, int, int), private.clean_drawing(jsonb),
  private.round_answer(uuid, int, text, int), private.validate_step(jsonb, jsonb, jsonb, uuid, int, int),
  private.public_payload(jsonb, jsonb), private.step_seats(jsonb, jsonb), private.round_complete(uuid, int, jsonb, jsonb),
  private.compute_result(public.game_sessions, jsonb), private.topic_tags_for(text[])
  from public, anon, authenticated;
