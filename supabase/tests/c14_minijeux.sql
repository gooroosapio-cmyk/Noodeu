-- Tests des mini-jeux du lot 2 (Morpion, Points et carrés, Pierre-feuille-ciseaux, Dé chanceux, Bataille navale) :
-- cas d'acceptation du kit C03/C04 V1, idempotence, secrets. Transaction annulée à la fin : aucune donnée ne reste.
begin;

create schema t8;
create function t8.as_user(p uuid) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', json_build_object('sub', p, 'role', 'authenticated')::text, true);
end $$;
create function t8.ok(cond boolean, msg text) returns void language plpgsql as $$
begin
  if cond is distinct from true then raise exception 'ÉCHEC : %', msg; end if;
end $$;
create function t8.err(res jsonb, expected text, msg text) returns void language plpgsql as $$
begin
  if res ->> 'error' is distinct from expected then raise exception 'ÉCHEC : % (attendu %, obtenu %)', msg, expected, res; end if;
end $$;
create function t8.card(s uuid) returns jsonb language sql as $$
  select card from public.session_rounds r join public.game_sessions g on g.id = r.session_id and r.round_no = g.current_round where g.id = s $$;
create function t8.uid(s uuid, seat int) returns uuid language sql as $$
  select user_id from public.session_players where session_id = s and seat = $2 $$;
-- Joue au nom d'un siège donné.
create function t8.mv(s uuid, seat int, typ text, p jsonb default '{}', act uuid default gen_random_uuid()) returns jsonb language plpgsql as $$
begin
  perform t8.as_user(t8.uid(s, seat));
  return public.play_move(s, (select current_round from public.game_sessions where id = s), act, typ, p);
end $$;
-- Joue au nom de la personne dont c'est le tour.
create function t8.turn(s uuid, typ text, p jsonb default '{}') returns jsonb language sql as $$
  select t8.mv(s, (t8.card(s) ->> 'turn')::int, typ, p) $$;
create function t8.start(gid text, settings jsonb default null) returns uuid language plpgsql as $$
declare s uuid;
begin
  update public.game_sessions set status = 'abandoned' where status in ('lobby', 'playing', 'paused', 'ended');
  perform t8.as_user('00000000-0000-4000-a000-0000000000a8');
  s := (public.create_session(gid) ->> 'session_id')::uuid;
  if settings is not null then perform public.update_session_settings(s, settings); end if;
  perform public.set_ready(s, true);
  perform t8.as_user('00000000-0000-4000-a000-0000000000b8');
  perform public.set_ready(s, true);
  return s;
end $$;

insert into auth.users (id, email, raw_user_meta_data) values
  ('00000000-0000-4000-a000-0000000000a8', 'joueur-a8@noodeu.invalid', '{"display_name":"A"}'),
  ('00000000-0000-4000-a000-0000000000b8', 'joueur-b8@noodeu.invalid', '{"display_name":"B"}');
do $$
declare r jsonb;
begin
  perform t8.as_user('00000000-0000-4000-a000-0000000000a8');
  r := public.create_invitation();
  perform t8.as_user('00000000-0000-4000-a000-0000000000b8');
  perform public.claim_invitation(r ->> 'code');
  perform t8.as_user('00000000-0000-4000-a000-0000000000a8');
  perform public.respond_to_claim((r ->> 'id')::uuid, true);
end $$;

-- ===== Catalogue =====================================================================
do $$ begin
  perform t8.ok((select count(*) from public.games where id in ('N2-076', 'N2-079', 'N2-083', 'nd-de-chanceux', 'N2-078')
                 and implementation = 'playable' and current_version is not null) = 5, '5 mini-jeux jouables');
end $$;

-- ===== M01 Morpion ===================================================================
do $$
declare s uuid; c jsonb; x int; res jsonb; act uuid := gen_random_uuid();
begin
  s := t8.start('N2-076');
  c := t8.card(s);
  perform t8.ok((select total_rounds from public.game_sessions where id = s) = 12, 'série plafonnée à 12 manches');
  perform t8.ok(c ->> 'x_seat' = c ->> 'turn' and c ->> 'first' = c ->> 'turn', 'X au premier joueur tiré');
  x := (c ->> 'turn')::int;
  -- Hors tour : refusé.
  perform t8.err(t8.mv(s, 3 - x, 'place', '{"cell": 0}'), 'not_your_turn', 'coup hors tour');
  perform t8.ok((t8.turn(s, 'place', '{"cell": 4}') ->> 'ok')::boolean, 'pose valide');
  -- Case occupée : refusée sans consommer le tour.
  perform t8.err(t8.turn(s, 'place', '{"cell": 4}'), 'occupied', 'case occupée');
  perform t8.ok((t8.card(s) ->> 'turn')::int = 3 - x, 'tour conservé après refus');
  perform t8.err(t8.turn(s, 'place', '{"cell": 9}'), 'invalid_move', 'hors plateau');
  -- Idempotence : même action rejouée = un seul effet.
  perform t8.turn(s, 'place', '{"cell": 0}');
  res := t8.mv(s, x, 'place', '{"cell": 1}', act);
  perform t8.ok((t8.mv(s, x, 'place', '{"cell": 1}', act) ->> 'repeated')::boolean, 'action rejouée reconnue');
  perform t8.ok((t8.card(s) ->> 'turn')::int = 3 - x, 'pas de second coup');
  -- O : 0 ; X : 4, 1 → X joue 7 : colonne 1-4-7.
  perform t8.turn(s, 'place', '{"cell": 2}');
  perform t8.turn(s, 'place', '{"cell": 7}');
  c := t8.card(s);
  perform t8.ok((c ->> 'done')::boolean and (c ->> 'winner')::int = x and c -> 'line' = '[1, 4, 7]', 'victoire immédiate en colonne');
  perform t8.ok((select status from public.game_sessions where id = s) = 'ended', 'série à 1 victoire terminée');
  perform t8.ok((select result #>> array['points', x::text] from public.game_sessions where id = s)::int = 1, 'bilan : 1 victoire');
  perform t8.err(t8.mv(s, 3 - x, 'place', '{"cell": 8}'), 'not_playing', 'coup après fin refusé');
end $$;

-- Neuvième case gagnante : victoire prioritaire sur la nulle ; série en 2 victoires, premier joueur alterné.
do $$
declare s uuid; c jsonb; x int; k int;
begin
  s := t8.start('N2-076', '{"series_wins": 2}');
  x := (t8.card(s) ->> 'turn')::int;
  foreach k in array array[0, 1, 2, 3, 4, 5, 7, 6, 8] loop
    perform t8.turn(s, 'place', jsonb_build_object('cell', k));
  end loop;
  c := t8.card(s);
  perform t8.ok((c ->> 'done')::boolean and (c ->> 'winner')::int = x and c -> 'line' = '[0, 4, 8]', 'neuvième case gagnante, pas de nulle');
  perform t8.ok((select status from public.game_sessions where id = s) = 'playing', 'série en 2 victoires continue');
  perform t8.as_user(t8.uid(s, 1));
  perform public.next_round(s, 1);
  c := t8.card(s);
  perform t8.ok((c ->> 'turn')::int = 3 - x and (c #>> array['series', x::text])::int = 1, 'premier joueur alterné, série reportée');
  -- Manche nulle : 0 chacun.
  foreach k in array array[0, 1, 2, 4, 3, 5, 7, 6, 8] loop
    perform t8.turn(s, 'place', jsonb_build_object('cell', k));
  end loop;
  c := t8.card(s);
  perform t8.ok((c ->> 'done')::boolean and (c ->> 'winner')::int = 0 and c -> 'scores' = '{"1": 0, "2": 0}', 'nulle à 0 chacun');
end $$;

-- ===== M04 Points et carrés ==========================================================
do $$
declare s uuid; c jsonb; p int; e text; res jsonb; n int := 0;
begin
  s := t8.start('N2-079');
  p := (t8.card(s) ->> 'turn')::int;
  perform t8.err(t8.turn(s, 'draw_edge', '{"edge_id": "h:5:0"}'), 'invalid_move', 'arête hors plateau');
  perform t8.err(t8.turn(s, 'draw_edge', '{"edge_id": "d:0:0"}'), 'invalid_move', 'diagonale refusée');
  -- Aucune case fermée : le tour passe.
  perform t8.turn(s, 'draw_edge', '{"edge_id": "h:0:0"}');
  perform t8.ok((t8.card(s) ->> 'turn')::int = 3 - p, 'tour passé sans capture');
  perform t8.err(t8.turn(s, 'draw_edge', '{"edge_id": "h:0:0"}'), 'edge_taken', 'arête déjà tracée');
  perform t8.ok((t8.card(s) ->> 'turn')::int = 3 - p, 'tour conservé après refus');
  -- Préparer deux cases (0 et 1) à trois côtés chacune, partageant v:0:1.
  foreach e in array array['h:1:0', 'v:0:0', 'h:0:1', 'h:1:1', 'v:0:2'] loop
    perform t8.turn(s, 'draw_edge', jsonb_build_object('edge_id', e));
  end loop;
  p := (t8.card(s) ->> 'turn')::int;
  res := t8.turn(s, 'draw_edge', '{"edge_id": "v:0:1"}');
  c := t8.card(s);
  perform t8.ok((res #>> '{info,gained}')::int = 2 and (c #>> array['tally', p::text])::int = 2, 'arête centrale : +2');
  perform t8.ok((c ->> 'turn')::int = p, 'même joueur rejoue');
  -- Fermeture simple : +1 et rejoue.
  foreach e in array array['h:2:0', 'v:1:0'] loop perform t8.turn(s, 'draw_edge', jsonb_build_object('edge_id', e)); end loop;
  p := (t8.card(s) ->> 'turn')::int;
  perform t8.turn(s, 'draw_edge', '{"edge_id": "v:1:1"}');
  c := t8.card(s);
  perform t8.ok((c #>> array['owner', '4'])::int = p and (c ->> 'turn')::int = p, 'fermeture simple : +1 et rejoue');
  -- Fin de partie (robot des deux côtés) : 16 cases, somme des points = 16.
  while not coalesce((t8.card(s) ->> 'done')::boolean, false) and n < 60 loop
    perform t8.turn(s, (private.board_bot6('dots_boxes', t8.card(s), '{}', (t8.card(s) ->> 'turn')::int)) ->> 'type',
                    (private.board_bot6('dots_boxes', t8.card(s), '{}', (t8.card(s) ->> 'turn')::int)) -> 'payload');
    n := n + 1;
  end loop;
  c := t8.card(s);
  perform t8.ok((c #>> '{tally,1}')::int + (c #>> '{tally,2}')::int = 16, 'somme des points = 16');
  perform t8.ok((c ->> 'winner')::int = case when (c #>> '{tally,1}')::int > (c #>> '{tally,2}')::int then 1
                                             when (c #>> '{tally,1}')::int < (c #>> '{tally,2}')::int then 2 else 0 end, 'gagnant cohérent (8-8 = égalité)');
  perform t8.ok((select status from public.game_sessions where id = s) = 'ended', 'partie finie');
end $$;

-- ===== M11 Pierre, feuille, ciseaux ===================================================
do $$
declare s uuid; c jsonb; st jsonb; g1 text; g2 text; want int; pairs text[][] := array[
  ['rock','rock','0'],['rock','paper','2'],['rock','scissors','1'],['paper','rock','1'],['paper','paper','0'],
  ['paper','scissors','2'],['scissors','rock','2'],['scissors','paper','1'],['scissors','scissors','0']]; i int;
begin
  -- Matrice complète des neuf couples (une nouvelle partie à chaque couple).
  for i in 1..9 loop
    s := t8.start('N2-083');
    perform t8.mv(s, 1, 'lock_gesture', jsonb_build_object('gesture', pairs[i][1]));
    perform t8.mv(s, 2, 'lock_gesture', jsonb_build_object('gesture', pairs[i][2]));
    c := t8.card(s);
    perform t8.ok((c ->> 'winner')::int = pairs[i][3]::int, format('matrice %s contre %s', pairs[i][1], pairs[i][2]));
  end loop;
  -- Secret avant révélation, verrouillage, deux victoires.
  s := t8.start('N2-083');
  perform t8.ok((select total_rounds from public.game_sessions where id = s) = 20, 'plafond de 20 engagements');
  perform t8.mv(s, 1, 'lock_gesture', '{"gesture": "rock"}');
  perform t8.err(t8.mv(s, 1, 'lock_gesture', '{"gesture": "paper"}'), 'locked', 'changement après verrouillage refusé');
  perform t8.as_user(t8.uid(s, 2));
  st := public.get_session_state(s);
  perform t8.ok(position('rock' in (st -> 'rounds')::text) = 0 and coalesce(st #> '{rounds,0,private}', 'null') = 'null', 'geste adverse absent de l''état avant révélation');
  perform t8.as_user(t8.uid(s, 1));
  st := public.get_session_state(s);
  perform t8.ok(st #>> '{rounds,0,private,gesture}' = 'rock', 'son propre geste visible pour soi');
  perform t8.mv(s, 2, 'lock_gesture', '{"gesture": "scissors"}');
  perform t8.ok(t8.card(s) -> 'gestures' = '{"1": "rock", "2": "scissors"}', 'révélation commune');
  -- Échéance : une seule réponse → manche annulée sans dévoiler le geste isolé.
  perform t8.as_user(t8.uid(s, 1));
  perform public.next_round(s, 1);
  perform t8.mv(s, 2, 'lock_gesture', '{"gesture": "paper"}');
  perform t8.err(t8.mv(s, 1, 'expire'), 'too_early', 'pas d''annulation avant l''échéance');
  update public.session_rounds set card = card || jsonb_build_object('deadline_at', now() - interval '1 second')
    where session_id = s and round_no = 2;
  perform t8.mv(s, 1, 'expire');
  c := t8.card(s);
  perform t8.ok((c ->> 'done')::boolean and (c ->> 'void')::boolean and not (c ? 'gestures')
                and c -> 'scores' = '{"1": 0, "2": 0}', 'manche annulée, zéro point, aucun geste révélé');
  perform t8.as_user(t8.uid(s, 1));
  perform t8.ok(position('paper' in (public.get_session_state(s) -> 'rounds')::text) = 0, 'geste isolé jamais transmis');
  -- Deuxième victoire décisive : fin de partie.
  perform public.next_round(s, 2);
  perform t8.mv(s, 1, 'lock_gesture', '{"gesture": "paper"}');
  perform t8.mv(s, 2, 'lock_gesture', '{"gesture": "rock"}');
  perform t8.ok((select status from public.game_sessions where id = s) = 'ended', 'premier à 2 victoires : fin');
  perform t8.ok((select result #>> '{points,1}' from public.game_sessions where id = s)::int = 2, 'score final 2');
end $$;

-- ===== M12 Le Dé chanceux ============================================================
do $$
declare s uuid; c jsonb; p int; before jsonb; res jsonb; act uuid := gen_random_uuid(); n int := 0; busted boolean := false;
begin
  s := t8.start('nd-de-chanceux');
  perform t8.err(t8.turn(s, 'hold'), 'nothing_to_hold', 'S''arrêter sans provisoire refusé');
  -- Idempotence : le même lancer rejoué ne tire pas une seconde fois.
  p := (t8.card(s) ->> 'turn')::int;
  res := t8.mv(s, p, 'roll', '{}', act);
  before := t8.card(s);
  perform t8.ok((t8.mv(s, p, 'roll', '{}', act) ->> 'repeated')::boolean and t8.card(s) = before, 'pas de second tirage');
  -- Sur 1 : provisoire perdu, scores conservés intacts, main passée.
  while not busted and n < 300 loop
    c := t8.card(s);
    p := (c ->> 'turn')::int;
    update public.session_rounds set card = card || jsonb_build_object('turn_total', 12)
      where session_id = s and round_no = 1;
    before := t8.card(s);
    res := t8.mv(s, p, 'roll');
    c := t8.card(s);
    if (res #>> '{info,die}')::int = 1 then
      busted := true;
      perform t8.ok((c ->> 'turn_total')::int = 0 and c -> 'banked' = before -> 'banked' and (c ->> 'turn')::int = 3 - p,
                    'dé 1 : provisoire à 0, scores intacts, autre joueur');
    else
      perform t8.ok((c ->> 'turn_total')::int = 12 + (res #>> '{info,die}')::int and (c ->> 'turn')::int = p, 'cumul et même joueur');
    end if;
    n := n + 1;
  end loop;
  perform t8.ok(busted, 'un 1 est sorti');
  -- Score + provisoire ≥ 100 sans S'arrêter : pas de victoire automatique ; S'arrêter à 98 + 5 → 103 et victoire.
  p := (t8.card(s) ->> 'turn')::int;
  update public.session_rounds set card = card || jsonb_build_object('banked', jsonb_build_object(p::text, 98, (3 - p)::text, 0), 'turn_total', 5)
    where session_id = s and round_no = 1;
  perform t8.ok(not coalesce((t8.card(s) ->> 'done')::boolean, false), 'pas de victoire sans S''arrêter');
  perform t8.mv(s, p, 'hold');
  c := t8.card(s);
  perform t8.ok((c #>> array['banked', p::text])::int = 103 and (c ->> 'winner')::int = p and (c ->> 'done')::boolean, '98 + 5 → 103 et victoire');
  perform t8.ok((select status from public.game_sessions where id = s) = 'ended', 'partie finie immédiatement');
end $$;

-- ===== M07 Bataille navale ===========================================================
do $$
declare s uuid; c jsonb; st jsonb; fleet_b jsonb; cell text; p int; n int := 0; misses int := 0;
  overlap jsonb := '[{"id":"porte-avions","start_row":0,"start_col":0,"orientation":"H"},
                     {"id":"croiseur","start_row":0,"start_col":2,"orientation":"V"},
                     {"id":"contre-torpilleur","start_row":5,"start_col":0,"orientation":"H"},
                     {"id":"sous-marin","start_row":7,"start_col":0,"orientation":"H"},
                     {"id":"torpilleur","start_row":9,"start_col":0,"orientation":"H"}]';
  adjacent jsonb := '[{"id":"porte-avions","start_row":0,"start_col":0,"orientation":"H"},
                      {"id":"croiseur","start_row":1,"start_col":0,"orientation":"H"},
                      {"id":"contre-torpilleur","start_row":2,"start_col":0,"orientation":"H"},
                      {"id":"sous-marin","start_row":3,"start_col":0,"orientation":"H"},
                      {"id":"torpilleur","start_row":4,"start_col":0,"orientation":"H"}]';
begin
  s := t8.start('N2-078');
  perform t8.err(t8.mv(s, 1, 'set_fleet', jsonb_build_object('ships', overlap)), 'placement', 'flotte chevauchée refusée');
  perform t8.err(t8.mv(s, 1, 'lock_fleet'), 'placement', 'verrouiller sans flotte refusé');
  perform t8.err(t8.mv(s, 1, 'fire', '{"row": 0, "col": 0}'), 'phase', 'tir pendant le placement refusé');
  perform t8.ok((t8.mv(s, 1, 'set_fleet', jsonb_build_object('ships', adjacent)) ->> 'ok')::boolean, 'navires adjacents acceptés');
  perform t8.mv(s, 1, 'lock_fleet');
  perform t8.err(t8.mv(s, 1, 'random_fleet'), 'locked', 'pas de repositionnement après verrouillage');
  perform t8.mv(s, 2, 'random_fleet');
  perform t8.mv(s, 2, 'lock_fleet');
  c := t8.card(s);
  perform t8.ok(c ->> 'phase' = 'fire' and (c ->> 'turn')::int in (1, 2), 'deux flottes verrouillées : tirs, premier tireur tiré');
  -- Secret : l'état de A ne contient ni la flotte de B ni ses coordonnées.
  fleet_b := (select secret #> '{seats,2,fleet}' from private.round_secrets where session_id = s and round_no = 1);
  perform t8.as_user(t8.uid(s, 1));
  st := public.get_session_state(s);
  perform t8.ok(st #> '{rounds,0,private,fleet}' = (select secret #> '{seats,1,fleet}' from private.round_secrets where session_id = s and round_no = 1)
                and position(fleet_b::text in st::text) = 0 and not (st::text like '%"seats"%'), 'aucune coordonnée adverse transmise');
  -- B commence par un tir dans l'eau si c'est son tour (zone vide de la flotte de A : lignes 5 à 9, colonnes 5 à 9).
  if (t8.card(s) ->> 'turn')::int = 2 then perform t8.mv(s, 2, 'fire', '{"row": 9, "col": 9}'); misses := 1; end if;
  -- A vise chaque case de la flotte de B ; B tire dans l'eau entre deux.
  for cell in select unnest(private.bn_cells((x ->> 'r')::int, (x ->> 'c')::int, x ->> 'o', (x ->> 'len')::int))
              from jsonb_array_elements(fleet_b) x loop
    perform t8.mv(s, 1, 'fire', jsonb_build_object('row', split_part(cell, ':', 1)::int, 'col', split_part(cell, ':', 2)::int));
    n := n + 1;
    if n = 1 then
      perform t8.ok(t8.card(s) #>> '{shots,1,0,res}' in ('hit', 'sunk') and t8.card(s) #>> '{shots,1,0,ship}' is not null, 'touché : type du navire annoncé');
    end if;
    exit when coalesce((t8.card(s) ->> 'done')::boolean, false);
    -- Même case rejouée par B : refusée sans perte du tour.
    if misses = 1 and n = 1 then
      perform t8.err(t8.mv(s, 2, 'fire', '{"row": 9, "col": 9}'), 'repeat_cell', 'tir déjà joué refusé');
      perform t8.ok((t8.card(s) ->> 'turn')::int = 2, 'tour conservé');
    end if;
    perform t8.mv(s, 2, 'fire', jsonb_build_object('row', 5 + misses / 5, 'col', 5 + misses % 5));
    misses := misses + 1;
  end loop;
  c := t8.card(s);
  perform t8.ok((c ->> 'done')::boolean and (c ->> 'winner')::int = 1 and n = 17, '17e case : victoire unique');
  perform t8.ok(jsonb_array_length(c #> '{sunk,1}') = 5 and (c #>> '{scores,1}')::int = 5, 'cinq navires coulés');
  perform t8.ok((select status from public.game_sessions where id = s) = 'ended', 'partie finie');
  perform t8.as_user(t8.uid(s, 2));
  perform t8.ok(position((select secret #> '{seats,1,fleet}' from private.round_secrets where session_id = s and round_no = 1)::text
                in public.get_session_state(s)::text) = 0, 'flotte de A toujours secrète après la partie');
end $$;

-- ===== Partenaire automatique ========================================================
do $$
declare s uuid; m text; c jsonb; mv jsonb; seat int; n int;
begin
  foreach m in array array['N2-076', 'N2-079', 'N2-083', 'nd-de-chanceux', 'N2-078'] loop
    s := t8.start(m);
    n := 0;
    while (select status from public.game_sessions where id = s) = 'playing' and n < 600 loop
      c := t8.card(s);
      if (c ->> 'done')::boolean then
        perform t8.as_user(t8.uid(s, 1));
        perform public.next_round(s, (select current_round from public.game_sessions where id = s));
      else
        mv := null;
        foreach seat in array array[1, 2] loop
          mv := private.board_bot_any((select config ->> 'mechanic' from public.game_versions v join public.games g on g.id = v.game_id
                                       and v.version = g.current_version where g.id = m), c,
                                      (select secret from private.round_secrets where session_id = s
                                       and round_no = (select current_round from public.game_sessions where id = s)), seat);
          if mv is not null then
            perform t8.ok((t8.mv(s, seat, mv ->> 'type', coalesce(mv -> 'payload', '{}')) ->> 'ok')::boolean, format('coup du robot accepté (%s)', m));
            exit;
          end if;
        end loop;
      end if;
      n := n + 1;
    end loop;
    perform t8.ok((select status from public.game_sessions where id = s) = 'ended', format('robot : partie %s menée à son terme', m));
  end loop;
end $$;

select 'TOUS LES TESTS MINI-JEUX (LOT 2) SONT PASSÉS';
rollback;
