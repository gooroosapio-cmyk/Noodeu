-- Noodeu · État des invitations pour l'interface + index de performance.

-- Renvoie l'invitation envoyée (avec le prénom de la personne qui demande à rejoindre)
-- et la demande envoyée (avec le prénom de la personne qui invite). Rien d'autre.
create function public.get_invitation_status() returns jsonb
language sql stable security definer set search_path = '' as $$
  select jsonb_build_object(
    'outgoing', (select jsonb_build_object(
                   'id', i.id, 'code', i.code, 'status', i.status, 'expires_at', i.expires_at,
                   'expired', i.expires_at <= now(),
                   'claimer_name', case when i.status = 'claimed' then (select p.display_name from public.profiles p where p.id = i.claimed_by) end)
                 from public.invitations i
                 where i.inviter_id = auth.uid() and i.status in ('open', 'claimed')
                 order by i.created_at desc limit 1),
    'incoming', (select jsonb_build_object(
                   'id', i.id, 'status', i.status, 'expires_at', i.expires_at,
                   'inviter_name', (select p.display_name from public.profiles p where p.id = i.inviter_id))
                 from public.invitations i
                 where i.claimed_by = auth.uid() and i.status = 'claimed'
                 order by i.claimed_at desc limit 1)
  )
$$;
revoke execute on function public.get_invitation_status() from public, anon;
grant execute on function public.get_invitation_status() to authenticated;

create index game_favorites_game on public.game_favorites (game_id);
create index game_sessions_game_version on public.game_sessions (game_id, game_version);
create index game_sessions_created_by on public.game_sessions (created_by);
create index game_sessions_paused_by on public.game_sessions (paused_by);
create index games_current_version on public.games (id, current_version);
create index invitations_couple on public.invitations (couple_id);
create index session_answers_user on public.session_answers (user_id);
create index session_messages_user on public.session_messages (user_id);
create index session_players_user_id on public.session_players (user_id);
