-- Uniquement sur PostgreSQL jetable. Aucun compte réel.
begin;
create schema ts26;
create function ts26.as_user(p uuid) returns void language sql as $$ select set_config('request.jwt.claims', json_build_object('sub', p, 'role', 'authenticated')::text, true) $$;
create function ts26.ok(c boolean, msg text) returns void language plpgsql as $$ begin if c is distinct from true then raise exception 'ÉCHEC : %', msg; end if; end $$;
create function ts26.pair(a uuid, b uuid) returns uuid language plpgsql as $$ declare r jsonb; begin
 perform ts26.as_user(a); r := public.create_invitation(); perform ts26.as_user(b); perform public.claim_invitation(r->>'code');
 perform ts26.as_user(a); return (public.respond_to_claim((r->>'id')::uuid,true)->>'couple_id')::uuid; end $$;
grant usage on schema ts26 to authenticated;
grant execute on all functions in schema ts26 to authenticated;
insert into auth.users(id,email,raw_user_meta_data) values
('00000000-0000-4000-a000-000000000026','a26@noodeu.invalid','{"display_name":"A"}'),
('00000000-0000-4000-b000-000000000026','b26@noodeu.invalid','{"display_name":"B"}'),
('00000000-0000-4000-c000-000000000026','c26@noodeu.invalid','{"display_name":"C"}');
create temp table mixed_snapshots(kind text,payload jsonb);
do $$ declare a uuid:='00000000-0000-4000-a000-000000000026'; b uuid:='00000000-0000-4000-b000-000000000026'; c uuid:='00000000-0000-4000-c000-000000000026';
 sid uuid; ab uuid; q jsonb; snap jsonb; res jsonb; cfg jsonb; n int; seen text[]:='{}'; first_id text; before_round jsonb;
begin
 ab:=ts26.pair(a,b);perform ts26.as_user(a);
 select v.config into cfg from public.games g join public.game_versions v on v.game_id=g.id and v.version=g.current_version where g.id='ND-Q-RND1';
 perform ts26.ok(jsonb_array_length(cfg#>'{pack,pool}')=14,'six banques ordinaires et huit À huis clos');
 perform ts26.ok(not((cfg#>'{pack,pool}') ?| array['q_aron','q_series','q_rice','q_ecrrs']),'exceptions intactes');
 perform ts26.ok((select adult_available and content_level='standard' from public.games where id='ND-Q-RND1'),'mode mixte standard signalé adult_available');
 -- Le retour trop intime de B exclut réellement toutes les cartes ordinaires, sans modifier les banques.
 insert into public.item_feedback(user_id,bank,item_id,value)
 select b,bank,value->>'id','trop_intime' from public.content_banks where bank in(select jsonb_array_elements_text(cfg#>'{pack,pool}')) and bank not like 'q_hc%';
 foreach n in array array[5,10,20] loop
  perform ts26.as_user(a);sid:=(public.create_session('ND-Q-RND1')->>'session_id')::uuid;
  res:=public.update_session_settings(sid,jsonb_build_object('questions',n));perform ts26.ok((res->>'ok')::boolean,'réglage accepté');
  insert into mixed_snapshots values('lobby',public.get_session_state(sid));
  perform public.set_ready(sid,true);perform ts26.as_user(b);res:=public.set_ready(sid,true);perform ts26.ok((res->>'ok')::boolean,'démarrage réel');
  snap:=public.get_session_state(sid);q:=snap#>'{rounds,0,card,queue}';
  perform ts26.ok(jsonb_array_length(q)=n,'nombre demandé5/10/20');
  perform ts26.ok((select count(*)=count(distinct v) from jsonb_array_elements(q) v),'file sans doublon');
  perform ts26.ok(not exists(select 1 from jsonb_array_elements(q) v where v->>0 not like 'q_hc%'),'À huis clos réellement tiré et exclusions B respectées');
  perform ts26.ok(public.get_session_state(sid)#>'{rounds,0,card,queue}'=q,'reconnexion stable');
  first_id:=(snap#>>'{rounds,0,card,item,bank}')||':'||(snap#>>'{rounds,0,card,item,id}');
  perform ts26.ok(not first_id=any(seen),'pas de répétition après nouvelle séance');seen:=array_append(seen,first_id);
  perform ts26.as_user(a);res:=public.play_move(sid,1,gen_random_uuid(),'answer','{"choice":"private","text":"SECRET_A_26"}');
  perform ts26.ok((res->>'ok')::boolean,'réponse privée acceptée');
  perform ts26.as_user(b);perform ts26.ok(position('SECRET_A_26' in public.get_session_state(sid)::text)=0,'aucune fuite avant révélation');
  perform public.play_move(sid,1,gen_random_uuid(),'answer','{"choice":"share","text":"B"}');
  perform ts26.ok(position('SECRET_A_26' in public.get_session_state(sid)::text)=0,'réponse privée reste privée après révélation');
  perform public.next_round(sid,1);
  perform ts26.ok(public.get_session_state(sid)#>'{rounds,1,card,queue}'=q,'manche suivante conserve file');
  perform ts26.as_user(c);perform ts26.ok(not(public.get_session_state(sid)->>'ok')::boolean,'tiers exclu');
  perform ts26.as_user(a);perform public.abandon_session(sid);
 end loop;
 -- Exclusion de thème : toutes les cartes non annotées sont conservativement non candidates.
 sid:=(public.create_session('ND-Q-RND1')->>'session_id')::uuid;
 update public.session_prefs set excluded_topics=array['desir'] where session_id=sid and user_id=b;
 perform ts26.ok(cardinality(private.excluded_tags(sid))>0,'préférence B enregistrée');
 perform public.set_ready(sid,true);perform ts26.as_user(b);
 begin
  res:=public.set_ready(sid,true);raise exception 'unexpected_success';
 exception when others then
  perform ts26.ok(sqlerrm='not_enough_cards','aucun tirage non annoté sous exclusion de thème');
 end;
 -- Fixture annotée sur DB jetable uniquement, sans changement des textes ni de production.
 update public.content_banks set value=value||'{"topic_tags":["sante_sexuelle"]}'::jsonb where bank='q_hc_protection';
 res:=public.set_ready(sid,true);perform ts26.ok((res->>'ok')::boolean,'banque annotée compatible disponible');
 q:=public.get_session_state(sid)#>'{rounds,0,card,queue}';
 perform ts26.ok(not exists(select 1 from jsonb_array_elements(q) v where v->>0<>'q_hc_protection'),'thème exclu et absence annotations respectés');
 perform ts26.ok(not exists(select 1 from public.games g join public.game_versions v on v.game_id=g.id and v.version=g.current_version where (g.mechanic='test_form' or g.id in('ND-Q-P01','ND-Q-P20')) and v.config#>>'{pack,mixed_queue}'='true'),'tests Aron P20 inchangés');
end $$;
select 'MIXED_LOBBY='||payload::text from mixed_snapshots where kind='lobby' limit 1;
select 'TOUS LES TESTS MIXTES SONT PASSÉS';
rollback;
