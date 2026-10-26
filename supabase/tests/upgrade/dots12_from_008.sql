-- Preuve d'upgrade008 ->010, à exécuter AVANT l'application persistante de010.
-- Base PostgreSQL locale jetable migrée jusqu'à008 ;009 indépendante est permise.
-- La version draft010 et ses fonctions doivent être absentes au départ.
-- Ce fichier est volontairement hors du glob supabase/tests/*.sql exécuté après010.
--
-- Usage depuis la racine du dépôt (psql doit lire ce fichier avec -f pour que
-- l'inclusion relative suive le chemin du script, pas le répertoire courant) :
-- psql -X -v ON_ERROR_STOP=1 -d <base_jetable> -f supabase/tests/upgrade/dots12_from_008.sql
-- Avec Docker, copier ce fichier et la migration en conservant l'arborescence
-- supabase/tests/upgrade et supabase/migrations, puis appeler psql -f dans le conteneur.
-- Tout, migration incluse, est annulé ; les assertions finales vérifient le rollback.
\set ON_ERROR_STOP on

begin;
do $$ begin
  if current_database() !~ '^noodeu_server_[a-zA-Z0-9_]+$'
     or shobj_description((select oid from pg_database where datname=current_database()),'pg_database')
        is distinct from 'noodeu:disposable-local-sql-test' then
    raise exception 'Base locale jetable autorisée et marquée attendue';
  end if;
  if exists(select 1 from public.game_versions where game_id='N2-079'
            and config->>'version'='noodeu-m04-2.0.0')
     or to_regprocedure('private.db_setup12(public.game_sessions)') is not null then
    raise exception 'Précondition upgrade : 010 doit être absente, y compris sa version draft';
  end if;
  if not exists(select 1 from public.games g join public.game_versions v
                on v.game_id=g.id and v.version=g.current_version
                where g.id='N2-079' and v.config#>>'{parameters,dot_rows}'='5'
                  and v.config#>>'{parameters,dot_columns}'='5') then
    raise exception 'Précondition upgrade : Points et carrés courant doit être en 5 × 5 points';
  end if;
end $$;
create schema t31compat;
create function t31compat.ok(cond boolean,msg text) returns void language plpgsql as $$ begin if cond is distinct from true then raise exception 'ECHEC : %',msg; end if; end $$;
create function t31compat.as_user(u uuid) returns void language plpgsql as $$ begin perform set_config('request.jwt.claims',json_build_object('sub',u,'role','authenticated')::text,true); end $$;
insert into auth.users(id,email,raw_user_meta_data) values
 ('00000000-0000-4000-a000-000000000a41','compat-a41@noodeu.invalid','{"display_name":"A"}'),
 ('00000000-0000-4000-a000-000000000b41','compat-b41@noodeu.invalid','{"display_name":"B"}'),
 ('00000000-0000-4000-a000-000000000a42','compat-a42@noodeu.invalid','{"display_name":"A"}'),
 ('00000000-0000-4000-a000-000000000b42','compat-b42@noodeu.invalid','{"display_name":"B"}');
create temp table compat_sessions(kind text,id uuid,pre_action uuid);
do $$ declare a uuid; b uuid; inv jsonb; sid uuid; n int; who int; action uuid:=gen_random_uuid(); begin
 for n in 41..42 loop
  a:=('00000000-0000-4000-a000-000000000a'||n)::uuid; b:=('00000000-0000-4000-a000-000000000b'||n)::uuid;
  perform t31compat.as_user(a); inv:=public.create_invitation();
  perform t31compat.as_user(b); perform public.claim_invitation(inv->>'code');
  perform t31compat.as_user(a); perform public.respond_to_claim((inv->>'id')::uuid,true);
  sid:=(public.create_session('N2-079')->>'session_id')::uuid;
  perform t31compat.ok(sid is not null,'session avant migration creee');
  if n=41 then
   perform public.set_ready(sid,true); perform t31compat.as_user(b); perform public.set_ready(sid,true);
   select (card->>'turn')::int into who from public.session_rounds where session_id=sid and round_no=1;
   perform t31compat.as_user((select user_id from public.session_players where session_id=sid and seat=who));
   perform t31compat.ok((public.play_move(sid,1,action,'draw_edge','{"edge_id":"h:0:0"}')->>'ok')::boolean,'premier coup avant010');
   insert into compat_sessions values('playing',sid,action);
  else insert into compat_sessions values('lobby',sid,null); end if;
 end loop;
end $$;
create temp table compat_before_sessions as select id,to_jsonb(s) val from public.game_sessions s;
create temp table compat_before_rounds as select session_id,round_no,to_jsonb(r) val from public.session_rounds r;
create temp table compat_before_secrets as select session_id,round_no,to_jsonb(r) val from private.round_secrets r;
create temp table compat_before_moves as select action_id,to_jsonb(m) val from private.board_moves m;
create temp table compat_before_published as select game_id,version,to_jsonb(v) val from public.game_versions v where published_at is not null;
create temp table compat_before_games as select id,to_jsonb(g) val from public.games g;
select 'AVANT010 : une partie5 jouee et un salon5 existent';
\ir ../../migrations/20261029001000_dots12_versioned.sql

do $$ declare sid uuid; who int; reply jsonb; before jsonb; action uuid; begin
 perform t31compat.ok(not exists(select 1 from compat_before_sessions b full join public.game_sessions s using(id) where b.val is distinct from to_jsonb(s)),'sessions exactes avant/apres010');
 perform t31compat.ok(not exists(select 1 from compat_before_rounds b full join public.session_rounds r using(session_id,round_no) where b.val is distinct from to_jsonb(r)),'cartes exactes avant/apres010');
 perform t31compat.ok(not exists(select 1 from compat_before_secrets b full join private.round_secrets r using(session_id,round_no) where b.val is distinct from to_jsonb(r)),'secrets exacts avant/apres010');
 perform t31compat.ok(not exists(select 1 from compat_before_moves b full join private.board_moves m using(action_id) where b.val is distinct from to_jsonb(m)),'journal exact avant/apres010');
 perform t31compat.ok(not exists(select 1 from compat_before_games b full join public.games g using(id) where b.val is distinct from to_jsonb(g)),'catalogue et pointeurs exacts avant/apres010');
 perform t31compat.ok(not exists(select 1 from compat_before_published b full join (select * from public.game_versions where published_at is not null) v using(game_id,version) where b.val is distinct from to_jsonb(v)),'versions publiees exactes avant/apres010');
 select id,pre_action into sid,action from compat_sessions where kind='playing';
 select card into before from public.session_rounds where session_id=sid and round_no=1;
 who:=(before->>'turn')::int;
 perform t31compat.as_user((select user_id from public.session_players where session_id=sid and seat=3-who));
 reply:=public.play_move(sid,1,action,'draw_edge','{"edge_id":"h:0:0"}');
 perform t31compat.ok((reply->>'repeated')::boolean and (select card=before from public.session_rounds where session_id=sid and round_no=1),'action premigration reconnue sans second effet');
 perform t31compat.as_user((select user_id from public.session_players where session_id=sid and seat=who));
 reply:=public.play_move(sid,1,gen_random_uuid(),'draw_edge','{"edge_id":"h:4:3"}');
 perform t31compat.ok((reply->>'ok')::boolean,'ancienne partie continue viaRPC apres010');
 perform t31compat.as_user((select user_id from public.session_players where session_id=sid and seat=3-who));
 reply:=public.play_move(sid,1,gen_random_uuid(),'draw_edge','{"edge_id":"h:11:10"}');
 perform t31compat.ok(reply->>'error'='invalid_move','ancienne partie refuse geometrie12');
 perform t31compat.ok((select jsonb_array_length(card->'owner')=16 and not(card?'dot_rows') from public.session_rounds where session_id=sid and round_no=1),'ancienne carte garde16cases');
 select id into sid from compat_sessions where kind='lobby';
 perform t31compat.as_user((select user_id from public.session_players where session_id=sid and seat=1)); perform public.set_ready(sid,true);
 perform t31compat.as_user((select user_id from public.session_players where session_id=sid and seat=2)); perform public.set_ready(sid,true);
 perform t31compat.ok((select jsonb_array_length(card->'owner')=16 and not(card?'dot_rows') from public.session_rounds where session_id=sid and round_no=1),'salon cree avant010 demarre en5 apres010');
 perform t31compat.ok((select count(*)=1 and bool_and(published_at is null) from public.game_versions where game_id='N2-079' and config->>'version'='noodeu-m04-2.0.0'),'draft12 unique inactive');
end $$;
select 'COMPAT PASS : donnees exactes avant/apres010, partie5 et salon5 preexistants repris parRPC, draft12 inactive';
rollback;
-- Vérification sans écriture après rollback : aucune fixture ni définition010
-- ne doit rester sur la base qui servira aux phases suivantes du runner.
do $$ begin
  if exists(select 1 from auth.users where email in
      ('compat-a41@noodeu.invalid','compat-b41@noodeu.invalid','compat-a42@noodeu.invalid','compat-b42@noodeu.invalid'))
     or exists(select 1 from pg_namespace where nspname='t31compat')
     or exists(select 1 from public.game_versions where game_id='N2-079' and config->>'version'='noodeu-m04-2.0.0')
     or to_regprocedure('private.db_setup12(public.game_sessions)') is not null then
    raise exception 'Résidu inattendu après rollback du test upgrade010';
  end if;
end $$;
select 'UPGRADE010 PASS : rollback intégral, zéro fixture et aucune migration010 persistée';
