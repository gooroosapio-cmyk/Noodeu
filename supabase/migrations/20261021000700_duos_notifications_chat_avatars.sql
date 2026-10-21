-- Noodeu · Refonte « duos » : épisodes et reprise d'une même paire, notifications, chat de duo, photos de profil.
-- Les tables gardent leurs noms historiques (couples = duos) ; l'interface parle de « duo ».
-- Règles : un seul duo actif par personne (index unique existant), plusieurs duos archivés ;
-- une même paire retrouve le même espace après une NOUVELLE acceptation des deux (nouvel épisode).

-- ---------------------------------------------------------------------------
-- 1. Paire stable et épisodes
-- ---------------------------------------------------------------------------
alter table public.couples add column pair_key text;
update public.couples c set pair_key = (
  select min(user_id::text) || ':' || max(user_id::text) from public.couple_members m where m.couple_id = c.id);
create unique index couples_pair_key on public.couples (pair_key) where pair_key is not null;

create table public.duo_episodes (
  id uuid primary key default gen_random_uuid(),
  couple_id uuid not null references public.couples (id) on delete cascade,
  started_at timestamptz not null default now(),
  ended_at timestamptz,
  ended_by uuid references auth.users (id) on delete set null
);
create unique index duo_episodes_one_open on public.duo_episodes (couple_id) where ended_at is null;
create index duo_episodes_couple on public.duo_episodes (couple_id, started_at);
create index duo_episodes_ended_by on public.duo_episodes (ended_by);
alter table public.duo_episodes enable row level security;
create policy duo_episodes_read on public.duo_episodes for select to authenticated
  using (private.is_member(couple_id, true));
revoke all on public.duo_episodes from anon, authenticated;
grant select on public.duo_episodes to authenticated;

insert into public.duo_episodes (couple_id, started_at, ended_at)
  select id, created_at, separated_at from public.couples;

alter table public.game_sessions add column episode_id uuid references public.duo_episodes (id) on delete set null;
create index game_sessions_episode on public.game_sessions (episode_id);
update public.game_sessions s set episode_id = (select e.id from public.duo_episodes e where e.couple_id = s.couple_id order by e.started_at limit 1);

-- Photo de profil : chemin dans le stockage privé « avatars ».
alter table public.profiles add column avatar_path text check (avatar_path is null or avatar_path ~ '^[0-9a-f-]{36}/[A-Za-z0-9._-]{1,80}$');
grant update (avatar_path) on public.profiles to authenticated;

-- ---------------------------------------------------------------------------
-- 2. Notifications personnelles
-- ---------------------------------------------------------------------------
create table public.notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  type text not null check (type in ('invitation_claimed', 'invitation_accepted', 'invitation_declined',
                                     'duo_ended', 'game_proposed', 'message')),
  couple_id uuid references public.couples (id) on delete cascade,
  data jsonb not null default '{}',
  created_at timestamptz not null default now(),
  read_at timestamptz
);
create index notifications_user_time on public.notifications (user_id, created_at desc);
create index notifications_couple on public.notifications (couple_id);
alter table public.notifications enable row level security;
create policy notifications_own on public.notifications for select to authenticated
  using (user_id = (select auth.uid()));
revoke all on public.notifications from anon, authenticated;
grant select on public.notifications to authenticated;

-- Crée une notification et prévient le navigateur du destinataire (signal sans contenu).
create function private.notify(p_user uuid, p_type text, p_couple uuid, p_data jsonb default '{}') returns void
language plpgsql security definer set search_path = '' as $$
begin
  if p_user is null then return; end if;
  if p_type = 'message' then
    -- Un seul rappel « nouveaux messages » non lu par duo : on le met à jour au lieu d'empiler.
    update public.notifications set created_at = now(),
      data = data || jsonb_build_object('count', coalesce((data ->> 'count')::int, 1) + 1) || p_data
      where user_id = p_user and type = 'message' and couple_id = p_couple and read_at is null;
    if found then
      perform private.notify_user(p_user, 'notification', '{}');
      return;
    end if;
  end if;
  insert into public.notifications (user_id, type, couple_id, data) values (p_user, p_type, p_couple, p_data);
  perform private.notify_user(p_user, 'notification', '{}');
end $$;
revoke execute on function private.notify(uuid, text, uuid, jsonb) from public, anon, authenticated;

create function public.mark_notifications_read(p_ids uuid[] default null) returns jsonb
language plpgsql security definer set search_path = '' as $$
begin
  update public.notifications set read_at = now()
    where user_id = auth.uid() and read_at is null and (p_ids is null or id = any (p_ids));
  return jsonb_build_object('ok', true);
end $$;

-- ---------------------------------------------------------------------------
-- 3. Chat du duo (remplace le salon éphémère : une seule messagerie, liée au duo)
-- ---------------------------------------------------------------------------
create table public.duo_messages (
  id uuid primary key default gen_random_uuid(),
  couple_id uuid not null references public.couples (id) on delete cascade,
  episode_id uuid references public.duo_episodes (id) on delete set null,
  user_id uuid references auth.users (id) on delete set null,
  client_id uuid not null,
  body text not null check (char_length(body) between 1 and 1000),
  created_at timestamptz not null default now(),
  unique (couple_id, client_id)
);
create index duo_messages_couple_time on public.duo_messages (couple_id, created_at);
create index duo_messages_user on public.duo_messages (user_id);
create index duo_messages_episode on public.duo_messages (episode_id);
alter table public.duo_messages enable row level security;
-- Lecture : membres actuels ou anciens du duo (archives consultables). Écriture : uniquement par fonction.
create policy duo_messages_read on public.duo_messages for select to authenticated
  using (private.is_member(couple_id, true));
revoke all on public.duo_messages from anon, authenticated;
grant select on public.duo_messages to authenticated;

-- Dernière lecture du chat : donnée personnelle (sert au compteur de non-lus, jamais d'accusé de lecture).
create table public.duo_reads (
  couple_id uuid not null references public.couples (id) on delete cascade,
  user_id uuid not null references auth.users (id) on delete cascade,
  last_read_at timestamptz not null default now(),
  primary key (couple_id, user_id)
);
create index duo_reads_user on public.duo_reads (user_id);
alter table public.duo_reads enable row level security;
create policy duo_reads_own on public.duo_reads for select to authenticated using (user_id = (select auth.uid()));
revoke all on public.duo_reads from anon, authenticated;
grant select on public.duo_reads to authenticated;

create function public.send_duo_message(p_client_id uuid, p_body text) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  me uuid := auth.uid();
  c uuid := private.my_couple_id();
  m public.duo_messages;
  body text := trim(coalesce(p_body, ''));
  other uuid;
begin
  if c is null then return jsonb_build_object('ok', false, 'error', 'no_couple'); end if;
  if char_length(body) = 0 or char_length(body) > 1000 then
    return jsonb_build_object('ok', false, 'error', 'invalid_message');
  end if;
  insert into public.duo_messages (couple_id, episode_id, user_id, client_id, body)
    values (c, (select id from public.duo_episodes where couple_id = c and ended_at is null), me, p_client_id, body)
    on conflict (couple_id, client_id) do nothing
    returning * into m;
  if m.id is null then
    select * into m from public.duo_messages where couple_id = c and client_id = p_client_id;
    return jsonb_build_object('ok', true, 'id', m.id, 'created_at', m.created_at, 'repeated', true);
  end if;
  insert into public.duo_reads (couple_id, user_id, last_read_at) values (c, me, m.created_at)
    on conflict (couple_id, user_id) do update set last_read_at = excluded.last_read_at;
  perform realtime.send(jsonb_build_object('id', m.id, 'couple_id', c, 'user_id', me, 'client_id', m.client_id,
      'body', m.body, 'created_at', m.created_at), 'chat', 'couple:' || c::text, true);
  select user_id into other from public.couple_members where couple_id = c and user_id <> me and left_at is null;
  perform private.notify(other, 'message', c,
    jsonb_build_object('from', (select display_name from public.profiles where id = me)));
  return jsonb_build_object('ok', true, 'id', m.id, 'created_at', m.created_at);
end $$;

create function public.mark_chat_read(p_couple uuid) returns jsonb
language plpgsql security definer set search_path = '' as $$
begin
  if not private.is_member(p_couple, true) then return jsonb_build_object('ok', false, 'error', 'not_found'); end if;
  insert into public.duo_reads (couple_id, user_id, last_read_at) values (p_couple, auth.uid(), now())
    on conflict (couple_id, user_id) do update set last_read_at = now();
  update public.notifications set read_at = now()
    where user_id = auth.uid() and couple_id = p_couple and type = 'message' and read_at is null;
  return jsonb_build_object('ok', true);
end $$;

create function public.get_chat_unread() returns int
language sql stable security definer set search_path = '' as $$
  select count(*)::int from public.duo_messages m
  where m.couple_id = private.my_couple_id() and m.user_id is distinct from auth.uid()
    and m.created_at > coalesce((select r.last_read_at from public.duo_reads r
                                 where r.couple_id = m.couple_id and r.user_id = auth.uid()), '-infinity')
$$;

-- Ancien salon éphémère : vide, remplacé par le chat du duo.
drop function public.send_session_message(uuid, uuid, text);
drop table public.session_messages;

create or replace function private.purge_session(p_session uuid, p_keep_answers boolean) returns void
language plpgsql security definer set search_path = '' as $$
begin
  if not p_keep_answers then
    delete from public.session_answers where session_id = p_session;
  end if;
end $$;

-- ---------------------------------------------------------------------------
-- 4. Duos : acceptation (création ou reprise), fin, liste
-- ---------------------------------------------------------------------------
create or replace function public.respond_to_claim(p_invitation uuid, p_accept boolean) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  me uuid := auth.uid();
  inv public.invitations;
  target uuid;
  key text;
  resumed boolean := false;
begin
  select * into inv from public.invitations where id = p_invitation and inviter_id = me for update;
  if inv.id is null then return jsonb_build_object('ok', false, 'error', 'invalid_code'); end if;
  if inv.status = 'accepted' and p_accept then
    return jsonb_build_object('ok', true, 'couple_id', inv.couple_id); -- action répétée
  end if;
  if inv.status <> 'claimed' or inv.claimed_by is null then
    return jsonb_build_object('ok', false, 'error', 'no_pending_request');
  end if;
  if not p_accept then
    update public.invitations set status = 'declined', responded_at = now() where id = inv.id;
    perform private.notify(inv.claimed_by, 'invitation_declined', null,
      jsonb_build_object('name', (select display_name from public.profiles where id = me)));
    return jsonb_build_object('ok', true);
  end if;
  if inv.expires_at <= now() then return jsonb_build_object('ok', false, 'error', 'expired'); end if;

  -- Sérialise les acceptations concernant ces deux personnes.
  perform pg_advisory_xact_lock(hashtext('duo:' || least(me, inv.claimed_by)::text));
  perform pg_advisory_xact_lock(hashtext('duo:' || greatest(me, inv.claimed_by)::text));
  if exists (select 1 from public.couple_members where user_id in (me, inv.claimed_by) and left_at is null) then
    return jsonb_build_object('ok', false, 'error', 'already_paired');
  end if;

  key := least(me, inv.claimed_by)::text || ':' || greatest(me, inv.claimed_by)::text;
  select id into target from public.couples where pair_key = key for update;
  begin
    if target is not null then
      -- Même paire : on retrouve l'espace existant, avec un nouvel épisode.
      resumed := true;
      update public.couples set status = 'active', separated_at = null where id = target;
      update public.couple_members set left_at = null where couple_id = target and user_id in (me, inv.claimed_by);
    else
      insert into public.couples (pair_key) values (key) returning id into target;
      insert into public.couple_members (couple_id, user_id, display_name_snapshot)
        select target, p.id, p.display_name from public.profiles p where p.id in (me, inv.claimed_by);
    end if;
    insert into public.duo_episodes (couple_id) values (target);
  exception when unique_violation then
    return jsonb_build_object('ok', false, 'error', 'already_paired');
  end;

  update public.invitations set status = 'accepted', responded_at = now(), couple_id = target where id = inv.id;
  update public.invitations set status = 'revoked', responded_at = now()
    where id <> inv.id and status in ('open', 'claimed')
      and (inviter_id in (me, inv.claimed_by) or claimed_by in (me, inv.claimed_by));
  perform private.notify(inv.claimed_by, 'invitation_accepted', target,
    jsonb_build_object('name', (select display_name from public.profiles where id = me), 'resumed', resumed));
  return jsonb_build_object('ok', true, 'couple_id', target, 'resumed', resumed);
end $$;

-- La demande de B prévient aussi A par une notification.
create or replace function public.claim_invitation(p_code text) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  r record;
  me uuid := auth.uid();
begin
  select * into r from private.check_invitation_code(p_code);
  if r.err is not null then return jsonb_build_object('ok', false, 'error', r.err); end if;
  if exists (select 1 from public.invitations where claimed_by = me and status = 'claimed' and id <> (r.inv).id) then
    return jsonb_build_object('ok', false, 'error', 'pending_request_elsewhere');
  end if;
  if (r.inv).status = 'claimed' then
    return jsonb_build_object('ok', true, 'id', (r.inv).id, 'repeated', true);
  end if;
  update public.invitations set status = 'claimed', claimed_by = me, claimed_at = now() where id = (r.inv).id;
  perform private.notify((r.inv).inviter_id, 'invitation_claimed', null,
    jsonb_build_object('name', (select display_name from public.profiles where id = me)));
  return jsonb_build_object('ok', true, 'id', (r.inv).id);
end $$;

-- Nouveau code : l'ancien est immédiatement invalidé.
create function public.regenerate_invitation() returns jsonb
language plpgsql security definer set search_path = '' as $$
begin
  update public.invitations set status = 'revoked', responded_at = now()
    where inviter_id = auth.uid() and status = 'open';
  return public.create_invitation();
end $$;

-- Terminer le duo actif (décision 8C) : chacun garde l'historique en lecture seule ; l'autre est prévenu.
create or replace function public.leave_couple() returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  me uuid := auth.uid();
  c uuid := private.my_couple_id();
  other uuid;
  open_session uuid;
begin
  if c is null then return jsonb_build_object('ok', true, 'repeated', true); end if;
  for open_session in select id from public.game_sessions where couple_id = c and status in ('lobby', 'playing', 'paused', 'ended') loop
    if (select status from public.game_sessions where id = open_session) = 'ended' then
      perform private.purge_session(open_session, (select count(*) = 2 and bool_and(keep_memory) from public.session_players where session_id = open_session));
      update public.game_sessions set status = 'closed', closed_at = now() where id = open_session;
    else
      perform private.purge_session(open_session, false);
      update public.game_sessions set status = 'abandoned', closed_at = now() where id = open_session;
    end if;
    perform private.bump_session(open_session, 'abandoned');
  end loop;
  select user_id into other from public.couple_members where couple_id = c and user_id <> me and left_at is null;
  update public.couples set status = 'separated', separated_at = now() where id = c;
  update public.couple_members set left_at = now() where couple_id = c and left_at is null;
  update public.duo_episodes set ended_at = now(), ended_by = me where couple_id = c and ended_at is null;
  perform private.notify(other, 'duo_ended', c, jsonb_build_object('name', (select display_name from public.profiles where id = me)));
  perform realtime.send(jsonb_build_object('status', 'separated'), 'duo', 'couple:' || c::text, true);
  return jsonb_build_object('ok', true);
end $$;

-- Mes duos (actif et archivés). Ne révèle jamais les autres duos de l'autre personne.
create function public.get_my_duos() returns jsonb
language sql stable security definer set search_path = '' as $$
  select coalesce(jsonb_agg(d order by (d ->> 'active')::boolean desc, d ->> 'last_activity' desc), '[]')
  from (
    select jsonb_build_object(
      'id', c.id,
      'active', c.status = 'active' and me.left_at is null,
      'created_at', c.created_at,
      'separated_at', c.separated_at,
      'partner', (select jsonb_build_object(
                    'id', o.user_id,
                    'name', coalesce(nullif(p.display_name, ''), o.display_name_snapshot, ''),
                    'avatar_path', p.avatar_path,
                    'deleted', o.user_id is null)
                  from public.couple_members o left join public.profiles p on p.id = o.user_id
                  where o.couple_id = c.id and o.id <> me.id limit 1),
      'episodes', (select coalesce(jsonb_agg(jsonb_build_object('started_at', e.started_at, 'ended_at', e.ended_at) order by e.started_at), '[]')
                   from public.duo_episodes e where e.couple_id = c.id),
      'last_activity', greatest(c.created_at, c.separated_at,
                         (select max(started_at) from public.duo_episodes e where e.couple_id = c.id))
    ) as d
    from public.couple_members me join public.couples c on c.id = me.couple_id
    where me.user_id = auth.uid()
  ) x
$$;

-- ---------------------------------------------------------------------------
-- 5. Parties : rattachement à l'épisode et proposition notifiée
-- ---------------------------------------------------------------------------
create or replace function private.after_session_created() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  new.episode_id := coalesce(new.episode_id,
    (select id from public.duo_episodes where couple_id = new.couple_id and ended_at is null));
  return new;
end $$;
create trigger game_sessions_episode before insert on public.game_sessions
  for each row execute function private.after_session_created();

create function private.notify_game_proposed() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  perform private.notify(cm.user_id, 'game_proposed', new.couple_id,
    jsonb_build_object('session_id', new.id, 'game_id', new.game_id,
      'title', (select title from public.games where id = new.game_id),
      'name', (select display_name from public.profiles where id = new.created_by)))
  from public.couple_members cm
  where cm.couple_id = new.couple_id and cm.left_at is null and cm.user_id is distinct from new.created_by;
  return null;
end $$;
create trigger game_sessions_proposed after insert on public.game_sessions
  for each row execute function private.notify_game_proposed();

-- ---------------------------------------------------------------------------
-- 6. Photos de profil : stockage privé, lisible par soi et ses partenaires (actuels ou passés)
-- ---------------------------------------------------------------------------
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('avatars', 'avatars', false, 524288, array['image/webp', 'image/jpeg', 'image/png'])
on conflict (id) do nothing;

create function private.avatar_owner(p_name text) returns uuid
language plpgsql immutable set search_path = '' as $$
begin
  return split_part(p_name, '/', 1)::uuid;
exception when others then
  return null;
end $$;
grant execute on function private.avatar_owner(text) to authenticated;

create policy avatars_read on storage.objects for select to authenticated
  using (bucket_id = 'avatars' and (private.avatar_owner(name) = (select auth.uid())
                                    or private.shares_couple_with(private.avatar_owner(name))));
create policy avatars_insert on storage.objects for insert to authenticated
  with check (bucket_id = 'avatars' and private.avatar_owner(name) = (select auth.uid()));
create policy avatars_update on storage.objects for update to authenticated
  using (bucket_id = 'avatars' and private.avatar_owner(name) = (select auth.uid()));
create policy avatars_delete on storage.objects for delete to authenticated
  using (bucket_id = 'avatars' and private.avatar_owner(name) = (select auth.uid()));

-- L'état d'une partie expose aussi le chemin de photo des joueurs (lecture soumise aux règles ci-dessus).
create or replace function public.get_session_state(p_session uuid) returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare
  s public.game_sessions;
  me uuid := auth.uid();
  my_seat int;
begin
  select * into s from public.game_sessions where id = p_session;
  if s.id is null or not private.is_member(s.couple_id, true) then
    return jsonb_build_object('ok', false, 'error', 'session_not_found');
  end if;
  select seat into my_seat from public.session_players where session_id = p_session and user_id = me;

  return jsonb_build_object(
    'ok', true,
    'session', jsonb_build_object(
      'id', s.id, 'game_id', s.game_id, 'game_version', s.game_version, 'status', s.status,
      'settings', s.settings, 'current_round', s.current_round, 'total_rounds', s.total_rounds,
      'paused_by', s.paused_by, 'state_version', s.state_version, 'created_at', s.created_at,
      'started_at', s.started_at, 'ended_at', s.ended_at, 'closed_at', s.closed_at,
      'read_only', not private.is_member(s.couple_id)),
    'my_seat', my_seat,
    'game', (select jsonb_build_object('title', g.title, 'mechanic', g.mechanic, 'rules', v.rules, 'config', v.config)
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
                 'round_no', rd.round_no, 'card', rd.card, 'revealed', rd.revealed_at is not null,
                 'answers', (select coalesce(jsonb_agg(jsonb_build_object(
                                'step', a.step, 'seat', a.seat, 'skipped', a.skipped,
                                'payload', case when a.seat = my_seat or rd.revealed_at is not null then a.payload end)
                              order by a.seat, a.created_at), '[]')
                             from public.session_answers a
                             where a.session_id = s.id and a.round_no = rd.round_no)
               ) order by rd.round_no), '[]')
               from public.session_rounds rd where rd.session_id = s.id)
  );
end $$;

revoke execute on all functions in schema public from public, anon;
grant execute on function public.mark_notifications_read(uuid[]), public.send_duo_message(uuid, text),
  public.mark_chat_read(uuid), public.get_chat_unread(), public.regenerate_invitation(), public.get_my_duos()
  to authenticated;
revoke execute on function private.after_session_created(), private.notify_game_proposed() from public, anon, authenticated;
