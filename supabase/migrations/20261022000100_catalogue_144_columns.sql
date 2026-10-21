-- Noodeu · Édition 2.1.0 (144 activités) : catalogue enrichi, banques de contenus, préférences privées
-- de partie (+18, thèmes à éviter) et moteur générique « manches à étapes » (famille 1).
-- Non destructif : les parties, réponses et jeux existants sont conservés.

-- Colonnes et tables ajoutées (aucune donnée supprimée).
alter table public.game_categories add column if not exists family_no int unique check (family_no between 1 and 8);


alter table public.games
  add column if not exists hook text not null default '',
  -- playable : moteur livré et testé ; coming_soon : visible grisé « Bientôt », non lançable (décision 2b).
  add column if not exists implementation text not null default 'playable' check (implementation in ('playable', 'coming_soon')),
  add column if not exists adult_available boolean not null default false,
  add column if not exists solo_allowed boolean not null default false,
  add column if not exists mute_ok boolean not null default true,
  add column if not exists difficulties text[] not null default '{}',
  add column if not exists thumbnail text,
  add column if not exists content_version text,
  add column if not exists meta jsonb not null default '{}';

alter table public.game_cards
  add column if not exists adult boolean not null default false,
  add column if not exists topic_tags text[] not null default '{}',
  add column if not exists theme text,
  add column if not exists content_version text;

-- Banques partagées entre activités (lexiques, objets, amorces…). Tirées côté serveur uniquement.
create table if not exists public.content_banks (
  bank text not null check (bank ~ '^[a-z_]{2,40}$'),
  idx int not null check (idx >= 0),
  value jsonb not null,
  content_version text not null,
  updated_at timestamptz not null default now(),
  primary key (bank, idx)
);
alter table public.content_banks enable row level security;
create policy content_banks_admin on public.content_banks for select to authenticated using (private.is_admin());
grant select on public.content_banks to authenticated;

-- Journal des imports (rapport : ajoutés, mis à jour, rejetés).
create table if not exists public.catalogue_imports (
  id bigint generated always as identity primary key,
  content_version text not null,
  report jsonb not null,
  created_at timestamptz not null default now()
);
alter table public.catalogue_imports enable row level security;
create policy catalogue_imports_admin on public.catalogue_imports for select to authenticated using (private.is_admin());
grant select on public.catalogue_imports to authenticated;

-- ---------------------------------------------------------------------------
-- 2. Parties : préférences privées, résultat, révisions d'étapes
-- ---------------------------------------------------------------------------
alter table public.game_sessions add column if not exists result jsonb not null default '{}';
alter table public.session_answers add column if not exists revision int not null default 0;
alter table public.session_answers add column if not exists updated_at timestamptz not null default now();
alter table public.session_rounds add column if not exists reveal_at timestamptz;

-- Préférences de chaque joueur pour la partie. Jamais lisibles par l'autre (décision 5a et kit 2.1.0).
create table if not exists public.session_prefs (
  session_id uuid not null references public.game_sessions (id) on delete cascade,
  seat int not null check (seat in (1, 2)),
  user_id uuid references auth.users (id) on delete set null,
  adult boolean not null default false,
  excluded_topics text[] not null default '{}',
  updated_at timestamptz not null default now(),
  primary key (session_id, seat)
);
alter table public.session_prefs enable row level security;
create policy session_prefs_own on public.session_prefs for select to authenticated using (user_id = (select auth.uid()));
grant select on public.session_prefs to authenticated;

