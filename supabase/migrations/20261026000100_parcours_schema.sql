-- Parcours : classement et filtres des contenus, rythme (Plus tard, Pause à double reprise, Arrêter), question du jour,
-- favoris, progression, retours privés et rappels doux. Migration non destructive : uniquement des ajouts de tables,
-- de colonnes et de fonctions ; aucun identifiant, texte, ordre ni calcul de questionnaire n'est modifié.

-- ===========================================================================
-- 1. Classement des contenus (serveur uniquement)
-- ===========================================================================
create table if not exists public.content_meta (
  bank text not null,
  item_id text not null,
  intensity text not null check (intensity in ('soft', 'moyen', 'hot')),
  adult boolean not null default false,
  duration_kind text not null check (duration_kind in ('rapide', 'discussion')),
  minutes_min int not null check (minutes_min between 1 and 60),
  minutes_max int not null check (minutes_max between 1 and 60),
  formats text[] not null default '{}',
  standalone boolean not null default false,
  review boolean not null default false,
  review_note text,
  seasons text[] not null default '{}',
  theme text,
  long_followup text,
  source text not null default 'regles-v1',
  updated_at timestamptz not null default now(),
  primary key (bank, item_id),
  check (formats <@ array['solo', 'duo', 'jeu', 'rituel', 'defi']),
  check (seasons <@ array['hiver', 'printemps', 'ete', 'automne'])
);
alter table public.content_meta enable row level security;
revoke all on public.content_meta from anon, authenticated;

-- Classement des activités (lisible avec le catalogue).
alter table public.games add column if not exists intensity text check (intensity in ('soft', 'moyen', 'hot'));
alter table public.games add column if not exists formats text[] not null default '{}';
alter table public.games add column if not exists duration_kind text check (duration_kind in ('rapide', 'discussion'));

-- ===========================================================================
-- 2. Préférences personnelles
-- ===========================================================================
alter table public.profiles add column if not exists max_intensity text not null default 'moyen'
  check (max_intensity in ('soft', 'moyen', 'hot'));
alter table public.profiles add column if not exists adult_confirmed_at timestamptz;
alter table public.profiles add column if not exists daily_adult boolean not null default false;
alter table public.profiles add column if not exists timezone text;
alter table public.profiles add column if not exists country text check (country is null or country ~ '^[A-Z]{2}$');
alter table public.profiles add column if not exists reminders jsonb not null
  default '{"enabled": false, "per_week": 2, "quiet_start": 21, "quiet_end": 9}';
alter table public.couples add column if not exists timezone text;

-- Les personnes qui avaient déjà activé « À huis clos » gardent les cartes qu'elles voyaient : intensité « Hot » autorisée.
update public.profiles set max_intensity = 'hot' where intimate_opt_in and max_intensity = 'moyen' and adult_confirmed_at is null;

-- Activer le +18 exige une déclaration de majorité (horodatée) ; la désactivation reste toujours possible.
-- Le +18 dans la question du jour demande aussi le +18 activé ; les rappels restent plafonnés (3 par semaine au plus).
create or replace function private.profile_guard() returns trigger
language plpgsql set search_path = '' as $$
begin
  if new.intimate_opt_in and not coalesce(old.intimate_opt_in, false) and new.adult_confirmed_at is null then
    raise exception 'adult_confirmation_required';
  end if;
  if not new.intimate_opt_in then new.daily_adult := false; end if;
  if new.timezone is not null and not exists (select 1 from pg_catalog.pg_timezone_names where name = new.timezone) then
    new.timezone := old.timezone;
  end if;
  new.reminders := jsonb_build_object(
    'enabled', coalesce((new.reminders ->> 'enabled')::boolean, false),
    'per_week', least(3, greatest(1, coalesce((new.reminders ->> 'per_week')::int, 2))),
    'quiet_start', least(23, greatest(0, coalesce((new.reminders ->> 'quiet_start')::int, 21))),
    'quiet_end', least(23, greatest(0, coalesce((new.reminders ->> 'quiet_end')::int, 9))));
  return new;
end $$;
do $$ begin
  if not exists (select 1 from pg_trigger where tgname = 'profile_guard' and tgrelid = 'public.profiles'::regclass) then
    create trigger profile_guard before update on public.profiles for each row execute function private.profile_guard();
  end if;
end $$;

create or replace function private.intensity_rank(t text) returns int
language sql immutable set search_path = '' as $$
  select case t when 'soft' then 1 when 'moyen' then 2 when 'hot' then 3 else 1 end $$;

-- Plafond commun du duo : l'intensité la plus basse acceptée par les deux.
create or replace function private.couple_cap(p_couple uuid) returns int
language sql stable security definer set search_path = '' as $$
  select coalesce(min(private.intensity_rank(p.max_intensity)), 1)
  from public.couple_members cm join public.profiles p on p.id = cm.user_id
  where cm.couple_id = p_couple and cm.left_at is null $$;

create or replace function private.session_cap(p_session uuid) returns int
language sql stable security definer set search_path = '' as $$
  select coalesce(min(private.intensity_rank(p.max_intensity)), 1)
  from public.session_players sp join public.profiles p on p.id = sp.user_id
  where sp.session_id = p_session and sp.user_id is not null $$;

-- Filtres effectifs pour l'écran : plafond commun et +18 possible pour les deux (sans dire qui a choisi quoi).
create or replace function public.get_my_filters() returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare
  me public.profiles;
  c uuid := private.my_couple_id();
begin
  select * into me from public.profiles where id = auth.uid();
  if me.id is null then return jsonb_build_object('ok', false, 'error', 'not_authenticated'); end if;
  return jsonb_build_object('ok', true,
    'my_max', me.max_intensity,
    'duo_cap', case when c is null then private.intensity_rank(me.max_intensity) else private.couple_cap(c) end,
    'duo_adult', c is not null and not exists (
      select 1 from public.couple_members cm join public.profiles p on p.id = cm.user_id
      where cm.couple_id = c and cm.left_at is null and not p.intimate_opt_in),
    'in_duo', c is not null);
end $$;

-- ===========================================================================
-- 3. Rythme : pause à double reprise, chronos suspendus
-- ===========================================================================
alter table public.game_sessions add column if not exists pause_state jsonb;

-- Décale les échéances de la manche en cours de la durée de la pause.
create or replace function private.shift_times(c jsonb, d interval) returns jsonb
language plpgsql immutable set search_path = '' as $$
declare k text;
begin
  foreach k in array array['starts_at', 'deadline_at', 'stop_after', 'validation_deadline'] loop
    if jsonb_typeof(c -> k) = 'string' then
      c := jsonb_set(c, array[k], to_jsonb(((c ->> k)::timestamptz + d)));
    end if;
  end loop;
  return c;
end $$;

-- Une personne peut mettre en pause ; la reprise exige l'accord des deux (chaque appel « reprendre » vaut un accord).
create or replace function public.set_paused(p_session uuid, p_paused boolean) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  r record;
  ps jsonb;
  votes jsonb;
  humans int;
  elapsed interval;
begin
  select * into r from private.lock_session(p_session);
  if p_paused then
    if (r.s).status <> 'playing' then return jsonb_build_object('ok', true, 'repeated', true); end if;
    update public.game_sessions set status = 'paused', paused_by = auth.uid(),
      pause_state = jsonb_build_object('paused_at', now(), 'by', r.seat, 'resume', '[]'::jsonb)
      where id = p_session;
    perform private.bump_session(p_session, 'pause');
    return jsonb_build_object('ok', true);
  end if;
  if (r.s).status <> 'paused' then return jsonb_build_object('ok', true, 'repeated', true); end if;
  ps := coalesce((r.s).pause_state, jsonb_build_object('paused_at', now(), 'resume', '[]'::jsonb));
  votes := coalesce(ps -> 'resume', '[]');
  if not votes ? r.seat::text then votes := votes || to_jsonb(r.seat::text); end if;
  select count(*) into humans from public.session_players where session_id = p_session and user_id is not null;
  if jsonb_array_length(votes) >= greatest(humans, 1) then
    elapsed := greatest(now() - coalesce((ps ->> 'paused_at')::timestamptz, now()), interval '0');
    update public.session_rounds set card = private.shift_times(card, elapsed)
      where session_id = p_session and round_no = (r.s).current_round and revealed_at is null;
    update public.game_sessions set status = 'playing', paused_by = null, pause_state = null where id = p_session;
    perform private.bump_session(p_session, 'pause');
    return jsonb_build_object('ok', true, 'resumed', true);
  end if;
  update public.game_sessions set pause_state = jsonb_set(ps, '{resume}', votes) where id = p_session;
  perform private.bump_session(p_session, 'pause');
  return jsonb_build_object('ok', true, 'waiting', true);
end $$;

-- ===========================================================================
-- 4. Plus tard, favoris, retours privés (données personnelles, jamais transmises au partenaire)
-- ===========================================================================
create table if not exists public.later_items (
  user_id uuid not null references auth.users (id) on delete cascade,
  bank text not null,
  item_id text not null,
  game_id text,
  created_at timestamptz not null default now(),
  primary key (user_id, bank, item_id)
);
create table if not exists public.item_favorites (
  user_id uuid not null references auth.users (id) on delete cascade,
  kind text not null check (kind in ('question', 'story')),
  bank text not null,
  item_id text not null,
  created_at timestamptz not null default now(),
  primary key (user_id, bank, item_id)
);
create table if not exists public.item_feedback (
  user_id uuid not null references auth.users (id) on delete cascade,
  bank text not null,
  item_id text not null,
  value text not null check (value in ('utile', 'trop_intime', 'bien_adaptee')),
  updated_at timestamptz not null default now(),
  primary key (user_id, bank, item_id)
);
alter table public.later_items enable row level security;
alter table public.item_favorites enable row level security;
alter table public.item_feedback enable row level security;
do $$ begin
  if not exists (select 1 from pg_policies where schemaname = 'public' and tablename = 'later_items' and policyname = 'later_own') then
    create policy later_own on public.later_items for all to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());
  end if;
end $$;
do $$ begin
  if not exists (select 1 from pg_policies where schemaname = 'public' and tablename = 'item_favorites' and policyname = 'favorites_own') then
    create policy favorites_own on public.item_favorites for all to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());
  end if;
end $$;
do $$ begin
  if not exists (select 1 from pg_policies where schemaname = 'public' and tablename = 'item_feedback' and policyname = 'feedback_own') then
    create policy feedback_own on public.item_feedback for all to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());
  end if;
end $$;
grant select, insert, update, delete on public.later_items, public.item_favorites, public.item_feedback to authenticated;
revoke all on public.later_items, public.item_favorites, public.item_feedback from anon;

-- Texte d'une question pour son propriétaire : jamais une carte +18 si le +18 n'est plus activé.
create or replace function private.item_view(p_bank text, p_item text, p_adult_ok boolean) returns jsonb
language sql stable security definer set search_path = '' as $$
  select case when cb.value is null then null
    when coalesce((cb.value ->> 'adult')::boolean, false) and not p_adult_ok then jsonb_build_object('hidden', true)
    else jsonb_strip_nulls(jsonb_build_object('text', coalesce(cb.value ->> 'text', cb.value ->> 'text_fr'),
      'prompt', cb.value ->> 'prompt', 'options', cb.value -> 'options', 'kind', cb.value ->> 'kind',
      'adult', coalesce((cb.value ->> 'adult')::boolean, false), 'theme', coalesce(cb.value ->> 'theme', m.theme),
      'intensity', m.intensity, 'duration_kind', m.duration_kind, 'minutes_min', m.minutes_min, 'minutes_max', m.minutes_max,
      'formats', to_jsonb(m.formats), 'long_followup', m.long_followup)) end
  from (select 1) one
  left join public.content_banks cb on cb.bank = p_bank and cb.value ->> 'id' = p_item
  left join public.content_meta m on m.bank = p_bank and m.item_id = p_item $$;

-- Mettre de côté la question de la manche en cours (sans prévenir le partenaire).
create or replace function public.save_for_later(p_session uuid, p_round int) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  r record;
  rd public.session_rounds;
  cfg jsonb;
  item text;
begin
  select * into r from private.lock_session(p_session);
  cfg := private.version_config(r.s);
  select * into rd from public.session_rounds where session_id = p_session and round_no = p_round;
  item := coalesce(rd.card #>> '{item,id}', rd.card ->> 'card_id');
  if item is null or cfg ->> 'bank' is null or coalesce((rd.card ->> 'redacted')::boolean, false) then
    return jsonb_build_object('ok', false, 'error', 'not_allowed');
  end if;
  insert into public.later_items (user_id, bank, item_id, game_id) values (auth.uid(), cfg ->> 'bank', item, (r.s).game_id)
    on conflict (user_id, bank, item_id) do nothing;
  return jsonb_build_object('ok', true);
end $$;

-- Mes questions mises de côté et favorites, avec leur texte.
create or replace function public.get_my_items() returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare
  adult_ok boolean := coalesce((select intimate_opt_in from public.profiles where id = auth.uid()), false);
begin
  if auth.uid() is null then return jsonb_build_object('ok', false, 'error', 'not_authenticated'); end if;
  return jsonb_build_object('ok', true,
    'later', (select coalesce(jsonb_agg(jsonb_build_object('bank', l.bank, 'item_id', l.item_id, 'game_id', l.game_id,
                'created_at', l.created_at, 'view', private.item_view(l.bank, l.item_id, adult_ok)) order by l.created_at desc), '[]')
              from public.later_items l where l.user_id = auth.uid()),
    'favorites', (select coalesce(jsonb_agg(jsonb_build_object('kind', f.kind, 'bank', f.bank, 'item_id', f.item_id,
                'created_at', f.created_at, 'view', private.item_view(f.bank, f.item_id, adult_ok)) order by f.created_at desc), '[]')
              from public.item_favorites f where f.user_id = auth.uid()));
end $$;

-- Métadonnées des cartes d'une partie (intensité, durée, version approfondie) pour les membres de la partie.
create or replace function public.get_session_meta(p_session uuid) returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare
  s public.game_sessions;
  cfg jsonb;
begin
  select * into s from public.game_sessions where id = p_session;
  if s.id is null or not private.is_member(s.couple_id, true) then return jsonb_build_object('ok', false, 'error', 'session_not_found'); end if;
  cfg := private.version_config(s);
  return jsonb_build_object('ok', true, 'bank', cfg ->> 'bank',
    'items', (select coalesce(jsonb_object_agg(m.item_id, jsonb_strip_nulls(jsonb_build_object('intensity', m.intensity,
                'duration_kind', m.duration_kind, 'minutes_min', m.minutes_min, 'minutes_max', m.minutes_max,
                'long_followup', m.long_followup, 'formats', to_jsonb(m.formats)))), '{}')
              from public.content_meta m
              where m.bank = cfg ->> 'bank' and m.item_id in (
                select coalesce(rd.card #>> '{item,id}', rd.card ->> 'card_id') from public.session_rounds rd
                where rd.session_id = p_session and not coalesce((rd.card ->> 'redacted')::boolean, false))));
end $$;

-- ===========================================================================
-- 5. Question du jour (même carte pour le duo, conservée pour la journée du fuseau du duo)
-- ===========================================================================
create table if not exists public.daily_cards (
  scope text not null,
  day date not null,
  bank text not null,
  item_id text not null,
  mode text not null default 'hasard' check (mode in ('hasard', 'theme', 'saison')),
  theme text,
  redraws int not null default 0,
  drawn_by uuid,
  drawn_at timestamptz not null default now(),
  primary key (scope, day)
);
alter table public.daily_cards enable row level security;
revoke all on public.daily_cards from anon, authenticated;

create or replace function private.season_of(d date) returns text
language sql immutable set search_path = '' as $$
  select case when extract(month from d) in (12, 1, 2) then 'hiver' when extract(month from d) in (3, 4, 5) then 'printemps'
              when extract(month from d) in (6, 7, 8) then 'ete' else 'automne' end $$;

create or replace function public.get_daily(p_mode text default null, p_theme text default null, p_tz text default null) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  me uuid := auth.uid();
  c uuid := private.my_couple_id();
  v_scope text;
  tz text;
  today date;
  cap int;
  adult_ok boolean;
  dc public.daily_cards;
  pick record;
  mode text := coalesce(p_mode, 'hasard');
begin
  if me is null then return jsonb_build_object('ok', false, 'error', 'not_authenticated'); end if;
  if mode not in ('hasard', 'theme', 'saison') then return jsonb_build_object('ok', false, 'error', 'invalid_mode'); end if;
  if p_tz is not null and not exists (select 1 from pg_catalog.pg_timezone_names where name = p_tz) then p_tz := null; end if;
  if c is not null then
    v_scope := 'c:' || c::text;
    update public.couples set timezone = p_tz where id = c and timezone is null and p_tz is not null;
    select coalesce(timezone, 'Europe/Paris') into tz from public.couples where id = c;
    cap := private.couple_cap(c);
    -- +18 dans la question du jour : activé personnellement par chacun des deux, en plus du +18 général.
    select bool_and(p.intimate_opt_in and p.daily_adult) and count(*) = 2 into adult_ok
      from public.couple_members cm join public.profiles p on p.id = cm.user_id where cm.couple_id = c and cm.left_at is null;
  else
    v_scope := 'u:' || me::text;
    update public.profiles set timezone = p_tz where id = me and timezone is null and p_tz is not null;
    select coalesce(timezone, 'Europe/Paris'), private.intensity_rank(max_intensity), intimate_opt_in and daily_adult
      into tz, cap, adult_ok from public.profiles where id = me;
  end if;
  today := (now() at time zone tz)::date;
  perform pg_advisory_xact_lock(hashtext('daily:' || v_scope));
  select * into dc from public.daily_cards d where d.scope = v_scope and d.day = today;
  -- Une nouvelle carte n'est tirée que pour un premier affichage ou un changement de thème demandé (3 par jour au plus).
  if dc.scope is null or (p_mode is not null and (dc.mode, coalesce(dc.theme, '')) is distinct from (mode, coalesce(p_theme, ''))
                           and dc.redraws < 3) then
    select m.bank, m.item_id into pick from public.content_meta m
      join public.content_banks cb on cb.bank = m.bank and cb.value ->> 'id' = m.item_id
      where m.standalone and not m.review
        and private.intensity_rank(m.intensity) <= cap
        and (not m.adult or coalesce(adult_ok, false))
        and (mode <> 'theme' or m.theme = p_theme)
        and (mode <> 'saison' or private.season_of(today) = any(m.seasons))
        and not exists (select 1 from public.daily_cards d where d.scope = v_scope and d.day > today - 90
                        and d.bank = m.bank and d.item_id = m.item_id)
      order by random() limit 1;
    if pick.bank is null then
      if dc.scope is null then return jsonb_build_object('ok', false, 'error', 'no_card'); end if;
      return jsonb_build_object('ok', false, 'error', 'no_card_for_filter', 'day', today);
    end if;
    insert into public.daily_cards (scope, day, bank, item_id, mode, theme, drawn_by)
      values (v_scope, today, pick.bank, pick.item_id, mode, case when mode = 'theme' then p_theme end, me)
      on conflict (scope, day) do update set bank = excluded.bank, item_id = excluded.item_id, mode = excluded.mode,
        theme = excluded.theme, redraws = daily_cards.redraws + 1, drawn_by = excluded.drawn_by, drawn_at = now()
      returning * into dc;
  end if;
  return jsonb_build_object('ok', true, 'day', dc.day, 'mode', dc.mode, 'theme', dc.theme, 'redraws_left', 3 - dc.redraws,
    'bank', dc.bank, 'item_id', dc.item_id, 'shared', c is not null,
    'card', private.item_view(dc.bank, dc.item_id, coalesce(adult_ok, false)));
end $$;

create or replace function public.get_daily_themes() returns jsonb
language sql stable security definer set search_path = '' as $$
  select coalesce(jsonb_agg(t order by t), '[]') from (
    select distinct m.theme t from public.content_meta m
    where m.standalone and not m.review and not m.adult and m.theme is not null
      and private.intensity_rank(m.intensity) <= coalesce(private.couple_cap(private.my_couple_id()),
        (select private.intensity_rank(max_intensity) from public.profiles where id = auth.uid()))) x $$;

-- ===========================================================================
-- 6. Progression du duo (compteurs seulement : aucune réponse n'est renvoyée)
-- ===========================================================================
create or replace function public.get_progress() returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare
  c uuid := private.my_couple_id();
begin
  if c is null then return jsonb_build_object('ok', true, 'games', '{}'::jsonb); end if;
  return jsonb_build_object('ok', true, 'games', coalesce((
    select jsonb_object_agg(g.id, x.p) from public.games g
    cross join lateral (
      select case
        when g.mechanic = 'pack_conversation' then (
          select jsonb_build_object('kind', 'pack',
            'count', (v.config #>> '{pack,count}')::int,
            'cards_done', coalesce(pp.cards_done, 0),
            'completed', coalesce(pp.cards_done, 0) >= (v.config #>> '{pack,count}')::int,
            'viewed', (select count(distinct rd.card #>> '{item,id}') from public.session_rounds rd join public.game_sessions gs on gs.id = rd.session_id
                       where gs.couple_id = c and gs.game_id = g.id),
            'answered', (select count(distinct rd.card #>> '{item,id}') from public.session_rounds rd join public.game_sessions gs on gs.id = rd.session_id
                         where gs.couple_id = c and gs.game_id = g.id and coalesce((rd.card ->> 'done')::boolean, false)
                           and rd.card #>> '{answers,1,choice}' in ('share', 'private') and rd.card #>> '{answers,2,choice}' in ('share', 'private')),
            'passed', (select count(distinct rd.card #>> '{item,id}') from public.session_rounds rd join public.game_sessions gs on gs.id = rd.session_id
                       where gs.couple_id = c and gs.game_id = g.id and coalesce((rd.card ->> 'done')::boolean, false)
                         and 'pass' in (rd.card #>> '{answers,1,choice}', rd.card #>> '{answers,2,choice}')))
          from public.game_versions v left join private.pack_progress pp on pp.couple_id = c and pp.game_id = g.id
          where v.game_id = g.id and v.version = g.current_version)
        when g.mechanic = 'test_form' then (
          select case when count(*) = 0 then null else jsonb_build_object('kind', 'test',
            'me', case when bool_or(rd.card -> 'completed' ? sp.seat::text) then 'completed'
                       when bool_or(rd.card -> 'declined' ? sp.seat::text) then 'declined' else 'started' end,
            'partner', case when bool_or(rd.card -> 'completed' ? (3 - sp.seat)::text) then 'completed'
                            when bool_or(rd.card -> 'declined' ? (3 - sp.seat)::text) then 'declined' else 'started' end) end
          from public.game_sessions gs join public.session_rounds rd on rd.session_id = gs.id
          join public.session_players sp on sp.session_id = gs.id and sp.user_id = auth.uid()
          where gs.couple_id = c and gs.game_id = g.id)
        else (
          select case when count(*) = 0 then null else jsonb_build_object('kind', 'game', 'played', count(*) filter (where gs.status in ('ended', 'closed')),
            'started', count(*)) end
          from public.game_sessions gs where gs.couple_id = c and gs.game_id = g.id and gs.status <> 'abandoned')
      end p) x
    where g.status = 'published' and x.p is not null
      and (g.mechanic <> 'pack_conversation' or (x.p ->> 'viewed')::int > 0 or (x.p ->> 'cards_done')::int > 0)), '{}'::jsonb));
end $$;

-- ===========================================================================
-- 7. Défi léger facultatif et rappels doux
-- ===========================================================================
create or replace function public.get_light_challenge() returns jsonb
language sql stable security definer set search_path = '' as $$
  select coalesce((select jsonb_build_object('ok', true, 'bank', m.bank, 'item_id', m.item_id, 'text', cb.value ->> 'text')
    from public.content_meta m join public.content_banks cb on cb.bank = m.bank and cb.value ->> 'id' = m.item_id
    where 'defi' = any(m.formats) and m.intensity = 'soft' and not m.adult and not m.review and m.bank = 'conv_truth_dare'
    order by random() limit 1), jsonb_build_object('ok', false, 'error', 'no_card')) $$;

-- Nouveau type de notification « rappel doux » (liste élargie, aucun type existant retiré).
alter table public.notifications drop constraint if exists notifications_type_check;
alter table public.notifications add constraint notifications_type_check check (type in ('invitation_claimed', 'invitation_accepted',
  'invitation_declined', 'duo_ended', 'game_proposed', 'message', 'gentle_reminder'));

-- Rappel doux : notification sans contenu intime, hors heures calmes, plafonnée par semaine et espacée de 48 h.
-- À planifier (par exemple toutes les heures) une fois l'extension pg_cron activée.
create or replace function private.send_gentle_reminders() returns int
language plpgsql security definer set search_path = '' as $$
declare
  p record;
  n int := 0;
  hour int;
begin
  for p in select pr.id, pr.reminders, coalesce(pr.timezone, cpl.timezone, 'Europe/Paris') tz, cm.couple_id
           from public.profiles pr
           left join public.couple_members cm on cm.user_id = pr.id and cm.left_at is null
           left join public.couples cpl on cpl.id = cm.couple_id
           where (pr.reminders ->> 'enabled')::boolean loop
    hour := extract(hour from now() at time zone p.tz)::int;
    if (p.reminders ->> 'quiet_start')::int > (p.reminders ->> 'quiet_end')::int
       and (hour >= (p.reminders ->> 'quiet_start')::int or hour < (p.reminders ->> 'quiet_end')::int) then continue; end if;
    if (p.reminders ->> 'quiet_start')::int <= (p.reminders ->> 'quiet_end')::int
       and hour >= (p.reminders ->> 'quiet_start')::int and hour < (p.reminders ->> 'quiet_end')::int then continue; end if;
    if (select count(*) from public.notifications where user_id = p.id and type = 'gentle_reminder'
        and created_at > now() - interval '7 days') >= (p.reminders ->> 'per_week')::int then continue; end if;
    if exists (select 1 from public.notifications where user_id = p.id and type = 'gentle_reminder'
               and created_at > now() - interval '48 hours') then continue; end if;
    -- Déjà venu aujourd'hui : pas de rappel.
    if exists (select 1 from public.daily_cards d where d.scope = coalesce('c:' || p.couple_id::text, 'u:' || p.id::text)
               and d.day = (now() at time zone p.tz)::date) then continue; end if;
    insert into public.notifications (user_id, type, couple_id, data) values (p.id, 'gentle_reminder', p.couple_id, '{}');
    n := n + 1;
  end loop;
  return n;
end $$;

revoke execute on function private.send_gentle_reminders(), private.profile_guard() from public, anon, authenticated;
revoke execute on function public.get_my_filters(), public.save_for_later(uuid, int), public.get_my_items(),
  public.get_session_meta(uuid), public.get_daily(text, text, text), public.get_daily_themes(), public.get_progress(),
  public.get_light_challenge(), public.set_paused(uuid, boolean) from public, anon;
grant execute on function public.get_my_filters(), public.save_for_later(uuid, int), public.get_my_items(),
  public.get_session_meta(uuid), public.get_daily(text, text, text), public.get_daily_themes(), public.get_progress(),
  public.get_light_challenge(), public.set_paused(uuid, boolean) to authenticated;
