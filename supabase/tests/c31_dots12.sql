-- Serveur M04 12 × 12 POINTS. Exécuter avec psql -X -v ON_ERROR_STOP=1.
-- Docker jetable uniquement. La version préparée n'est jamais publiée : les
-- seules sessions12 sont liées à sa version par la fixture AVANT set_ready.
-- Tout est ROLLBACK. Les réessais ci-dessous sont séquentiels ; les courses réelles
-- nécessitent deux connexions distinctes et sont vérifiées séparément.
begin;
do $$ begin
  if current_database() !~ '^noodeu_server_[a-zA-Z0-9_]+$'
     or shobj_description((select oid from pg_database where datname=current_database()),'pg_database') is distinct from 'noodeu:disposable-local-sql-test' then
    raise exception 'Base Docker jetable explicitement autorisée attendue';
  end if;
end $$;
create schema t31;
create function t31.ok(cond boolean, msg text) returns void language plpgsql as $$
begin if cond is distinct from true then raise exception 'ÉCHEC : %', msg; end if; end $$;
create function t31.as_user(p uuid) returns void language plpgsql as $$
begin perform set_config('request.jwt.claims', json_build_object('sub',p,'role','authenticated')::text,true); end $$;
create function t31.uid(s uuid, seat int) returns uuid language sql as $$
  select user_id from public.session_players where session_id=s and seat=$2 $$;
create function t31.card(s uuid) returns jsonb language sql as $$
  select card from public.session_rounds where session_id=s and round_no=1 $$;
create function t31.mv(s uuid, seat int, typ text, p jsonb default '{}', action uuid default gen_random_uuid()) returns jsonb language plpgsql as $$
begin perform t31.as_user(t31.uid(s,seat)); return public.play_move(s,1,action,typ,p); end $$;
create function t31.reject(s uuid, seat int, typ text, p jsonb, expected text) returns void language plpgsql as $$
declare before jsonb:=t31.card(s); v bigint; n bigint; r jsonb;
begin
  select state_version into v from public.game_sessions where id=s;
  select count(*) into n from private.board_moves where session_id=s;
  r:=t31.mv(s,seat,typ,p);
  perform t31.ok(r->>'error'=expected,format('refus %s %s : %s',typ,p,r));
  perform t31.ok(t31.card(s)=before and (select state_version=v from public.game_sessions where id=s)
    and (select count(*)=n from private.board_moves where session_id=s),'refus sans mutation ni coup enregistré');
end $$;
create function t31.start(v int default null, lobby boolean default false) returns uuid language plpgsql as $$
declare s uuid;
begin
  update public.game_sessions g set status='abandoned' where status in ('lobby','playing','paused','ended')
    and exists(select 1 from public.session_players p where p.session_id=g.id and p.user_id='00000000-0000-4000-a000-000000000a31');
  perform t31.as_user('00000000-0000-4000-a000-000000000a31');
  s:=(public.create_session('N2-079')->>'session_id')::uuid;
  if s is null then raise exception 'Création de la session de test impossible'; end if;
  if v is not null then update public.game_sessions set game_version=v where id=s; end if;
  if not lobby then
    perform public.set_ready(s,true);
    perform t31.as_user('00000000-0000-4000-a000-000000000b31'); perform public.set_ready(s,true);
  end if;
  return s;
end $$;
create function t31.draft_version() returns int language sql as $$
  select version from public.game_versions where game_id='N2-079' and config->>'version'='noodeu-m04-2.0.0' $$;
create temp table t31_original_version as select current_version from public.games where id='N2-079';
create temp table t31_published_before as select * from public.game_versions where published_at is not null;

-- Géométrie complète et signatures historiques conservées.
do $$ declare e text; box int; side text; n int:=0; adjacent int:=0;
begin
  perform t31.ok((select count(*)=1 and bool_and(published_at is null) from public.game_versions
    where game_id='N2-079' and config->>'version'='noodeu-m04-2.0.0'),'une seule version12 préparée et non publiée');
  perform t31.ok((select current_version<>t31.draft_version() from public.games where id='N2-079'),'version12 non courante');
  perform t31.ok((select config#>'{parameters}' @> '{"dot_rows":12,"dot_columns":12,"boxes":121,"edges":264}'::jsonb
    from public.game_versions where game_id='N2-079' and version=t31.draft_version()),'paramètres12points/121cases/264segments');
  perform t31.ok(private.db_edge_ok('h:4:3') and not private.db_edge_ok('h:5:0'),'signature historique inchangée');
  perform t31.ok(private.db_boxes('v:0:1')=array[0,1] and private.db_count('{"h:0:0":1}',0)=1,'indexation historique4 inchangée');
  for e in select 'h:'||r||':'||c from generate_series(0,11)r,generate_series(0,10)c
    union all select 'v:'||r||':'||c from generate_series(0,10)r,generate_series(0,11)c loop
    perform t31.ok(private.db_edge_ok(e,12,12),'chaque segment12 valide');
    n:=n+1; adjacent:=adjacent+cardinality(private.db_boxes(e,12,12));
  end loop;
  perform t31.ok(n=264 and adjacent=484,'264 segments, exactement4 côtés pour121 cases');
  for box in 0..120 loop
    foreach side in array private.db_sides(box/11,box%11) loop
      perform t31.ok(box=any(private.db_boxes(side,12,12)),'chaque côté appartient à sa case');
    end loop;
  end loop;
  perform t31.ok(private.db_boxes('h:11:10',12,12)=array[120] and private.db_boxes('v:10:11',12,12)=array[120],'coins éloignés et index120');
  perform t31.ok(not private.db_edge_ok('h:0:0',13,12) and not private.db_edge_ok(null,12,12),'géométrie excessive et null refusés');
end $$;

insert into auth.users(id,email,raw_user_meta_data) values
  ('00000000-0000-4000-a000-000000000a31','dots-a31@noodeu.invalid','{"display_name":"A"}'),
  ('00000000-0000-4000-a000-000000000b31','dots-b31@noodeu.invalid','{"display_name":"B"}');
do $$ declare r jsonb;
begin
  perform t31.as_user('00000000-0000-4000-a000-000000000a31'); r:=public.create_invitation();
  perform t31.as_user('00000000-0000-4000-a000-000000000b31'); perform public.claim_invitation(r->>'code');
  perform t31.as_user('00000000-0000-4000-a000-000000000a31'); perform public.respond_to_claim((r->>'id')::uuid,true);
end $$;

-- Le pointeur ne suffit pas à rendre la draft accessible ; ancien salon et
-- ancienne partie restent5 même si le catalogue pointe temporairement ailleurs.
do $$ declare s uuid; old_v int; r jsonb; seat int;
begin
  select current_version into old_v from t31_original_version;
  s:=t31.start(null,true);
  update public.games set current_version=t31.draft_version() where id='N2-079';
  perform t31.as_user(t31.uid(s,1)); perform public.set_ready(s,true);
  perform t31.as_user(t31.uid(s,2)); perform public.set_ready(s,true);
  perform t31.ok((select game_version=old_v from public.game_sessions where id=s)
    and jsonb_array_length(t31.card(s)->'owner')=16 and not(t31.card(s)?'dot_rows'),'ancien salon démarré après nouveau pointeur reste5');
  seat:=(t31.card(s)->>'turn')::int;
  perform t31.ok((t31.mv(s,seat,'draw_edge','{"edge_id":"h:4:3"}')->>'ok')::boolean,'ancienne partie continue');
  perform t31.reject(s,3-seat,'draw_edge','{"edge_id":"h:11:10"}','invalid_move');
  update public.game_sessions set status='abandoned' where id=s;
  perform t31.as_user(t31.uid(s,1)); r:=public.create_session('N2-079');
  perform t31.ok(r->>'error'='game_unavailable','draft non publiée inaccessible même avec pointeur changé');
  update public.games set current_version=old_v where id='N2-079';
  s:=t31.start();
  perform t31.ok(jsonb_array_length(t31.card(s)->'owner')=16,'RPC normal continue à créer5points');
end $$;

-- Refus structurés sans effet ; trois côtés ne valent rien ; quatrième côté,
-- double fermeture, rejeu et identifiants répétés restent décidés par le serveur.
do $$ declare s uuid; c jsonb; seat int; e text; bad jsonb; r jsonb; action uuid:=gen_random_uuid();
begin
  s:=t31.start(t31.draft_version()); c:=t31.card(s); seat:=(c->>'turn')::int;
  perform t31.ok(c#>>'{dot_rows}'='12' and c#>>'{dot_columns}'='12' and jsonb_array_length(c->'owner')=121
    and c->>'total_edges'='264' and c->'tally'='{"1":0,"2":0}'::jsonb,'card serveur12 figée');
  perform t31.reject(s,3-seat,'draw_edge','{"edge_id":"h:0:0"}','not_your_turn');
  for bad in select value from jsonb_array_elements('[null,{},[],{"edge_id":null},{"edge_id":17},{"edge_id":[]},{"edge_id":{}}]') loop
    perform t31.reject(s,seat,'draw_edge',bad,'invalid_move');
  end loop;
  foreach e in array array['h:12:0','h:11:11','v:11:0','v:10:12','d:0:0','h:-1:0','h:00:0','h:1.5:0','h:0:0:1','h:99999999999999999999:0',' h:0:0','h:0:0 '] loop
    perform t31.reject(s,seat,'draw_edge',jsonb_build_object('edge_id',e),'invalid_move');
  end loop;
  perform t31.reject(s,seat,'place','{"edge_id":"h:0:0"}','invalid_move');
  foreach e in array array['h:0:0','h:1:0','v:0:0','h:0:1','h:1:1','v:0:2'] loop
    seat:=(t31.card(s)->>'turn')::int;
    r:=t31.mv(s,seat,'draw_edge',jsonb_build_object('edge_id',e,'gained',121,'tally','{"1":999,"2":999}'::jsonb));
    perform t31.ok((r->>'ok')::boolean and r#>>'{info,gained}'='0' and t31.card(s)->'tally'='{"1":0,"2":0}'::jsonb,'trois côtés maximum, score client ignoré');
    perform t31.ok((t31.card(s)->>'turn')::int=3-seat,'sans fermeture la main passe');
  end loop;
  seat:=(t31.card(s)->>'turn')::int;
  r:=t31.mv(s,seat,'draw_edge','{"edge_id":"v:0:1"}',action); c:=t31.card(s);
  perform t31.ok(r#>>'{info,gained}'='2' and c#>>array['tally',seat::text]='2' and (c->>'turn')::int=seat
    and c#>>'{owner,0}'=seat::text and c#>>'{owner,1}'=seat::text,'double fermeture +2, deux propriétaires et rejeu');
  r:=t31.mv(s,seat,'draw_edge','{"edge_id":"v:0:1"}',action);
  perform t31.ok((r->>'repeated')::boolean and t31.card(s)=c,'réessai même action sans second score');
  perform t31.reject(s,seat,'draw_edge','{"edge_id":"v:0:1"}','edge_taken');
  foreach e in array array['h:2:0','v:1:0','v:1:1'] loop
    seat:=(t31.card(s)->>'turn')::int; r:=t31.mv(s,seat,'draw_edge',jsonb_build_object('edge_id',e));
  end loop;
  perform t31.ok(r#>>'{info,gained}'='1' and (t31.card(s)->>'turn')::int=seat
    and t31.card(s)#>>'{owner,11}'=seat::text,'fermeture simple +1 et indexation11');
end $$;

-- Une partie complète passe par les264 RPC draw_edge ; vérifier l'invariant
-- score=cases possédées après chaque coup, pas seulement au résultat final.
do $$ declare s uuid; e text; seat int; c jsonb; reply jsonb; n int:=0; count1 int; count2 int; elapsed timestamptz:=clock_timestamp();
begin
  s:=t31.start(t31.draft_version());
  for e in select eid from (
    select 'h:'||r||':'||col eid,0 orient,r,col from generate_series(0,11)r,generate_series(0,10)col
    union all select 'v:'||r||':'||col,1,r,col from generate_series(0,10)r,generate_series(0,11)col) all_edges order by orient,r,col loop
    c:=t31.card(s); seat:=(c->>'turn')::int;
    reply:=t31.mv(s,seat,'draw_edge',jsonb_build_object('edge_id',e)); c:=t31.card(s); n:=n+1;
    perform t31.ok((reply->>'ok')::boolean,'chaque segment légal est accepté une fois');
    select count(*) filter(where x='1'::jsonb),count(*) filter(where x='2'::jsonb) into count1,count2 from jsonb_array_elements(c->'owner')x;
    perform t31.ok((c#>>'{tally,1}')::int=count1 and (c#>>'{tally,2}')::int=count2,'score égal aux cases possédées à chaque coup');
    perform t31.ok(coalesce((c->>'done')::boolean,false)=(n=264),'fin uniquement après les121 fermetures');
  end loop;
  perform t31.ok(n=264 and (select count(*)=264 from private.board_moves where session_id=s)
    and (select count(*)=264 from jsonb_object_keys(c->'edges')),'264 coups/segments distincts');
  perform t31.ok(count1+count2=121 and c->>'winner' in ('1','2') and c->'scores'=c->'tally','total121 et gagnant sans égalité');
  perform t31.ok((select status='ended' and result->'points'=c->'scores' from public.game_sessions where id=s),'résultat RPC égal au score autoritaire');
  perform t31.reject(s,seat,'draw_edge','{"edge_id":"h:0:0"}','not_playing');
  raise notice '264 RPC, invariants à chaque coup : % ms',extract(epoch from clock_timestamp()-elapsed)*1000;
end $$;

-- Le robot devait pouvoir finir une chaîne121>40, sans modifier les autres jeux.
-- Préparer légalement les132 horizontales et les11 verticales gauches donne zéro
-- case fermée ; les121 verticales restantes ferment ensuite une case chacune.
do $$ declare s uuid; edges jsonb; c jsonb; claims text; sub text; mv jsonb; n int;
begin
  s:=t31.start(t31.draft_version());
  mv:=private.board_bot_any('dots_boxes',t31.card(s),'{}',(t31.card(s)->>'turn')::int);
  perform t31.ok(mv->>'type'='draw_edge' and private.db_edge_ok(mv#>>'{payload,edge_id}',12,12),'robot sur plateau vide : segment légal');
  select jsonb_object_agg(e,1) into edges from (
    select 'h:'||r||':'||col e from generate_series(0,11)r,generate_series(0,10)col
    union all select 'v:'||r||':0' from generate_series(0,10)r) prefilled;
  update public.session_rounds set card=jsonb_set(card||'{"turn":2}', '{edges}',edges) where session_id=s;
  insert into private.test_autoplayers(user_id,note) values('00000000-0000-4000-a000-000000000b31','Fixture C31 annulée');
  perform t31.as_user(t31.uid(s,1));
  claims:=current_setting('request.jwt.claims',true); sub:=current_setting('request.jwt.claim.sub',true);
  perform private.bump_session(s,'move');
  c:=t31.card(s);
  select count(*) into n from private.board_moves where session_id=s;
  perform t31.ok(n=121 and c->>'winner'='2' and c#>>'{scores,2}'='121' and (c->>'done')::boolean,'autoplay dépasse40 et termine121 captures');
  perform t31.ok(current_setting('request.jwt.claims',true)=claims
    and current_setting('request.jwt.claim.sub',true)=coalesce(sub,''),'claims humains restaurés après chaîne robot');
  delete from private.test_autoplayers where user_id='00000000-0000-4000-a000-000000000b31';
end $$;

do $$ begin
  perform t31.ok((select g.current_version=o.current_version from public.games g cross join t31_original_version o where g.id='N2-079'),'pointeur final inchangé');
  perform t31.ok((select published_at is null from public.game_versions where game_id='N2-079' and version=t31.draft_version()),'version12 toujours non publiée');
  perform t31.ok(not exists(select 1 from t31_published_before b join public.game_versions v using(game_id,version) where to_jsonb(b)<>to_jsonb(v)),'toutes versions publiées inchangées');
end $$;
select 'C31 PASS : DRAFT INACTIVE, ANCIENNES PARTIES5, 264 SEGMENTS, 121 CASES, SCORES/REJEU ET CHAÎNE ROBOT';
rollback;
