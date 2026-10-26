-- Régression des entrées navales malformées, via public.play_move.
-- À exécuter uniquement sur les bases Docker jetables autorisées. Tout est annulé.
begin;
do $$ begin
  if current_database() not in ('noodeu_lot6_clean_2154', 'noodeu') and not (
    current_database() ~ '^noodeu_server_[a-zA-Z0-9_]+$' and coalesce((
      select shobj_description(oid, 'pg_database') from pg_database where datname = current_database()
    ), '') = 'noodeu:disposable-local-sql-test'
  ) then
    raise exception 'Base de test jetable attendue';
  end if;
end $$;

create schema t29;
create function t29.ok(cond boolean, msg text) returns void language plpgsql as $$
begin if cond is distinct from true then raise exception 'ÉCHEC : %', msg; end if; end $$;
create function t29.as_user(p uuid) returns void language plpgsql as $$
begin perform set_config('request.jwt.claims', json_build_object('sub', p, 'role', 'authenticated')::text, true); end $$;
create function t29.uid(s uuid, seat int) returns uuid language sql as $$
  select user_id from public.session_players where session_id = s and seat = $2 $$;
create function t29.card(s uuid) returns jsonb language sql as $$
  select card from public.session_rounds where session_id = s and round_no = 1 $$;
create function t29.sec(s uuid) returns jsonb language sql as $$
  select secret from private.round_secrets where session_id = s and round_no = 1 $$;
create function t29.mv(s uuid, seat int, typ text, p jsonb default '{}', act uuid default gen_random_uuid())
returns jsonb language plpgsql as $$
begin
  perform t29.as_user(t29.uid(s, seat));
  return public.play_move(s, 1, act, typ, p);
end $$;
create function t29.reject(s uuid, seat int, typ text, p jsonb, expected text) returns void language plpgsql as $$
declare c jsonb := t29.card(s); sec jsonb := t29.sec(s); r jsonb; v bigint; n bigint;
begin
  select state_version into v from public.game_sessions where id = s;
  select count(*) into n from private.board_moves where session_id = s;
  r := t29.mv(s, seat, typ, p);
  perform t29.ok(r ->> 'error' = expected, format('%s %s refusé : %s', typ, p, r));
  perform t29.ok(t29.card(s) = c and t29.sec(s) = sec, 'aucun changement de carte, tour ou secret après refus');
  perform t29.ok((select state_version = v from public.game_sessions where id = s), 'version inchangée après refus');
  perform t29.ok((select count(*) = n from private.board_moves where session_id = s), 'aucun coup enregistré après refus');
end $$;

insert into auth.users(id, email, raw_user_meta_data) values
  ('00000000-0000-4000-a000-000000000029', 'naval-a29@noodeu.invalid', '{"display_name":"A"}'),
  ('00000000-0000-4000-a000-000000000129', 'naval-b29@noodeu.invalid', '{"display_name":"B"}');
do $$
declare r jsonb;
begin
  perform t29.as_user('00000000-0000-4000-a000-000000000029');
  r := public.create_invitation();
  perform t29.as_user('00000000-0000-4000-a000-000000000129');
  perform public.claim_invitation(r ->> 'code');
  perform t29.as_user('00000000-0000-4000-a000-000000000029');
  perform public.respond_to_claim((r ->> 'id')::uuid, true);
end $$;

do $$
declare
  s uuid; r jsonb; c jsonb; st jsonb; f jsonb; f2 jsonb; bad jsonb; v jsonb; k text;
  shooter int; act uuid; prior jsonb; n int; shot_row int; shot_col int;
  fleet jsonb := '[{"id":"porte-avions","start_row":0,"start_col":0,"orientation":"H"},
    {"id":"croiseur","start_row":1,"start_col":0,"orientation":"H"},
    {"id":"contre-torpilleur","start_row":2,"start_col":0,"orientation":"H"},
    {"id":"sous-marin","start_row":3,"start_col":0,"orientation":"H"},
    {"id":"torpilleur","start_row":4,"start_col":0,"orientation":"H"}]';
begin
  perform t29.as_user('00000000-0000-4000-a000-000000000029');
  s := (public.create_session('N2-078') ->> 'session_id')::uuid;
  perform public.set_ready(s, true);
  perform t29.as_user('00000000-0000-4000-a000-000000000129');
  perform public.set_ready(s, true);

  -- Le défaut initial permettait un navire vertical implicite sur les lignes 9 à 13.
  bad := jsonb_set(fleet, '{0}', ((fleet -> 0) - 'orientation') || '{"start_row":9}');
  perform t29.reject(s, 1, 'set_fleet', jsonb_build_object('ships', bad), 'placement');
  foreach k in array array['orientation', 'start_row', 'start_col'] loop
    bad := jsonb_set(fleet, '{0}', (fleet -> 0) - k);
    perform t29.reject(s, 1, 'set_fleet', jsonb_build_object('ships', bad), 'placement');
  end loop;
  for v in select value from jsonb_array_elements('[null,"", "h", "diagonal", 0, {}, []]') loop
    perform t29.reject(s, 1, 'set_fleet', jsonb_build_object('ships', jsonb_set(fleet, '{0,orientation}', v)), 'placement');
  end loop;
  foreach k in array array['start_row', 'start_col'] loop
    for v in select value from jsonb_array_elements('[null,"0",true,{},[],0.5,-1,10,1e100]') loop
      perform t29.reject(s, 1, 'set_fleet', jsonb_build_object('ships', jsonb_set(fleet, array['0', k], v)), 'placement');
    end loop;
  end loop;
  for bad in select value from jsonb_array_elements('[null,{},[],{"ships":null},{"ships":{}},{"ships":[null,null,null,null,null]}]') loop
    perform t29.reject(s, 1, 'set_fleet', bad, 'placement');
  end loop;
  perform t29.reject(s, 1, 'set_fleet', null, 'placement');
  perform t29.reject(s, 1, 'set_fleet', jsonb_build_object('ships', jsonb_set(fleet, '{0,start_col}', '6')), 'placement');
  perform t29.reject(s, 1, 'set_fleet', jsonb_build_object('ships', jsonb_set(fleet, '{0,orientation}', '"V"')), 'placement');
  -- Valeurs JSON numériquement entières acceptées, flotte adjacente inchangée.
  r := t29.mv(s, 1, 'set_fleet', jsonb_build_object('ships', jsonb_set(fleet, '{0,start_row}', '0.0')));
  perform t29.ok((r ->> 'ok')::boolean, 'flotte légale et entier JSON 0.0 acceptés');
  f := t29.sec(s) #> '{seats,1,fleet}';
  perform t29.mv(s, 1, 'lock_fleet');
  select jsonb_agg(x || '{"start_col":5}' order by ord) into f2
    from jsonb_array_elements(fleet) with ordinality t(x, ord);
  perform t29.ok((t29.mv(s, 2, 'set_fleet', jsonb_build_object('ships', f2)) ->> 'ok')::boolean, 'flotte adverse légale');
  perform t29.mv(s, 2, 'lock_fleet');
  f2 := t29.sec(s) #> '{seats,2,fleet}';
  perform t29.as_user(t29.uid(s, 1));
  st := public.get_session_state(s);
  perform t29.ok(st #> '{rounds,0,private,fleet}' = f and position(f2::text in st::text) = 0
    and not (st::text like '%"seats"%'), 'seule la flotte propre est transmise');

  shooter := (t29.card(s) ->> 'turn')::int;
  for bad in select value from jsonb_array_elements('[null,{},[],{"row":0},{"col":0}]') loop
    perform t29.reject(s, shooter, 'fire', bad, 'invalid_move');
  end loop;
  perform t29.reject(s, shooter, 'fire', null, 'invalid_move');
  foreach k in array array['row', 'col'] loop
    for v in select value from jsonb_array_elements('[null,"0",true,{},[],0.5,-1,10,1e100]') loop
      perform t29.reject(s, shooter, 'fire', jsonb_set('{"row":0,"col":0}', array[k], v), 'invalid_move');
    end loop;
  end loop;

  -- Une flotte valide reste jouable : touché, tir répété refusé, coulé et victoire au 17e impact.
  if shooter = 2 then perform t29.mv(s, 2, 'fire', '{"row":9,"col":9}'); end if;
  act := gen_random_uuid();
  r := t29.mv(s, 1, 'fire', '{"row":0.0,"col":5.0}', act);
  perform t29.ok((r ->> 'ok')::boolean and r #>> '{info,res}' = 'hit', 'touché calculé côté serveur');
  prior := t29.card(s);
  r := t29.mv(s, 1, 'fire', '{"row":0,"col":5}', act);
  perform t29.ok((r ->> 'repeated')::boolean and t29.card(s) = prior, 'double clic : un seul tir');
  perform t29.mv(s, 2, 'fire', '{"row":8,"col":9}');
  perform t29.reject(s, 1, 'fire', '{"row":0,"col":5}', 'repeat_cell');
  n := 1;
  for shot_row, shot_col in
    select (x ->> 'r')::int, (x ->> 'c')::int + step
      from jsonb_array_elements(f2) with ordinality t(x, ord),
           lateral generate_series(0, (x ->> 'len')::int - 1) step
      order by ord, step
  loop
    continue when shot_row = 0 and shot_col = 5;
    perform t29.ok((t29.mv(s, 1, 'fire', jsonb_build_object('row', shot_row, 'col', shot_col)) ->> 'ok')::boolean, 'tir valide accepté');
    n := n + 1;
    if n = 5 then
      perform t29.ok(t29.card(s) #> '{sunk,1}' = '["porte-avions"]'
        and (select count(*) = 5 from jsonb_array_elements(t29.card(s) #> '{shots,1}') x where x ->> 'res' = 'sunk'), 'coulé : seules les cinq cases touchées sont marquées');
    end if;
    exit when (t29.card(s) ->> 'done')::boolean;
    perform t29.mv(s, 2, 'fire', jsonb_build_object('row', 5 + n / 5, 'col', 5 + n % 5));
  end loop;
  c := t29.card(s);
  perform t29.ok(n = 17 and (c ->> 'done')::boolean and c ->> 'winner' = '1'
    and jsonb_array_length(c #> '{sunk,1}') = 5, '17 impacts : cinq navires coulés, victoire unique');
  perform t29.as_user(t29.uid(s, 2));
  st := public.get_session_state(s);
  perform t29.ok(st #> '{rounds,0,private,fleet}' = f2 and position(f::text in st::text) = 0, 'flotte adverse encore secrète après la victoire');
  perform t29.ok(not has_table_privilege('authenticated', 'private.round_secrets', 'SELECT')
    and not has_table_privilege('authenticated', 'private.board_moves', 'SELECT'), 'tables privées illisibles directement');
end $$;

select 'TESTS NAVALS C29 : PAYLOADS REFUSÉS SANS EFFET, TOUCHÉ/COULÉ, SECRETS ET IDEMPOTENCE VALIDÉS';
rollback;
