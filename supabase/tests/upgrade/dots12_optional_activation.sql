-- Test local dédié APRES010 inactive. Jamais inclus dans la suite intégrée C18–C25 et C30–C40.
-- Trois refus attendus, puis activation et rejeu dans UNE transaction annulée.
\set ON_ERROR_STOP on
begin;
do $$ begin
  if current_database() !~ '^noodeu_server_[a-zA-Z0-9_]+$'
     or shobj_description((select oid from pg_database where datname=current_database()),'pg_database')
        is distinct from 'noodeu:disposable-local-sql-test' then
    raise exception 'Base locale jetable autorisée et marquée attendue';
  end if;
  if (select current_version from public.games where id='N2-079') is distinct from 1
     or (select count(*) from public.game_versions where game_id='N2-079'
       and config->>'version'='noodeu-m04-2.0.0' and published_at is null) <> 1 then
    raise exception 'Précondition : legacy1 courant et unique draft010 inactive';
  end if;
end $$;
create schema t33;
create function t33.ok(cond boolean,msg text) returns void language plpgsql as $$
begin if cond is distinct from true then raise exception 'ÉCHEC : %',msg; end if; end $$;
create function t33.as_user(u uuid) returns void language plpgsql as $$
begin perform set_config('request.jwt.claims',jsonb_build_object('sub',u,'role','authenticated')::text,true); end $$;
grant usage on schema t33 to authenticated;
grant execute on function t33.ok(boolean,text),t33.as_user(uuid) to authenticated;

-- Chaque erreur est capturée par psql, puis le sous-état est annulé AVANT
-- l'assertion exacte. L'absence d'erreur doit également faire échouer le test.
savepoint wrong_current;
update public.games set current_version=null where id='N2-079';
\set ON_ERROR_STOP off
\ir ../../optional/activate_dots12_after_validation.sql
\if :ERROR
  \set activation_error :LAST_ERROR_MESSAGE
\else
  \set activation_error missing_expected_failure
\endif
\set ON_ERROR_STOP on
rollback to savepoint wrong_current;
select t33.ok(:'activation_error'='dots12_activation_current_mismatch','pointeur courant inattendu refusé');

savepoint wrong_contract;
update public.game_versions set config=jsonb_set(config,'{frontend_contract}','"wrong-client"')
  where game_id='N2-079' and config->>'version'='noodeu-m04-2.0.0';
\set ON_ERROR_STOP off
\ir ../../optional/activate_dots12_after_validation.sql
\if :ERROR
  \set activation_error :LAST_ERROR_MESSAGE
\else
  \set activation_error missing_expected_failure
\endif
\set ON_ERROR_STOP on
rollback to savepoint wrong_contract;
select t33.ok(:'activation_error'='dots12_activation_contract_mismatch','mauvais contrat frontend refusé');

savepoint duplicate_target;
insert into public.game_versions(game_id,version,rules,config,published_at)
  select game_id,(select max(version)+1 from public.game_versions where game_id='N2-079'),rules,
    jsonb_set(config,'{frontend_contract}','"wrong-client"'),null
  from public.game_versions where game_id='N2-079' and config->>'version'='noodeu-m04-2.0.0';
\set ON_ERROR_STOP off
\ir ../../optional/activate_dots12_after_validation.sql
\if :ERROR
  \set activation_error :LAST_ERROR_MESSAGE
\else
  \set activation_error missing_expected_failure
\endif
\set ON_ERROR_STOP on
rollback to savepoint duplicate_target;
select t33.ok(:'activation_error'='dots12_activation_target_not_unique','doublon de nom refusé même si contrat différent');

insert into auth.users(id,email,raw_user_meta_data) values
 ('00000000-0000-4000-a000-000000000a61','activation-a61@noodeu.invalid','{"display_name":"A"}'),
 ('00000000-0000-4000-a000-000000000b61','activation-b61@noodeu.invalid','{"display_name":"B"}'),
 ('00000000-0000-4000-a000-000000000a62','activation-a62@noodeu.invalid','{"display_name":"C"}'),
 ('00000000-0000-4000-a000-000000000b62','activation-b62@noodeu.invalid','{"display_name":"D"}');
create temp table activation_sessions(kind text primary key,id uuid,pre_action uuid);
do $$ declare a uuid; b uuid; n int; inv jsonb; sid uuid; action uuid:=gen_random_uuid(); begin
  for n in 61..62 loop
    a:=('00000000-0000-4000-a000-000000000a'||n)::uuid;
    b:=('00000000-0000-4000-a000-000000000b'||n)::uuid;
    perform t33.as_user(a); inv:=public.create_invitation();
    perform t33.as_user(b); perform public.claim_invitation(inv->>'code');
    perform t33.as_user(a); perform public.respond_to_claim((inv->>'id')::uuid,true);
    if n=61 then
      sid:=(public.create_session('N2-079')->>'session_id')::uuid;
      perform public.set_ready(sid,true); perform t33.as_user(b); perform public.set_ready(sid,true);
      perform t33.as_user((select p.user_id from public.session_players p where p.session_id=sid and p.seat=(
        select (r.card->>'turn')::int from public.session_rounds r where r.session_id=sid and r.round_no=1)));
      perform t33.ok((public.play_move(sid,1,action,'draw_edge','{"edge_id":"h:0:0"}')->>'ok')::boolean,'coup5 avant activation');
      insert into activation_sessions values('legacy',sid,action);
    end if;
  end loop;
end $$;
create temp table activation_before_games as select id,to_jsonb(g) val from public.games g;
create temp table activation_before_versions as select game_id,version,to_jsonb(v) val from public.game_versions v;
create temp table activation_before_sessions as select id,to_jsonb(s) val from public.game_sessions s;
create temp table activation_before_rounds as select session_id,round_no,to_jsonb(r) val from public.session_rounds r;
create temp table activation_before_secrets as select session_id,round_no,to_jsonb(r) val from private.round_secrets r;
create temp table activation_before_moves as select action_id,to_jsonb(m) val from private.board_moves m;
-- Un timestamp now() serait identique lors du second appel dans cette transaction.
-- Compter les UPDATE prouve l'absence réelle de réécriture au rejeu.
create table t33.updates(table_name text,row_data jsonb);
create function t33.audit_update() returns trigger language plpgsql as $$
begin insert into t33.updates values(tg_table_name,to_jsonb(new)); return new; end $$;
create trigger t33_games after update on public.games for each row execute function t33.audit_update();
create trigger t33_versions after update on public.game_versions for each row execute function t33.audit_update();

\ir ../../optional/activate_dots12_after_validation.sql
\ir ../../optional/activate_dots12_after_validation.sql

do $$ declare draft public.game_versions; sid uuid; old_action uuid; reply jsonb; original jsonb; who uuid; denied boolean:=false; begin
  select * into draft from public.game_versions where game_id='N2-079' and config->>'version'='noodeu-m04-2.0.0';
  perform t33.ok(draft.published_at is not null and (select current_version=draft.version from public.games where id=draft.game_id),'draft publiée et courante');
  perform t33.ok((select count(*)=2 from t33.updates) and (select count(*)=1 from t33.updates where table_name='games')
    and (select count(*)=1 from t33.updates where table_name='game_versions'),'une publication et un seul bump catalogue, rejeu sans UPDATE');
  perform t33.ok(not exists(select 1 from activation_before_games b full join public.games g using(id)
    where case when g.id='N2-079' then (b.val-'current_version'-'updated_at') is distinct from (to_jsonb(g)-'current_version'-'updated_at')
    else b.val is distinct from to_jsonb(g) end),'seuls pointeur et updated_at changés au catalogue');
  perform t33.ok(not exists(select 1 from activation_before_versions b full join public.game_versions v using(game_id,version)
    where case when v.game_id=draft.game_id and v.version=draft.version then (b.val-'published_at') is distinct from (to_jsonb(v)-'published_at')
    else b.val is distinct from to_jsonb(v) end),'seule publication du draft, aucune config/règle/version réécrite');
  perform t33.ok(not exists(select 1 from activation_before_sessions b full join public.game_sessions s using(id) where b.val is distinct from to_jsonb(s)),'séances exactes après activation');
  perform t33.ok(not exists(select 1 from activation_before_rounds b full join public.session_rounds r using(session_id,round_no) where b.val is distinct from to_jsonb(r)),'cartes exactes après activation');
  perform t33.ok(not exists(select 1 from activation_before_secrets b full join private.round_secrets r using(session_id,round_no) where b.val is distinct from to_jsonb(r)),'secrets exacts après activation');
  perform t33.ok(not exists(select 1 from activation_before_moves b full join private.board_moves m using(action_id) where b.val is distinct from to_jsonb(m)),'coups exacts après activation');
  begin update public.game_versions set config=config||'{"unexpected":true}' where game_id=draft.game_id and version=draft.version;
  exception when raise_exception then if sqlerrm<>'published_version_is_immutable' then raise; end if; denied:=true; end;
  perform t33.ok(denied,'version12 publiée effectivement immuable');

  select id,pre_action into sid,old_action from activation_sessions where kind='legacy';
  select card into original from public.session_rounds where session_id=sid and round_no=1;
  perform t33.ok(jsonb_array_length(original->'owner')=16 and not(original?'dot_rows')
    and (select game_version=1 from public.game_sessions where id=sid),'ancienne partie figée5/version1');
  select p.user_id into who from public.session_players p where p.session_id=sid and p.seat=3-(original->>'turn')::int;
  perform t33.as_user(who); set local role authenticated;
  reply:=public.play_move(sid,1,old_action,'draw_edge','{"edge_id":"h:0:0"}'); reset role;
  perform t33.ok(reply='{"ok":true,"repeated":true}'::jsonb and (select card=original from public.session_rounds where session_id=sid and round_no=1),'ancien coup idempotent après activation');
  select p.user_id into who from public.session_players p where p.session_id=sid and p.seat=(original->>'turn')::int;
  perform t33.as_user(who); set local role authenticated;
  reply:=public.play_move(sid,1,gen_random_uuid(),'draw_edge','{"edge_id":"h:4:3"}'); reset role;
  perform t33.ok((reply->>'ok')::boolean,'ancienne partie5 continue sous rôle authenticated');

  perform t33.as_user('00000000-0000-4000-a000-000000000a62'); set local role authenticated;
  perform t33.ok((select count(*)=1 from public.game_versions where game_id='N2-079' and config->>'version'='noodeu-m04-2.0.0'),'version publiée visible par RLS');
  reply:=public.create_session('N2-079'); sid:=(reply->>'session_id')::uuid;
  perform t33.ok((reply->>'ok')::boolean and not(reply->>'existing')::boolean,'nouvelle session créée par RPC public');
  perform public.set_ready(sid,true); perform t33.as_user('00000000-0000-4000-a000-000000000b62'); perform public.set_ready(sid,true);
  reply:=public.get_session_state(sid); reset role;
  perform t33.ok((select game_version=draft.version from public.game_sessions where id=sid)
    and reply#>>'{game,config,frontend_contract}'='dots12-v1'
    and (select card->>'dot_rows'='12' and card->>'dot_columns'='12' and jsonb_array_length(card->'owner')=121
      and card->>'total_edges'='264' from public.session_rounds where session_id=sid and round_no=1),'nouvelle partie12 publique sans substitution fixture de version');
end $$;
select 'ACTIVATION PASS : trois refus exacts, nouvelle partie12 publique, ancienne partie5 intacte, publication unique, rejeu sans UPDATE, version immuable';
rollback;
do $$ begin
  if (select current_version from public.games where id='N2-079') is distinct from 1
     or exists(select 1 from public.game_versions where game_id='N2-079' and config->>'version'='noodeu-m04-2.0.0' and published_at is not null)
     or exists(select 1 from auth.users where email like 'activation-%@noodeu.invalid')
     or to_regnamespace('t33') is not null then
    raise exception 'Résidu inattendu après rollback activation facultative';
  end if;
end $$;
select 'ROLLBACK PASS : draft toujours inactive, zéro fixture activation et aucune mise en service persistée';
