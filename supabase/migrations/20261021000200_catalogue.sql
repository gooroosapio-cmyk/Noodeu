-- Noodeu · Catalogue des jeux (données publiques pour les comptes connectés) et favoris personnels.
-- Identifiants stables en texte (slug). Une version publiée est immuable : une partie commencée
-- garde la copie de ses cartes (voir game_sessions / session_rounds).

create table public.app_admins (
  user_id uuid primary key references auth.users (id) on delete cascade,
  created_at timestamptz not null default now()
);
alter table public.app_admins enable row level security;

create function private.is_admin() returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.app_admins where user_id = auth.uid())
$$;
grant execute on function private.is_admin() to authenticated;

create table public.game_categories (
  id text primary key check (id ~ '^[a-z0-9-]{2,40}$'),
  title text not null,
  promise text not null default '',
  sort int not null default 0,
  status text not null default 'draft' check (status in ('draft', 'published', 'archived')),
  is_demo boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.games (
  id text primary key check (id ~ '^[a-z0-9-]{2,60}$'),
  category_id text not null references public.game_categories (id),
  mechanic text not null check (mechanic in ('portrait_words')),
  title text not null,
  promise text not null default '',
  style text not null default 'echange' check (style in ('echange', 'duel', 'cooperation')),
  duration_min int not null check (duration_min > 0),
  duration_max int not null check (duration_max >= duration_min),
  content_level text not null default 'standard' check (content_level in ('standard', 'intime')),
  current_version int,
  sort int not null default 0,
  status text not null default 'draft' check (status in ('draft', 'published', 'archived')),
  is_demo boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index games_category on public.games (category_id);

-- rules : textes affichés (objectif, étapes, règles détaillées).
-- config : paramètres du moteur (manches, étapes, réglages proposés, condition de révélation).
create table public.game_versions (
  game_id text not null references public.games (id) on delete cascade,
  version int not null check (version > 0),
  rules jsonb not null,
  config jsonb not null,
  published_at timestamptz,
  created_at timestamptz not null default now(),
  primary key (game_id, version)
);
alter table public.games add constraint games_current_version_fk
  foreign key (id, current_version) references public.game_versions (game_id, version) deferrable initially deferred;

create function private.game_version_immutable() returns trigger
language plpgsql set search_path = '' as $$
begin
  if old.published_at is not null then
    raise exception 'published_version_is_immutable';
  end if;
  return coalesce(new, old);
end $$;
create trigger game_versions_immutable before update or delete on public.game_versions
  for each row execute function private.game_version_immutable();

create table public.game_cards (
  id text primary key check (id ~ '^[A-Za-z0-9._-]{2,80}$'),
  game_id text not null references public.games (id) on delete cascade,
  kind text not null check (kind in ('word')),
  content jsonb not null,
  content_level text not null default 'standard' check (content_level in ('standard', 'intime')),
  sort int not null default 0,
  status text not null default 'draft' check (status in ('draft', 'published', 'archived')),
  is_demo boolean not null default false,
  source_note text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index game_cards_game on public.game_cards (game_id, status);

create trigger game_categories_touch before update on public.game_categories for each row execute function private.touch_updated_at();
create trigger games_touch before update on public.games for each row execute function private.touch_updated_at();
create trigger game_cards_touch before update on public.game_cards for each row execute function private.touch_updated_at();

alter table public.game_categories enable row level security;
alter table public.games enable row level security;
alter table public.game_versions enable row level security;
alter table public.game_cards enable row level security;

create policy categories_read on public.game_categories for select to authenticated
  using (status = 'published' or private.is_admin());
create policy games_read on public.games for select to authenticated
  using (status = 'published' or private.is_admin());
create policy versions_read on public.game_versions for select to authenticated
  using (published_at is not null or private.is_admin());
-- Les cartes ne sont pas lisibles directement par les joueurs : elles sont tirées côté serveur
-- au début de chaque manche (évite de dévoiler les cartes à l'avance).
create policy cards_read_admin on public.game_cards for select to authenticated
  using (private.is_admin());
create policy admins_read_self on public.app_admins for select to authenticated
  using (user_id = (select auth.uid()));

-- Favoris personnels : jamais partagés avec le ou la partenaire.
create table public.game_favorites (
  user_id uuid not null references auth.users (id) on delete cascade,
  game_id text not null references public.games (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_id, game_id)
);
alter table public.game_favorites enable row level security;
create policy game_favorites_own on public.game_favorites for all to authenticated
  using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));

revoke all on public.app_admins, public.game_categories, public.games, public.game_versions,
  public.game_cards, public.game_favorites from anon, authenticated;
grant select on public.app_admins, public.game_categories, public.games, public.game_versions, public.game_cards to authenticated;
grant select, insert, delete on public.game_favorites to authenticated;
