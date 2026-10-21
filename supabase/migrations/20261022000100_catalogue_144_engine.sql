-- Noodeu · Édition 2.1.0 (144 activités) : catalogue enrichi, banques de contenus, préférences privées
-- de partie (+18, thèmes à éviter) et moteur générique « manches à étapes » (famille 1).
-- Non destructif : les parties, réponses et jeux existants sont conservés.

-- ---------------------------------------------------------------------------
-- 1. Catalogue : familles, activités, cartes
-- ---------------------------------------------------------------------------
alter table public.game_categories add column if not exists family_no int unique check (family_no between 1 and 8);

alter table public.games drop constraint if exists games_id_check;
alter table public.games add constraint games_id_check check (id ~ '^[A-Za-z0-9-]{2,60}$');
alter table public.games drop constraint if exists games_mechanic_check;
alter table public.games add constraint games_mechanic_check check (mechanic ~ '^[a-z_]{2,40}$');
alter table public.games drop constraint if exists games_style_check;
alter table public.games add constraint games_style_check check (style in ('echange', 'duel', 'cooperation', 'creation'));

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

alter table public.game_cards drop constraint if exists game_cards_kind_check;
alter table public.game_cards add constraint game_cards_kind_check check (kind in ('word', 'question'));
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
revoke all on public.content_banks from anon, authenticated;
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
revoke all on public.catalogue_imports from anon, authenticated;
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
revoke all on public.session_prefs from anon, authenticated;
grant select on public.session_prefs to authenticated;

-- Les manches et réponses ne se lisent plus en direct : uniquement via get_session_state(), qui applique
-- les règles de visibilité propres à chaque étape (révélation, champ non partagé, date de réouverture).
revoke select on public.session_answers, public.session_rounds from authenticated;

-- Une manche est révélée quand revealed_at est passé (la capsule fixe une date future).
create or replace function private.can_read_answer(p_session uuid, p_round int, p_user uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select p_user = auth.uid()
    or (private.is_member(private.session_couple(p_session), true)
        and exists (select 1 from public.session_rounds r
                    where r.session_id = p_session and r.round_no = p_round and r.revealed_at <= now()))
$$;

-- Thèmes à éviter proposés dans les options et étiquettes de cartes correspondantes.
create or replace function private.topic_tags_for(p_topics text[]) returns text[]
language sql immutable set search_path = '' as $$
  select coalesce(array_agg(distinct t), '{}') from (
    select unnest(case k
      when 'passe' then array['passe', 'ancienne_relation']
      when 'sante_sexuelle' then array['sante_sexuelle']
      when 'numerique' then array['numerique']
      when 'desir' then array['desir']
      else array[]::text[] end) as t
    from unnest(coalesce(p_topics, '{}')) as k) x
$$;

-- ---------------------------------------------------------------------------
-- 3. Tirage : cartes de questions (deck) et listes tirées dans les banques
-- ---------------------------------------------------------------------------
create or replace function private.adult_allowed(p_session uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select count(*) = 2 and bool_and(sp.adult and coalesce(pr.intimate_opt_in, false))
  from public.session_prefs sp left join public.profiles pr on pr.id = sp.user_id
  where sp.session_id = p_session
$$;

create or replace function private.excluded_tags(p_session uuid) returns text[]
language sql stable security definer set search_path = '' as $$
  select private.topic_tags_for(coalesce(array_agg(t), '{}'))
  from public.session_prefs sp, unnest(sp.excluded_topics) t where sp.session_id = p_session
$$;

-- Nombre de cartes encore tirables pour cette partie (filtre +18 et thèmes appliqué).
create or replace function private.deck_available(s public.game_sessions) returns int
language sql stable security definer set search_path = '' as $$
  select count(*)::int from public.game_cards c
  where c.game_id = s.game_id and c.status = 'published' and c.kind = 'question'
    and (not c.adult or private.adult_allowed(s.id))
    and not (c.topic_tags && private.excluded_tags(s.id))
    and not exists (select 1 from public.session_rounds r where r.session_id = s.id and r.card ->> 'id' = c.id)
$$;

create or replace function private.bank_sample(p_bank text, p_count int) returns jsonb
language sql volatile security definer set search_path = '' as $$
  select coalesce(jsonb_agg(jsonb_build_object('i', b.idx, 'v', b.value) order by b.r), '[]')
  from (select idx, value, random() as r from public.content_banks where bank = p_bank
        order by case when p_count is null then idx::float else random() end
        limit coalesce(p_count, 10000)) b
$$;

create or replace function private.draw_round_card(s public.game_sessions, cfg jsonb) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  allow_intimate boolean;
  deck_size int;
  words jsonb;
  card jsonb := '{}';
  q public.game_cards;
  l jsonb;
  role_a int;
begin
  -- Ancienne démo (parties existantes uniquement).
  if cfg ->> 'mechanic' = 'portrait_words' then
    select bool_and(p.intimate_opt_in) into allow_intimate
      from public.session_players sp join public.profiles p on p.id = sp.user_id where sp.session_id = s.id;
    deck_size := coalesce((s.settings ->> 'deck_size')::int, (cfg #>> '{settings,deck_size,default}')::int, 12);
    select jsonb_agg(jsonb_build_object('id', c.id, 'f', c.content ->> 'f', 'm', c.content ->> 'm') order by random())
      into words
      from (select * from public.game_cards
            where game_id = s.game_id and status = 'published' and kind = 'word'
              and (content_level = 'standard' or coalesce(allow_intimate, false))
            order by random() limit deck_size) c;
    if words is null or jsonb_array_length(words) < (cfg ->> 'pick')::int then
      raise exception 'not_enough_cards';
    end if;
    return jsonb_build_object('words', words);
  end if;

  if cfg ->> 'engine' <> 'rounds' then raise exception 'unknown_mechanic'; end if;

  -- Carte de question : sans répétition dans la partie, en évitant d'abord celles vues récemment par le duo.
  if cfg #>> '{draw,deck}' = 'true' then
    select c.* into q from public.game_cards c
    where c.game_id = s.game_id and c.status = 'published' and c.kind = 'question'
      and (not c.adult or private.adult_allowed(s.id))
      and not (c.topic_tags && private.excluded_tags(s.id))
      and not exists (select 1 from public.session_rounds r where r.session_id = s.id and r.card ->> 'id' = c.id)
    order by exists (select 1 from public.session_rounds r join public.game_sessions gs on gs.id = r.session_id
                     where gs.couple_id = s.couple_id and gs.game_id = s.game_id
                       and gs.created_at > now() - interval '60 days' and r.card ->> 'id' = c.id),
             random()
    limit 1;
    if q.id is null then raise exception 'not_enough_cards'; end if;
    card := jsonb_build_object('id', q.id, 'text', q.content ->> 'text', 'choices', coalesce(q.content -> 'choices', '[]'),
                               'adult', q.adult, 'theme', q.theme, 'format', q.content ->> 'format');
  end if;

  for l in select * from jsonb_array_elements(coalesce(cfg #> '{draw,lists}', '[]')) loop
    card := card || jsonb_build_object(l ->> 'key', private.bank_sample(l ->> 'bank', (l ->> 'count')::int));
  end loop;
  card := card || coalesce(cfg #> '{draw,fixed}', '{}');

  -- Rôles alternés (prédiction, écoute) : le siège « a » change à chaque manche.
  role_a := case when cfg ->> 'roles' = 'alternate' then ((greatest(s.current_round, 1) - 1) % 2) + 1 else 1 end;
  return card || jsonb_build_object('role_a', role_a);
end $$;

-- ---------------------------------------------------------------------------
-- 4. Validation des étapes (côté serveur ; le navigateur n'est jamais cru sur parole)
-- ---------------------------------------------------------------------------
create or replace function private.clean_text(p jsonb, p_key text, p_max int, p_required boolean default false) returns text
language plpgsql immutable set search_path = '' as $$
declare
  v text;
begin
  if p is null or p -> p_key is null or jsonb_typeof(p -> p_key) = 'null' then
    v := '';
  elsif jsonb_typeof(p -> p_key) <> 'string' then
    raise exception 'invalid_answer';
  else
    v := btrim(regexp_replace(p ->> p_key, '[\u0000-\u0008\u000B\u000C\u000E-\u001F\u007F]', '', 'g'));
  end if;
  if char_length(v) > p_max or (p_required and v = '') then raise exception 'invalid_answer'; end if;
  return nullif(v, '');
end $$;

-- Index entier dans [0, n).
create or replace function private.idx(v jsonb, n int) returns int
language plpgsql immutable set search_path = '' as $$
begin
  if v is null or jsonb_typeof(v) <> 'number' or (v::text)::numeric <> floor((v::text)::numeric)
     or (v::text)::int < 0 or (v::text)::int >= n then
    raise exception 'invalid_answer';
  end if;
  return (v::text)::int;
end $$;

-- Liste d'index distincts, longueur dans [p_min, p_max].
create or replace function private.idx_list(v jsonb, n int, p_min int, p_max int) returns int[]
language plpgsql immutable set search_path = '' as $$
declare
  res int[] := '{}';
  e jsonb;
  i int;
begin
  if v is null then v := '[]'; end if;
  if jsonb_typeof(v) <> 'array' or jsonb_array_length(v) < p_min or jsonb_array_length(v) > p_max then
    raise exception 'invalid_answer';
  end if;
  for e in select * from jsonb_array_elements(v) loop
    i := private.idx(e, n);
    if i = any(res) then raise exception 'invalid_answer'; end if;
    res := res || i;
  end loop;
  return res;
end $$;

-- Dessin vectoriel : traits normalisés 0..1 (couleur, épaisseur, points). Limites raisonnables.
create or replace function private.clean_drawing(v jsonb) returns jsonb
language plpgsql immutable set search_path = '' as $$
declare
  s jsonb;
  pt jsonb;
  total int := 0;
  out_strokes jsonb := '[]';
  pts jsonb;
  x numeric;
  y numeric;
begin
  if v is null or jsonb_typeof(v) = 'null' then return null; end if;
  if jsonb_typeof(v) <> 'array' or jsonb_array_length(v) > 80 then raise exception 'invalid_answer'; end if;
  for s in select * from jsonb_array_elements(v) loop
    if jsonb_typeof(s -> 'p') <> 'array' or jsonb_array_length(s -> 'p') < 1 or jsonb_array_length(s -> 'p') > 500 then
      raise exception 'invalid_answer';
    end if;
    pts := '[]';
    for pt in select * from jsonb_array_elements(s -> 'p') loop
      if jsonb_typeof(pt) <> 'array' or jsonb_array_length(pt) <> 2
         or jsonb_typeof(pt -> 0) <> 'number' or jsonb_typeof(pt -> 1) <> 'number' then
        raise exception 'invalid_answer';
      end if;
      x := round((pt ->> 0)::numeric, 3); y := round((pt ->> 1)::numeric, 3);
      if x < 0 or x > 1 or y < 0 or y > 1 then raise exception 'invalid_answer'; end if;
      pts := pts || jsonb_build_array(jsonb_build_array(x, y));
    end loop;
    total := total + jsonb_array_length(pts);
    out_strokes := out_strokes || jsonb_build_array(jsonb_build_object(
      'c', private.idx(s -> 'c', 8), 'w', private.idx(s -> 'w', 3), 'p', pts));
  end loop;
  if total > 6000 then raise exception 'invalid_answer'; end if;
  return case when jsonb_array_length(out_strokes) = 0 then null else out_strokes end;
end $$;

-- Charge utile d'une réponse déjà donnée dans la manche (pour les étapes qui en dépendent).
create or replace function private.round_answer(p_session uuid, p_round int, p_step text, p_seat int) returns jsonb
language sql stable security definer set search_path = '' as $$
  select payload from public.session_answers
  where session_id = p_session and round_no = p_round and step = p_step and seat = p_seat
$$;

create or replace function private.validate_step(st jsonb, card jsonb, p jsonb, p_session uuid, p_round int, p_seat int)
returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare
  k text := st ->> 'kind';
  prm jsonb := coalesce(st -> 'params', '{}');
  other int := 3 - p_seat;
  n int;
  items int[];
  arr jsonb := '[]';
  e jsonb;
  i int;
  total int;
  allowed int[];
  cells text[] := '{}';
  ref jsonb;
  t text;
begin
  if p is null or jsonb_typeof(p) <> 'object' then raise exception 'invalid_answer'; end if;

  case k
  when 'text' then
    return jsonb_build_object('text', private.clean_text(p, 'text', (prm ->> 'max')::int, true));

  when 'choice' then
    n := jsonb_array_length(card -> 'choices');
    if jsonb_typeof(p -> 'choice') = 'string' then
      if not coalesce(prm -> 'extras', '[]') ? (p ->> 'choice') then raise exception 'invalid_answer'; end if;
      return jsonb_strip_nulls(jsonb_build_object('choice', p ->> 'choice',
        'other', case when p ->> 'choice' = 'other' then private.clean_text(p, 'other', 80, true) end,
        'comment', private.clean_text(p, 'comment', coalesce((prm ->> 'comment_max')::int, 0))));
    end if;
    return jsonb_strip_nulls(jsonb_build_object('choice', private.idx(p -> 'choice', n),
      'comment', private.clean_text(p, 'comment', coalesce((prm ->> 'comment_max')::int, 0))));

  when 'yes_no' then
    if p ->> 'answer' not in ('yes', 'no') then raise exception 'invalid_answer'; end if;
    return jsonb_build_object('answer', p ->> 'answer');

  when 'pick' then
    -- Sélection dans une liste tirée (mots, valeurs) ; mots personnels facultatifs ; ordre conservé.
    n := jsonb_array_length(card -> (prm ->> 'list'));
    items := private.idx_list(p -> 'items', n, 0, (prm ->> 'max')::int);
    if jsonb_typeof(coalesce(p -> 'custom', '[]')) <> 'array'
       or jsonb_array_length(coalesce(p -> 'custom', '[]')) > coalesce((prm ->> 'custom_max')::int, 0) then
      raise exception 'invalid_answer';
    end if;
    for e in select * from jsonb_array_elements(coalesce(p -> 'custom', '[]')) loop
      t := private.clean_text(jsonb_build_object('t', e), 't', coalesce((prm ->> 'custom_len')::int, 24), true);
      arr := arr || to_jsonb(t);
    end loop;
    total := coalesce(array_length(items, 1), 0) + jsonb_array_length(arr);
    if total < (prm ->> 'min')::int or total > (prm ->> 'max')::int then raise exception 'invalid_answer'; end if;
    return jsonb_strip_nulls(jsonb_build_object('items', to_jsonb(items), 'custom', arr,
      'note', private.clean_text(p, 'note', coalesce((prm ->> 'note_max')::int, 0))));

  when 'objects' then
    n := jsonb_array_length(card -> 'objects');
    if jsonb_typeof(p -> 'items') <> 'array' or jsonb_array_length(p -> 'items') <> (prm ->> 'count')::int then
      raise exception 'invalid_answer';
    end if;
    for e in select * from jsonb_array_elements(p -> 'items') loop
      i := private.idx(e -> 'i', n);
      if i = any(coalesce(items, '{}')) then raise exception 'invalid_answer'; end if;
      items := coalesce(items, '{}') || i;
      arr := arr || jsonb_build_array(jsonb_strip_nulls(jsonb_build_object('i', i,
        'caption', private.clean_text(e, 'caption', (prm ->> 'caption_max')::int))));
    end loop;
    return jsonb_build_object('items', arr, 'bg', private.idx(p -> 'bg', (prm ->> 'backgrounds')::int));

  when 'sky' then
    items := private.idx_list(p -> 'symbols', jsonb_array_length(card -> 'symbols'), 1, 3);
    return jsonb_strip_nulls(jsonb_build_object('symbols', to_jsonb(items),
      'energy', private.idx(p -> 'energy', jsonb_array_length(card -> 'energies')),
      'note', private.clean_text(p, 'note', 200)));

  when 'frise' then
    n := jsonb_array_length(card -> 'prompts');
    if jsonb_typeof(p -> 'entries') <> 'array' or jsonb_array_length(p -> 'entries') <> n
       or coalesce(p ->> 'order', '') not in ('chrono', 'emotion') then
      raise exception 'invalid_answer';
    end if;
    for e in select * from jsonb_array_elements(p -> 'entries') loop
      i := private.idx(e -> 'p', n);
      if i = any(coalesce(items, '{}')) then raise exception 'invalid_answer'; end if;
      items := coalesce(items, '{}') || i;
      arr := arr || jsonb_build_array(jsonb_strip_nulls(jsonb_build_object('p', i,
        'title', private.clean_text(e, 'title', 40, true), 'text', private.clean_text(e, 'text', 160),
        'date', private.clean_text(e, 'date', 20))));
    end loop;
    return jsonb_build_object('entries', arr, 'order', p ->> 'order');

  when 'gesture' then
    e := jsonb_strip_nulls(jsonb_build_object('action', private.idx(p -> 'action', jsonb_array_length(card -> 'actions')),
      'text', private.clean_text(p, 'text', 280), 'drawing', private.clean_drawing(p -> 'drawing')));
    if e -> 'text' is null and e -> 'drawing' is null then raise exception 'invalid_answer'; end if;
    return e;

  when 'buy' then
    items := private.idx_list(p -> 'items', jsonb_array_length(card -> 'activities'), 1, (prm ->> 'max_items')::int);
    select sum((card -> 'activities' -> x -> 'v' ->> 'cost')::int) into total from unnest(items) x;
    if total > (prm ->> 'budget')::int then raise exception 'invalid_answer'; end if;
    return jsonb_build_object('items', to_jsonb(items), 'spent', total);

  when 'common' then
    -- Combinaison commune : uniquement parmi les activités choisies par l'un ou l'autre.
    select array_agg(distinct (x::text)::int) into allowed
      from public.session_answers a, jsonb_array_elements(a.payload -> 'items') x
      where a.session_id = p_session and a.round_no = p_round and a.step = (prm ->> 'from');
    items := private.idx_list(p -> 'items', jsonb_array_length(card -> 'activities'), 1, 12);
    if not (items <@ coalesce(allowed, '{}')) then raise exception 'invalid_answer'; end if;
    select sum((card -> 'activities' -> x -> 'v' ->> 'cost')::int) into total from unnest(items) x;
    if total > (prm ->> 'budget')::int then raise exception 'invalid_answer'; end if;
    return jsonb_build_object('items', to_jsonb(items), 'spent', total);

  when 'place' then
    -- Trois objets sur sa moitié d'une grille 6 × 4 : colonnes 0–2 pour le siège 1, 3–5 pour le siège 2.
    n := jsonb_array_length(card -> 'objects');
    if jsonb_typeof(p -> 'objects') <> 'array' or jsonb_array_length(p -> 'objects') <> (prm ->> 'count')::int then
      raise exception 'invalid_answer';
    end if;
    for e in select * from jsonb_array_elements(p -> 'objects') loop
      i := private.idx(e -> 'i', n);
      if i = any(coalesce(items, '{}')) then raise exception 'invalid_answer'; end if;
      items := coalesce(items, '{}') || i;
      total := private.idx(e -> 'x', 6);
      if (p_seat = 1 and total > 2) or (p_seat = 2 and total < 3) then raise exception 'invalid_answer'; end if;
      t := total || ':' || private.idx(e -> 'y', 4);
      if t = any(cells) then raise exception 'invalid_answer'; end if;
      cells := cells || t;
      arr := arr || jsonb_build_array(jsonb_build_object('i', i, 'x', total, 'y', (e ->> 'y')::int));
    end loop;
    return jsonb_build_object('objects', arr);

  when 'light' then
    return jsonb_build_object('light', private.idx(p -> 'light', jsonb_array_length(card -> 'lights')),
      'ambiance', private.idx(p -> 'ambiance', jsonb_array_length(card -> 'ambiances')));

  when 'agree' then
    i := private.idx(p -> 'pick', 3);
    if i = 0 then raise exception 'invalid_answer'; end if;
    return jsonb_build_object('pick', i);

  when 'gift' then
    e := jsonb_strip_nulls(jsonb_build_object(
      'paper', private.idx(p -> 'paper', jsonb_array_length(card -> 'papers')),
      'ribbon', private.idx(p -> 'ribbon', jsonb_array_length(card -> 'ribbons')),
      'object', case when p -> 'object' is null or jsonb_typeof(p -> 'object') = 'null' then null
                     else private.idx(p -> 'object', jsonb_array_length(card -> 'objects')) end,
      'word', private.clean_text(p, 'word', 160),
      'drawing', private.clean_drawing(p -> 'drawing')));
    return e;

  when 'page' then
    n := jsonb_array_length(card -> 'stickers');
    if jsonb_typeof(coalesce(p -> 'stickers', '[]')) <> 'array' or jsonb_array_length(coalesce(p -> 'stickers', '[]')) > 8 then
      raise exception 'invalid_answer';
    end if;
    for e in select * from jsonb_array_elements(coalesce(p -> 'stickers', '[]')) loop
      if jsonb_typeof(e -> 'x') <> 'number' or jsonb_typeof(e -> 'y') <> 'number'
         or (e ->> 'x')::numeric not between 0 and 1 or (e ->> 'y')::numeric not between 0 and 1 then
        raise exception 'invalid_answer';
      end if;
      arr := arr || jsonb_build_array(jsonb_build_object('s', private.idx(e -> 's', n),
        'x', round((e ->> 'x')::numeric, 3), 'y', round((e ->> 'y')::numeric, 3)));
    end loop;
    e := jsonb_strip_nulls(jsonb_build_object('text', private.clean_text(p, 'text', 200), 'stickers', arr,
      'drawing', private.clean_drawing(p -> 'drawing')));
    if e -> 'text' is null and jsonb_array_length(arr) = 0 and e -> 'drawing' is null then raise exception 'invalid_answer'; end if;
    return e;

  when 'cover_pick' then
    -- Un détail de sa propre page proposé pour la couverture : une gommette posée ou une courte phrase.
    if p -> 'sticker' is not null then
      i := private.idx(p -> 'sticker', jsonb_array_length(card -> 'stickers'));
      if not exists (select 1 from jsonb_array_elements(private.round_answer(p_session, p_round, prm ->> 'from', p_seat) -> 'stickers') s
                     where (s ->> 's')::int = i) then
        raise exception 'invalid_answer';
      end if;
      return jsonb_build_object('sticker', i);
    end if;
    return jsonb_build_object('text', private.clean_text(p, 'text', 40, true));

  when 'line' then
    if p -> 'sticker' is not null then
      return jsonb_build_object('sticker', private.idx(p -> 'sticker', jsonb_array_length(card -> 'stickers')));
    end if;
    return jsonb_build_object('text', private.clean_text(p, 'text', 80, true));

  when 'fields' then
    -- Capsule : trois champs, chacun partagé ou gardé pour soi.
    if jsonb_typeof(p -> 'fields') <> 'array' or jsonb_array_length(p -> 'fields') <> (prm ->> 'count')::int then
      raise exception 'invalid_answer';
    end if;
    for e in select * from jsonb_array_elements(p -> 'fields') loop
      if jsonb_typeof(coalesce(e -> 'shared', 'false'::jsonb)) <> 'boolean' then raise exception 'invalid_answer'; end if;
      arr := arr || jsonb_build_array(jsonb_strip_nulls(jsonb_build_object(
        'text', private.clean_text(e, 'text', (prm ->> 'max')::int), 'shared', coalesce((e ->> 'shared')::boolean, false))));
    end loop;
    if not exists (select 1 from jsonb_array_elements(arr) x where x ? 'text') then raise exception 'invalid_answer'; end if;
    return jsonb_build_object('fields', arr);

  when 'share' then
    -- Un thème ou une amorce tirés, puis un texte.
    return jsonb_build_object('topic', private.idx(p -> 'topic', jsonb_array_length(card -> coalesce(prm ->> 'list', 'topics'))),
      'text', private.clean_text(p, 'text', coalesce((prm ->> 'max')::int, 500), true));

  when 'confirm' then
    if jsonb_typeof(p -> 'ok') <> 'boolean' then raise exception 'invalid_answer'; end if;
    if (p ->> 'ok')::boolean then return jsonb_build_object('ok', true); end if;
    return jsonb_build_object('ok', false, 'nuance', private.clean_text(p, 'nuance', 250, true));

  when 'reaction' then
    if prm ? 'options' then
      return jsonb_strip_nulls(jsonb_build_object('option', private.idx(p -> 'option', jsonb_array_length(prm -> 'options')),
        'text', private.clean_text(p, 'text', coalesce((prm ->> 'max')::int, 0))));
    end if;
    return jsonb_build_object('text', private.clean_text(p, 'text', (prm ->> 'max')::int, true));

  when 'surprise' then
    -- Entourer un mot du portrait de l'autre : un mot choisi (i) ou un mot personnel (c).
    ref := private.round_answer(p_session, p_round, prm ->> 'from', other);
    if ref is null then raise exception 'invalid_answer'; end if;
    if p -> 'i' is not null then
      i := private.idx(p -> 'i', 1000);
      if not (ref -> 'items') @> to_jsonb(i) then raise exception 'invalid_answer'; end if;
      return jsonb_build_object('i', i);
    end if;
    i := private.idx(p -> 'c', jsonb_array_length(coalesce(ref -> 'custom', '[]')));
    return jsonb_build_object('c', i);

  when 'zones' then
    n := jsonb_array_length(card -> 'labels');
    if jsonb_typeof(p -> 'places') <> 'array' or jsonb_array_length(p -> 'places') > (prm ->> 'max')::int then
      raise exception 'invalid_answer';
    end if;
    for e in select * from jsonb_array_elements(p -> 'places') loop
      i := private.idx(e -> 'i', n);
      if i = any(coalesce(items, '{}')) then raise exception 'invalid_answer'; end if;
      items := coalesce(items, '{}') || i;
      arr := arr || jsonb_build_array(jsonb_build_object('i', i, 'z', private.idx(e -> 'z', 3)));
    end loop;
    if jsonb_array_length(arr) = 0 then raise exception 'invalid_answer'; end if;
    if p -> 'detail' is not null and jsonb_typeof(p -> 'detail') <> 'null' then
      i := private.idx(p #> '{detail,i}', n);
      if not (i = any(items)) then raise exception 'invalid_answer'; end if;
      return jsonb_build_object('places', arr, 'detail',
        jsonb_build_object('i', i, 'text', private.clean_text(p -> 'detail', 'text', 80, true)));
    end if;
    return jsonb_build_object('places', arr);

  when 'ask' then
    ref := private.round_answer(p_session, p_round, prm ->> 'from', other);
    i := private.idx(p -> 'label', jsonb_array_length(card -> 'labels'));
    if ref is null or not exists (select 1 from jsonb_array_elements(ref -> 'places') x where (x ->> 'i')::int = i) then
      raise exception 'invalid_answer';
    end if;
    return jsonb_strip_nulls(jsonb_build_object('label', i, 'text', private.clean_text(p, 'text', 120)));

  else
    raise exception 'unknown_step';
  end case;
end $$;

-- Ce que l'autre peut voir d'une réponse : les champs de capsule gardés pour soi ne sortent jamais.
create or replace function private.public_payload(st jsonb, p jsonb) returns jsonb
language sql immutable set search_path = '' as $$
  select case when st ->> 'kind' = 'fields' and p is not null then
    jsonb_build_object('fields', (select coalesce(jsonb_agg(case when (f ->> 'shared')::boolean then f
                                                               else jsonb_build_object('shared', false) end), '[]')
                                  from jsonb_array_elements(p -> 'fields') f))
  else p end
$$;

-- ---------------------------------------------------------------------------
-- 5. Règles de manche : qui répond, dans quel ordre, quand la manche est révélée
-- ---------------------------------------------------------------------------
create or replace function private.step_seats(st jsonb, card jsonb) returns int[]
language sql immutable set search_path = '' as $$
  select case coalesce(st ->> 'who', 'both')
    when 'a' then array[coalesce((card ->> 'role_a')::int, 1)]
    when 'b' then array[3 - coalesce((card ->> 'role_a')::int, 1)]
    when 'seat1' then array[1]
    when 'seat2' then array[2]
    else array[1, 2] end
$$;

-- Toutes les étapes principales attendues sont-elles faites ?
create or replace function private.round_complete(p_session uuid, p_round int, cfg jsonb, card jsonb) returns boolean
language sql stable security definer set search_path = '' as $$
  select not exists (
    select 1 from jsonb_array_elements(cfg -> 'steps') st, unnest(private.step_seats(st, card)) seat
    where not exists (select 1 from public.session_answers a
                      where a.session_id = p_session and a.round_no = p_round and a.step = st ->> 'key' and a.seat = seat))
$$;

create or replace function private.compute_result(s public.game_sessions, cfg jsonb) returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare
  pts1 int := 0;
  pts2 int := 0;
  rd public.session_rounds;
  target jsonb;
  guess jsonb;
  role_a int;
begin
  if cfg ->> 'score' = 'prediction' then
    -- 1 point au joueur qui devine le choix de l'autre, cartes ordinaires uniquement ; « autre » annule le point.
    for rd in select * from public.session_rounds where session_id = s.id and revealed_at is not null loop
      if coalesce((rd.card ->> 'adult')::boolean, false) then continue; end if;
      role_a := (rd.card ->> 'role_a')::int;
      target := private.round_answer(s.id, rd.round_no, 'choice', role_a);
      guess := private.round_answer(s.id, rd.round_no, 'guess', 3 - role_a);
      if jsonb_typeof(target -> 'choice') = 'number' and target -> 'choice' = guess -> 'choice' then
        if role_a = 1 then pts2 := pts2 + 1; else pts1 := pts1 + 1; end if;
      end if;
    end loop;
    return jsonb_build_object('points', jsonb_build_object('1', pts1, '2', pts2));
  end if;
  return jsonb_build_object('cards', (select count(*) from public.session_rounds where session_id = s.id and revealed_at is not null));
end $$;

-- ---------------------------------------------------------------------------
-- 6. Fonctions appelées par l'application
-- ---------------------------------------------------------------------------
create or replace function public.create_session(p_game text) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  me uuid := auth.uid();
  c uuid := private.my_couple_id();
  g public.games;
  v public.game_versions;
  existing public.game_sessions;
  new_id uuid;
  ended record;
begin
  if c is null then return jsonb_build_object('ok', false, 'error', 'no_couple'); end if;
  select * into g from public.games where id = p_game and status = 'published';
  if g.id is null or g.implementation <> 'playable' then return jsonb_build_object('ok', false, 'error', 'game_unavailable'); end if;
  if g.content_level = 'intime' and exists (
      select 1 from public.couple_members cm join public.profiles p on p.id = cm.user_id
      where cm.couple_id = c and cm.left_at is null and not p.intimate_opt_in) then
    return jsonb_build_object('ok', false, 'error', 'content_not_enabled');
  end if;

  perform pg_advisory_xact_lock(hashtext('couple-session:' || c::text));
  for ended in select id from public.game_sessions where couple_id = c and status = 'ended' loop
    perform public.close_session(ended.id);
  end loop;

  select * into existing from public.game_sessions where couple_id = c and status in ('lobby', 'playing', 'paused');
  if existing.id is not null then
    if existing.game_id = p_game then
      return jsonb_build_object('ok', true, 'session_id', existing.id, 'existing', true);
    end if;
    return jsonb_build_object('ok', false, 'error', 'session_in_progress', 'session_id', existing.id, 'game_id', existing.game_id);
  end if;

  select * into v from public.game_versions where game_id = g.id and version = g.current_version and published_at is not null;
  if v.game_id is null then return jsonb_build_object('ok', false, 'error', 'game_unavailable'); end if;

  insert into public.game_sessions (couple_id, game_id, game_version, created_by, total_rounds, settings)
    values (c, g.id, v.version, me, coalesce((v.config ->> 'rounds')::int, 1),
            coalesce((select jsonb_object_agg(k, val -> 'default') from jsonb_each(v.config -> 'settings') as e(k, val)), '{}'))
    returning id into new_id;
  insert into public.session_players (session_id, user_id, seat)
    select new_id, cm.user_id, case when cm.user_id = me then 1 else 2 end
    from public.couple_members cm where cm.couple_id = c and cm.left_at is null;
  insert into public.session_prefs (session_id, seat, user_id)
    select session_id, seat, user_id from public.session_players where session_id = new_id;
  perform private.bump_session(new_id, 'created');
  return jsonb_build_object('ok', true, 'session_id', new_id, 'existing', false);
end $$;

-- Préférences privées (+18, thèmes à éviter). En salon, toute modification redemande « prêt » aux deux,
-- sans dire laquelle. En partie, elle vaut pour la prochaine carte ; retirer le +18 remplace aussitôt
-- une carte intime pas encore révélée.
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

create or replace function public.set_ready(p_session uuid, p_ready boolean) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  r record;
  all_ready boolean;
  cfg jsonb;
  wanted int;
  sess public.game_sessions;
begin
  select * into r from private.lock_session(p_session);
  if (r.s).status <> 'lobby' then
    return jsonb_build_object('ok', true, 'status', (r.s).status);
  end if;
  update public.session_players set ready_at = case when p_ready then coalesce(ready_at, now()) end
    where session_id = p_session and seat = r.seat;
  select count(*) = 2 and bool_and(ready_at is not null) into all_ready
    from public.session_players where session_id = p_session and user_id is not null;
  if all_ready then
    cfg := private.version_config(r.s);
    wanted := coalesce(((r.s).settings ->> (cfg ->> 'rounds_setting'))::int, (cfg ->> 'rounds')::int, 1);
    -- Banque filtrée trop petite : on réduit le nombre de cartes (jamais d'élargissement silencieux des thèmes).
    if cfg #>> '{draw,deck}' = 'true' then
      wanted := least(wanted, private.deck_available(r.s));
      if wanted < 1 then
        update public.session_players set ready_at = null where session_id = p_session;
        perform private.bump_session(p_session, 'ready');
        return jsonb_build_object('ok', false, 'error', 'not_enough_cards');
      end if;
    end if;
    update public.game_sessions set status = 'playing', started_at = now(), current_round = 1, total_rounds = wanted
      where id = p_session returning * into sess;
    insert into public.session_rounds (session_id, round_no, card) values (p_session, 1, private.draw_round_card(sess, cfg));
  end if;
  perform private.bump_session(p_session, case when all_ready then 'started' else 'ready' end);
  return jsonb_build_object('ok', true, 'status', case when all_ready then 'playing' else 'lobby' end);
end $$;

-- Changer la liste tirée avant que quiconque ait répondu (« relance », une fois par manche si la fiche le prévoit).
create or replace function public.reroll_round(p_session uuid, p_round int) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  r record;
  cfg jsonb;
  rd public.session_rounds;
begin
  select * into r from private.lock_session(p_session);
  cfg := private.version_config(r.s);
  if (r.s).status <> 'playing' or (r.s).current_round <> p_round then return jsonb_build_object('ok', false, 'error', 'stale_round'); end if;
  if coalesce((cfg ->> 'rerolls')::int, 0) < 1 then return jsonb_build_object('ok', false, 'error', 'not_allowed'); end if;
  select * into rd from public.session_rounds where session_id = p_session and round_no = p_round;
  if coalesce((rd.card ->> 'rerolled')::int, 0) >= (cfg ->> 'rerolls')::int
     or exists (select 1 from public.session_answers where session_id = p_session and round_no = p_round) then
    return jsonb_build_object('ok', false, 'error', 'not_allowed');
  end if;
  update public.session_rounds
    set card = private.draw_round_card(r.s, cfg) || jsonb_build_object('rerolled', coalesce((rd.card ->> 'rerolled')::int, 0) + 1)
    where session_id = p_session and round_no = p_round;
  perform private.bump_session(p_session, 'reroll');
  return jsonb_build_object('ok', true);
end $$;

-- Réponse à une étape (ou « passer »). Idempotent : la même réponse renvoyée deux fois n'a qu'un effet.
create or replace function public.submit_answer(p_session uuid, p_round int, p_step text, p_payload jsonb, p_skip boolean default false)
returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  r record;
  cfg jsonb;
  steps jsonb;
  cur_step jsonb;
  step_index int;
  is_after boolean := false;
  rnd public.session_rounds;
  normalized jsonb;
  prev public.session_answers;
  revealed boolean := false;
  done_count int;
  max_rev int;
begin
  select * into r from private.lock_session(p_session);
  if (r.s).status = 'paused' then return jsonb_build_object('ok', false, 'error', 'paused'); end if;
  cfg := private.version_config(r.s);

  -- Ancienne démo : comportement d'origine conservé.
  if cfg ->> 'mechanic' = 'portrait_words' then
    if (r.s).status <> 'playing' then return jsonb_build_object('ok', false, 'error', 'not_playing'); end if;
    if p_round <> (r.s).current_round then return jsonb_build_object('ok', false, 'error', 'stale_round'); end if;
    steps := cfg -> 'steps';
    select e.value, e.ordinality - 1 into cur_step, step_index
      from jsonb_array_elements(steps) with ordinality e where e.value ->> 'key' = p_step;
    if cur_step is null then return jsonb_build_object('ok', false, 'error', 'unknown_step'); end if;
    select * into rnd from public.session_rounds where session_id = p_session and round_no = p_round;
    if rnd.revealed_at is not null then return jsonb_build_object('ok', false, 'error', 'already_revealed'); end if;
    if step_index > 0 and not exists (
        select 1 from public.session_answers a where a.session_id = p_session and a.round_no = p_round
          and a.seat = r.seat and a.step = steps -> (step_index - 1) ->> 'key') then
      return jsonb_build_object('ok', false, 'error', 'previous_step_missing');
    end if;
    normalized := case when p_skip then null else private.validate_payload(cfg, cur_step, rnd.card, p_payload) end;
    select * into prev from public.session_answers a
      where a.session_id = p_session and a.round_no = p_round and a.step = p_step and a.seat = r.seat;
    if prev.id is not null then
      if prev.skipped = p_skip and prev.payload is not distinct from normalized then
        return jsonb_build_object('ok', true, 'repeated', true);
      end if;
      return jsonb_build_object('ok', false, 'error', 'already_submitted');
    end if;
    insert into public.session_answers (session_id, round_no, step, user_id, seat, payload, skipped)
      values (p_session, p_round, p_step, auth.uid(), r.seat, normalized, p_skip);
    select count(*) into done_count from public.session_answers where session_id = p_session and round_no = p_round;
    if done_count >= 2 * jsonb_array_length(steps) then
      revealed := true;
      update public.session_rounds set revealed_at = now() where session_id = p_session and round_no = p_round;
      if p_round >= (r.s).total_rounds then
        update public.game_sessions set status = 'ended', ended_at = now() where id = p_session;
      end if;
    end if;
    perform private.bump_session(p_session, case when revealed then 'revealed' else 'answer' end);
    return jsonb_build_object('ok', true, 'revealed', revealed);
  end if;

  select * into rnd from public.session_rounds where session_id = p_session and round_no = p_round;
  if rnd.session_id is null then return jsonb_build_object('ok', false, 'error', 'stale_round'); end if;

  select e.value into cur_step from jsonb_array_elements(cfg -> 'steps') e where e.value ->> 'key' = p_step;
  if cur_step is null then
    select e.value into cur_step from jsonb_array_elements(coalesce(cfg -> 'after', '[]')) e where e.value ->> 'key' = p_step;
    is_after := cur_step is not null;
  end if;
  if cur_step is null then return jsonb_build_object('ok', false, 'error', 'unknown_step'); end if;
  if not (r.seat = any(private.step_seats(cur_step, rnd.card))) then return jsonb_build_object('ok', false, 'error', 'not_your_turn'); end if;

  if is_after then
    -- Étapes après révélation (réaction, combinaison commune…) : possibles aussi sur l'écran de fin.
    if (r.s).status not in ('playing', 'ended') or rnd.revealed_at is null or rnd.revealed_at > now() then
      return jsonb_build_object('ok', false, 'error', 'not_revealed');
    end if;
  else
    if (r.s).status <> 'playing' then return jsonb_build_object('ok', false, 'error', 'not_playing'); end if;
    if p_round <> (r.s).current_round then return jsonb_build_object('ok', false, 'error', 'stale_round'); end if;
    if rnd.revealed_at is not null then return jsonb_build_object('ok', false, 'error', 'already_revealed'); end if;
  end if;

  -- Ordre : une étape peut dépendre d'une autre (écoute : reformuler après le récit) ;
  -- sinon, chacun suit l'ordre des étapes communes.
  if cur_step ? 'after' then
    if not exists (select 1 from public.session_answers a where a.session_id = p_session and a.round_no = p_round
                   and a.step = cur_step ->> 'after') then
      return jsonb_build_object('ok', false, 'error', 'previous_step_missing');
    end if;
  elsif not is_after then
    select e.ordinality - 1 into step_index from jsonb_array_elements(cfg -> 'steps') with ordinality e
      where e.value ->> 'key' = p_step;
    if step_index > 0 and coalesce(cfg -> 'steps' -> (step_index - 1) ->> 'who', 'both') = 'both'
       and coalesce(cur_step ->> 'who', 'both') = 'both'
       and not exists (select 1 from public.session_answers a where a.session_id = p_session and a.round_no = p_round
                       and a.seat = r.seat and a.step = cfg -> 'steps' -> (step_index - 1) ->> 'key') then
      return jsonb_build_object('ok', false, 'error', 'previous_step_missing');
    end if;
  end if;

  if p_skip then
    if not coalesce((cur_step ->> 'skippable')::boolean, false) then return jsonb_build_object('ok', false, 'error', 'invalid_answer'); end if;
    normalized := null;
  else
    begin
      normalized := private.validate_step(cur_step, rnd.card, p_payload, p_session, p_round, r.seat);
    exception when raise_exception then
      return jsonb_build_object('ok', false, 'error', 'invalid_answer');
    end;
  end if;

  select * into prev from public.session_answers a
    where a.session_id = p_session and a.round_no = p_round and a.step = p_step and a.seat = r.seat;
  if prev.id is not null then
    if prev.skipped = p_skip and prev.payload is not distinct from normalized then
      return jsonb_build_object('ok', true, 'repeated', true);
    end if;
    -- Seules certaines étapes après révélation acceptent une révision (ex. : combinaison commune, révision = 1).
    max_rev := coalesce((cur_step ->> 'revisions')::int, 0);
    if not is_after or prev.revision >= max_rev then
      return jsonb_build_object('ok', false, 'error', 'already_submitted');
    end if;
    update public.session_answers set payload = normalized, skipped = p_skip, revision = revision + 1, updated_at = now()
      where id = prev.id;
  else
    insert into public.session_answers (session_id, round_no, step, user_id, seat, payload, skipped)
      values (p_session, p_round, p_step, auth.uid(), r.seat, normalized, p_skip);
  end if;

  if not is_after and private.round_complete(p_session, p_round, cfg, rnd.card) then
    revealed := true;
    update public.session_rounds
      set revealed_at = case when cfg ->> 'reveal' = 'capsule'
                             then now() + make_interval(days => coalesce(((r.s).settings ->> 'delai')::int, 7))
                             else now() end
      where session_id = p_session and round_no = p_round;
    if p_round >= (r.s).total_rounds then
      update public.game_sessions set status = 'ended', ended_at = now(), result = private.compute_result(r.s, cfg)
        where id = p_session;
    end if;
  end if;
  perform private.bump_session(p_session, case when revealed then 'revealed' else 'answer' end);
  return jsonb_build_object('ok', true, 'revealed', revealed);
end $$;

create or replace function public.next_round(p_session uuid, p_from_round int) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  r record;
  cfg jsonb;
  sess public.game_sessions;
begin
  select * into r from private.lock_session(p_session);
  if (r.s).status <> 'playing' or (r.s).current_round <> p_from_round then
    return jsonb_build_object('ok', true, 'repeated', true);
  end if;
  if not exists (select 1 from public.session_rounds where session_id = p_session and round_no = p_from_round and revealed_at is not null) then
    return jsonb_build_object('ok', false, 'error', 'not_revealed');
  end if;
  cfg := private.version_config(r.s);
  if cfg #>> '{draw,deck}' = 'true' and private.deck_available(r.s) < 1 then
    -- Banque filtrée épuisée : la partie se termine proprement au lieu d'élargir les thèmes.
    update public.game_sessions set status = 'ended', ended_at = now(), total_rounds = p_from_round,
      result = private.compute_result(r.s, cfg) where id = p_session;
    perform private.bump_session(p_session, 'ended');
    return jsonb_build_object('ok', true, 'ended', true);
  end if;
  update public.game_sessions set current_round = p_from_round + 1 where id = p_session returning * into sess;
  insert into public.session_rounds (session_id, round_no, card) values (p_session, p_from_round + 1, private.draw_round_card(sess, cfg));
  perform private.bump_session(p_session, 'round');
  return jsonb_build_object('ok', true);
end $$;

-- Fin commune avant la dernière carte (« sortie commune ») : la partie passe aux résultats.
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

-- Rangement : la capsule garde son contenu jusqu'à sa réouverture (c'est son principe) ; ailleurs,
-- les réponses ne restent que si les deux ont choisi « Garder ce souvenir ».
create or replace function public.close_session(p_session uuid) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  r record;
  keep boolean;
begin
  select * into r from private.lock_session(p_session);
  if (r.s).status <> 'ended' then return jsonb_build_object('ok', true, 'repeated', true); end if;
  select count(*) = 2 and bool_and(keep_memory) into keep from public.session_players where session_id = p_session;
  keep := keep or private.version_config(r.s) ->> 'reveal' = 'capsule';
  perform private.purge_session(p_session, keep);
  update public.game_sessions set status = 'closed', closed_at = now() where id = p_session;
  perform private.bump_session(p_session, 'closed');
  return jsonb_build_object('ok', true, 'kept', keep);
end $$;

-- Effacement différé (décision 10a) : 24 h après la fin, une partie terminée est rangée ; ses réponses
-- ne restent que sur accord des deux. Appelée par la planification (pg_cron) ou à l'ouverture de l'app.
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
revoke execute on function private.purge_expired_sessions() from public, anon, authenticated;

create or replace function public.get_session_state(p_session uuid) returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare
  s public.game_sessions;
  me uuid := auth.uid();
  my_seat int;
  cfg jsonb;
begin
  select * into s from public.game_sessions where id = p_session;
  if s.id is null or not private.is_member(s.couple_id, true) then
    return jsonb_build_object('ok', false, 'error', 'session_not_found');
  end if;
  select seat into my_seat from public.session_players where session_id = p_session and user_id = me;
  cfg := private.version_config(s);

  return jsonb_build_object(
    'ok', true,
    'session', jsonb_build_object(
      'id', s.id, 'game_id', s.game_id, 'game_version', s.game_version, 'status', s.status,
      'settings', s.settings, 'current_round', s.current_round, 'total_rounds', s.total_rounds,
      'paused_by', s.paused_by, 'state_version', s.state_version, 'created_at', s.created_at,
      'started_at', s.started_at, 'ended_at', s.ended_at, 'closed_at', s.closed_at, 'result', s.result,
      'read_only', not private.is_member(s.couple_id)),
    'my_seat', my_seat,
    -- Mes préférences uniquement ; celles de l'autre ne sortent jamais.
    'my_prefs', (select jsonb_build_object('adult', sp.adult, 'excluded_topics', to_jsonb(sp.excluded_topics))
                 from public.session_prefs sp where sp.session_id = s.id and sp.user_id = me),
    'game', (select jsonb_build_object('title', g.title, 'mechanic', g.mechanic, 'rules', v.rules, 'config', v.config,
                                       'adult_available', g.adult_available, 'thumbnail', g.thumbnail)
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
                 'round_no', rd.round_no, 'card', rd.card,
                 'revealed', rd.revealed_at is not null and rd.revealed_at <= now(),
                 'reveal_at', case when rd.revealed_at > now() then rd.revealed_at end,
                 'answers', (select coalesce(jsonb_agg(jsonb_build_object(
                                'step', a.step, 'seat', a.seat, 'skipped', a.skipped, 'revision', a.revision,
                                'payload', case
                                  when a.seat = my_seat then a.payload
                                  when (rd.revealed_at <= now())
                                       or exists (select 1 from jsonb_array_elements(coalesce(cfg -> 'steps', '[]')) st
                                                  where st ->> 'key' = a.step and st ->> 'visible' = 'immediate')
                                    then private.public_payload(
                                      (select st from jsonb_array_elements(coalesce(cfg -> 'steps', '[]') || coalesce(cfg -> 'after', '[]')) st
                                       where st ->> 'key' = a.step limit 1), a.payload)
                                end)
                              order by a.seat, a.created_at), '[]')
                             from public.session_answers a
                             where a.session_id = s.id and a.round_no = rd.round_no)
               ) order by rd.round_no), '[]')
               from public.session_rounds rd where rd.session_id = s.id)
  );
end $$;

revoke execute on all functions in schema public from public, anon;
grant execute on function public.set_session_prefs(uuid, boolean, text[]), public.reroll_round(uuid, int),
  public.finish_session(uuid), public.create_session(text), public.set_ready(uuid, boolean),
  public.submit_answer(uuid, int, text, jsonb, boolean), public.next_round(uuid, int), public.close_session(uuid),
  public.get_session_state(uuid) to authenticated;
-- Fonctions internes : appelables uniquement depuis les fonctions ci-dessus (jamais directement par un client).
revoke execute on function private.adult_allowed(uuid), private.excluded_tags(uuid),
  private.deck_available(public.game_sessions), private.bank_sample(text, int),
  private.draw_round_card(public.game_sessions, jsonb), private.clean_text(jsonb, text, int, boolean),
  private.idx(jsonb, int), private.idx_list(jsonb, int, int, int), private.clean_drawing(jsonb),
  private.round_answer(uuid, int, text, int), private.validate_step(jsonb, jsonb, jsonb, uuid, int, int),
  private.public_payload(jsonb, jsonb), private.step_seats(jsonb, jsonb), private.round_complete(uuid, int, jsonb, jsonb),
  private.compute_result(public.game_sessions, jsonb), private.topic_tags_for(text[])
  from public, anon, authenticated;
