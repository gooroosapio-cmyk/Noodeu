-- À coller dans l'éditeur SQL de Supabase (projet Noodeu). Reste de la migration 150, sans l'ancienne
-- version de set_session_prefs (remplacée par celle des lots 3 et 4).
revoke select on public.session_answers, public.session_rounds from authenticated;
revoke all on public.content_banks, public.catalogue_imports, public.session_prefs from anon;
revoke insert, update, delete on public.content_banks, public.catalogue_imports, public.session_prefs from authenticated;

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
