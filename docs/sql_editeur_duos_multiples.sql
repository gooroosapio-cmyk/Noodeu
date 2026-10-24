-- Noodeu : plusieurs duos actifs, bascule de l'un à l'autre, fin de duo sans notification.
-- À coller tel quel dans l'éditeur SQL de Supabase (projet Noodeu), puis « Run ». Indépendant du fichier
-- docs/sql_editeur_catalogue_final.sql (l'ordre n'a pas d'importance). En cas d'erreur, rien n'est modifié.
begin;
-- Plusieurs duos actifs en même temps : chacun choisit le duo affiché (« duo courant ») et peut basculer de l'un
-- à l'autre sans perte de données. Toutes les fonctions qui servent « mon duo » utilisent ce duo courant ;
-- l'accès reste limité, partout, aux duos dont la personne est membre (is_member), jamais aux duos de son partenaire.
-- Fin d'un duo : aucune notification n'est envoyée ; les anciennes notifications « duo terminé » sont effacées.

drop index if exists public.couple_members_one_active_couple;

create table if not exists private.current_duo (
  user_id uuid primary key references auth.users (id) on delete cascade,
  couple_id uuid not null references public.couples (id) on delete cascade,
  updated_at timestamptz not null default now()
);
alter table private.current_duo enable row level security;
revoke all on private.current_duo from public, anon, authenticated;

create or replace function private.max_duos() returns int language sql immutable set search_path = '' as $$ select 10 $$;

create or replace function private.active_duo_count(p_user uuid) returns int
language sql stable security definer set search_path = '' as $$
  select count(*)::int from public.couple_members cm join public.couples c on c.id = cm.couple_id
  where cm.user_id = p_user and cm.left_at is null and c.status = 'active' $$;

create or replace function private.active_pair(p_a uuid, p_b uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.couples c where c.status = 'active'
                 and c.pair_key = least(p_a, p_b)::text || ':' || greatest(p_a, p_b)::text
                 and not exists (select 1 from public.couple_members cm where cm.couple_id = c.id and cm.left_at is not null)) $$;

-- Duo courant : celui choisi par la personne s'il est toujours actif, sinon son duo actif le plus récent.
create or replace function private.my_couple_id() returns uuid
language sql stable security definer set search_path = '' as $$
  select cm.couple_id from public.couple_members cm
  join public.couples c on c.id = cm.couple_id
  where cm.user_id = auth.uid() and cm.left_at is null and c.status = 'active'
  order by (cm.couple_id = (select cd.couple_id from private.current_duo cd where cd.user_id = auth.uid())) is true desc,
           cm.joined_at desc
  limit 1
$$;

-- Bascule vers un autre de mes duos actifs (rien n'est modifié dans les duos eux-mêmes).
create or replace function public.set_current_duo(p_couple uuid) returns jsonb
language plpgsql security definer set search_path = '' as $$
begin
  if auth.uid() is null then return jsonb_build_object('ok', false, 'error', 'not_authenticated'); end if;
  if not private.is_member(p_couple) then return jsonb_build_object('ok', false, 'error', 'not_allowed'); end if;
  insert into private.current_duo (user_id, couple_id) values (auth.uid(), p_couple)
    on conflict (user_id) do update set couple_id = excluded.couple_id, updated_at = now();
  return jsonb_build_object('ok', true, 'couple_id', p_couple);
end $$;

create or replace function private.check_invitation_code(p_code text, out inv public.invitations, out err text)
language plpgsql security definer set search_path = '' as $$
declare
  me uuid := auth.uid();
  failures int;
begin
  if me is null then err := 'not_authenticated'; return; end if;
  select count(*) into failures from private.invitation_attempts
    where user_id = me and not success and created_at > now() - interval '15 minutes';
  if failures >= 8 then err := 'too_many_attempts'; return; end if;

  select * into inv from public.invitations where code = private.normalize_code(p_code) for update;
  if inv.id is null then
    err := 'invalid_code';
  elsif inv.inviter_id = me then
    err := 'own_invitation';
  elsif inv.status in ('revoked', 'declined') then
    err := 'revoked';
  elsif inv.status = 'accepted' or (inv.status = 'claimed' and inv.claimed_by is distinct from me) then
    err := 'already_used';
  elsif inv.expires_at <= now() then
    err := 'expired';
  elsif private.active_pair(me, inv.inviter_id) then
    err := 'already_your_duo';
  elsif private.active_duo_count(me) >= private.max_duos() then
    err := 'too_many_duos';
  elsif private.active_duo_count(inv.inviter_id) >= private.max_duos() then
    err := 'inviter_too_many_duos';
  end if;

  insert into private.invitation_attempts (user_id, success) values (me, err is null);
end $$;

create or replace function public.create_invitation() returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  me uuid := auth.uid();
  inv public.invitations;
begin
  if me is null then raise exception 'not_authenticated'; end if;
  if private.active_duo_count(me) >= private.max_duos() then
    return jsonb_build_object('ok', false, 'error', 'too_many_duos');
  end if;
  -- Réutilise l'invitation encore valide pour éviter les doublons (double clic, deux onglets).
  select * into inv from public.invitations
    where inviter_id = me and status = 'open' and expires_at > now() for update;
  if inv.id is null then
    update public.invitations set status = 'revoked', responded_at = now()
      where inviter_id = me and status in ('open', 'claimed');
    loop
      begin
        insert into public.invitations (inviter_id, code) values (me, private.new_invitation_code())
          returning * into inv;
        exit;
      exception when unique_violation then
        -- collision de code très improbable : on retente
      end;
    end loop;
  end if;
  return jsonb_build_object('ok', true, 'id', inv.id, 'code', inv.code, 'expires_at', inv.expires_at);
end $$;

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
  -- Plusieurs duos possibles : seule une même paire ne peut pas avoir deux duos actifs ; nombre de duos plafonné.
  if private.active_pair(me, inv.claimed_by) then
    return jsonb_build_object('ok', false, 'error', 'already_your_duo');
  end if;
  if private.active_duo_count(me) >= private.max_duos() or private.active_duo_count(inv.claimed_by) >= private.max_duos() then
    return jsonb_build_object('ok', false, 'error', 'too_many_duos');
  end if;
  -- Les duos déjà ouverts restent le duo affiché de chacun : le nouveau duo n'en prend la place que pour la personne
  -- qui accepte (et pour l'autre seulement si elle n'avait aucun duo).
  insert into private.current_duo (user_id, couple_id)
    select cm.user_id, cm.couple_id from public.couple_members cm join public.couples c on c.id = cm.couple_id
    where cm.user_id = inv.claimed_by and cm.left_at is null and c.status = 'active'
    order by cm.joined_at desc limit 1
    on conflict (user_id) do nothing;

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
  -- Seules les autres invitations entre ces deux mêmes personnes deviennent inutiles.
  update public.invitations set status = 'revoked', responded_at = now()
    where id <> inv.id and status in ('open', 'claimed')
      and ((inviter_id = me and claimed_by = inv.claimed_by) or (inviter_id = inv.claimed_by and claimed_by = me));
  insert into private.current_duo (user_id, couple_id) values (me, target)
    on conflict (user_id) do update set couple_id = excluded.couple_id, updated_at = now();
  perform private.notify(inv.claimed_by, 'invitation_accepted', target,
    jsonb_build_object('name', (select display_name from public.profiles where id = me), 'resumed', resumed));
  return jsonb_build_object('ok', true, 'couple_id', target, 'resumed', resumed);
end $$;

create or replace function public.leave_duo(p_couple uuid) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  me uuid := auth.uid();
  c uuid := case when private.is_member(p_couple) then p_couple end;
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
  update public.couples set status = 'separated', separated_at = now() where id = c;
  update public.couple_members set left_at = now() where couple_id = c and left_at is null;
  update public.duo_episodes set ended_at = now(), ended_by = me where couple_id = c and ended_at is null;
  -- Aucun des deux n'est prévenu par une notification : l'espace passe simplement en lecture seule.
  delete from private.current_duo where couple_id = c;
  perform realtime.send(jsonb_build_object('status', 'separated'), 'duo', 'couple:' || c::text, true);
  return jsonb_build_object('ok', true);
end $$;

-- Ancienne entrée (suppression de compte) : met fin à tous les duos actifs de la personne, sans notification.
create or replace function public.leave_couple() returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  c uuid;
begin
  for c in select cm.couple_id from public.couple_members cm join public.couples x on x.id = cm.couple_id
           where cm.user_id = auth.uid() and cm.left_at is null and x.status = 'active' loop
    perform public.leave_duo(c);
  end loop;
  return jsonb_build_object('ok', true);
end $$;

create or replace function public.get_my_duos() returns jsonb
language sql stable security definer set search_path = '' as $$
  select coalesce(jsonb_agg(d order by (d ->> 'current')::boolean desc, (d ->> 'active')::boolean desc, d ->> 'last_activity' desc), '[]')
  from (
    select jsonb_build_object(
      'id', c.id,
      'active', c.status = 'active' and me.left_at is null,
      'current', c.id = private.my_couple_id(),
      'unread', case when c.status = 'active' and me.left_at is null then (select count(*) from public.duo_messages m
                  where m.couple_id = c.id and m.user_id is distinct from auth.uid()
                    and m.created_at > coalesce((select r.last_read_at from public.duo_reads r
                                                 where r.couple_id = c.id and r.user_id = auth.uid()), '-infinity')) else 0 end,
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

delete from public.notifications where type = 'duo_ended';

revoke execute on function public.set_current_duo(uuid), public.leave_duo(uuid) from public, anon;
grant execute on function public.set_current_duo(uuid), public.leave_duo(uuid) to authenticated;
revoke execute on function private.active_duo_count(uuid), private.active_pair(uuid, uuid), private.max_duos() from public, anon, authenticated;

commit;
-- Contrôle : doit afficher true, true, 0.
select exists (select 1 from pg_proc where proname = 'set_current_duo') as bascule,
       not exists (select 1 from pg_indexes where indexname = 'couple_members_one_active_couple') as plusieurs_duos,
       (select count(*) from public.notifications where type = 'duo_ended') as notifications_fin;
