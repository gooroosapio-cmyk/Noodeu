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
    select 1 from jsonb_array_elements(cfg -> 'steps') st, unnest(private.step_seats(st, card)) as x(seat_no)
    where not exists (select 1 from public.session_answers a
                      where a.session_id = p_session and a.round_no = p_round and a.step = st ->> 'key' and a.seat = x.seat_no))
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

