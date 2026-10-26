-- Réglages du salon : uniquement sur PostgreSQL jetable, après la migration 009.
-- Les fixtures, y compris une version de schéma synthétique, sont toutes annulées.
begin;

create schema t30;
create function t30.ok(cond boolean, msg text) returns void language plpgsql as $$
begin
  if cond is distinct from true then raise exception 'ÉCHEC : %', msg; end if;
end $$;
create function t30.as_user(p uuid) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', json_build_object('sub', p, 'role', 'authenticated')::text, true);
end $$;
create function t30.snapshot(s uuid) returns jsonb language sql as $$
  select jsonb_build_object(
    'session', (select to_jsonb(g) from public.game_sessions g where g.id = s),
    'players', (select jsonb_agg(to_jsonb(p) order by p.seat) from public.session_players p where p.session_id = s),
    'prefs', (select jsonb_agg(to_jsonb(p) order by p.seat) from public.session_prefs p where p.session_id = s),
    'rounds', (select jsonb_agg(to_jsonb(r) order by r.round_no) from public.session_rounds r where r.session_id = s))
$$;
create function t30.reject(s uuid, payload jsonb, expected text default 'invalid_settings') returns void language plpgsql as $$
declare before_state jsonb := t30.snapshot(s); res jsonb;
begin
  res := public.update_session_settings(s, payload);
  perform t30.ok(res = jsonb_build_object('ok', false, 'error', expected), format('refus de %s : %s', payload, res));
  perform t30.ok(t30.snapshot(s) = before_state, 'refus sans mutation des réglages, disponibilités, version, préférences ou manches');
end $$;
create function t30.noop(s uuid, payload jsonb) returns void language plpgsql as $$
declare before_state jsonb := t30.snapshot(s); res jsonb;
begin
  res := public.update_session_settings(s, payload);
  perform t30.ok(res = '{"ok":true}'::jsonb, 'patch inchangé accepté');
  perform t30.ok(t30.snapshot(s) = before_state, 'patch inchangé sans effet ni nouvelle confirmation');
end $$;

insert into auth.users (id, email, raw_user_meta_data) values
  ('00000000-0000-4000-a000-000000000030', 'settings-a30@noodeu.invalid', '{"display_name":"A"}'),
  ('00000000-0000-4000-b000-000000000030', 'settings-b30@noodeu.invalid', '{"display_name":"B"}'),
  ('00000000-0000-4000-c000-000000000030', 'settings-c30@noodeu.invalid', '{"display_name":"C"}');
do $$
declare res jsonb;
begin
  perform t30.as_user('00000000-0000-4000-a000-000000000030');
  res := public.create_invitation();
  perform t30.as_user('00000000-0000-4000-b000-000000000030');
  perform public.claim_invitation(res ->> 'code');
  perform t30.as_user('00000000-0000-4000-a000-000000000030');
  perform public.respond_to_claim((res ->> 'id')::uuid, true);
end $$;

do $$
declare
  a uuid := '00000000-0000-4000-a000-000000000030';
  b uuid := '00000000-0000-4000-b000-000000000030';
  outsider uuid := '00000000-0000-4000-c000-000000000030';
  s uuid; res jsonb; bad jsonb; n int; prior jsonb; v bigint; denied boolean := false;
begin
  perform t30.as_user(a);
  s := (public.create_session('nd-deux-verites-mensonge') ->> 'session_id')::uuid;
  perform t30.ok((select settings = '{"cartes":6}'::jsonb from public.game_sessions where id = s), 'G08 : six tours par défaut');
  perform t30.ok((select private.version_config(g) ->> 'mode' = 'simultaneous'
    and private.version_config(g) #> '{settings,cartes,options}' = '[4,6,10]'::jsonb
    from public.game_sessions g where g.id = s), 'G08 simultané, options 4/6/10 inchangées');
  perform public.set_ready(s, true);

  -- SQL NULL, JSON null et chaque type non objet : retour contrôlé, aucune exception.
  perform t30.reject(s, null);
  for bad in select value from jsonb_array_elements('[null,[],[4],"cartes",4,true,false]') loop
    perform t30.reject(s, bad);
  end loop;
  -- Une clé inconnue seule ou mêlée à un réglage valide invalide le patch entier.
  for bad in select value from jsonb_array_elements('[{"inconnue":true},{"cartes":4,"inconnue":true},{"mode":"alternate"},{"cartes":4,"adult":true},{"":4}]') loop
    perform t30.reject(s, bad);
  end loop;
  for bad in select value from jsonb_array_elements('[null,"4",true,false,[],[4],{}, {"value":4},0,3,5,6.5,100,1e100]') loop
    perform t30.reject(s, jsonb_build_object('cartes', bad));
  end loop;
  perform t30.noop(s, '{}');
  perform t30.noop(s, '{"cartes":6}');
  perform t30.noop(s, '{"cartes":6.0}');

  -- Le changement invalide la disponibilité de A, puis celle de B.
  select state_version into v from public.game_sessions where id = s;
  res := public.update_session_settings(s, '{"cartes":4}');
  perform t30.ok((res ->> 'ok')::boolean and (select settings = '{"cartes":4}'::jsonb and state_version = v + 1
    from public.game_sessions where id = s), 'réglage accepté, un seul incrément de version');
  perform t30.ok(not exists (select 1 from public.session_players where session_id = s and ready_at is not null), 'A doit reconfirmer');
  perform t30.as_user(b);
  perform public.set_ready(s, true);
  res := public.update_session_settings(s, '{"cartes":10}');
  perform t30.ok((res ->> 'ok')::boolean and not exists
    (select 1 from public.session_players where session_id = s and ready_at is not null), 'B peut régler et doit reconfirmer');

  -- L'ancien RPC acceptait et stockait 4.0. Un patch valide répare aussi ce salon.
  update public.game_sessions set settings = '{"cartes":4.0}' where id = s;
  perform public.set_ready(s, true);
  select state_version into v from public.game_sessions where id = s;
  res := public.update_session_settings(s, '{"cartes":4}');
  perform t30.ok((res ->> 'ok')::boolean and (select settings ->> 'cartes' = '4' and state_version = v + 1
    from public.game_sessions where id = s), 'ancien nombre 4.0 normalisé malgré son égalité JSONB avec 4');
  perform t30.ok(not exists (select 1 from public.session_players where session_id = s and ready_at is not null),
    'salon corrigé : disponibilités remises à zéro');

  -- Le verrou d'accès reste en place : ne jamais avaler l'assertion d'exclusion.
  prior := t30.snapshot(s);
  perform t30.as_user(outsider);
  begin
    perform public.update_session_settings(s, '{"cartes":4}');
  exception when raise_exception then
    if sqlerrm <> 'session_not_found' then raise; end if;
    denied := true;
  end;
  perform t30.ok(denied and t30.snapshot(s) = prior, 'tiers refusé sans mutation');
  perform t30.as_user(a);
  perform public.abandon_session(s);

  -- Les options effectivement choisies contrôlent le démarrage, y compris 4.0 normalisé.
  foreach n in array array[4,6,10] loop
    s := (public.create_session('nd-deux-verites-mensonge') ->> 'session_id')::uuid;
    res := public.update_session_settings(s, case when n = 4 then '{"cartes":4.0}'::jsonb else jsonb_build_object('cartes', n) end);
    perform t30.ok((res ->> 'ok')::boolean and (select settings ->> 'cartes' = n::text from public.game_sessions where id = s),
      'nombre stocké sous la forme canonique de l''option');
    perform public.set_ready(s, true);
    perform t30.as_user(b);
    res := public.set_ready(s, true);
    perform t30.ok((res ->> 'ok')::boolean and (select status = 'playing' and total_rounds = n from public.game_sessions where id = s),
      format('démarrage à %s tours', n));
    perform t30.ok((select card ->> 'mode' = 'simultaneous' from public.session_rounds where session_id = s and round_no = 1), 'mode simultané conservé');
    perform t30.reject(s, '{"cartes":4}', 'not_in_lobby');
    perform t30.as_user(a);
    perform public.abandon_session(s);
  end loop;
end $$;

do $$
declare
  a uuid := '00000000-0000-4000-a000-000000000030';
  s uuid; res jsonb; base public.game_versions; next_version int; cfg jsonb;
begin
  perform t30.as_user(a);
  s := (public.create_session('N2-023') ->> 'session_id')::uuid;
  res := public.update_session_settings(s, '{"difficulte":"facile"}');
  perform t30.ok((res ->> 'ok')::boolean and (select settings = '{"cartes":6,"difficulte":"facile"}'::jsonb
    from public.game_sessions where id = s), 'patch texte conserve le nombre de manches');
  res := public.update_session_settings(s, '{"cartes":10}');
  perform t30.ok((res ->> 'ok')::boolean and (select settings = '{"cartes":10,"difficulte":"facile"}'::jsonb
    from public.game_sessions where id = s), 'patch numérique conserve le réglage texte');
  perform public.set_ready(s, true);
  perform t30.reject(s, '{"cartes":4,"difficulte":"inconnue"}');
  perform t30.reject(s, '{"difficulte":1}');
  perform t30.reject(s, '{"difficulte":["facile"]}');
  perform t30.noop(s, '{"difficulte":"facile"}');

  -- Une future version publiée n'étend pas les réglages autorisés d'une séance existante.
  select gv.* into base from public.game_versions gv join public.game_sessions g
    on gv.game_id = g.game_id and gv.version = g.game_version where g.id = s;
  select max(version) + 1 into next_version from public.game_versions where game_id = base.game_id;
  cfg := base.config || jsonb_build_object('settings', (base.config -> 'settings') || '{
    "flag":{"default":false,"options":[false,true]},
    "shape":{"default":{"a":1,"b":2},"options":[{"a":1,"b":2},{"a":3,"b":4}]},
    "broken":{"default":0,"options":"invalid"},
    "missing":{"default":0},
    "empty":{"default":0,"options":[]}
  }'::jsonb);
  insert into public.game_versions (game_id, version, rules, config, published_at)
    values (base.game_id, next_version, base.rules, cfg, now());
  update public.games set current_version = next_version where id = base.game_id;
  perform t30.reject(s, '{"flag":true}');
  res := public.update_session_settings(s, '{"difficulte":"difficile"}');
  perform t30.ok((res ->> 'ok')::boolean and (select game_version = base.version and settings ->> 'cartes' = '10'
    from public.game_sessions where id = s), 'ancienne version et patch partiel conservés');
  perform public.abandon_session(s);

  -- Schéma synthétique de test : égalité exacte, jamais containment d'une sous-valeur.
  s := (public.create_session('N2-023') ->> 'session_id')::uuid;
  perform t30.ok((select game_version = next_version from public.game_sessions where id = s), 'nouvelle session liée à sa propre version');
  perform t30.reject(s, '{"flag":"true"}');
  perform t30.reject(s, '{"flag":1}');
  perform t30.reject(s, '{"shape":{"a":1}}');
  perform t30.reject(s, '{"shape":{"a":1,"b":2,"c":3}}');
  perform t30.reject(s, '{"broken":0}');
  perform t30.reject(s, '{"missing":0}');
  perform t30.reject(s, '{"empty":0}');
  res := public.update_session_settings(s, '{"flag":true,"shape":{"b":4,"a":3}}');
  perform t30.ok((res ->> 'ok')::boolean and (select settings -> 'flag' = 'true'::jsonb
    and settings -> 'shape' = '{"a":3,"b":4}'::jsonb and settings ->> 'cartes' = '6'
    and settings ->> 'difficulte' = 'standard' from public.game_sessions where id = s),
    'options exactes acceptées, types et autres réglages conservés');
  perform t30.noop(s, '{"flag":true,"shape":{"a":3,"b":4}}');
  perform public.abandon_session(s);

  -- Un jeu sans réglages accepte le patch vide, sans autoriser de clés arbitraires.
  s := (public.create_session('N2-078') ->> 'session_id')::uuid;
  perform t30.noop(s, '{}');
  perform t30.reject(s, '{"cartes":4}');
end $$;

select 'TOUS LES TESTS DE VALIDATION DES RÉGLAGES SONT PASSÉS';
rollback;
