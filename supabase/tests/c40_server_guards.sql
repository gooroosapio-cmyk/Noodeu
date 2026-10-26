-- ACL et garde-fous serveur : base Docker dédiée, jamais production.
-- Le remplacement de bot_step est une instrumentation de contrôle, annulée avec
-- toute la transaction. Elle mesure le plafond réel d'autoplay et son exception,
-- sans prétendre vérifier à nouveau l'intelligence ou les coups du robot.
begin;
do $$ begin
  if current_database() !~ '^noodeu_server_[a-zA-Z0-9_]+$'
     or shobj_description((select oid from pg_database where datname=current_database()),'pg_database') is distinct from 'noodeu:disposable-local-sql-test' then
    raise exception 'Base Docker jetable dédiée roles explicitement autorisée attendue';
  end if;
end $$;
create schema t32;
create function t32.ok(cond boolean,msg text) returns void language plpgsql as $$
begin if cond is distinct from true then raise exception 'ÉCHEC : %',msg; end if; end $$;
-- SECURITY INVOKER impératif : EXECUTE doit rencontrer les ACL du rôle testé.
create function t32.denied(query text) returns void language plpgsql as $$
declare rejected boolean:=false;
begin
  begin execute query;
  exception when insufficient_privilege then rejected:=true;
  end;
  perform t32.ok(rejected,'ACL doit refuser : '||query);
end $$;
create function t32.as_user(p uuid) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims',jsonb_build_object('sub',p,'role','authenticated','test_marker','human32')::text,true);
  perform set_config('request.jwt.claim.sub',p::text,true);
end $$;
create function t32.snapshot(s uuid) returns jsonb language sql as $$
  select jsonb_build_object(
    'session',(select to_jsonb(g) from public.game_sessions g where g.id=s),
    'players',(select jsonb_agg(to_jsonb(p) order by seat) from public.session_players p where p.session_id=s),
    'rounds',(select jsonb_agg(to_jsonb(r) order by round_no) from public.session_rounds r where r.session_id=s),
    'secrets',(select jsonb_agg(to_jsonb(r) order by round_no) from private.round_secrets r where r.session_id=s),
    'moves',(select jsonb_agg(to_jsonb(m) order by action_id) from private.board_moves m where m.session_id=s))
$$;
grant usage on schema t32 to authenticated,anon;
grant execute on function t32.ok(boolean,text),t32.denied(text) to authenticated,anon;

-- Les six nouvelles signatures doivent refuser un appel direct, pas seulement
-- annoncer une ACL dans pg_proc. Seul insufficient_privilege est attendu.
do $$ declare role_name text; query text; signature text;
begin
  foreach role_name in array array['authenticated','anon'] loop
    foreach signature in array array[
      'private.db_edge_ok(text,integer,integer)', 'private.db_boxes(text,integer,integer)',
      'private.db_count(jsonb,integer,integer,integer)', 'private.db_setup12(public.game_sessions)',
      'private.db_apply(jsonb,jsonb,integer,text,jsonb)', 'private.db_bot(jsonb,integer)'] loop
      perform t32.ok(not has_function_privilege(role_name,signature,'EXECUTE'),role_name||' sans EXECUTE '||signature);
    end loop;
    execute format('set local role %I',role_name);
    foreach query in array array[
      $q$select private.db_edge_ok('h:0:0',12,12)$q$,
      $q$select private.db_boxes('h:0:0',12,12)$q$,
      $q$select private.db_count('{}'::jsonb,0,12,12)$q$,
      $q$select private.db_setup12(null::public.game_sessions)$q$,
      $q$select private.db_apply('{}'::jsonb,'{}'::jsonb,1,'draw_edge','{}'::jsonb)$q$,
      $q$select private.db_bot('{}'::jsonb,1)$q$] loop
      perform t32.denied(query);
    end loop;
    reset role;
  end loop;
end $$;

insert into auth.users(id,email,raw_user_meta_data) values
 ('00000000-0000-4000-a000-000000000a32','guards-a32@noodeu.invalid','{"display_name":"A"}'),
 ('00000000-0000-4000-a000-000000000b32','guards-b32@noodeu.invalid','{"display_name":"B"}'),
 ('00000000-0000-4000-a000-000000000c32','guards-c32@noodeu.invalid','{"display_name":"C"}');
create table t32.sessions(kind text primary key,id uuid not null);
do $$ declare r jsonb; s uuid; prior jsonb;
  a constant uuid:='00000000-0000-4000-a000-000000000a32';
  b constant uuid:='00000000-0000-4000-a000-000000000b32';
begin
  perform t32.as_user(a); r:=public.create_invitation();
  perform t32.as_user(b); perform public.claim_invitation(r->>'code');
  perform t32.as_user(a); perform public.respond_to_claim((r->>'id')::uuid,true);
  s:=(public.create_session('nd-deux-verites-mensonge')->>'session_id')::uuid;
  perform t32.ok(s is not null,'salon G08 créé');
  perform public.set_ready(s,true);
  set local role authenticated;
  perform t32.ok(current_user='authenticated','rôle réel authenticated');
  r:=public.update_session_settings(s,'{"cartes":4}');
  perform t32.ok(r='{"ok":true}'::jsonb,'RPC public autorisé au joueur authentifié');
  reset role;
  perform t32.ok((select settings->>'cartes'='4' from public.game_sessions where id=s)
    and not exists(select 1 from public.session_players where session_id=s and ready_at is not null),'réglage modifié et confirmations réinitialisées');
  prior:=t32.snapshot(s);
  set local role authenticated;
  r:=public.update_session_settings(s,'{"cartes":6,"inconnue":true}');
  perform t32.ok(r='{"ok":false,"error":"invalid_settings"}'::jsonb,'patch invalide refusé sous rôle réel');
  reset role;
  perform t32.ok(t32.snapshot(s)=prior,'aucune mutation du patch refusé sous authenticated');
  perform set_config('request.jwt.claims','{}',true);
  perform set_config('request.jwt.claim.sub','',true);
  set local role anon;
  perform t32.ok(current_user='anon' and auth.uid() is null,'rôle réel anon sans identité');
  perform t32.denied(format('select public.update_session_settings(%L::uuid,%L::jsonb)',s,'{"cartes":6}'));
  reset role;
  perform t32.ok(t32.snapshot(s)=prior,'aucune mutation après refus anonyme');
  perform t32.as_user(a); perform public.abandon_session(s);

  -- Les deux formats seront réutilisés uniquement pour mesurer autoplay.
  s:=(public.create_session('N2-079')->>'session_id')::uuid;
  perform public.set_ready(s,true); perform t32.as_user(b); perform public.set_ready(s,true);
  insert into t32.sessions values('legacy',s);
  -- Fixture seulement : libérer le salon sans purger sa véritable carte5.
  update public.game_sessions set status='abandoned' where id=s;
  perform t32.as_user(a);
  s:=(public.create_session('N2-079')->>'session_id')::uuid;
  update public.game_sessions set game_version=(select version from public.game_versions
    where game_id='N2-079' and config->>'version'='noodeu-m04-2.0.0') where id=s;
  perform public.set_ready(s,true); perform t32.as_user(b); perform public.set_ready(s,true);
  insert into t32.sessions values('dots12',s);
end $$;

-- Le tiers a réellement le rôle authenticated ; refus exact, sans mutation de
-- l'état public, secret, des confirmations, de la version ou du journal de coups.
do $$ declare s uuid; prior jsonb; r jsonb; hidden int; rejected boolean:=false; action uuid:=gen_random_uuid();
begin
  select id into s from t32.sessions where kind='dots12'; prior:=t32.snapshot(s);
  perform t32.as_user('00000000-0000-4000-a000-000000000c32');
  set local role authenticated;
  begin
    r:=public.play_move(s,1,action,'draw_edge','{"edge_id":"h:0:0"}');
  exception when raise_exception then
    if sqlerrm <> 'session_not_found' then raise; end if;
    rejected:=true;
  end;
  perform t32.ok(rejected,'tiers C exclu du coup12 par session_not_found');
  r:=public.get_session_state(s);
  perform t32.ok(r='{"ok":false,"error":"session_not_found"}'::jsonb,'tiers C exclu de la vue12');
  select count(*) into hidden from public.game_versions where game_id='N2-079' and config->>'version'='noodeu-m04-2.0.0';
  perform t32.ok(hidden=0,'draft masquée par RLS au rôle authentifié non admin');
  reset role;
  perform t32.ok(t32.snapshot(s)=prior,'tiers sans mutation public/secret/version/coups');
end $$;

-- Une séquence est volontairement non transactionnelle dans les sous-blocs :
-- elle prouve qu'un bot_step ayant levé a été exécuté, même si son travail SQL
-- est annulé par le bloc EXCEPTION d'autoplay. L'objet lui-même est créé ici et
-- sera supprimé par le ROLLBACK extérieur.
do $$ begin
  perform t32.ok(exists(select 1 from t32.sessions s join public.session_rounds r on r.session_id=s.id
    where s.kind='legacy' and r.round_no=1 and r.card->>'mech'='dots_boxes'
      and jsonb_array_length(r.card->'owner')=16 and not(r.card ? 'dot_rows')
      and not(r.card ? 'dot_columns')),'véritable carte historique5 conservée avant instrumentation');
end $$;
create sequence t32.bot_calls;
create table t32.bot_control(throw_on int);
insert into t32.bot_control values(null);
create table t32.bot_seen(claims jsonb,sub text,seat int,session_id uuid);
create temp table t32_bot_original as select pg_get_functiondef('private.bot_step(uuid,integer)'::regprocedure) as definition;
create or replace function private.bot_step(p_session uuid,p_seat int) returns boolean
language plpgsql security definer set search_path='' as $$
declare n bigint;
begin
  n:=nextval('t32.bot_calls');
  insert into t32.bot_seen values(current_setting('request.jwt.claims',true)::jsonb,current_setting('request.jwt.claim.sub',true),p_seat,p_session);
  if n=(select throw_on from t32.bot_control) then raise exception 't32_forced_bot_failure'; end if;
  return true;
end $$;
insert into private.test_autoplayers(user_id,note) values('00000000-0000-4000-a000-000000000b32','C32 instrumentation annulée');
do $$ declare s uuid; entry record; claims text; sub text; prior jsonb; calls bigint; original_card jsonb;
  a constant uuid:='00000000-0000-4000-a000-000000000a32';
  b constant uuid:='00000000-0000-4000-a000-000000000b32';
begin
  for entry in select kind,id,case when kind='dots12' then 264 else 40 end cap from t32.sessions order by kind loop
    s:=entry.id;
    perform setval('t32.bot_calls',1,false); truncate t32.bot_seen;
    perform t32.as_user(a); claims:=current_setting('request.jwt.claims',true); sub:=current_setting('request.jwt.claim.sub',true);
    prior:=t32.snapshot(s);
    perform private.autoplay(s);
    select last_value into calls from t32.bot_calls;
    perform t32.ok(calls=entry.cap and (select count(*)=entry.cap from t32.bot_seen),format('%s : exactement %s appels, pas davantage',entry.kind,entry.cap));
    perform t32.ok(not exists(select 1 from t32.bot_seen seen where seen.claims->>'sub' is distinct from b::text or seen.claims->>'role' is distinct from 'authenticated'
      or seen.sub is distinct from b::text or seen.seat<>2 or seen.session_id<>s),'chaque appel utilise uniquement les claims et siège du robot attendu');
    perform t32.ok(current_setting('request.jwt.claims',true)=claims and current_setting('request.jwt.claim.sub',true)=sub,'deux claims humains restaurés après succès');
    perform t32.ok(t32.snapshot(s)=prior,'instrumentation de plafond sans modification du plateau');
  end loop;

  -- Des dimensions12 ne suffisent pas : le mécanisme doit également être Dots.
  select id into s from t32.sessions where kind='dots12';
  select card into original_card from public.session_rounds where session_id=s and round_no=1;
  update public.session_rounds set card=jsonb_set(card,'{mech}','"tic_tac_toe"') where session_id=s and round_no=1;
  perform setval('t32.bot_calls',1,false); truncate t32.bot_seen;
  perform private.autoplay(s);
  perform t32.ok((select last_value=40 from t32.bot_calls) and (select count(*)=40 from t32.bot_seen),'autre mécanisme même dimensions : plafond40');
  update public.session_rounds set card=original_card where session_id=s and round_no=1;

  -- L'exception est réellement déclenchée au troisième appel ; elle ne doit
  -- ni sortir d'autoplay ni laisser l'identité du robot dans les deux GUC.
  update t32.bot_control set throw_on=3;
  perform setval('t32.bot_calls',1,false); truncate t32.bot_seen;
  perform t32.as_user(a); claims:=current_setting('request.jwt.claims',true); sub:=current_setting('request.jwt.claim.sub',true);
  prior:=t32.snapshot(s);
  perform private.autoplay(s);
  perform t32.ok((select last_value=3 from t32.bot_calls),'troisième appel atteint et exception arrête la chaîne');
  perform t32.ok(not exists(select 1 from t32.bot_seen),'travail du bloc robot annulé après exception');
  perform t32.ok(current_setting('request.jwt.claims',true)=claims and current_setting('request.jwt.claim.sub',true)=sub,'deux claims humains restaurés après exception');
  perform t32.ok(t32.snapshot(s)=prior,'exception robot sans effet sur la séance');
end $$;
-- Restauration explicite pour vérifier la définition, puis ROLLBACK intégral.
do $$ begin execute (select definition from t32_bot_original); end $$;
select t32.ok(pg_get_functiondef('private.bot_step(uuid,integer)'::regprocedure)=(select definition from t32_bot_original),'bot_step historique restauré exactement');
select 'C32 PASS : ACL RÉELLES, ANON/TIERS REFUSÉS, PLAFONDS40/264 ET RESTAURATION CLAIMS AVEC EXCEPTION';
rollback;
