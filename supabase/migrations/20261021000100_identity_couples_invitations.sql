-- Noodeu · Identité, couple et invitations
-- Règles : un utilisateur appartient au plus à un couple actif ; un couple compte au plus deux membres.
-- Les écritures sensibles passent par des fonctions (RPC) qui vérifient chaque règle côté serveur.

create schema if not exists private;
revoke all on schema private from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- Profils (données personnelles ; lisibles par soi et par son ou sa partenaire)
-- ---------------------------------------------------------------------------
create table public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  display_name text not null default '' check (char_length(display_name) <= 40),
  -- Accord grammatical utilisé par les jeux de mots : f = féminin, m = masculin, n = les deux formes.
  word_form text not null default 'n' check (word_form in ('f', 'm', 'n')),
  -- Contenus intimes : facultatifs, activés seulement si les deux partenaires l'acceptent.
  intimate_opt_in boolean not null default false,
  reduced_motion boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
alter table public.profiles enable row level security;

create function private.handle_new_user() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  insert into public.profiles (id, display_name)
  values (new.id, left(coalesce(trim(new.raw_user_meta_data ->> 'display_name'), ''), 40))
  on conflict (id) do nothing;
  return new;
end $$;

create trigger on_auth_user_created after insert on auth.users
  for each row execute function private.handle_new_user();

create function private.touch_updated_at() returns trigger
language plpgsql set search_path = '' as $$
begin new.updated_at := now(); return new; end $$;

create trigger profiles_touch before update on public.profiles
  for each row execute function private.touch_updated_at();

-- ---------------------------------------------------------------------------
-- Couples et membres
-- ---------------------------------------------------------------------------
create table public.couples (
  id uuid primary key default gen_random_uuid(),
  status text not null default 'active' check (status in ('active', 'separated')),
  created_at timestamptz not null default now(),
  separated_at timestamptz
);
alter table public.couples enable row level security;

create table public.couple_members (
  id uuid primary key default gen_random_uuid(),
  couple_id uuid not null references public.couples (id) on delete cascade,
  -- set null : après suppression d'un compte, l'autre membre conserve l'historique commun (décision 9A/8C).
  user_id uuid references auth.users (id) on delete set null,
  display_name_snapshot text not null default '',
  joined_at timestamptz not null default now(),
  left_at timestamptz
);
alter table public.couple_members enable row level security;
create unique index couple_members_one_active_couple on public.couple_members (user_id) where left_at is null;
create unique index couple_members_unique_member on public.couple_members (couple_id, user_id);
create index couple_members_couple on public.couple_members (couple_id);

-- Couple actif de l'utilisateur courant (null si aucun).
create function private.my_couple_id() returns uuid
language sql stable security definer set search_path = '' as $$
  select cm.couple_id from public.couple_members cm
  join public.couples c on c.id = cm.couple_id
  where cm.user_id = auth.uid() and cm.left_at is null and c.status = 'active'
  limit 1
$$;

-- Appartenance actuelle ou passée à un couple (l'historique reste lisible en lecture seule après séparation).
create function private.is_member(p_couple uuid, p_include_former boolean default false) returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.couple_members cm
    join public.couples c on c.id = cm.couple_id
    where cm.couple_id = p_couple and cm.user_id = auth.uid()
      and (p_include_former or (cm.left_at is null and c.status = 'active'))
  )
$$;

-- Partenaire actuel ou passé : sert à lire son profil.
create function private.shares_couple_with(p_user uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.couple_members me
    join public.couple_members other on other.couple_id = me.couple_id
    where me.user_id = auth.uid() and other.user_id = p_user
  )
$$;

create policy profiles_select on public.profiles for select to authenticated
  using (id = (select auth.uid()) or private.shares_couple_with(id));
create policy profiles_update on public.profiles for update to authenticated
  using (id = (select auth.uid())) with check (id = (select auth.uid()));

create policy couples_select on public.couples for select to authenticated
  using (private.is_member(id, true));
create policy couple_members_select on public.couple_members for select to authenticated
  using (private.is_member(couple_id, true));

grant usage on schema private to authenticated;
grant execute on function private.my_couple_id() to authenticated;
grant execute on function private.is_member(uuid, boolean) to authenticated;
grant execute on function private.shares_couple_with(uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- Invitations
-- ---------------------------------------------------------------------------
create table public.invitations (
  id uuid primary key default gen_random_uuid(),
  inviter_id uuid not null references auth.users (id) on delete cascade,
  code text not null unique check (code ~ '^[A-HJ-NP-Z2-9]{4}-[A-HJ-NP-Z2-9]{4}$'),
  status text not null default 'open'
    check (status in ('open', 'claimed', 'accepted', 'declined', 'revoked')),
  expires_at timestamptz not null default now() + interval '24 hours',
  claimed_by uuid references auth.users (id) on delete set null,
  claimed_at timestamptz,
  responded_at timestamptz,
  couple_id uuid references public.couples (id) on delete set null,
  created_at timestamptz not null default now()
);
alter table public.invitations enable row level security;
create unique index invitations_one_pending_per_inviter on public.invitations (inviter_id)
  where status in ('open', 'claimed');
create index invitations_claimed_by on public.invitations (claimed_by);

create policy invitations_select on public.invitations for select to authenticated
  using (inviter_id = (select auth.uid()) or claimed_by = (select auth.uid()));

-- Journal des tentatives (protection contre les essais répétés de codes).
create table private.invitation_attempts (
  id bigint generated always as identity primary key,
  user_id uuid not null,
  success boolean not null,
  created_at timestamptz not null default now()
);
create index invitation_attempts_user_time on private.invitation_attempts (user_id, created_at);

create function private.normalize_code(p_code text) returns text
language sql immutable set search_path = '' as $$
  select case when char_length(c) = 8 then substr(c, 1, 4) || '-' || substr(c, 5, 4) else c end
  from (select upper(regexp_replace(coalesce(p_code, ''), '[^A-Za-z0-9]', '', 'g')) as c) s
$$;

create function private.new_invitation_code() returns text
language plpgsql volatile set search_path = '' as $$
declare
  alphabet constant text := 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
  bytes bytea := extensions.gen_random_bytes(8);
  out text := '';
begin
  for i in 0..7 loop
    out := out || substr(alphabet, (get_byte(bytes, i) % 31) + 1, 1);
    if i = 3 then out := out || '-'; end if;
  end loop;
  return out;
end $$;

-- Notifie un utilisateur précis (canal privé « user:<id> »). Le contenu ne transporte aucune donnée sensible.
create function private.notify_user(p_user uuid, p_event text, p_payload jsonb default '{}') returns void
language plpgsql security definer set search_path = '' as $$
begin
  if p_user is not null then
    perform realtime.send(p_payload, p_event, 'user:' || p_user::text, true);
  end if;
end $$;

-- Vérifie le code et renvoie l'invitation, en journalisant la tentative. Résultat jsonb {ok, error?}.
create function private.check_invitation_code(p_code text, out inv public.invitations, out err text)
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
  elsif private.my_couple_id() is not null then
    err := 'you_are_already_paired';
  elsif exists (select 1 from public.couple_members where user_id = inv.inviter_id and left_at is null) then
    err := 'inviter_already_paired';
  end if;

  insert into private.invitation_attempts (user_id, success) values (me, err is null);
end $$;

-- Créer (ou recréer) son invitation. Une seule invitation en attente à la fois.
create function public.create_invitation() returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  me uuid := auth.uid();
  inv public.invitations;
begin
  if me is null then raise exception 'not_authenticated'; end if;
  if private.my_couple_id() is not null then
    return jsonb_build_object('ok', false, 'error', 'you_are_already_paired');
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

create function public.revoke_invitation(p_invitation uuid) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  inv public.invitations;
begin
  update public.invitations set status = 'revoked', responded_at = now()
    where id = p_invitation and inviter_id = auth.uid() and status in ('open', 'claimed')
    returning * into inv;
  if inv.id is not null and inv.claimed_by is not null then
    perform private.notify_user(inv.claimed_by, 'invitation', jsonb_build_object('status', 'revoked'));
  end if;
  return jsonb_build_object('ok', true);
end $$;

-- Aperçu avant de rejoindre : affiche le prénom de la personne qui invite.
create function public.preview_invitation(p_code text) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  r record;
begin
  select * into r from private.check_invitation_code(p_code);
  if r.err is not null then return jsonb_build_object('ok', false, 'error', r.err); end if;
  return jsonb_build_object('ok', true, 'id', (r.inv).id, 'expires_at', (r.inv).expires_at,
    'inviter_name', (select display_name from public.profiles where id = (r.inv).inviter_id));
end $$;

-- Première confirmation : la personne invitée demande à rejoindre.
create function public.claim_invitation(p_code text) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  r record;
  me uuid := auth.uid();
begin
  select * into r from private.check_invitation_code(p_code);
  if r.err is not null then return jsonb_build_object('ok', false, 'error', r.err); end if;
  -- Une seule demande en cours par personne invitée.
  if exists (select 1 from public.invitations where claimed_by = me and status = 'claimed' and id <> (r.inv).id) then
    return jsonb_build_object('ok', false, 'error', 'pending_request_elsewhere');
  end if;
  update public.invitations set status = 'claimed', claimed_by = me, claimed_at = coalesce(claimed_at, now())
    where id = (r.inv).id;
  perform private.notify_user((r.inv).inviter_id, 'invitation', jsonb_build_object('status', 'claimed'));
  return jsonb_build_object('ok', true, 'id', (r.inv).id);
end $$;

-- La personne invitée retire sa demande.
create function public.withdraw_claim(p_invitation uuid) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  inv public.invitations;
begin
  update public.invitations set status = 'open', claimed_by = null, claimed_at = null
    where id = p_invitation and claimed_by = auth.uid() and status = 'claimed'
    returning * into inv;
  if inv.id is not null then
    perform private.notify_user(inv.inviter_id, 'invitation', jsonb_build_object('status', 'open'));
  end if;
  return jsonb_build_object('ok', true);
end $$;

-- Seconde confirmation : la personne qui invite accepte ou refuse explicitement.
create function public.respond_to_claim(p_invitation uuid, p_accept boolean) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  me uuid := auth.uid();
  inv public.invitations;
  new_couple uuid;
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
    perform private.notify_user(inv.claimed_by, 'invitation', jsonb_build_object('status', 'declined'));
    return jsonb_build_object('ok', true);
  end if;
  if inv.expires_at <= now() then return jsonb_build_object('ok', false, 'error', 'expired'); end if;
  if exists (select 1 from public.couple_members where user_id in (me, inv.claimed_by) and left_at is null) then
    return jsonb_build_object('ok', false, 'error', 'already_paired');
  end if;

  insert into public.couples default values returning id into new_couple;
  insert into public.couple_members (couple_id, user_id, display_name_snapshot)
    select new_couple, p.id, p.display_name from public.profiles p where p.id in (me, inv.claimed_by);
  update public.invitations set status = 'accepted', responded_at = now(), couple_id = new_couple where id = inv.id;
  -- Les autres invitations en attente des deux personnes deviennent caduques.
  update public.invitations set status = 'revoked', responded_at = now()
    where id <> inv.id and status in ('open', 'claimed') and (inviter_id in (me, inv.claimed_by) or claimed_by in (me, inv.claimed_by));
  perform private.notify_user(inv.claimed_by, 'invitation', jsonb_build_object('status', 'accepted'));
  return jsonb_build_object('ok', true, 'couple_id', new_couple);
end $$;

-- Séparation (décision 8C) : le couple est figé ; chacun garde l'historique en lecture seule.
create function public.leave_couple() returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  c uuid := private.my_couple_id();
  other uuid;
begin
  if c is null then return jsonb_build_object('ok', true); end if;
  select user_id into other from public.couple_members where couple_id = c and user_id <> auth.uid() and left_at is null;
  update public.couples set status = 'separated', separated_at = now() where id = c;
  update public.couple_members set left_at = now() where couple_id = c and left_at is null;
  perform private.notify_user(other, 'couple', jsonb_build_object('status', 'separated'));
  return jsonb_build_object('ok', true);
end $$;

revoke execute on all functions in schema public from public, anon;
grant execute on function public.create_invitation(), public.revoke_invitation(uuid), public.preview_invitation(text),
  public.claim_invitation(text), public.withdraw_claim(uuid), public.respond_to_claim(uuid, boolean),
  public.leave_couple() to authenticated;
revoke execute on function private.check_invitation_code(text), private.new_invitation_code(),
  private.notify_user(uuid, text, jsonb), private.handle_new_user() from public, anon, authenticated;

-- Supabase accorde par défaut tous les droits aux rôles d'API : on repart de zéro puis on ouvre le strict nécessaire.
revoke all on public.profiles, public.couples, public.couple_members, public.invitations from anon, authenticated;
grant select, update (display_name, word_form, intimate_opt_in, reduced_motion) on public.profiles to authenticated;
grant select on public.couples, public.couple_members, public.invitations to authenticated;
