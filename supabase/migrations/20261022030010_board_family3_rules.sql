-- Famille 3 « Dessin et création » : tirage et règles (moteur plateau, comme la famille 2).
-- Dessins : traits normalisés 0..1 (private.clean_drawing). Aucune reconnaissance d'image : c'est l'autre joueur qui devine.

-- Un trait (ou une liste de traits) propre ; refus lisible sinon.
create or replace function private.stroke_in(p jsonb) returns jsonb
language plpgsql immutable set search_path = '' as $$
declare
  r jsonb;
begin
  r := private.clean_drawing(jsonb_build_array(p -> 's'));
  if r is null then perform private.mv('invalid_drawing'); end if;
  return r -> 0;
exception when raise_exception then
  if sqlerrm like 'move:%' then raise; end if;
  perform private.mv('invalid_drawing');
  return null;
end $$;

create or replace function private.strokes_in(p jsonb, k text, p_max int) returns jsonb
language plpgsql immutable set search_path = '' as $$
declare
  r jsonb;
begin
  if p -> k is null or jsonb_typeof(p -> k) = 'null' then return '[]'; end if;
  if jsonb_typeof(p -> k) <> 'array' or jsonb_array_length(p -> k) > p_max then perform private.mv('too_many_strokes'); end if;
  r := private.clean_drawing(p -> k);
  return coalesce(r, '[]');
exception when raise_exception then
  if sqlerrm like 'move:%' then raise; end if;
  perform private.mv('invalid_drawing');
  return null;
end $$;

-- Gommettes / objets posés : [{s, x, y, r}] (index, position 0..1, rotation par pas de 15°).
create or replace function private.items_in(p jsonb, k text, n int, p_max int) returns jsonb
language plpgsql immutable set search_path = '' as $$
declare
  e jsonb;
  res jsonb := '[]';
begin
  if p -> k is null or jsonb_typeof(p -> k) = 'null' then return '[]'; end if;
  if jsonb_typeof(p -> k) <> 'array' or jsonb_array_length(p -> k) > p_max then perform private.mv('too_many_items'); end if;
  for e in select * from jsonb_array_elements(p -> k) loop
    if jsonb_typeof(e -> 'x') <> 'number' or jsonb_typeof(e -> 'y') <> 'number'
       or (e ->> 'x')::numeric not between 0 and 1 or (e ->> 'y')::numeric not between 0 and 1 then
      perform private.mv('invalid_move');
    end if;
    res := res || jsonb_build_array(jsonb_build_object('s', private.int_in(e, 's', n),
      'x', round((e ->> 'x')::numeric, 3), 'y', round((e ->> 'y')::numeric, 3),
      'r', (coalesce((e ->> 'r')::int, 0) / 15 * 15) % 360));
  end loop;
  return res;
end $$;

-- ---------------------------------------------------------------------------
-- Tangram : pièces à sommets entiers sur une grille ; chaque case est coupée en 4 triangles par ses diagonales.
-- Une pièce recouvre exactement des quarts de case : on compare ces quarts à la silhouette (pas de boîtes englobantes).
-- ---------------------------------------------------------------------------
create or replace function private.tg_poly(base jsonb, px int, py int, rot int, flip boolean) returns jsonb
language plpgsql immutable set search_path = '' as $$
declare
  pts jsonb := '[]';
  e jsonb;
  x int;
  y int;
  t int;
  k int;
  mx int;
  my int;
begin
  for e in select * from jsonb_array_elements(base) loop
    x := (e ->> 0)::int; y := (e ->> 1)::int;
    if flip then x := -x; end if;
    for k in 1 .. ((rot % 4) + 4) % 4 loop t := x; x := -y; y := t; end loop;
    pts := pts || jsonb_build_array(jsonb_build_array(x, y));
  end loop;
  select min((q ->> 0)::int), min((q ->> 1)::int) into mx, my from jsonb_array_elements(pts) q;
  select jsonb_agg(jsonb_build_array((q ->> 0)::int - mx + px, (q ->> 1)::int - my + py) order by o) into pts
    from jsonb_array_elements(pts) with ordinality u(q, o);
  return pts;
end $$;

create or replace function private.pip(x numeric, y numeric, poly jsonb) returns boolean
language plpgsql immutable set search_path = '' as $$
declare
  n int := jsonb_array_length(poly);
  i int;
  j int;
  xi numeric; yi numeric; xj numeric; yj numeric;
  inside boolean := false;
begin
  j := n - 1;
  for i in 0 .. n - 1 loop
    xi := (poly -> i ->> 0)::numeric; yi := (poly -> i ->> 1)::numeric;
    xj := (poly -> j ->> 0)::numeric; yj := (poly -> j ->> 1)::numeric;
    if ((yi > y) <> (yj > y)) and (x < (xj - xi) * (y - yi) / (yj - yi) + xi) then inside := not inside; end if;
    j := i;
  end loop;
  return inside;
end $$;

create or replace function private.tg_quarters(poly jsonb) returns text[]
language plpgsql immutable set search_path = '' as $$
declare
  res text[] := '{}';
  x0 int; x1 int; y0 int; y1 int;
  cx int; cy int;
begin
  select min((q ->> 0)::int), max((q ->> 0)::int), min((q ->> 1)::int), max((q ->> 1)::int)
    into x0, x1, y0, y1 from jsonb_array_elements(poly) q;
  for cx in x0 .. x1 - 1 loop
    for cy in y0 .. y1 - 1 loop
      if private.pip(cx + 0.5, cy + 1.0 / 6, poly) then res := res || (cx || ':' || cy || ':n'); end if;
      if private.pip(cx + 5.0 / 6, cy + 0.5, poly) then res := res || (cx || ':' || cy || ':e'); end if;
      if private.pip(cx + 0.5, cy + 5.0 / 6, poly) then res := res || (cx || ':' || cy || ':s'); end if;
      if private.pip(cx + 1.0 / 6, cy + 0.5, poly) then res := res || (cx || ':' || cy || ':w'); end if;
    end loop;
  end loop;
  return res;
end $$;

-- Silhouette couverte exactement, sans chevauchement ?
create or replace function private.tg_solved(c jsonb) returns boolean
language plpgsql immutable set search_path = '' as $$
declare
  all_q text[] := '{}';
  pc jsonb;
  tx int := (c #>> '{target,x}')::int;
  ty int := (c #>> '{target,y}')::int;
  sz int := (c #>> '{target,size}')::int;
begin
  for pc in select * from jsonb_array_elements(c -> 'pieces') loop
    all_q := all_q || private.tg_quarters(private.tg_poly(pc -> 'base', (pc ->> 'x')::int, (pc ->> 'y')::int,
                                                           (pc ->> 'rot')::int, (pc ->> 'flip')::boolean));
  end loop;
  return cardinality(all_q) = sz * sz * 4
     and (select count(distinct q) from unnest(all_q) q) = cardinality(all_q)
     and not exists (select 1 from unnest(all_q) q
                     where split_part(q, ':', 1)::int not between tx and tx + sz - 1
                        or split_part(q, ':', 2)::int not between ty and ty + sz - 1);
end $$;

-- ---------------------------------------------------------------------------
-- Île en tuiles : une maison doit toucher un chemin ; objectif = deux maisons reliées par un même chemin continu.
-- ---------------------------------------------------------------------------
create or replace function private.is_path(t text) returns boolean
language sql immutable set search_path = '' as $$ select t in ('chemin droit', 'chemin courbe', 'carrefour') $$;

create or replace function private.neighbors5(i int) returns int[]
language sql immutable set search_path = '' as $$
  select array_remove(array[
    case when i >= 5 then i - 5 end, case when i < 20 then i + 5 end,
    case when i % 5 > 0 then i - 1 end, case when i % 5 < 4 then i + 1 end], null)
$$;

create or replace function private.island_goal(grid jsonb) returns boolean
language plpgsql immutable set search_path = '' as $$
declare
  comp int[] := array_fill(0, array[25]);
  label int := 0;
  stack int[];
  cur int;
  nb int;
  i int;
  h int;
  hits int[];
begin
  -- composantes connexes de chemin
  for i in 0 .. 24 loop
    if private.is_path(grid ->> i) and comp[i + 1] = 0 then
      label := label + 1; stack := array[i]; comp[i + 1] := label;
      while cardinality(stack) > 0 loop
        cur := stack[cardinality(stack)]; stack := stack[1:cardinality(stack) - 1];
        foreach nb in array private.neighbors5(cur) loop
          if private.is_path(grid ->> nb) and comp[nb + 1] = 0 then comp[nb + 1] := label; stack := stack || nb; end if;
        end loop;
      end loop;
    end if;
  end loop;
  -- pour chaque composante, nombre de maisons qui la touchent
  for h in 1 .. label loop
    select count(*) into i from generate_series(0, 24) m
      where grid ->> m = 'maison' and exists (select 1 from unnest(private.neighbors5(m)) z where comp[z + 1] = h);
    if i >= 2 then return true; end if;
  end loop;
  return false;
end $$;

create or replace function private.tile_draw() returns text
language sql volatile set search_path = '' as $$
  select (array['chemin droit','chemin droit','chemin courbe','carrefour','maison','maison','eau','plage','forêt','prairie'])[1 + floor(random() * 10)::int]
$$;

create or replace function private.tile_legal(grid jsonb, t text, i int) returns boolean
language sql immutable set search_path = '' as $$
  select grid ->> i is null
     and exists (select 1 from unnest(private.neighbors5(i)) z where grid ->> z is not null)
     and (t <> 'maison' or exists (select 1 from unnest(private.neighbors5(i)) z where private.is_path(grid ->> z)))
$$;

-- ===========================================================================
-- Tirage (famille 3) : appelé par private.board_setup pour les mécaniques qu'il ne connaît pas.
-- ===========================================================================
create or replace function private.board_setup3(s public.game_sessions, cfg jsonb) returns jsonb
language plpgsql volatile security definer set search_path = '' as $$
declare
  m text := cfg ->> 'mechanic';
  rn int := greatest(s.current_round, 1);
  ra int := ((greatest(s.current_round, 1) - 1) % 2) + 1;
  e jsonb;
  v jsonb;
  arr jsonb;
  k int;
  perm int[];
  pieces jsonb := '[]';
  pc jsonb;
  slots int[][] := array[[6,0],[6,3],[6,6],[0,6],[3,7],[8,2],[8,5]];
  bw int; bh int; r int;
begin
  case m
  when 'draw_guess', 'stroke_budget' then
    e := private.pick_entry(s.id, 'objects');
    return jsonb_build_object('mech', m, 'drawer', ra, 'guesser', 3 - ra, 'strokes', '[]'::jsonb, 'used', 0,
      'budget', case when m = 'stroke_budget' then 10 end, 'guesses', '[]'::jsonb, 'max', 3,
      'done', false, 'success', false, 'points', 0,
      '_secret', jsonb_build_object('bank', 'objects', 'idx', e -> 'i',
        'seats', jsonb_build_object(ra::text, jsonb_build_object('target', e -> 'v')), 'solution', jsonb_build_object('target', e -> 'v')));

  when 'complete_doodle' then
    e := private.pick_entry(s.id, 'doodle_shapes');
    return jsonb_build_object('mech', m, 'shape', e -> 'v', 'starter', coalesce(cfg -> 'starters' -> (e ->> 'v'), '[]'),
      'strokes', '[]'::jsonb, 'turn', ra, 'pass', 1, 'max_pass', 4, 'in_pass', 0, 'per_pass', 3, 'phase', 'draw',
      'titles', '{}'::jsonb, 'done', false,
      '_secret', jsonb_build_object('bank', 'doodle_shapes', 'idx', e -> 'i'));

  when 'draw_dictation' then
    k := case when rn = 1 then 4 else 6 end;
    select jsonb_agg(value order by r2) into arr from (
      select value, random() r2 from public.content_banks where bank = 'geometry' order by random() limit k) g;
    return jsonb_build_object('mech', m, 'guide', ra, 'drawer', 3 - ra, 'k', k, 'messages', '[]'::jsonb, 'placed', '[]'::jsonb,
      'done', false, 'score', null, 'points', 0,
      '_secret', jsonb_build_object('seats', jsonb_build_object(ra::text, jsonb_build_object('model', arr)),
        'solution', jsonb_build_object('model', arr)));

  when 'exquisite_drawing' then
    return jsonb_build_object('mech', m, 'owners', jsonb_build_array(ra, 3 - ra, ra),
      'suggestions', jsonb_build_array(
        (select value from public.content_banks where bank = 'character_parts' and idx between 0 and 5 order by random() limit 1),
        (select value from public.content_banks where bank = 'character_parts' and idx between 6 and 11 order by random() limit 1),
        (select value from public.content_banks where bank = 'character_parts' and idx between 12 and 17 order by random() limit 1)),
      'marks', jsonb_build_array(jsonb_build_array(round((0.3 + random() * 0.1)::numeric, 2), round((0.6 + random() * 0.1)::numeric, 2)),
                                 jsonb_build_array(round((0.3 + random() * 0.1)::numeric, 2), round((0.6 + random() * 0.1)::numeric, 2))),
      'done_bands', '{}'::jsonb, 'bands', null, 'phase', 'draw', 'names', '{}'::jsonb, 'done', false,
      '_secret', jsonb_build_object('seats', '{}'::jsonb));

  when 'pixel_art' then
    e := private.pick_entry(s.id, 'pixel_patterns');
    select jsonb_agg(null::int) into arr from generate_series(1, 64);
    return jsonb_build_object('mech', m, 'size', 8, 'cells', arr, 'colors', jsonb_build_object(ra::text, '[0,1,2]'::jsonb, (3 - ra)::text, '[3,4,5]'::jsonb),
      'model', e -> 'v', 'offset', 1, 'pending', '[]'::jsonb, 'validated', '{}'::jsonb, 'done', false, 'score', null,
      '_secret', jsonb_build_object('bank', 'pixel_patterns', 'idx', e -> 'i'));

  when 'tangram' then
    e := private.pick_entry(s.id, 'tangram');
    perm := private.shuffle_int(7);
    for k in 0 .. 6 loop
      select jsonb_agg(jsonb_build_array(round((q ->> 0)::numeric * 4)::int, round((q ->> 1)::numeric * 4)::int) order by o) into arr
        from jsonb_array_elements(e -> 'v' -> 'pieces' -> k) with ordinality u(q, o);
      r := private.rnd(4);
      pc := private.tg_poly(arr, 0, 0, r, false);
      select max((q ->> 0)::int), max((q ->> 1)::int) into bw, bh from jsonb_array_elements(pc) q;
      pieces := pieces || jsonb_build_array(jsonb_build_object('id', k, 'base', arr, 'rot', r, 'flip', false,
        'flippable', k = coalesce((e -> 'v' ->> 'allow_flip_piece')::int, 2),
        'x', least(slots[perm[k + 1] + 1][1], 10 - bw), 'y', least(slots[perm[k + 1] + 1][2], 10 - bh)));
    end loop;
    return jsonb_build_object('mech', m, 'board', jsonb_build_object('w', 10, 'h', 10),
      'target', jsonb_build_object('x', 1, 'y', 1, 'size', 4), 'pieces', pieces, 'moves', 0, 'done', false, 'success', false, 'points', 0,
      '_secret', jsonb_build_object('bank', 'tangram', 'idx', e -> 'i'));

  when 'jigsaw' then
    e := private.pick_entry(s.id, 'jigsaw'); v := e -> 'v';
    k := case when rn = 1 then 3 else 4 end;
    if k = 3 then
      arr := v -> 'permutation';
    else
      loop
        perm := private.shuffle_int(16);
        exit when perm <> (select array_agg(x order by x) from unnest(perm) x);
      end loop;
      arr := to_jsonb(perm);
    end if;
    return jsonb_build_object('mech', m, 'art', '/assets/jeux/puzzles/' || (v ->> 'art') || '.svg', 'rows', k, 'cols', k,
      'order', arr, 'selected', null, 'moves', 0, 'done', false, 'success', false, 'points', 0,
      '_secret', jsonb_build_object('bank', 'jigsaw', 'idx', e -> 'i'));

  when 'sticker_portrait' then
    select jsonb_agg(value order by idx) into arr from public.content_banks where bank = 'stickers';
    return jsonb_build_object('mech', m, 'stickers', arr, 'max', 12, 'submitted', '{}'::jsonb, 'portraits', null, 'done', false,
      '_secret', jsonb_build_object('seats', '{}'::jsonb));

  when 'emblem' then
    select jsonb_agg(value order by idx) into arr from public.content_banks where bank = 'objects';
    return jsonb_build_object('mech', m, 'symbols', arr,
      'colors', (select jsonb_agg(value order by idx) from public.content_banks where bank = 'palettes' and idx in (1, 2, 3, 4, 5, 13)),
      'supports', '["cercle", "carré arrondi", "losange"]'::jsonb, 'support', null,
      'slots', '{}'::jsonb, 'turn', ra, 'name', null, 'validated', '{}'::jsonb, 'done', false,
      '_secret', '{}'::jsonb);

  when 'mirror_draw' then
    return jsonb_build_object('mech', m, 'strokes', '[]'::jsonb, 'turn', ra, 'tour', 1, 'max', 6, 'in_tour', 0, 'per_tour', 2,
      'phase', 'draw', 'names', '{}'::jsonb, 'done', false, '_secret', '{}'::jsonb);

  when 'palette' then
    e := private.pick_entry(s.id, 'palette_scenes');
    select jsonb_agg(value order by idx) into arr from public.content_banks where bank = 'palettes';
    return jsonb_build_object('mech', m, 'scene', e -> 'v', 'colors', arr, 'submitted', '{}'::jsonb, 'picks', null,
      'final', '[]'::jsonb, 'proposal', null, 'turn', null, 'phase', 'pick', 'done', false,
      '_secret', jsonb_build_object('bank', 'palette_scenes', 'idx', e -> 'i', 'seats', '{}'::jsonb));

  when 'poster' then
    e := private.pick_entry(s.id, 'poster');
    return jsonb_build_object('mech', m, 'event', e -> 'v',
      'constraint', cfg -> 'constraints' -> private.rnd(jsonb_array_length(cfg -> 'constraints')),
      'objects', (select jsonb_agg(value order by idx) from public.content_banks where bank = 'objects'),
      'a', ra, 'b', 3 - ra, 'phase', 'title', 'turn', ra, 'title', null, 'visual', null, 'subtitle', null, 'detail', null,
      'done', false, '_secret', jsonb_build_object('bank', 'poster', 'idx', e -> 'i'));

  when 'silent_comic' then
    e := private.pick_entry(s.id, 'scenes');
    return jsonb_build_object('mech', m, 'subject', e -> 'v', 'owners', jsonb_build_array(ra, 3 - ra, ra),
      'stickers', (select jsonb_agg(value order by idx) from public.content_banks where bank = 'stickers'),
      'frames', '[null, null, null]'::jsonb, 'turn', ra, 'phase', 'draw', 'submitted', '{}'::jsonb, 'titles', null, 'done', false,
      '_secret', jsonb_build_object('bank', 'scenes', 'idx', e -> 'i', 'seats', '{}'::jsonb));

  when 'tile_scene' then
    select jsonb_agg(case when g = 12 then 'prairie' end order by g) into arr from generate_series(0, 24) g;
    return jsonb_build_object('mech', m, 'grid', arr,
      'hands', jsonb_build_object('1', jsonb_build_array(private.tile_draw(), private.tile_draw(), 'chemin droit'),
                                  '2', jsonb_build_array(private.tile_draw(), private.tile_draw(), 'maison')),
      'turn', ra, 'placed', 1, 'max', 15, 'goal', false, 'done', false, 'success', false, 'points', 0, '_secret', '{}'::jsonb);

  when 'constellation' then
    e := private.pick_entry(s.id, 'constellation_levels'); v := e -> 'v';
    return jsonb_build_object('mech', m, 'stars', v -> 'stars', 'steps', coalesce((v ->> 'steps')::int, 8), 'bpm', coalesce((v ->> 'bpm')::int, 96),
      'seq', '[]'::jsonb, 'turn', ra, 'phase', 'compose', 'names', '{}'::jsonb, 'done', false,
      '_secret', jsonb_build_object('bank', 'constellation_levels', 'idx', e -> 'i'));

  when 'flipbook' then
    e := private.pick_entry(s.id, 'flipbook_scenes'); v := e -> 'v';
    return jsonb_build_object('mech', m, 'scene', v -> 'name', 'objects', v -> 'objects',
      'owners', (select jsonb_agg(case when g % 2 = 0 then ra else 3 - ra end order by g) from generate_series(0, 7) g),
      'frames', (select jsonb_agg(null::int) from generate_series(1, 8)), 'validated', '{}'::jsonb, 'done', false,
      '_secret', jsonb_build_object('bank', 'flipbook_scenes', 'idx', e -> 'i'));

  when 'weaving' then
    e := private.pick_entry(s.id, 'weave_levels'); v := e -> 'v';
    return jsonb_build_object('mech', m, 'a', ra, 'b', 3 - ra, 'palette', cfg -> 'weave_palette',
      'model', jsonb_build_object('vertical', v -> 'vertical_colors', 'horizontal', v -> 'horizontal_colors', 'mask', v -> 'over_mask'),
      'vcolors', '[null,null,null,null,null,null]'::jsonb, 'hcolors', '[null,null,null,null,null,null]'::jsonb,
      'mask', (select jsonb_agg(0) from generate_series(1, 36)), 'title', null, 'validated', '{}'::jsonb,
      'done', false, 'success', false, 'points', 0, '_secret', jsonb_build_object('bank', 'weave_levels', 'idx', e -> 'i'));
  else
    raise exception 'unknown_mechanic';
  end case;
end $$;

-- ===========================================================================
-- Règles des coups (famille 3)
-- ===========================================================================
create or replace function private.board_apply3(m text, c jsonb, sec jsonb, seat int, typ text, p jsonb, p_session uuid) returns jsonb
language plpgsql volatile security definer set search_path = '' as $$
declare
  me text := seat::text;
  oth text := (3 - seat)::text;
  sol jsonb := coalesce(sec -> 'solution', '{}');
  t text;
  n text;
  w text;
  i int;
  k int;
  x int;
  y int;
  ok boolean;
  arr jsonb;
  st jsonb;
  e jsonb;
begin
  case m
  -- -------------------------------------------------------------------------
  when 'draw_guess', 'stroke_budget' then
    if typ in ('stroke', 'undo') then
      if seat <> (c ->> 'drawer')::int then perform private.mv('not_your_turn'); end if;
      if c ? 'budget' and c -> 'budget' <> 'null'::jsonb and (c ->> 'used')::int >= (c ->> 'budget')::int then
        perform private.mv('no_strokes_left');
      end if;
      if typ = 'stroke' then
        if jsonb_array_length(c -> 'strokes') >= 80 then perform private.mv('too_many_strokes'); end if;
        c := c || jsonb_build_object('strokes', (c -> 'strokes') || jsonb_build_array(private.stroke_in(p)));
      else
        if jsonb_array_length(c -> 'strokes') = 0 then perform private.mv('invalid_move'); end if;
        c := c || jsonb_build_object('strokes', (c -> 'strokes') - (-1));
      end if;
      -- La gomme consomme aussi un trait : pas de contournement du budget.
      c := c || jsonb_build_object('used', (c ->> 'used')::int + 1);
      return private.res(c, sec);
    elsif typ = 'guess' then
      if seat <> (c ->> 'guesser')::int then perform private.mv('not_your_turn'); end if;
      if jsonb_array_length(c -> 'strokes') = 0 then perform private.mv('wait_drawing'); end if;
      t := private.txt(p, 'text', 40);
      n := private.nrm_lower(t); w := private.nrm_lower(sol ->> 'target');
      ok := n = w or regexp_replace(n, '[sx]$', '') = w;
      c := c || jsonb_build_object('guesses', private.push(c -> 'guesses', jsonb_build_object('text', t, 'ok', ok)));
      if ok then
        c := c || '{"done": true, "success": true, "points": 1}';
      elsif jsonb_array_length(c -> 'guesses') >= (c ->> 'max')::int then
        c := c || '{"done": true}';
      end if;
      return private.res(c, sec);
    end if;

  -- -------------------------------------------------------------------------
  when 'complete_doodle', 'mirror_draw' then
    if typ in ('stroke', 'pass') and c ->> 'phase' = 'draw' then
      perform private.need_turn(c, seat);
      if typ = 'stroke' then
        st := private.stroke_in(p);
        if m = 'mirror_draw' and exists (select 1 from jsonb_array_elements(st -> 'p') q where (q ->> 0)::numeric > 0.5) then
          perform private.mv('left_half');
        end if;
        c := c || jsonb_build_object('strokes', (c -> 'strokes') || jsonb_build_array(st || jsonb_build_object('by', seat)));
        if m = 'mirror_draw' then
          c := c || jsonb_build_object('in_tour', (c ->> 'in_tour')::int + 1);
          ok := (c ->> 'in_tour')::int >= (c ->> 'per_tour')::int;
        else
          c := c || jsonb_build_object('in_pass', (c ->> 'in_pass')::int + 1);
          ok := (c ->> 'in_pass')::int >= (c ->> 'per_pass')::int;
        end if;
      else
        ok := true;
      end if;
      if ok then
        if m = 'mirror_draw' then
          c := c || jsonb_build_object('tour', (c ->> 'tour')::int + 1, 'in_tour', 0, 'turn', 3 - seat);
          if (c ->> 'tour')::int > (c ->> 'max')::int then c := c || '{"phase": "name", "turn": null}'; end if;
        else
          c := c || jsonb_build_object('pass', (c ->> 'pass')::int + 1, 'in_pass', 0, 'turn', 3 - seat);
          if (c ->> 'pass')::int > (c ->> 'max_pass')::int then c := c || '{"phase": "name", "turn": null}'; end if;
        end if;
      end if;
      return private.res(c, sec);
    elsif typ = 'undo' and c ->> 'phase' = 'draw' then
      perform private.need_turn(c, seat);
      k := case when m = 'mirror_draw' then (c ->> 'in_tour')::int else (c ->> 'in_pass')::int end;
      if k = 0 or (c -> 'strokes' -> -1 ->> 'by')::int <> seat then perform private.mv('invalid_move'); end if;
      c := c || jsonb_build_object('strokes', (c -> 'strokes') - (-1));
      if m = 'mirror_draw' then c := c || jsonb_build_object('in_tour', k - 1); else c := c || jsonb_build_object('in_pass', k - 1); end if;
      return private.res(c, sec);
    elsif typ = 'name' and c ->> 'phase' = 'name' then
      t := private.txt(p, 'text', 40);
      w := case when m = 'mirror_draw' then 'names' else 'titles' end;
      c := jsonb_set(c, array[w, me], to_jsonb(t));
      if c -> w ? oth then c := c || '{"done": true}'; end if;
      return private.res(c, sec);
    end if;

  -- -------------------------------------------------------------------------
  when 'draw_dictation' then
    if typ in ('say', 'ask') then
      if (typ = 'say' and seat <> (c ->> 'guide')::int) or (typ = 'ask' and seat <> (c ->> 'drawer')::int) then
        perform private.mv('not_your_turn');
      end if;
      if jsonb_array_length(c -> 'messages') >= 40 then perform private.mv('too_many_items'); end if;
      c := c || jsonb_build_object('messages', private.push(c -> 'messages', jsonb_build_object('seat', seat, 'text', private.txt(p, 'text', 140))));
      return private.res(c, sec);
    elsif typ in ('place', 'validate') then
      if seat <> (c ->> 'drawer')::int then perform private.mv('not_your_turn'); end if;
      if typ = 'place' then
        if jsonb_typeof(p -> 'shapes') <> 'array' or jsonb_array_length(p -> 'shapes') > 8 then perform private.mv('too_many_items'); end if;
        arr := '[]';
        for e in select * from jsonb_array_elements(p -> 'shapes') loop
          if e ->> 'shape' not in ('circle', 'square', 'triangle') then perform private.mv('invalid_move'); end if;
          arr := arr || jsonb_build_array(jsonb_build_object('shape', e ->> 'shape', 'x', private.int_in(e, 'x', 6), 'y', private.int_in(e, 'y', 6),
            'rotation', (private.int_in(e, 'rotation', 360) / 90) * 90));
        end loop;
        return private.res(c || jsonb_build_object('placed', arr), sec);
      end if;
      -- Validation : correspondance des formes (forme et case ; orientation pour le triangle), pas du style.
      select count(*) into k from jsonb_array_elements(sol -> 'model') mo
        where exists (select 1 from jsonb_array_elements(c -> 'placed') pl
                      where pl ->> 'shape' = mo ->> 'shape' and pl ->> 'x' = mo ->> 'x' and pl ->> 'y' = mo ->> 'y'
                        and (mo ->> 'shape' <> 'triangle' or (pl ->> 'rotation')::int = (mo ->> 'rotation')::int % 360));
      return private.res(c || jsonb_build_object('done', true, 'score', k, 'points', k, 'success', k = (c ->> 'k')::int), sec);
    end if;

  -- -------------------------------------------------------------------------
  when 'exquisite_drawing' then
    if typ = 'band' and c ->> 'phase' = 'draw' then
      i := private.int_in(p, 'band', 3);
      if (c -> 'owners' ->> i)::int <> seat then perform private.mv('not_your_turn'); end if;
      if c -> 'done_bands' ? i::text then perform private.mv('already_submitted'); end if;
      arr := private.strokes_in(p, 'strokes', 60);
      if jsonb_array_length(arr) = 0 then perform private.mv('invalid_drawing'); end if;
      -- Les bandes restent cachées (état privé) jusqu'à ce que les trois soient dessinées.
      sec := jsonb_set(sec, array['seats', me], coalesce(sec -> 'seats' -> me, '{}') || jsonb_build_object(i::text, arr));
      sec := jsonb_set(sec, '{bands}', coalesce(sec -> 'bands', '{}') || jsonb_build_object(i::text, arr));
      c := jsonb_set(c, array['done_bands', i::text], 'true');
      if (select count(*) from jsonb_object_keys(c -> 'done_bands')) = 3 then
        c := c || jsonb_build_object('bands', jsonb_build_array(sec #> '{bands,0}', sec #> '{bands,1}', sec #> '{bands,2}'), 'phase', 'name');
      end if;
      return private.res(c, sec);
    elsif typ = 'name' and c ->> 'phase' = 'name' then
      c := jsonb_set(c, array['names', me], to_jsonb(private.txt(p, 'text', 40)));
      if c -> 'names' ? oth then c := c || '{"done": true}'; end if;
      return private.res(c, sec);
    end if;

  -- -------------------------------------------------------------------------
  when 'pixel_art' then
    if typ = 'paint' then
      i := private.int_in(p, 'i', 64);
      if p -> 'c' is null or jsonb_typeof(p -> 'c') = 'null' then
        k := null;
      else
        k := private.int_in(p, 'c', 6);
        if not (c -> 'colors' -> me) @> to_jsonb(k) then perform private.mv('not_your_color'); end if;
      end if;
      if c -> 'cells' ->> i is not null and not (c -> 'colors' -> me) @> (c -> 'cells' -> i) then
        perform private.mv('ask_partner');
      end if;
      c := jsonb_set(c, array['cells', i::text], coalesce(to_jsonb(k), 'null'::jsonb)) || '{"validated": {}}';
      return private.res(c, sec);
    elsif typ = 'propose' then
      i := private.int_in(p, 'i', 64);
      if c -> 'cells' ->> i is null or (c -> 'colors' -> me) @> (c -> 'cells' -> i) then perform private.mv('invalid_move'); end if;
      k := case when p -> 'c' is null or jsonb_typeof(p -> 'c') = 'null' then null else private.int_in(p, 'c', 6) end;
      if jsonb_array_length(c -> 'pending') >= 10 then perform private.mv('too_many_items'); end if;
      c := c || jsonb_build_object('pending', private.push(c -> 'pending', jsonb_build_object('i', i, 'c', k, 'by', seat)));
      return private.res(c, sec);
    elsif typ in ('accept', 'refuse') then
      k := private.int_in(p, 'k', jsonb_array_length(c -> 'pending'));
      e := c -> 'pending' -> k;
      if (e ->> 'by')::int = seat then perform private.mv('not_your_turn'); end if;
      if typ = 'accept' then c := jsonb_set(c, array['cells', e ->> 'i'], e -> 'c') || '{"validated": {}}'; end if;
      c := c || jsonb_build_object('pending', (c -> 'pending') - k);
      return private.res(c, sec);
    elsif typ = 'validate' then
      c := jsonb_set(c, array['validated', me], 'true');
      if c -> 'validated' ? oth then
        -- Comparaison case par case avec le modèle (5 × 5 placé à partir de la case (1, 1)).
        select count(*) into k from generate_series(0, 63) g
          where (case when g / 8 between 1 and 5 and g % 8 between 1 and 5
                      then substr(c -> 'model' -> 'rows' ->> (g / 8 - 1), g % 8, 1) = '1' else false end)
                = (c -> 'cells' ->> g is not null);
        c := c || jsonb_build_object('done', true, 'score', k, 'points', case when k = 64 then 1 else 0 end, 'success', k = 64);
      end if;
      return private.res(c, sec);
    end if;

  -- -------------------------------------------------------------------------
  when 'tangram' then
    if typ = 'place' then
      i := private.int_in(p, 'id', 7);
      e := c -> 'pieces' -> i;
      ok := coalesce((p ->> 'flip')::boolean, false);
      if ok and not (e ->> 'flippable')::boolean then perform private.mv('no_flip'); end if;
      k := private.int_in(p, 'rot', 4);
      x := private.int_in(p, 'x', 10); y := private.int_in(p, 'y', 10);
      arr := private.tg_poly(e -> 'base', x, y, k, ok);
      if exists (select 1 from jsonb_array_elements(arr) q where (q ->> 0)::int > 10 or (q ->> 1)::int > 10) then
        perform private.mv('outside');
      end if;
      c := jsonb_set(c, array['pieces', i::text], e || jsonb_build_object('x', x, 'y', y, 'rot', k, 'flip', ok));
      c := c || jsonb_build_object('moves', (c ->> 'moves')::int + 1);
      if private.tg_solved(c) then c := c || '{"done": true, "success": true, "points": 1}'; end if;
      return private.res(c, sec);
    end if;

  -- -------------------------------------------------------------------------
  when 'jigsaw' then
    if typ = 'swap' then
      i := private.int_in(p, 'a', jsonb_array_length(c -> 'order'));
      k := private.int_in(p, 'b', jsonb_array_length(c -> 'order'));
      if i = k then perform private.mv('invalid_move'); end if;
      e := c -> 'order' -> i;
      c := jsonb_set(jsonb_set(c, array['order', i::text], c -> 'order' -> k), array['order', k::text], e);
      c := c || jsonb_build_object('moves', (c ->> 'moves')::int + 1);
      if not exists (select 1 from jsonb_array_elements(c -> 'order') with ordinality u(q, o) where (q::text)::int <> o - 1) then
        c := c || '{"done": true, "success": true, "points": 1}';
      end if;
      return private.res(c, sec);
    end if;

  -- -------------------------------------------------------------------------
  when 'sticker_portrait' then
    if typ = 'submit' then
      if c -> 'submitted' ? me then perform private.mv('already_submitted'); end if;
      arr := private.items_in(p, 'items', jsonb_array_length(c -> 'stickers'), 12);
      if jsonb_array_length(arr) = 0 then perform private.mv('invalid_move'); end if;
      sec := jsonb_set(sec, array['seats', me], jsonb_build_object('items', arr));
      c := jsonb_set(c, array['submitted', me], 'true');
      if c -> 'submitted' ? oth then
        c := c || jsonb_build_object('portraits', jsonb_build_object('1', sec #> '{seats,1,items}', '2', sec #> '{seats,2,items}'), 'done', true);
      end if;
      return private.res(c, sec);
    end if;

  -- -------------------------------------------------------------------------
  when 'emblem' then
    if typ = 'symbol' then
      perform private.need_turn(c, seat);
      c := jsonb_set(c, array['slots', me], jsonb_build_object('o', private.int_in(p, 'o', jsonb_array_length(c -> 'symbols')),
                                                               'c', private.int_in(p, 'c', jsonb_array_length(c -> 'colors'))));
      c := c || jsonb_build_object('turn', case when c -> 'slots' ? oth then null else 3 - seat end, 'validated', '{}'::jsonb);
      return private.res(c, sec);
    elsif typ = 'support' then
      return private.res(c || jsonb_build_object('support', private.int_in(p, 'k', 3), 'validated', '{}'::jsonb), sec);
    elsif typ = 'name' then
      return private.res(c || jsonb_build_object('name', private.txt(p, 'text', 24), 'validated', '{}'::jsonb), sec);
    elsif typ = 'validate' then
      if not (c -> 'slots' ? '1' and c -> 'slots' ? '2') or c -> 'support' = 'null'::jsonb or c -> 'name' = 'null'::jsonb then
        perform private.mv('not_finished');
      end if;
      c := jsonb_set(c, array['validated', me], 'true');
      if c -> 'validated' ? oth then c := c || '{"done": true}'; end if;
      return private.res(c, sec);
    end if;

  -- -------------------------------------------------------------------------
  when 'palette' then
    if typ = 'pick' and c ->> 'phase' = 'pick' then
      if c -> 'submitted' ? me then perform private.mv('already_submitted'); end if;
      if jsonb_typeof(p -> 'ids') <> 'array' or jsonb_array_length(p -> 'ids') <> 3 then perform private.mv('pick_three'); end if;
      select jsonb_agg(distinct private.int_in(jsonb_build_object('v', q), 'v', jsonb_array_length(c -> 'colors'))) into arr
        from jsonb_array_elements(p -> 'ids') q;
      if jsonb_array_length(arr) <> 3 then perform private.mv('pick_three'); end if;
      sec := jsonb_set(sec, array['seats', me], jsonb_build_object('ids', arr));
      c := jsonb_set(c, array['submitted', me], 'true');
      if c -> 'submitted' ? oth then
        select coalesce(jsonb_agg(q), '[]') into arr from jsonb_array_elements(sec #> '{seats,1,ids}') q where (sec #> '{seats,2,ids}') @> q;
        c := c || jsonb_build_object('picks', jsonb_build_object('1', sec #> '{seats,1,ids}', '2', sec #> '{seats,2,ids}'),
                                     'final', arr, 'phase', 'negotiate',
                                     'turn', (select ((greatest(current_round, 1) - 1) % 2) + 1 from public.game_sessions where id = p_session));
        if jsonb_array_length(arr) >= 5 then c := c || '{"done": true}'; end if;
      end if;
      return private.res(c, sec);
    elsif typ = 'propose' and c ->> 'phase' = 'negotiate' then
      perform private.need_turn(c, seat);
      if c -> 'proposal' <> 'null'::jsonb then perform private.mv('wait_answer'); end if;
      i := private.int_in(p, 'id', jsonb_array_length(c -> 'colors'));
      if (c -> 'final') @> to_jsonb(i) then perform private.mv('already_used'); end if;
      return private.res(c || jsonb_build_object('proposal', jsonb_build_object('id', i, 'by', seat), 'turn', 3 - seat), sec);
    elsif typ = 'answer' and c ->> 'phase' = 'negotiate' then
      perform private.need_turn(c, seat);
      if c -> 'proposal' = 'null'::jsonb then perform private.mv('invalid_move'); end if;
      if coalesce((p ->> 'ok')::boolean, false) then
        c := c || jsonb_build_object('final', (c -> 'final') || jsonb_build_array(c #> '{proposal,id}'));
      end if;
      c := c || '{"proposal": null}';
      if jsonb_array_length(c -> 'final') >= 5 then c := c || '{"done": true, "turn": null}'; end if;
      return private.res(c, sec);
    end if;

  -- -------------------------------------------------------------------------
  when 'poster' then
    perform private.need_turn(c, seat);
    if typ = 'title' and c ->> 'phase' = 'title' then
      c := c || jsonb_build_object('title', private.txt(p, 'text', 40), 'phase', 'visual', 'turn', c -> 'b');
    elsif typ = 'visual' and c ->> 'phase' = 'visual' then
      arr := private.items_in(p, 'items', jsonb_array_length(c -> 'objects'), 5);
      if jsonb_array_length(arr) = 0 then perform private.mv('invalid_move'); end if;
      c := c || jsonb_build_object('visual', arr, 'phase', 'subtitle');
    elsif typ = 'subtitle' and c ->> 'phase' = 'subtitle' then
      c := c || jsonb_build_object('subtitle', private.txt(p, 'text', 80), 'phase', 'detail', 'turn', c -> 'a');
    elsif typ = 'detail' and c ->> 'phase' = 'detail' then
      c := c || jsonb_build_object('detail', private.txt(p, 'text', 40), 'phase', 'done', 'turn', null, 'done', true);
    else
      perform private.mv('invalid_move');
    end if;
    return private.res(c, sec);

  -- -------------------------------------------------------------------------
  when 'silent_comic' then
    if typ = 'frame' and c ->> 'phase' = 'draw' then
      perform private.need_turn(c, seat);
      i := (select o - 1 from jsonb_array_elements(c -> 'frames') with ordinality u(q, o) where q = 'null'::jsonb order by o limit 1);
      arr := private.strokes_in(p, 'strokes', 40);
      e := private.items_in(p, 'stickers', jsonb_array_length(c -> 'stickers'), 4);
      if jsonb_array_length(arr) = 0 and jsonb_array_length(e) = 0 then perform private.mv('invalid_drawing'); end if;
      c := jsonb_set(c, array['frames', i::text], jsonb_build_object('strokes', arr, 'stickers', e, 'by', seat));
      if i >= 2 then c := c || '{"phase": "titles", "turn": null}';
      else c := c || jsonb_build_object('turn', c -> 'owners' -> (i + 1)); end if;
      return private.res(c, sec);
    elsif typ = 'title' and c ->> 'phase' = 'titles' then
      if c -> 'submitted' ? me then perform private.mv('already_submitted'); end if;
      sec := jsonb_set(sec, array['seats', me], jsonb_build_object('title', private.txt(p, 'text', 60)));
      c := jsonb_set(c, array['submitted', me], 'true');
      if c -> 'submitted' ? oth then
        c := c || jsonb_build_object('titles', jsonb_build_object('1', sec #> '{seats,1,title}', '2', sec #> '{seats,2,title}'), 'done', true);
      end if;
      return private.res(c, sec);
    end if;

  -- -------------------------------------------------------------------------
  when 'tile_scene' then
    perform private.need_turn(c, seat);
    if typ = 'place' then
      k := private.int_in(p, 'h', jsonb_array_length(c -> 'hands' -> me));
      i := private.int_in(p, 'i', 25);
      t := c -> 'hands' -> me ->> k;
      if c -> 'grid' ->> i is not null then perform private.mv('cell_taken'); end if;
      if not exists (select 1 from unnest(private.neighbors5(i)) z where c -> 'grid' ->> z is not null) then perform private.mv('not_adjacent'); end if;
      if not private.tile_legal(c -> 'grid', t, i) then perform private.mv('house_needs_path'); end if;
      c := jsonb_set(c, array['grid', i::text], to_jsonb(t));
      c := jsonb_set(c, array['hands', me, k::text], to_jsonb(private.tile_draw()));
      c := c || jsonb_build_object('placed', (c ->> 'placed')::int + 1, 'turn', 3 - seat, 'goal', private.island_goal(c -> 'grid'));
      if (c ->> 'placed')::int >= (c ->> 'max')::int or not exists (select 1 from jsonb_array_elements(c -> 'grid') q where q = 'null'::jsonb) then
        c := c || jsonb_build_object('done', true, 'success', (c ->> 'goal')::boolean, 'points', case when (c ->> 'goal')::boolean then 1 else 0 end);
      end if;
      return private.res(c, sec);
    elsif typ = 'swap' then
      -- Échange gratuit seulement si aucune tuile de la main n'est jouable.
      if exists (select 1 from jsonb_array_elements_text(c -> 'hands' -> me) h, generate_series(0, 24) g
                 where private.tile_legal(c -> 'grid', h, g)) then
        perform private.mv('playable_exists');
      end if;
      c := jsonb_set(c, array['hands', me], jsonb_build_array('chemin droit', private.tile_draw(), private.tile_draw()));
      return private.res(c, sec);
    end if;

  -- -------------------------------------------------------------------------
  when 'constellation' then
    if typ = 'note' and c ->> 'phase' = 'compose' then
      perform private.need_turn(c, seat);
      i := private.int_in(p, 'k', jsonb_array_length(c -> 'stars'));
      c := c || jsonb_build_object('seq', (c -> 'seq') || to_jsonb(i), 'turn', 3 - seat);
      if jsonb_array_length(c -> 'seq') >= (c ->> 'steps')::int then c := c || '{"phase": "name", "turn": null}'; end if;
      return private.res(c, sec);
    elsif typ = 'name' and c ->> 'phase' = 'name' then
      c := jsonb_set(c, array['names', me], to_jsonb(private.txt(p, 'text', 40)));
      if c -> 'names' ? oth then c := c || '{"done": true}'; end if;
      return private.res(c, sec);
    end if;

  -- -------------------------------------------------------------------------
  when 'flipbook' then
    if typ = 'frame' then
      i := private.int_in(p, 'i', 8);
      if (c -> 'owners' ->> i)::int <> seat then perform private.mv('not_your_frame'); end if;
      arr := private.items_in(p, 'objs', 2, 2);
      if jsonb_array_length(arr) <> 2 then perform private.mv('invalid_move'); end if;
      c := jsonb_set(c, array['frames', i::text], jsonb_build_object('objs', arr, 'strokes', private.strokes_in(p, 'strokes', 3)));
      return private.res(c || '{"validated": {}}', sec);
    elsif typ = 'validate' then
      if exists (select 1 from jsonb_array_elements(c -> 'frames') q where q = 'null'::jsonb) then perform private.mv('not_finished'); end if;
      c := jsonb_set(c, array['validated', me], 'true');
      if c -> 'validated' ? oth then c := c || '{"done": true}'; end if;
      return private.res(c, sec);
    end if;

  -- -------------------------------------------------------------------------
  when 'weaving' then
    if typ in ('vcolor', 'hcolor') then
      if (typ = 'vcolor' and seat <> (c ->> 'a')::int) or (typ = 'hcolor' and seat <> (c ->> 'b')::int) then perform private.mv('not_your_turn'); end if;
      i := private.int_in(p, 'k', 6);
      k := private.int_in(p, 'c', jsonb_array_length(c -> 'palette'));
      c := jsonb_set(c, array[case when typ = 'vcolor' then 'vcolors' else 'hcolors' end, i::text], to_jsonb(k));
      return private.res(c || '{"validated": {}}', sec);
    elsif typ = 'toggle' then
      i := private.int_in(p, 'i', 36);
      -- Chacun sa moitié : colonnes 1 à 3 pour celui qui pose les fils verticaux, 4 à 6 pour l'autre.
      if (seat = (c ->> 'a')::int) <> (i % 6 < 3) then perform private.mv('other_half'); end if;
      c := jsonb_set(c, array['mask', i::text], to_jsonb(1 - (c -> 'mask' ->> i)::int));
      return private.res(c || '{"validated": {}}', sec);
    elsif typ = 'title' then
      return private.res(c || jsonb_build_object('title', private.txt(p, 'text', 40), 'validated', '{}'::jsonb), sec);
    elsif typ = 'validate' then
      if c -> 'title' = 'null'::jsonb or exists (select 1 from jsonb_array_elements((c -> 'vcolors') || (c -> 'hcolors')) q where q = 'null'::jsonb) then
        perform private.mv('not_finished');
      end if;
      c := jsonb_set(c, array['validated', me], 'true');
      if c -> 'validated' ? oth then
        ok := c -> 'mask' = c -> 'model' -> 'mask';
        c := c || jsonb_build_object('done', true, 'success', ok, 'points', case when ok then 1 else 0 end,
          'matches', (select count(*) from generate_series(0, 35) g where c -> 'mask' -> g = c -> 'model' -> 'mask' -> g));
      end if;
      return private.res(c, sec);
    end if;
  else
    raise exception 'unknown_mechanic';
  end case;
  perform private.mv('invalid_move');
  return null;
end $$;

-- Aiguillage : la famille 2 reste dans board_setup / board_apply ; les autres mécaniques passent par la famille 3.
create or replace function private.board_route3() returns text[]
language sql immutable set search_path = '' as $$
  select array['draw_guess','complete_doodle','draw_dictation','exquisite_drawing','pixel_art','tangram','jigsaw','sticker_portrait',
               'emblem','stroke_budget','mirror_draw','palette','poster','silent_comic','tile_scene','constellation','flipbook','weaving']
$$;
