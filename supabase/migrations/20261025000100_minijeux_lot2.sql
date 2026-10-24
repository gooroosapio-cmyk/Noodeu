-- Mini-jeux interactifs, lot 2 (kit C03/C04 V1, espace noodeu_c34_v1) : Morpion (M01), Points et carrés (M04),
-- Pierre, feuille, ciseaux (M11), Le Dé chanceux (M12), Bataille navale (M07).
-- Le serveur tire le premier joueur, valide chaque coup, calcule les résultats et garde les secrets
-- (geste avant révélation, flottes) dans private.round_secrets : chacun ne reçoit que sa propre part.

create or replace function private.board_route6() returns text[]
language sql immutable set search_path = '' as $$
  select array['tic_tac_toe', 'dots_boxes', 'rps', 'nd_pig', 'battleship'] $$;

-- Victoires cumulées par siège dans les manches précédentes d'une série.
create or replace function private.series_wins(p_session uuid, p_before int) returns jsonb
language sql stable set search_path = '' as $$
  select jsonb_build_object(
    '1', coalesce(sum((card #>> '{scores,1}')::int), 0),
    '2', coalesce(sum((card #>> '{scores,2}')::int), 0))
  from public.session_rounds where session_id = p_session and round_no < p_before $$;

-- Premier joueur : tiré au sort à la première manche, puis alterné à chaque manche suivante.
create or replace function private.first_seat(s public.game_sessions) returns int
language plpgsql volatile set search_path = '' as $$
declare prev int;
begin
  if s.current_round <= 1 then return 1 + private.rnd(2); end if;
  select (card ->> 'first')::int into prev from public.session_rounds where session_id = s.id and round_no = s.current_round - 1;
  return case when prev = 1 then 2 else 1 end;
end $$;

-- ---------------------------------------------------------------------------
-- Bataille navale : flottes
-- ---------------------------------------------------------------------------
create or replace function private.bn_ships() returns jsonb
language sql immutable set search_path = '' as $$
  select '[{"id":"porte-avions","len":5},{"id":"croiseur","len":4},{"id":"contre-torpilleur","len":3},
           {"id":"sous-marin","len":3},{"id":"torpilleur","len":2}]'::jsonb $$;

-- Cases d'un navire placé (r, c, orientation H|V) : tableau de « r:c ».
create or replace function private.bn_cells(r int, c int, o text, len int) returns text[]
language sql immutable set search_path = '' as $$
  select array_agg(case when o = 'H' then r || ':' || (c + i) else (r + i) || ':' || c end order by i)
  from generate_series(0, len - 1) i $$;

-- Flotte valide : les cinq navires exactement, droits, dans la grille 10 × 10, sans chevauchement (contact autorisé).
-- Renvoie la flotte normalisée [{id,len,r,c,o}] ou lève move:placement.
create or replace function private.bn_check(ships jsonb) returns jsonb
language plpgsql immutable set search_path = '' as $$
declare
  model jsonb := private.bn_ships();
  m jsonb;
  s jsonb;
  r int; c int; o text; len int;
  used text[] := '{}';
  cells text[];
  out jsonb := '[]';
begin
  if jsonb_typeof(ships) <> 'array' or jsonb_array_length(ships) <> 5 then perform private.mv('placement'); end if;
  for m in select * from jsonb_array_elements(model) loop
    select x into s from jsonb_array_elements(ships) x where x ->> 'id' = m ->> 'id';
    if s is null then perform private.mv('placement'); end if;
    begin
      r := (s ->> 'start_row')::int; c := (s ->> 'start_col')::int;
    exception when others then perform private.mv('placement');
    end;
    o := s ->> 'orientation'; len := (m ->> 'len')::int;
    if r is null or c is null or o not in ('H', 'V') or r < 0 or c < 0
       or (o = 'H' and (r > 9 or c + len > 10)) or (o = 'V' and (c > 9 or r + len > 10)) then
      perform private.mv('placement');
    end if;
    cells := private.bn_cells(r, c, o, len);
    if used && cells then perform private.mv('placement'); end if;
    used := used || cells;
    out := out || jsonb_build_array(jsonb_build_object('id', m ->> 'id', 'len', len, 'r', r, 'c', c, 'o', o));
  end loop;
  return out;
end $$;

create or replace function private.bn_random() returns jsonb
language plpgsql volatile set search_path = '' as $$
declare
  m jsonb;
  used text[] := '{}';
  cells text[];
  r int; c int; o text; len int;
  out jsonb := '[]';
  tries int;
begin
  for m in select * from jsonb_array_elements(private.bn_ships()) loop
    len := (m ->> 'len')::int;
    tries := 0;
    loop
      tries := tries + 1;
      o := case when private.rnd(2) = 0 then 'H' else 'V' end;
      r := private.rnd(case when o = 'V' then 11 - len else 10 end);
      c := private.rnd(case when o = 'H' then 11 - len else 10 end);
      cells := private.bn_cells(r, c, o, len);
      exit when not (used && cells) or tries > 500;
    end loop;
    used := used || cells;
    out := out || jsonb_build_array(jsonb_build_object('id', m ->> 'id', 'len', len, 'r', r, 'c', c, 'o', o));
  end loop;
  return out;
end $$;

-- ---------------------------------------------------------------------------
-- Morpion
-- ---------------------------------------------------------------------------
create or replace function private.ttt_line(b jsonb) returns jsonb
language plpgsql immutable set search_path = '' as $$
declare l int[];
begin
  foreach l slice 1 in array array[[0,1,2],[3,4,5],[6,7,8],[0,3,6],[1,4,7],[2,5,8],[0,4,8],[2,4,6]] loop
    if (b ->> l[1])::int > 0 and b -> l[1] = b -> l[2] and b -> l[2] = b -> l[3] then
      return jsonb_build_array(l[1], l[2], l[3]);
    end if;
  end loop;
  return null;
end $$;

-- ---------------------------------------------------------------------------
-- Points et carrés : 5 × 5 points, 4 × 4 cases, arêtes h:r:c (r 0..4, c 0..3) et v:r:c (r 0..3, c 0..4).
-- ---------------------------------------------------------------------------
create or replace function private.db_sides(r int, c int) returns text[]
language sql immutable set search_path = '' as $$
  select array['h:' || r || ':' || c, 'h:' || (r + 1) || ':' || c, 'v:' || r || ':' || c, 'v:' || r || ':' || (c + 1)] $$;

create or replace function private.db_boxes(e text) returns int[]
language plpgsql immutable set search_path = '' as $$
declare k text; r int; c int; out int[] := '{}';
begin
  k := split_part(e, ':', 1); r := split_part(e, ':', 2)::int; c := split_part(e, ':', 3)::int;
  if k = 'h' then
    if r > 0 then out := out || ((r - 1) * 4 + c); end if;
    if r < 4 then out := out || (r * 4 + c); end if;
  else
    if c > 0 then out := out || (r * 4 + c - 1); end if;
    if c < 4 then out := out || (r * 4 + c); end if;
  end if;
  return out;
end $$;

create or replace function private.db_edge_ok(e text) returns boolean
language sql immutable set search_path = '' as $$
  select coalesce(e ~ '^h:[0-4]:[0-3]$' or e ~ '^v:[0-3]:[0-4]$', false) $$;

-- Nombre de côtés tracés d'une case (index 0..15).
create or replace function private.db_count(edges jsonb, box int) returns int
language sql immutable set search_path = '' as $$
  select count(*)::int from unnest(private.db_sides(box / 4, box % 4)) s where edges ? s $$;

-- ---------------------------------------------------------------------------
-- Tirage d'une manche
-- ---------------------------------------------------------------------------
create or replace function private.board_setup6(s public.game_sessions, cfg jsonb) returns jsonb
language plpgsql volatile security definer set search_path = '' as $$
declare
  m text := cfg ->> 'mechanic';
  first int := private.first_seat(s);
  target int;
begin
  if m = 'tic_tac_toe' then
    target := coalesce((s.settings ->> 'series_wins')::int, (cfg #>> '{settings,series_wins,default}')::int, 1);
    return jsonb_build_object('mech', m, 'board', '[0,0,0,0,0,0,0,0,0]'::jsonb, 'first', first, 'x_seat', first, 'turn', first,
      'target', target, 'max_rounds', 12, 'series', private.series_wins(s.id, s.current_round), 'done', false,
      '_secret', '{"seats": {}}'::jsonb);
  elsif m = 'dots_boxes' then
    return jsonb_build_object('mech', m, 'edges', '{}'::jsonb, 'owner', '[0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0]'::jsonb,
      'tally', '{"1": 0, "2": 0}'::jsonb, 'first', first, 'turn', first, 'done', false, '_secret', '{"seats": {}}'::jsonb);
  elsif m = 'rps' then
    return jsonb_build_object('mech', m, 'first', first, 'deadline_at', now() + interval '30 seconds', 'timeout', 30,
      'locked', '{}'::jsonb, 'target', 2, 'max_rounds', 20, 'series', private.series_wins(s.id, s.current_round),
      'done', false, '_secret', '{"seats": {}}'::jsonb);
  elsif m = 'nd_pig' then
    return jsonb_build_object('mech', m, 'first', first, 'turn', first, 'banked', '{"1": 0, "2": 0}'::jsonb,
      'turn_total', 0, 'rolls', '[]'::jsonb, 'target', 100, 'log', '[]'::jsonb, 'done', false, '_secret', '{"seats": {}}'::jsonb);
  elsif m = 'battleship' then
    return jsonb_build_object('mech', m, 'phase', 'placement', 'locked', '{}'::jsonb, 'shots', '{"1": [], "2": []}'::jsonb,
      'sunk', '{"1": [], "2": []}'::jsonb, 'ships', private.bn_ships(), 'done', false, '_secret', '{"seats": {}}'::jsonb);
  end if;
  raise exception 'unknown_mechanic';
end $$;

-- Fin de série : la manche courante devient la dernière (la partie se termine dans la même transaction).
create or replace function private.end_series_here(p_session uuid) returns void
language sql volatile security definer set search_path = '' as $$
  update public.game_sessions set total_rounds = current_round where id = p_session $$;

-- ---------------------------------------------------------------------------
-- Coups
-- ---------------------------------------------------------------------------
create or replace function private.board_apply6(m text, c jsonb, sec jsonb, seat int, typ text, p jsonb, p_session uuid) returns jsonb
language plpgsql volatile security definer set search_path = '' as $$
declare
  me text := seat::text;
  oth int := 3 - seat;
  rnd_no int;
  cell int;
  b jsonb;
  line jsonb;
  e text;
  box int;
  gained int := 0;
  g text;
  g2 text;
  w int;
  v int;
  fleet jsonb;
  ship jsonb;
  r int;
  col int;
  key text;
  hit_ship text;
  shots jsonb;
  n_hits int;
  ship_hits int;
begin
  select current_round into rnd_no from public.game_sessions where id = p_session;

  if m = 'tic_tac_toe' then
    if typ <> 'place' then perform private.mv('invalid_move'); end if;
    perform private.need_turn(c, seat);
    if jsonb_typeof(p -> 'cell') <> 'number' then perform private.mv('invalid_move'); end if;
    cell := (p ->> 'cell')::int;
    if cell < 0 or cell > 8 or (p ->> 'cell')::numeric <> cell then perform private.mv('invalid_move'); end if;
    b := c -> 'board';
    if (b ->> cell)::int <> 0 then perform private.mv('occupied'); end if;
    b := jsonb_set(b, array[cell::text], to_jsonb(seat));
    c := jsonb_set(c, '{board}', b);
    line := private.ttt_line(b);
    -- Alignement prioritaire sur le plateau plein (neuvième case gagnante).
    if line is not null then
      c := c || jsonb_build_object('done', true, 'winner', seat, 'line', line,
        'scores', jsonb_build_object(me, 1, oth::text, 0));
    elsif not exists (select 1 from jsonb_array_elements(b) x where x::int = 0) then
      c := c || jsonb_build_object('done', true, 'winner', 0, 'scores', '{"1": 0, "2": 0}'::jsonb);
    else
      c := jsonb_set(c, '{turn}', to_jsonb(oth));
    end if;
    if (c ->> 'done')::boolean then
      if coalesce((c #>> array['series', me])::int, 0) + (c #>> array['scores', me])::int >= (c ->> 'target')::int
         or rnd_no >= (c ->> 'max_rounds')::int then
        perform private.end_series_here(p_session);
        c := c || jsonb_build_object('series_over', true);
      end if;
    end if;
    return private.res(c, sec);

  elsif m = 'dots_boxes' then
    if typ <> 'draw_edge' then perform private.mv('invalid_move'); end if;
    perform private.need_turn(c, seat);
    e := p ->> 'edge_id';
    if not private.db_edge_ok(e) then perform private.mv('invalid_move'); end if;
    if c -> 'edges' ? e then perform private.mv('edge_taken'); end if;
    c := jsonb_set(c, array['edges', e], to_jsonb(seat));
    foreach box in array private.db_boxes(e) loop
      if (c #>> array['owner', box::text])::int = 0 and private.db_count(c -> 'edges', box) = 4 then
        c := jsonb_set(c, array['owner', box::text], to_jsonb(seat));
        gained := gained + 1;
      end if;
    end loop;
    c := jsonb_set(c, array['tally', me], to_jsonb((c #>> array['tally', me])::int + gained));
    if not exists (select 1 from jsonb_array_elements(c -> 'owner') x where x::int = 0) then
      c := c || jsonb_build_object('done', true, 'scores', c -> 'tally',
        'winner', case when (c #>> '{tally,1}')::int > (c #>> '{tally,2}')::int then 1
                       when (c #>> '{tally,2}')::int > (c #>> '{tally,1}')::int then 2 else 0 end);
    elsif gained = 0 then
      c := jsonb_set(c, '{turn}', to_jsonb(oth));
    end if;
    return private.res(c, sec, jsonb_build_object('gained', gained));

  elsif m = 'rps' then
    -- Échéance passée sans les deux gestes : manche annulée, aucun geste isolé révélé, zéro point.
    if now() > (c ->> 'deadline_at')::timestamptz and typ in ('lock_gesture', 'expire') then
      c := c || jsonb_build_object('done', true, 'void', true, 'locked', '{}'::jsonb, 'scores', '{"1": 0, "2": 0}'::jsonb);
      sec := '{"seats": {}}';
      if rnd_no >= (c ->> 'max_rounds')::int then
        perform private.end_series_here(p_session);
        c := c || '{"series_over": true, "shortened": true}';
      end if;
      return private.res(c, sec);
    end if;
    if typ = 'expire' then perform private.mv('too_early'); end if;
    if typ <> 'lock_gesture' then perform private.mv('invalid_move'); end if;
    g := p ->> 'gesture';
    if g is null or g not in ('rock', 'paper', 'scissors') then perform private.mv('invalid_move'); end if;
    if c -> 'locked' ? me then perform private.mv('locked'); end if;
    sec := jsonb_set(sec, '{seats}', coalesce(sec -> 'seats', '{}') || jsonb_build_object(me, jsonb_build_object('gesture', g)));
    c := jsonb_set(c, array['locked', me], 'true');
    if c -> 'locked' ? oth::text then
      g2 := sec #>> array['seats', oth::text, 'gesture'];
      w := case when g = g2 then 0
                when (g = 'rock' and g2 = 'scissors') or (g = 'scissors' and g2 = 'paper') or (g = 'paper' and g2 = 'rock') then seat
                else oth end;
      c := c || jsonb_build_object('done', true, 'winner', w,
        'gestures', jsonb_build_object(me, g, oth::text, g2),
        'scores', jsonb_build_object(me, case when w = seat then 1 else 0 end, oth::text, case when w = oth then 1 else 0 end));
      if (w > 0 and coalesce((c #>> array['series', w::text])::int, 0) + 1 >= (c ->> 'target')::int) then
        perform private.end_series_here(p_session);
        c := c || '{"series_over": true}';
      elsif rnd_no >= (c ->> 'max_rounds')::int then
        perform private.end_series_here(p_session);
        c := c || '{"series_over": true, "shortened": true}';
      end if;
    end if;
    return private.res(c, sec);

  elsif m = 'nd_pig' then
    perform private.need_turn(c, seat);
    if typ = 'roll' then
      v := 1 + private.rnd(6);
      c := c || jsonb_build_object('die', v, 'die_seat', seat,
        'log', (jsonb_build_array(jsonb_build_object('seat', seat, 'die', v)) || (c -> 'log')) - 8);
      if v = 1 then
        c := c || jsonb_build_object('turn_total', 0, 'rolls', '[]'::jsonb, 'turn', oth, 'bust', true);
      else
        c := c || jsonb_build_object('turn_total', (c ->> 'turn_total')::int + v, 'rolls', (c -> 'rolls') || to_jsonb(v), 'bust', false);
      end if;
      return private.res(c, sec, jsonb_build_object('die', v));
    elsif typ = 'hold' then
      if (c ->> 'turn_total')::int <= 0 then perform private.mv('nothing_to_hold'); end if;
      v := (c #>> array['banked', me])::int + (c ->> 'turn_total')::int;
      c := jsonb_set(c, array['banked', me], to_jsonb(v));
      c := c || jsonb_build_object('turn_total', 0, 'rolls', '[]'::jsonb, 'bust', false, 'die', null,
        'log', (jsonb_build_array(jsonb_build_object('seat', seat, 'hold', v)) || (c -> 'log')) - 8);
      if v >= (c ->> 'target')::int then
        c := c || jsonb_build_object('done', true, 'winner', seat, 'scores', c -> 'banked');
      else
        c := jsonb_set(c, '{turn}', to_jsonb(oth));
      end if;
      return private.res(c, sec);
    end if;
    perform private.mv('invalid_move');

  elsif m = 'battleship' then
    if typ in ('set_fleet', 'random_fleet', 'lock_fleet') then
      if c ->> 'phase' <> 'placement' then perform private.mv('phase'); end if;
      if c -> 'locked' ? me then perform private.mv('locked'); end if;
      if typ = 'set_fleet' then
        fleet := private.bn_check(p -> 'ships');
      elsif typ = 'random_fleet' then
        fleet := private.bn_random();
      else
        fleet := sec #> array['seats', me, 'fleet'];
        if fleet is null then perform private.mv('placement'); end if;
      end if;
      sec := jsonb_set(sec, '{seats}', coalesce(sec -> 'seats', '{}') || jsonb_build_object(me, jsonb_build_object('fleet', fleet)));
      if typ = 'lock_fleet' then
        c := jsonb_set(c, array['locked', me], 'true');
        if c -> 'locked' ? oth::text then
          c := c || jsonb_build_object('phase', 'fire', 'turn', 1 + private.rnd(2));
          c := c || jsonb_build_object('first', (c ->> 'turn')::int);
        end if;
      end if;
      return private.res(c, sec);
    elsif typ = 'fire' then
      if c ->> 'phase' <> 'fire' then perform private.mv('phase'); end if;
      perform private.need_turn(c, seat);
      if jsonb_typeof(p -> 'row') <> 'number' or jsonb_typeof(p -> 'col') <> 'number' then perform private.mv('invalid_move'); end if;
      r := (p ->> 'row')::int; col := (p ->> 'col')::int;
      if r < 0 or r > 9 or col < 0 or col > 9 then perform private.mv('invalid_move'); end if;
      shots := c #> array['shots', me];
      if exists (select 1 from jsonb_array_elements(shots) x where (x ->> 'r')::int = r and (x ->> 'c')::int = col) then
        perform private.mv('repeat_cell');
      end if;
      key := r || ':' || col;
      hit_ship := null;
      for ship in select * from jsonb_array_elements(sec #> array['seats', oth::text, 'fleet']) loop
        if key = any(private.bn_cells((ship ->> 'r')::int, (ship ->> 'c')::int, ship ->> 'o', (ship ->> 'len')::int)) then
          hit_ship := ship ->> 'id';
          exit;
        end if;
      end loop;
      if hit_ship is null then
        shots := shots || jsonb_build_array(jsonb_build_object('r', r, 'c', col, 'res', 'miss'));
      else
        shots := shots || jsonb_build_array(jsonb_build_object('r', r, 'c', col, 'res', 'hit', 'ship', hit_ship));
        select count(*) into ship_hits from jsonb_array_elements(shots) x where x ->> 'ship' = hit_ship;
        if ship_hits = (select (s2 ->> 'len')::int from jsonb_array_elements(private.bn_ships()) s2 where s2 ->> 'id' = hit_ship) then
          -- Coulé : on annonce son identité et on marque ses cases déjà atteintes (aucune autre coordonnée envoyée).
          shots := (select jsonb_agg(case when x ->> 'ship' = hit_ship then x || '{"res": "sunk"}' else x end order by o)
                    from jsonb_array_elements(shots) with ordinality t(x, o));
          c := jsonb_set(c, array['sunk', me], (c #> array['sunk', me]) || to_jsonb(hit_ship));
        end if;
      end if;
      c := jsonb_set(c, array['shots', me], shots);
      select count(*) into n_hits from jsonb_array_elements(shots) x where x ->> 'res' <> 'miss';
      if n_hits >= 17 then
        c := c || jsonb_build_object('done', true, 'winner', seat, 'scores', jsonb_build_object(
          '1', jsonb_array_length(c #> '{sunk,1}'), '2', jsonb_array_length(c #> '{sunk,2}')));
      else
        c := jsonb_set(c, '{turn}', to_jsonb(oth));
      end if;
      return private.res(c, sec, jsonb_build_object('res', shots -> -1 -> 'res', 'ship', hit_ship));
    end if;
    perform private.mv('invalid_move');
  end if;
  perform private.mv('invalid_move');
  return null;
end $$;

-- ---------------------------------------------------------------------------
-- Partenaire automatique de test (comptes listés dans private.test_autoplayers uniquement)
-- ---------------------------------------------------------------------------
create or replace function private.board_bot6(m text, c jsonb, sec jsonb, seat int) returns jsonb
language plpgsql volatile security definer set search_path = '' as $$
declare
  me text := seat::text;
  oth int := 3 - seat;
  b jsonb := c -> 'board';
  l int[];
  who int;
  i int;
  e text;
  cand text[];
  safe text[];
  box int;
  ok boolean;
  hits jsonb;
  x jsonb;
  r int; col int;
  tried text[];
begin
  if coalesce((c ->> 'done')::boolean, false) then return null; end if;
  if m = 'tic_tac_toe' then
    if (c ->> 'turn')::int <> seat then return null; end if;
    -- Gagner, sinon bloquer, sinon le centre, sinon une case libre.
    foreach who in array array[seat, oth] loop
      foreach l slice 1 in array array[[0,1,2],[3,4,5],[6,7,8],[0,3,6],[1,4,7],[2,5,8],[0,4,8],[2,4,6]] loop
        if (select count(*) from unnest(l) k where (b ->> k)::int = who) = 2 then
          select k into i from unnest(l) k where (b ->> k)::int = 0;
          if i is not null then return jsonb_build_object('type', 'place', 'payload', jsonb_build_object('cell', i)); end if;
        end if;
      end loop;
    end loop;
    if (b ->> 4)::int = 0 then return '{"type": "place", "payload": {"cell": 4}}'; end if;
    select k into i from generate_series(0, 8) k where (b ->> k)::int = 0 order by random() limit 1;
    return jsonb_build_object('type', 'place', 'payload', jsonb_build_object('cell', i));
  elsif m = 'dots_boxes' then
    if (c ->> 'turn')::int <> seat then return null; end if;
    select array_agg(t.eid) into cand from (
      select 'h:' || r2 || ':' || c2 as eid from generate_series(0, 4) r2, generate_series(0, 3) c2
      union all select 'v:' || r2 || ':' || c2 from generate_series(0, 3) r2, generate_series(0, 4) c2) t
      where not (c -> 'edges' ? t.eid);
    safe := '{}';
    foreach e in array cand loop
      ok := true;
      foreach box in array private.db_boxes(e) loop
        if private.db_count(c -> 'edges', box) = 3 then
          return jsonb_build_object('type', 'draw_edge', 'payload', jsonb_build_object('edge_id', e));
        end if;
        if private.db_count(c -> 'edges', box) = 2 then ok := false; end if;
      end loop;
      if ok then safe := safe || e; end if;
    end loop;
    if cardinality(safe) > 0 then cand := safe; end if;
    return jsonb_build_object('type', 'draw_edge', 'payload', jsonb_build_object('edge_id', cand[1 + private.rnd(cardinality(cand))]));
  elsif m = 'rps' then
    if c -> 'locked' ? me then return null; end if;
    return jsonb_build_object('type', 'lock_gesture', 'payload',
      jsonb_build_object('gesture', (array['rock', 'paper', 'scissors'])[1 + private.rnd(3)]));
  elsif m = 'nd_pig' then
    if (c ->> 'turn')::int <> seat then return null; end if;
    if (c ->> 'turn_total')::int > 0 and ((c ->> 'turn_total')::int >= 20
        or (c #>> array['banked', me])::int + (c ->> 'turn_total')::int >= 100) then
      return '{"type": "hold"}';
    end if;
    return '{"type": "roll"}';
  elsif m = 'battleship' then
    if c ->> 'phase' = 'placement' then
      if c -> 'locked' ? me then return null; end if;
      if sec #> array['seats', me, 'fleet'] is null then return '{"type": "random_fleet"}'; end if;
      return '{"type": "lock_fleet"}';
    end if;
    if (c ->> 'turn')::int <> seat then return null; end if;
    select array_agg((x2 ->> 'r') || ':' || (x2 ->> 'c')) into tried from jsonb_array_elements(c #> array['shots', me]) x2;
    tried := coalesce(tried, '{}');
    -- Viser autour d'un touché non coulé, sinon au hasard.
    for x in select * from jsonb_array_elements(c #> array['shots', me]) loop
      if x ->> 'res' = 'hit' then
        for r, col in select (x ->> 'r')::int + d.dr, (x ->> 'c')::int + d.dc
                      from (values (-1, 0), (1, 0), (0, -1), (0, 1)) d(dr, dc) loop
          if r between 0 and 9 and col between 0 and 9 and not ((r || ':' || col) = any(tried)) then
            return jsonb_build_object('type', 'fire', 'payload', jsonb_build_object('row', r, 'col', col));
          end if;
        end loop;
      end if;
    end loop;
    select rr, cc into r, col from generate_series(0, 9) rr, generate_series(0, 9) cc
      where not ((rr || ':' || cc) = any(tried)) order by random() limit 1;
    return jsonb_build_object('type', 'fire', 'payload', jsonb_build_object('row', r, 'col', col));
  end if;
  return null;
end $$;

-- ---------------------------------------------------------------------------
-- Aiguillage : la famille 6 rejoint les familles 2 à 5.
-- ---------------------------------------------------------------------------
create or replace function private.board_setup_any(s public.game_sessions, cfg jsonb) returns jsonb
language plpgsql volatile security definer set search_path = '' as $$
begin
  if cfg ->> 'mechanic' = any(private.board_route6()) then return private.board_setup6(s, cfg); end if;
  if cfg ->> 'mechanic' = any(private.board_route5()) then return private.board_setup5(s, cfg); end if;
  if cfg ->> 'mechanic' = any(private.board_route4()) then return private.board_setup4(s, cfg); end if;
  if cfg ->> 'mechanic' = any(private.board_route3()) then return private.board_setup3(s, cfg); end if;
  return private.board_setup(s, cfg);
end $$;

create or replace function private.board_apply_any(m text, c jsonb, sec jsonb, seat int, typ text, p jsonb, p_session uuid) returns jsonb
language plpgsql volatile security definer set search_path = '' as $$
begin
  if m = any(private.board_route6()) then return private.board_apply6(m, c, sec, seat, typ, p, p_session); end if;
  if m = any(private.board_route5()) then return private.board_apply5(m, c, sec, seat, typ, p, p_session); end if;
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
  if m = any(private.board_route6()) then return private.board_bot6(m, c, sec, seat); end if;
  if m = any(private.board_route5()) then return private.board_bot5(m, c, sec, seat); end if;
  if m = any(private.board_route4()) then return private.board_bot4(m, c, sec, seat); end if;
  if m = any(private.board_route3()) then return private.board_bot3(m, c, sec, seat); end if;
  return private.board_bot(m, c, sec, seat);
end $$;

-- ---------------------------------------------------------------------------
-- Coup joué : la fin de partie relit le nombre de manches (une série peut se terminer avant le maximum).
-- ---------------------------------------------------------------------------
create or replace function public.play_move(p_session uuid, p_round int, p_action uuid, p_type text, p_payload jsonb default '{}')
returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  r record;
  cfg jsonb;
  rd public.session_rounds;
  sec jsonb;
  res jsonb;
  new_card jsonb;
  last_round int;
begin
  select * into r from private.lock_session(p_session);
  if p_action is null or p_type is null or char_length(p_type) > 20 then
    return jsonb_build_object('ok', false, 'error', 'invalid_move');
  end if;
  if exists (select 1 from private.board_moves where action_id = p_action) then
    return jsonb_build_object('ok', true, 'repeated', true);
  end if;
  if (r.s).status = 'paused' then return jsonb_build_object('ok', false, 'error', 'paused'); end if;
  if (r.s).status <> 'playing' then return jsonb_build_object('ok', false, 'error', 'not_playing'); end if;
  cfg := private.version_config(r.s);
  if cfg ->> 'engine' is distinct from 'board' then return jsonb_build_object('ok', false, 'error', 'not_allowed'); end if;
  if p_round <> (r.s).current_round then return jsonb_build_object('ok', false, 'error', 'stale_round'); end if;
  select * into rd from public.session_rounds where session_id = p_session and round_no = p_round;
  if rd.session_id is null then return jsonb_build_object('ok', false, 'error', 'stale_round'); end if;
  if rd.revealed_at is not null or coalesce((rd.card ->> 'done')::boolean, false) then
    return jsonb_build_object('ok', false, 'error', 'round_over');
  end if;
  select secret into sec from private.round_secrets where session_id = p_session and round_no = p_round;

  begin
    res := private.board_apply_any(cfg ->> 'mechanic', rd.card, coalesce(sec, '{}'), r.seat, p_type,
                               coalesce(p_payload, '{}'), p_session);
  exception when raise_exception then
    if sqlerrm like 'move:%' then
      return jsonb_build_object('ok', false, 'error', substr(sqlerrm, 6));
    end if;
    raise;
  end;

  new_card := (res -> 'card') || jsonb_build_object('rev', coalesce((rd.card ->> 'rev')::int, 0) + 1,
                                                    'last', jsonb_build_object('seat', r.seat, 'type', p_type));
  insert into private.board_moves (action_id, session_id, round_no, seat, type, payload)
    values (p_action, p_session, p_round, r.seat, p_type, p_payload);
  update public.session_rounds set card = new_card,
    revealed_at = case when coalesce((new_card ->> 'done')::boolean, false) then now() end
    where session_id = p_session and round_no = p_round;
  update private.round_secrets set secret = res -> 'secret' where session_id = p_session and round_no = p_round;
  select total_rounds into last_round from public.game_sessions where id = p_session;
  if coalesce((new_card ->> 'done')::boolean, false) and p_round >= last_round then
    update public.game_sessions set status = 'ended', ended_at = now(), result = private.compute_result(r.s, cfg)
      where id = p_session;
  end if;
  perform private.bump_session(p_session, case when (new_card ->> 'done')::boolean then 'revealed' else 'move' end);
  return jsonb_build_object('ok', true, 'info', res -> 'info');
end $$;

grant execute on function public.play_move(uuid, int, uuid, text, jsonb) to authenticated;
