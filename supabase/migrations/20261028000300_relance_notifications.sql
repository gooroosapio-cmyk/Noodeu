-- Relance « X t'attend » et notifications sans messages (demande du propriétaire, 25/10/2026).
-- 1. Les messages de discussion ne créent plus de notification (ils restent dans la discussion, avec leur compteur).
-- 2. Relance en un toucher : notification de partie « nudge » à l'autre membre de la séance, limites vérifiées ici :
--    20 s après le début de l'attente, 60 s entre deux envois, 3 relances au plus par manche et par émetteur,
--    séance active, destinataire membre actif du duo. Rien n'est rédigé dans la discussion.

create or replace function private.notify(p_user uuid, p_type text, p_couple uuid, p_data jsonb default '{}'::jsonb)
 returns void language plpgsql security definer set search_path to ''
as $function$
begin
  if p_user is null then return; end if;
  -- Messages : aucune notification ; seul le signal temps réel reste (la discussion garde son compteur de non-lus).
  if p_type = 'message' then
    perform private.notify_user(p_user, 'notification', '{}');
    return;
  end if;
  insert into public.notifications (user_id, type, couple_id, data) values (p_user, p_type, p_couple, p_data);
  perform private.notify_user(p_user, 'notification', '{}');
end $function$;

delete from public.notifications where type = 'message';

alter table public.notifications drop constraint if exists notifications_type_check;
alter table public.notifications add constraint notifications_type_check check (type in ('invitation_claimed', 'invitation_accepted',
  'invitation_declined', 'duo_ended', 'game_proposed', 'message', 'gentle_reminder', 'nudge'));

create table if not exists private.nudges (
  id bigint generated always as identity primary key,
  session_id uuid not null references public.game_sessions (id) on delete cascade,
  round_no int not null default 0,
  from_user uuid not null,
  to_user uuid not null,
  created_at timestamptz not null default now()
);
create index if not exists nudges_session_from on private.nudges (session_id, from_user, created_at desc);
alter table private.nudges enable row level security;

create or replace function public.send_nudge(p_session uuid)
 returns jsonb language plpgsql security definer set search_path to ''
as $function$
declare
  me uuid := auth.uid();
  s public.game_sessions;
  other uuid;
  rnd int;
  since timestamptz;
  last timestamptz;
  n int;
begin
  if me is null then return jsonb_build_object('ok', false, 'error', 'not_authenticated'); end if;
  select * into s from public.game_sessions where id = p_session;
  if s.id is null or not private.is_member(s.couple_id) then return jsonb_build_object('ok', false, 'error', 'not_found'); end if;
  if not exists (select 1 from public.session_players where session_id = p_session and user_id = me) then
    return jsonb_build_object('ok', false, 'error', 'not_found');
  end if;
  if s.status not in ('lobby', 'playing') then return jsonb_build_object('ok', false, 'error', 'not_waiting'); end if;
  select sp.user_id into other from public.session_players sp
    join public.couple_members cm on cm.couple_id = s.couple_id and cm.user_id = sp.user_id and cm.left_at is null
    where sp.session_id = p_session and sp.user_id <> me;
  if other is null then return jsonb_build_object('ok', false, 'error', 'no_partner'); end if;
  -- Au salon, inutile de relancer quelqu'un qui est déjà prêt.
  if s.status = 'lobby' and exists (select 1 from public.session_players where session_id = p_session and user_id = other and ready_at is not null) then
    return jsonb_build_object('ok', false, 'error', 'not_waiting');
  end if;
  rnd := case when s.status = 'playing' then coalesce(s.current_round, 0) else 0 end;
  since := case when s.status = 'playing'
    then coalesce((select started_at from public.session_rounds where session_id = p_session and round_no = rnd), s.started_at, s.created_at)
    else coalesce((select ready_at from public.session_players where session_id = p_session and user_id = me), s.created_at) end;
  if since is not null and now() - since < interval '20 seconds' then
    return jsonb_build_object('ok', false, 'error', 'too_soon', 'retry_in', ceil(extract(epoch from (since + interval '20 seconds' - now()))));
  end if;
  perform pg_advisory_xact_lock(hashtext('nudge:' || p_session::text || ':' || me::text));
  select max(created_at), count(*) filter (where round_no = rnd) into last, n from private.nudges where session_id = p_session and from_user = me;
  if last is not null and now() - last < interval '60 seconds' then
    return jsonb_build_object('ok', false, 'error', 'cooldown', 'retry_in', ceil(extract(epoch from (last + interval '60 seconds' - now()))));
  end if;
  if n >= 3 then return jsonb_build_object('ok', false, 'error', 'limit'); end if;
  insert into private.nudges (session_id, round_no, from_user, to_user) values (p_session, rnd, me, other);
  -- Charge utile minimale : aucun contenu de jeu, aucune réponse.
  perform private.notify(other, 'nudge', s.couple_id, jsonb_build_object(
    'name', (select display_name from public.profiles where id = me), 'session_id', p_session,
    'title', (select title from public.games where id = s.game_id), 'round', rnd));
  return jsonb_build_object('ok', true, 'left', 2 - n, 'retry_in', 60);
end $function$;

revoke execute on function public.send_nudge(uuid) from public, anon;
grant execute on function public.send_nudge(uuid) to authenticated;
