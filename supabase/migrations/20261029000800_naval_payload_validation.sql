-- Validation des nouveaux coups de Bataille navale (audit serveur du 25/10/2026).
-- Défauts reproduits via public.play_move : orientation absente acceptée (navire hors grille
-- impossible à couler), tir sans coordonnées enregistré et tour consommé.
-- Aucun changement des règles, flottes déjà enregistrées, scores ou versions de partie.
-- Dépendances : moteur lot 2 (20261025000100). Les autres branches de board_apply6
-- sont reprises à l'identique ; seules les coordonnées de fire sont validées plus strictement.

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
  if jsonb_typeof(ships) is distinct from 'array' then perform private.mv('placement'); end if;
  if jsonb_array_length(ships) <> 5
     or exists (select 1 from jsonb_array_elements(ships) x where jsonb_typeof(x) is distinct from 'object') then
    perform private.mv('placement');
  end if;
  for m in select * from jsonb_array_elements(model) loop
    select x into s from jsonb_array_elements(ships) x where x ->> 'id' = m ->> 'id';
    if s is null then perform private.mv('placement'); end if;
    -- Les valeurs JSON absentes/nulles, chaînes et fractions ne sont pas des coordonnées.
    -- Vérifier en numeric avant de convertir en int évite aussi un dépassement d'entier.
    if jsonb_typeof(s -> 'start_row') is distinct from 'number'
       or jsonb_typeof(s -> 'start_col') is distinct from 'number' then
      perform private.mv('placement');
    end if;
    if (s ->> 'start_row')::numeric not between 0 and 9
       or (s ->> 'start_col')::numeric not between 0 and 9
       or (s ->> 'start_row')::numeric <> trunc((s ->> 'start_row')::numeric)
       or (s ->> 'start_col')::numeric <> trunc((s ->> 'start_col')::numeric) then
      perform private.mv('placement');
    end if;
    r := (s ->> 'start_row')::numeric::int; c := (s ->> 'start_col')::numeric::int;
    o := s ->> 'orientation'; len := (m ->> 'len')::int;
    if o is null or o not in ('H', 'V')
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
      if jsonb_typeof(p -> 'row') is distinct from 'number'
         or jsonb_typeof(p -> 'col') is distinct from 'number' then
        perform private.mv('invalid_move');
      end if;
      if (p ->> 'row')::numeric not between 0 and 9 or (p ->> 'col')::numeric not between 0 and 9
         or (p ->> 'row')::numeric <> trunc((p ->> 'row')::numeric)
         or (p ->> 'col')::numeric <> trunc((p ->> 'col')::numeric) then
        perform private.mv('invalid_move');
      end if;
      r := (p ->> 'row')::numeric::int; col := (p ->> 'col')::numeric::int;
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
