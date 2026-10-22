-- Famille 4 « Mémoire et observation » : tirage, règles et robot (moteur plateau).
-- Ce qu'il faut mémoriser est placé dans la part privée de chaque joueur (seats.N.view) ; au coup « seen »
-- (fin de l'observation), il en est retiré : l'écran ne peut plus le relire. Les réponses restent privées jusqu'à
-- ce que les deux aient répondu ; la solution n'est publiée qu'à la fin de la manche.

create or replace function private.both_view(v jsonb) returns jsonb
language sql immutable set search_path = '' as $$ select jsonb_build_object('1', jsonb_build_object('view', v), '2', jsonb_build_object('view', v)) $$;

create or replace function private.is_test_bot() returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (select 1 from private.test_autoplayers where user_id = auth.uid())
$$;

create or replace function private.board_route4() returns text[]
language sql immutable set search_path = '' as $$
  select array['memory_pairs','change_detection','differences','zoom_recognition','visual_search','recall_set','simon','rhythm',
               'ordered_recall','spatial_recall','pixel_recall','sorting','go_nogo','precision','split_memory','silhouette','layers','rotation']
$$;

-- ===========================================================================
-- Tirage
-- ===========================================================================
create or replace function private.board_setup4(s public.game_sessions, cfg jsonb) returns jsonb
language plpgsql volatile security definer set search_path = '' as $$
declare
  m text := cfg ->> 'mechanic';
  ra int := ((greatest(s.current_round, 1) - 1) % 2) + 1;
  e jsonb;
  v jsonb;
  arr jsonb;
  k int;
  base jsonb := jsonb_build_object('mech', m, 'seen', '{}'::jsonb, 'submitted', '{}'::jsonb, 'answers', null,
                                   'scores', jsonb_build_object('1', 0, '2', 0), 'done', false);
begin
  case m
  when 'memory_pairs' then
    e := private.pick_entry(s.id, 'memory');
    select jsonb_agg(x order by random()) into arr from jsonb_array_elements_text(e #> '{v,cards}') x;
    return base || jsonb_build_object('n', jsonb_array_length(arr), 'cols', e #> '{v,cols}', 'turn', 1 + private.rnd(2),
      'faces', '{}'::jsonb, 'matched', '{}'::jsonb, 'open', '[]'::jsonb, 'miss', '{}'::jsonb,
      '_secret', jsonb_build_object('bank', 'memory', 'idx', e -> 'i', 'solution', jsonb_build_object('cards', arr)));

  when 'change_detection' then
    e := private.pick_entry(s.id, 'change'); v := e -> 'v';
    select jsonb_object_agg(case when key::int = (v ->> 'move_from')::int then v ->> 'move_to' else key end, value) into arr
      from jsonb_each(v -> 'objects');
    return base || jsonb_build_object('rows', v -> 'rows', 'cols', v -> 'cols', 'exposure', 12,
      '_secret', jsonb_build_object('bank', 'change', 'idx', e -> 'i',
        'seats', private.both_view(jsonb_build_object('objects', v -> 'objects')),
        'solution', jsonb_build_object('after', arr, 'from', v -> 'move_from', 'to', v -> 'move_to', 'before', v -> 'objects')));

  when 'differences' then
    e := private.pick_entry(s.id, 'differences'); v := e -> 'v';
    return base || jsonb_build_object('objects', v -> 'base_objects', 'changes', v -> 'changes', 'found', '[]'::jsonb,
      'errors', jsonb_build_object('1', 0, '2', 0), 'turn', null,
      '_secret', jsonb_build_object('bank', 'differences', 'idx', e -> 'i', 'solution', jsonb_build_object('changes', v -> 'changes')));

  when 'zoom_recognition' then
    e := private.pick_entry(s.id, 'objects');
    select jsonb_agg(x order by random()) into arr from (
      select e ->> 'v' x union all
      (select value #>> '{}' from public.content_banks where bank = 'objects' and idx <> (e ->> 'i')::int order by random() limit 3)) z;
    return base || jsonb_build_object('choices', arr, 'image', '/assets/jeux/elements/' || private.slug(e ->> 'v') || '.svg',
      'focus', jsonb_build_array(round((0.35 + random() * 0.3)::numeric, 2), round((0.35 + random() * 0.3)::numeric, 2)),
      'levels', jsonb_build_object('1', 1, '2', 1),
      '_secret', jsonb_build_object('bank', 'objects', 'idx', e -> 'i', 'seats', '{}'::jsonb,
        'solution', jsonb_build_object('target', e -> 'v', 'index', (select o - 1 from jsonb_array_elements_text(arr) with ordinality t(x, o) where x = e ->> 'v'))));

  when 'visual_search' then
    e := private.pick_entry(s.id, 'search'); v := e -> 'v';
    return base || jsonb_build_object('items', v -> 'items', 'target', v -> 'items' -> (v ->> 'target_index')::int,
      'found', '{}'::jsonb, 'errors', jsonb_build_object('1', 0, '2', 0), 'turn', null,
      '_secret', jsonb_build_object('bank', 'search', 'idx', e -> 'i', 'solution', jsonb_build_object('index', v -> 'target_index')));

  when 'recall_set' then
    e := private.pick_entry(s.id, 'recall'); v := e -> 'v';
    return base || jsonb_build_object('choices', v -> 'choices', 'count', jsonb_array_length(v -> 'targets'), 'exposure', 15,
      '_secret', jsonb_build_object('bank', 'recall', 'idx', e -> 'i', 'seats', private.both_view(jsonb_build_object('targets', v -> 'targets')),
        'solution', jsonb_build_object('targets', v -> 'targets')));

  when 'simon' then
    select jsonb_agg(value -> 'sequence' order by idx) into arr from public.content_banks where bank = 'sequence';
    return base || jsonb_build_object('levels', jsonb_build_object('1', 0, '2', 0), 'errors', jsonb_build_object('1', 0, '2', 0),
      'finished', '{}'::jsonb, 'max_level', jsonb_array_length(arr), 'turn', null,
      '_secret', jsonb_build_object('seats', private.both_view(jsonb_build_object('sequence', arr -> 0)), 'solution', jsonb_build_object('levels', arr)));

  when 'rhythm' then
    e := private.pick_entry(s.id, 'rhythm'); v := e -> 'v';
    return base || jsonb_build_object('beats', v -> 'beats', 'bpm', v -> 'bpm',
      '_secret', jsonb_build_object('bank', 'rhythm', 'idx', e -> 'i', 'seats', private.both_view(jsonb_build_object('active', v -> 'active')),
        'solution', jsonb_build_object('active', v -> 'active')));

  when 'ordered_recall' then
    e := private.pick_entry(s.id, 'order'); v := e -> 'v';
    select jsonb_agg(x order by random()) into arr from jsonb_array_elements_text(v -> 'sequence') x;
    return base || jsonb_build_object('pool', arr, 'exposure_ms', 1500,
      '_secret', jsonb_build_object('bank', 'order', 'idx', e -> 'i', 'seats', private.both_view(jsonb_build_object('sequence', v -> 'sequence')),
        'solution', jsonb_build_object('sequence', v -> 'sequence')));

  when 'spatial_recall' then
    e := private.pick_entry(s.id, 'spatial'); v := e -> 'v';
    select jsonb_agg(value order by random()) into arr from jsonb_each_text(v -> 'positions');
    return base || jsonb_build_object('objects', arr, 'size', 4, 'exposure', 15,
      '_secret', jsonb_build_object('bank', 'spatial', 'idx', e -> 'i', 'seats', private.both_view(jsonb_build_object('positions', v -> 'positions')),
        'solution', jsonb_build_object('positions', v -> 'positions')));

  when 'pixel_recall' then
    e := private.pick_entry(s.id, 'pixel_patterns');
    return base || jsonb_build_object('size', 5, 'exposure', 12,
      '_secret', jsonb_build_object('bank', 'pixel_patterns', 'idx', e -> 'i', 'seats', private.both_view(jsonb_build_object('rows', e #> '{v,rows}')),
        'solution', jsonb_build_object('rows', e #> '{v,rows}', 'name', e #> '{v,name}')));

  when 'sorting' then
    e := private.pick_entry(s.id, 'sorts'); v := e -> 'v';
    return base || jsonb_build_object('rule', v -> 'rule', 'bins', jsonb_build_array(v -> 'left', v -> 'right'), 'items', v -> 'items',
      '_secret', jsonb_build_object('bank', 'sorts', 'idx', e -> 'i', 'solution', jsonb_build_object('expected',
        (select jsonb_agg(case when v ->> 'rule' = 'parité' then case when (x #>> '{}')::int % 2 = 0 then 0 else 1 end
                               when x #>> '{}' = v ->> 'left' then 0 else 1 end order by o)
         from jsonb_array_elements(v -> 'items') with ordinality t(x, o)))));

  when 'go_nogo' then
    e := private.pick_entry(s.id, 'signals'); v := e -> 'v';
    return base || jsonb_build_object('stimuli', v -> 'stimuli', 'target', v -> 'target', 'interval', coalesce((v ->> 'duration_ms')::int, 1400),
      '_secret', jsonb_build_object('bank', 'signals', 'idx', e -> 'i', 'solution', '{}'::jsonb));

  when 'precision' then
    e := private.pick_entry(s.id, 'precision'); v := e -> 'v';
    return base || jsonb_build_object('exposure_ms', coalesce((v ->> 'exposure_ms')::int, 3000),
      '_secret', jsonb_build_object('bank', 'precision', 'idx', e -> 'i', 'seats', private.both_view(jsonb_build_object('target', v -> 'target')),
        'solution', jsonb_build_object('target', v -> 'target')));

  when 'split_memory' then
    e := private.pick_entry(s.id, 'split_recall'); v := e -> 'v';
    select jsonb_agg(jsonb_build_object('cell', key::int, 'o', value) order by key::int) into arr from jsonb_each_text(v -> 'positions');
    return (base - 'scores') || jsonb_build_object('objects', (select jsonb_agg(x ->> 'o' order by random()) from jsonb_array_elements(arr) x),
      'size', 4, 'exposure', 12, 'placed', '{}'::jsonb, 'hinted', null, 'validated', '{}'::jsonb, 'points', 0, 'success', false,
      '_secret', jsonb_build_object('bank', 'split_recall', 'idx', e -> 'i',
        'seats', jsonb_build_object(ra::text, jsonb_build_object('view', (select jsonb_agg(arr -> (x::text)::int) from jsonb_array_elements(v -> 'roleA_indices') x)),
                                    (3 - ra)::text, jsonb_build_object('view', (select jsonb_agg(arr -> (x::text)::int) from jsonb_array_elements(v -> 'roleB_indices') x))),
        'solution', jsonb_build_object('positions', arr)));

  when 'silhouette' then
    e := private.pick_entry(s.id, 'silhouette_levels'); v := e -> 'v';
    return base || jsonb_build_object('choices', v -> 'choices',
      'labels', (select jsonb_agg(private.label_of(x) order by o) from jsonb_array_elements_text(v -> 'choices') with ordinality t(x, o)), 'shadow', '/assets/jeux/elements/' || (v ->> 'target') || '.svg', 'hints', '{}'::jsonb,
      '_secret', jsonb_build_object('bank', 'silhouette_levels', 'idx', e -> 'i', 'seats', '{}'::jsonb,
        'solution', jsonb_build_object('target', v -> 'target', 'index', (select o - 1 from jsonb_array_elements_text(v -> 'choices') with ordinality t(x, o) where x = v ->> 'target'))));

  when 'layers' then
    e := private.pick_entry(s.id, 'layer_levels'); v := e -> 'v';
    return base || jsonb_build_object('centers', v -> 'centers', 'radius', v -> 'radius', 'patterns', v -> 'patterns',
      'draw', v -> 'back_to_front', 'hints', '{}'::jsonb,
      '_secret', jsonb_build_object('bank', 'layer_levels', 'idx', e -> 'i', 'seats', '{}'::jsonb, 'solution', jsonb_build_object('order', v -> 'back_to_front')));

  when 'rotation' then
    e := private.pick_entry(s.id, 'rotation_levels'); v := e -> 'v';
    return base || jsonb_build_object('objects', v -> 'objects', 'positions', v -> 'positions',
      'labels', (select jsonb_agg(private.label_of(x) order by o) from jsonb_array_elements_text(v -> 'objects') with ordinality t(x, o)), 'turns', v -> 'quarter_turns_clockwise',
      '_secret', jsonb_build_object('bank', 'rotation_levels', 'idx', e -> 'i', 'seats', '{}'::jsonb, 'solution', jsonb_build_object('cells', v -> 'solution')));
  else
    raise exception 'unknown_mechanic';
  end case;
end $$;

-- Libellé → nom de fichier d'élément (même règle que l'application).
create or replace function private.slug(t text) returns text
language sql immutable set search_path = '' as $$
  select trim(both '-' from regexp_replace(
    translate(lower(replace(replace(replace(replace(coalesce(t, ''), 'Œ', 'oe'), 'œ', 'oe'), '’', ''), '''', '')),
              'àâäáãåçéèêëíìîïñóòôöõúùûüýÿ', 'aaaaaaceeeeiiiinooooouuuuyy'),
    '[^a-z0-9]+', '-', 'g'))
$$;

-- Nom affiché d'un élément du kit à partir de son nom de fichier (« cle » → « clé »).
create or replace function private.label_of(p_slug text) returns text
language sql stable security definer set search_path = '' as $$
  select coalesce((select value #>> '{}' from public.content_banks where bank = 'objects' and private.slug(value #>> '{}') = p_slug limit 1),
                  replace(p_slug, '-', ' '))
$$;

-- ===========================================================================
-- Réponse privée notée (jeux « chacun répond en privé ») : score calculé côté serveur.
-- ===========================================================================
create or replace function private.score4(m text, c jsonb, sol jsonb, p jsonb, seat int) returns jsonb
language plpgsql immutable set search_path = '' as $$
declare
  a jsonb;
  k int;
  n int;
begin
  case m
  when 'change_detection' then
    k := private.int_in(p, 'cell', (c ->> 'rows')::int * (c ->> 'cols')::int);
    return jsonb_build_object('answer', k, 'score', case when k = (sol ->> 'to')::int then 1 else 0 end);
  when 'zoom_recognition' then
    k := private.int_in(p, 'i', jsonb_array_length(c -> 'choices'));
    return jsonb_build_object('answer', k, 'score', case when k = (sol ->> 'index')::int then 4 - (c -> 'levels' ->> seat::text)::int else 0 end);
  when 'recall_set' then
    if jsonb_typeof(p -> 'items') <> 'array' or jsonb_array_length(p -> 'items') <> (c ->> 'count')::int then perform private.mv('pick_count'); end if;
    select jsonb_agg(distinct private.int_in(jsonb_build_object('v', x), 'v', jsonb_array_length(c -> 'choices'))) into a from jsonb_array_elements(p -> 'items') x;
    if jsonb_array_length(a) <> (c ->> 'count')::int then perform private.mv('pick_count'); end if;
    select count(*) into k from jsonb_array_elements(a) x where (sol -> 'targets') ? (c -> 'choices' ->> (x::text)::int);
    return jsonb_build_object('answer', a, 'score', k);
  when 'rhythm' then
    if jsonb_typeof(p -> 'mask') <> 'array' or jsonb_array_length(p -> 'mask') <> (c ->> 'beats')::int then perform private.mv('invalid_move'); end if;
    select count(*) into k from generate_series(0, (c ->> 'beats')::int - 1) g
      where coalesce((p -> 'mask' ->> g)::boolean, false) = (sol -> 'active') @> to_jsonb(g);
    return jsonb_build_object('answer', p -> 'mask', 'score', k);
  when 'ordered_recall' then
    n := jsonb_array_length(c -> 'pool');
    if jsonb_typeof(p -> 'order') <> 'array' or jsonb_array_length(p -> 'order') <> n then perform private.mv('invalid_move'); end if;
    select jsonb_agg(c -> 'pool' -> private.int_in(jsonb_build_object('v', x), 'v', n) order by o) into a
      from jsonb_array_elements(p -> 'order') with ordinality t(x, o);
    if (select count(distinct x) from jsonb_array_elements(p -> 'order') x) <> n then perform private.mv('invalid_move'); end if;
    select count(*) into k from generate_series(0, n - 1) g where a -> g = sol -> 'sequence' -> g;
    return jsonb_build_object('answer', a, 'score', k);
  when 'spatial_recall' then
    n := jsonb_array_length(c -> 'objects');
    if jsonb_typeof(p -> 'cells') <> 'array' or jsonb_array_length(p -> 'cells') <> n then perform private.mv('invalid_move'); end if;
    select jsonb_agg(private.int_in(jsonb_build_object('v', x), 'v', 16) order by o) into a from jsonb_array_elements(p -> 'cells') with ordinality t(x, o);
    select count(*) into k from generate_series(0, n - 1) g where sol -> 'positions' ->> (a ->> g) = c -> 'objects' ->> g;
    return jsonb_build_object('answer', a, 'score', k);
  when 'pixel_recall' then
    if jsonb_typeof(p -> 'cells') <> 'array' or jsonb_array_length(p -> 'cells') <> 25 then perform private.mv('invalid_move'); end if;
    select count(*) into k from generate_series(0, 24) g
      where coalesce((p -> 'cells' ->> g)::boolean, false) = (substr(sol -> 'rows' ->> (g / 5), g % 5 + 1, 1) = '1');
    return jsonb_build_object('answer', p -> 'cells', 'score', k);
  when 'sorting' then
    n := jsonb_array_length(c -> 'items');
    if jsonb_typeof(p -> 'bins') <> 'array' or jsonb_array_length(p -> 'bins') <> n then perform private.mv('invalid_move'); end if;
    select count(*) into k from generate_series(0, n - 1) g where (p -> 'bins' ->> g)::int = (sol -> 'expected' ->> g)::int;
    return jsonb_build_object('answer', p -> 'bins', 'score', k);
  when 'go_nogo' then
    if jsonb_typeof(coalesce(p -> 'taps', '[]')) <> 'array' then perform private.mv('invalid_move'); end if;
    select count(*) filter (where c -> 'stimuli' -> g = c -> 'target'), count(*) filter (where c -> 'stimuli' -> g <> c -> 'target') into k, n
      from (select distinct private.int_in(jsonb_build_object('v', x), 'v', jsonb_array_length(c -> 'stimuli')) g
            from jsonb_array_elements(coalesce(p -> 'taps', '[]')) x) z;
    return jsonb_build_object('answer', jsonb_build_object('hits', k, 'false_alarms', n), 'score', greatest(k - n, 0));
  when 'precision' then
    if jsonb_typeof(p -> 'value') <> 'number' or (p ->> 'value')::numeric not between 0 and 100 then perform private.mv('invalid_move'); end if;
    k := round((p ->> 'value')::numeric);
    return jsonb_build_object('answer', k, 'score', 100 - abs(k - (sol ->> 'target')::int));
  when 'silhouette' then
    k := private.int_in(p, 'i', jsonb_array_length(c -> 'choices'));
    return jsonb_build_object('answer', k, 'score', case when k = (sol ->> 'index')::int then 1 else 0 end);
  when 'layers' then
    if jsonb_typeof(p -> 'order') <> 'array' or jsonb_array_length(p -> 'order') <> 3
       or (select count(distinct private.int_in(jsonb_build_object('v', x), 'v', 3)) from jsonb_array_elements(p -> 'order') x) <> 3 then
      perform private.mv('invalid_move');
    end if;
    return jsonb_build_object('answer', p -> 'order', 'score', case when p -> 'order' = sol -> 'order' then 1 else 0 end);
  when 'rotation' then
    if jsonb_typeof(p -> 'cells') <> 'array' or jsonb_array_length(p -> 'cells') <> 3 then perform private.mv('invalid_move'); end if;
    select count(*) into k from generate_series(0, 2) g where private.int_in(jsonb_build_object('v', p -> 'cells' -> g), 'v', 9) = (sol -> 'cells' ->> g)::int;
    return jsonb_build_object('answer', p -> 'cells', 'score', k);
  else
    perform private.mv('invalid_move');
    return null;
  end case;
end $$;

-- Jeux à observation préalable : la réponse n'est possible qu'après la fin de l'observation.
create or replace function private.needs_seen(m text) returns boolean
language sql immutable set search_path = '' as $$
  select m in ('change_detection', 'recall_set', 'rhythm', 'ordered_recall', 'spatial_recall', 'pixel_recall', 'precision', 'split_memory', 'simon')
$$;

-- ===========================================================================
-- Règles des coups
-- ===========================================================================
create or replace function private.board_apply4(m text, c jsonb, sec jsonb, seat int, typ text, p jsonb, p_session uuid) returns jsonb
language plpgsql volatile security definer set search_path = '' as $$
declare
  me text := seat::text;
  oth text := (3 - seat)::text;
  sol jsonb := coalesce(sec -> 'solution', '{}');
  r jsonb;
  i int;
  k int;
  lbl text;
  now_ms bigint := (extract(epoch from clock_timestamp()) * 1000)::bigint;
begin
  -- Fin de l'observation : ce qui était à mémoriser quitte la part privée du joueur.
  if typ = 'seen' then
    if not private.needs_seen(m) then perform private.mv('invalid_move'); end if;
    if c -> 'seen' ? me then return private.res(c, sec); end if;
    sec := jsonb_set(sec, array['seats', me], (coalesce(sec -> 'seats' -> me, '{}') - 'view')
           || case when m = 'change_detection' then jsonb_build_object('after', sol -> 'after') else '{}'::jsonb end);
    return private.res(jsonb_set(c, array['seen', me], 'true'), sec);
  end if;

  case m
  -- ---------------------------------------------------------------- paires
  when 'memory_pairs' then
    if typ <> 'flip' then perform private.mv('invalid_move'); end if;
    perform private.need_turn(c, seat);
    i := private.int_in(p, 'i', (c ->> 'n')::int);
    if c -> 'matched' ? i::text or (c -> 'open') @> to_jsonb(i) then perform private.mv('already_revealed'); end if;
    -- La paire ratée de l'autre reste visible 1,2 s (champ « miss ») : pas de retournement avant.
    if jsonb_array_length(c -> 'open') = 0 and now_ms - coalesce((c #>> array['miss', oth, 'at'])::bigint, 0) < 1200
       and not private.is_test_bot() then
      perform private.mv('wait');
    end if;
    c := jsonb_set(c, array['faces', i::text], sol -> 'cards' -> i) || jsonb_build_object('open', (c -> 'open') || to_jsonb(i));
    if jsonb_array_length(c -> 'open') = 2 then
      if c -> 'faces' -> (c -> 'open' ->> 0) = c -> 'faces' -> (c -> 'open' ->> 1) then
        c := jsonb_set(jsonb_set(c, array['matched', c -> 'open' ->> 0], to_jsonb(seat)), array['matched', c -> 'open' ->> 1], to_jsonb(seat));
        c := jsonb_set(c, array['scores', me], to_jsonb((c -> 'scores' ->> me)::int + 1)) || '{"open": []}';
        if (select count(*) from jsonb_object_keys(c -> 'matched')) >= (c ->> 'n')::int then c := c || '{"done": true}'; end if;
      else
        -- Paire ratée : les faces quittent le plateau mais restent dans « miss » le temps de les voir.
        c := c || jsonb_build_object(
          'miss', jsonb_set(c -> 'miss', array[me], jsonb_build_object('cards', c -> 'open', 'at', now_ms,
                   'faces', jsonb_build_array(c -> 'faces' -> (c -> 'open' ->> 0), c -> 'faces' -> (c -> 'open' ->> 1)))),
          'faces', (c -> 'faces') - (c -> 'open' ->> 0) - (c -> 'open' ->> 1), 'open', '[]'::jsonb, 'turn', 3 - seat);
      end if;
    end if;
    return private.res(c, sec);

  -- ---------------------------------------------------------------- différences
  when 'differences' then
    if typ <> 'tap' then perform private.mv('invalid_move'); end if;
    i := private.int_in(p, 'i', jsonb_array_length(c -> 'objects'));
    if exists (select 1 from jsonb_array_elements(c -> 'found') f where (f ->> 'i')::int = i) then perform private.mv('already_revealed'); end if;
    if exists (select 1 from jsonb_array_elements(sol -> 'changes') ch where (ch ->> 'index')::int = i) then
      c := c || jsonb_build_object('found', private.push(c -> 'found', jsonb_build_object('i', i, 'seat', seat)));
      c := jsonb_set(c, array['scores', me], to_jsonb((c -> 'scores' ->> me)::int + 1));
      if jsonb_array_length(c -> 'found') >= jsonb_array_length(sol -> 'changes') then c := c || '{"done": true}'; end if;
      return private.res(c, sec, '{"hit": true}');
    end if;
    return private.res(jsonb_set(c, array['errors', me], to_jsonb((c -> 'errors' ->> me)::int + 1)), sec, '{"hit": false}');

  -- ---------------------------------------------------------------- chasse au détail
  when 'visual_search' then
    if typ <> 'tap' then perform private.mv('invalid_move'); end if;
    if c -> 'found' ? me then perform private.mv('already_submitted'); end if;
    i := private.int_in(p, 'i', jsonb_array_length(c -> 'items'));
    if i = (sol ->> 'index')::int then
      c := jsonb_set(jsonb_set(c, array['found', me], 'true'), array['scores', me], to_jsonb(greatest(1, 5 - (c -> 'errors' ->> me)::int)));
      if c -> 'found' ? oth then c := c || '{"done": true}'; end if;
      return private.res(c, sec, '{"hit": true}');
    end if;
    return private.res(jsonb_set(c, array['errors', me], to_jsonb((c -> 'errors' ->> me)::int + 1)), sec, '{"hit": false}');

  -- ---------------------------------------------------------------- suite lumineuse
  when 'simon' then
    if typ <> 'answer' then perform private.mv('invalid_move'); end if;
    if c -> 'finished' ? me then perform private.mv('already_submitted'); end if;
    if not (c -> 'seen' ? me) then perform private.mv('watch_first'); end if;
    k := (c -> 'levels' ->> me)::int;
    if jsonb_typeof(p -> 'seq') = 'array' and p -> 'seq' = sol -> 'levels' -> k then
      k := k + 1;
      c := jsonb_set(jsonb_set(c, array['levels', me], to_jsonb(k)), array['scores', me], to_jsonb(jsonb_array_length(sol -> 'levels' -> (k - 1))));
    else
      c := jsonb_set(c, array['errors', me], to_jsonb((c -> 'errors' ->> me)::int + 1));
    end if;
    if k >= (c ->> 'max_level')::int or (c -> 'errors' ->> me)::int >= 2 then
      c := jsonb_set(c, array['finished', me], 'true');
      if c -> 'finished' ? oth then c := c || '{"done": true}'; end if;
    else
      -- Nouvelle observation : la suite du niveau en cours.
      sec := jsonb_set(sec, array['seats', me], jsonb_build_object('view', jsonb_build_object('sequence', sol -> 'levels' -> k)));
      c := c || jsonb_build_object('seen', (c -> 'seen') - me);
    end if;
    return private.res(c, sec);

  -- ---------------------------------------------------------------- deux mémoires, un plateau
  when 'split_memory' then
    if typ in ('place', 'clear') then
      if not (c -> 'seen' ? me) then perform private.mv('watch_first'); end if;
      i := private.int_in(p, 'o', jsonb_array_length(c -> 'objects'));
      if typ = 'clear' then
        c := c || jsonb_build_object('placed', (c -> 'placed') - i::text);
      else
        k := private.int_in(p, 'cell', 16);
        if exists (select 1 from jsonb_each(c -> 'placed') x where (x.value::text)::int = k and x.key <> i::text) then perform private.mv('cell_taken'); end if;
        c := jsonb_set(c, array['placed', i::text], to_jsonb(k));
      end if;
      return private.res(c || '{"validated": {}}', sec);
    elsif typ = 'hint' then
      if c -> 'hinted' <> 'null'::jsonb then perform private.mv('no_hint'); end if;
      select x into r from jsonb_array_elements(sol -> 'positions') x
        where not exists (select 1 from jsonb_array_elements_text(c -> 'objects') with ordinality t(o, n)
                          where o = x ->> 'o' and (c -> 'placed' ->> (n - 1)::text)::int = (x ->> 'cell')::int)
        order by random() limit 1;
      if r is null then perform private.mv('no_hint'); end if;
      return private.res(c || jsonb_build_object('hinted', r), sec);
    elsif typ = 'validate' then
      if (select count(*) from jsonb_object_keys(c -> 'placed')) < jsonb_array_length(c -> 'objects') then perform private.mv('not_finished'); end if;
      c := jsonb_set(c, array['validated', me], 'true');
      if c -> 'validated' ? oth then
        select count(*) into k from jsonb_array_elements_text(c -> 'objects') with ordinality t(o, n)
          where exists (select 1 from jsonb_array_elements(sol -> 'positions') x where x ->> 'o' = o and (x ->> 'cell')::int = (c -> 'placed' ->> (n - 1)::text)::int);
        c := c || jsonb_build_object('done', true, 'points', case when k = jsonb_array_length(c -> 'objects') then 1 else 0 end,
                                     'success', k = jsonb_array_length(c -> 'objects'), 'correct', k);
      end if;
      return private.res(c, sec);
    end if;

  -- ---------------------------------------------------------------- réponses privées notées
  else
    if typ = 'zoom' and m = 'zoom_recognition' then
      if c -> 'submitted' ? me then perform private.mv('already_submitted'); end if;
      if (c -> 'levels' ->> me)::int >= 3 then perform private.mv('no_hint'); end if;
      return private.res(jsonb_set(c, array['levels', me], to_jsonb((c -> 'levels' ->> me)::int + 1)), sec);
    elsif typ = 'hint' and m in ('silhouette', 'layers') then
      if c -> 'hints' ? me then perform private.mv('no_hint'); end if;
      return private.res(jsonb_set(c, array['hints', me], case when m = 'layers'
        then jsonb_build_object('pos', 0, 'id', sol -> 'order' -> 0) else 'true'::jsonb end), sec);
    elsif typ = 'answer' then
      if c -> 'submitted' ? me then perform private.mv('already_submitted'); end if;
      if private.needs_seen(m) and not (c -> 'seen' ? me) then perform private.mv('watch_first'); end if;
      r := private.score4(m, c, sol, p, seat);
      sec := jsonb_set(sec, array['seats', me], coalesce(sec -> 'seats' -> me, '{}') || jsonb_build_object('answer', r -> 'answer', 'score', r -> 'score'));
      c := jsonb_set(c, array['submitted', me], 'true');
      if c -> 'submitted' ? oth then
        c := c || jsonb_build_object('answers', jsonb_build_object('1', sec #> '{seats,1,answer}', '2', sec #> '{seats,2,answer}'),
          'scores', jsonb_build_object('1', sec #> '{seats,1,score}', '2', sec #> '{seats,2,score}'), 'done', true);
      end if;
      return private.res(c, sec);
    end if;
  end case;
  perform private.mv('invalid_move');
  return null;
end $$;

-- ===========================================================================
-- Partenaire automatique de test (temporaire)
-- ===========================================================================
create or replace function private.board_bot4(m text, c jsonb, sec jsonb, seat int) returns jsonb
language plpgsql volatile security definer set search_path = '' as $$
declare
  me text := seat::text;
  oth text := (3 - seat)::text;
  sol jsonb := coalesce(sec -> 'solution', '{}');
  my_turn boolean := (c ->> 'turn')::int is not distinct from seat;
  human_last boolean := (c #>> '{last,seat}')::int is distinct from seat and c ? 'last';
  i int;
  k int;
  a jsonb;
begin
  if coalesce((c ->> 'done')::boolean, false) then return null; end if;
  if private.needs_seen(m) and not (c -> 'seen' ? me) and not (m = 'simon' and c -> 'finished' ? me) then
    return jsonb_build_object('type', 'seen');
  end if;
  case m
  when 'memory_pairs' then
    if not my_turn then return null; end if;
    if jsonb_array_length(c -> 'open') = 1 then
      -- Deuxième carte : la bonne une fois sur deux.
      select g into i from generate_series(0, (c ->> 'n')::int - 1) g
        where not (c -> 'matched' ? g::text) and not (c -> 'open') @> to_jsonb(g)
        order by (sol -> 'cards' -> g = sol -> 'cards' -> (c -> 'open' ->> 0)::int) = (random() < 0.5) desc, random() limit 1;
    else
      select g into i from generate_series(0, (c ->> 'n')::int - 1) g where not (c -> 'matched' ? g::text) order by random() limit 1;
    end if;
    return jsonb_build_object('type', 'flip', 'payload', jsonb_build_object('i', i));
  when 'differences' then
    if not human_last then return null; end if;
    select (ch ->> 'index')::int into i from jsonb_array_elements(sol -> 'changes') ch
      where not exists (select 1 from jsonb_array_elements(c -> 'found') f where f -> 'i' = ch -> 'index') limit 1;
    return jsonb_build_object('type', 'tap', 'payload', jsonb_build_object('i', i));
  when 'visual_search' then
    if c -> 'found' ? me or not human_last then return null; end if;
    return jsonb_build_object('type', 'tap', 'payload', jsonb_build_object('i', sol -> 'index'));
  when 'simon' then
    if c -> 'finished' ? me then return null; end if;
    return jsonb_build_object('type', 'answer', 'payload', jsonb_build_object('seq', sol -> 'levels' -> (c -> 'levels' ->> me)::int));
  when 'split_memory' then
    for a in select * from jsonb_array_elements(coalesce(sec -> 'seats' -> me -> 'mine', sec -> 'solution' -> 'positions')) loop
      select n - 1 into i from jsonb_array_elements_text(c -> 'objects') with ordinality t(o, n) where o = a ->> 'o';
      if (c -> 'placed' ->> i::text) is distinct from (a ->> 'cell') and human_last then
        if exists (select 1 from jsonb_each(c -> 'placed') x where (x.value::text)::int = (a ->> 'cell')::int) then continue; end if;
        return jsonb_build_object('type', 'place', 'payload', jsonb_build_object('o', i, 'cell', (a ->> 'cell')::int));
      end if;
    end loop;
    if c -> 'validated' ? oth and not c -> 'validated' ? me then return jsonb_build_object('type', 'validate'); end if;
    return null;
  else
    if c -> 'submitted' ? me then return null; end if;
    a := case m
      when 'change_detection' then jsonb_build_object('cell', sol -> 'to')
      when 'zoom_recognition' then jsonb_build_object('i', sol -> 'index')
      when 'recall_set' then jsonb_build_object('items', (select jsonb_agg(o - 1) from jsonb_array_elements_text(c -> 'choices') with ordinality t(x, o)
                                                          where (sol -> 'targets') ? x))
      when 'rhythm' then jsonb_build_object('mask', (select jsonb_agg((sol -> 'active') @> to_jsonb(g) order by g) from generate_series(0, (c ->> 'beats')::int - 1) g))
      when 'ordered_recall' then jsonb_build_object('order', (select jsonb_agg((select o - 1 from jsonb_array_elements(c -> 'pool') with ordinality t(x, o) where x = s.x) order by s.n)
                                                              from jsonb_array_elements(sol -> 'sequence') with ordinality s(x, n)))
      when 'spatial_recall' then jsonb_build_object('cells', (select jsonb_agg((select key::int from jsonb_each_text(sol -> 'positions') where value = x) order by n)
                                                              from jsonb_array_elements_text(c -> 'objects') with ordinality t(x, n)))
      when 'pixel_recall' then jsonb_build_object('cells', (select jsonb_agg(substr(sol -> 'rows' ->> (g / 5), g % 5 + 1, 1) = '1' order by g) from generate_series(0, 24) g))
      when 'sorting' then jsonb_build_object('bins', sol -> 'expected')
      when 'go_nogo' then jsonb_build_object('taps', (select coalesce(jsonb_agg(o - 1), '[]') from jsonb_array_elements(c -> 'stimuli') with ordinality t(x, o) where x = c -> 'target'))
      when 'precision' then jsonb_build_object('value', least(100, (sol ->> 'target')::int + 4))
      when 'silhouette' then jsonb_build_object('i', private.rnd(jsonb_array_length(c -> 'choices')))
      when 'layers' then jsonb_build_object('order', sol -> 'order')
      when 'rotation' then jsonb_build_object('cells', sol -> 'cells')
      else null end;
    if a is null then return null; end if;
    return jsonb_build_object('type', 'answer', 'payload', a);
  end case;
end $$;

-- Aiguillage : la famille 4 rejoint les familles 2 et 3.
create or replace function private.board_setup_any(s public.game_sessions, cfg jsonb) returns jsonb
language plpgsql volatile security definer set search_path = '' as $$
begin
  if cfg ->> 'mechanic' = any(private.board_route4()) then return private.board_setup4(s, cfg); end if;
  if cfg ->> 'mechanic' = any(private.board_route3()) then return private.board_setup3(s, cfg); end if;
  return private.board_setup(s, cfg);
end $$;

create or replace function private.board_apply_any(m text, c jsonb, sec jsonb, seat int, typ text, p jsonb, p_session uuid) returns jsonb
language plpgsql volatile security definer set search_path = '' as $$
begin
  if m = any(private.board_route3()) or m = any(private.board_route4()) then
    if typ = 'giveup' then return private.res(c || '{"done": true, "gave_up": true}', sec); end if;
    if m = any(private.board_route4()) then return private.board_apply4(m, c, sec, seat, typ, p, p_session); end if;
    return private.board_apply3(m, c, sec, seat, typ, p, p_session);
  end if;
  return private.board_apply(m, c, sec, seat, typ, p, p_session);
end $$;

create or replace function private.board_bot_any(m text, c jsonb, sec jsonb, seat int) returns jsonb
language plpgsql volatile security definer set search_path = '' as $$
begin
  if m = any(private.board_route4()) then return private.board_bot4(m, c, sec, seat); end if;
  if m = any(private.board_route3()) then return private.board_bot3(m, c, sec, seat); end if;
  return private.board_bot(m, c, sec, seat);
end $$;
