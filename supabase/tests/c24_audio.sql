-- Uniquement sur PostgreSQL jetable. Aucun compte réel.
begin;
create schema ts24;
create function ts24.as_user(p uuid) returns void language sql as $$ select set_config('request.jwt.claims', json_build_object('sub', p, 'role', 'authenticated')::text, true) $$;
create function ts24.ok(c boolean, msg text) returns void language plpgsql as $$ begin if c is distinct from true then raise exception 'ÉCHEC : %', msg; end if; end $$;
create function ts24.pair(a uuid, b uuid) returns uuid language plpgsql as $$ declare r jsonb; begin
 perform ts24.as_user(a); r := public.create_invitation(); perform ts24.as_user(b); perform public.claim_invitation(r->>'code');
 perform ts24.as_user(a); return (public.respond_to_claim((r->>'id')::uuid,true)->>'couple_id')::uuid; end $$;
grant usage on schema ts24 to authenticated;
grant execute on all functions in schema ts24 to authenticated;
insert into auth.users(id,email,raw_user_meta_data) values
('00000000-0000-4000-a000-000000000024','a24@noodeu.invalid','{"display_name":"A"}'),
('00000000-0000-4000-b000-000000000024','b24@noodeu.invalid','{"display_name":"B"}'),
('00000000-0000-4000-c000-000000000024','c24@noodeu.invalid','{"display_name":"C"}');
do $$ declare a uuid := '00000000-0000-4000-a000-000000000024'; b uuid := '00000000-0000-4000-b000-000000000024'; c uuid := '00000000-0000-4000-c000-000000000024';
 ab uuid; sid uuid; aid uuid:=gen_random_uuid(); path text; res jsonb; jobs1 jsonb; jobs2 jsonb; act uuid:=gen_random_uuid();
begin
 ab:=ts24.pair(a,b); perform ts24.as_user(a); sid:=(public.create_session('ND-Q-P21')->>'session_id')::uuid;
 perform public.set_ready(sid,true); perform ts24.as_user(b); perform public.set_ready(sid,true); perform ts24.as_user(a);
 perform ts24.ok(public.reserve_answer_audio(sid,1,aid,'audio/webm')->>'error'='unavailable','audio désactivé par défaut');
 update private.media_capabilities set audio_enabled=true;
 -- Fixture déterministe : carte libre, sans options (la banque mêle plusieurs modalités).
 update public.session_rounds set card=jsonb_set(jsonb_set(card,'{item,options}','null'),'{item,response}','"open"') where session_id=sid and round_no=1;
 perform ts24.ok(public.reserve_answer_audio(sid,1,aid,'video/mp4')->>'error'='invalid_file','MIME refusé');
 res:=public.reserve_answer_audio(sid,1,aid,'audio/webm'); path:=res->>'path';
 perform ts24.ok((res->>'ok')::boolean,'réserve brouillon');
 perform ts24.ok(public.reserve_answer_audio(sid,1,aid,'audio/webm')->>'path'=path,'réservation idempotente');
 set local role authenticated;
 insert into storage.objects(bucket_id,name) values('answer-audio',path);
 reset role;
 perform ts24.ok(public.play_move(sid,1,act,'answer',jsonb_build_object('choice','share','audio_id',aid))->>'error'='audio_not_ready','aucun audio non vérifié accepté');
 perform public.verify_answer_audio(aid,30001);
 perform ts24.ok((select state from private.audio_answers where id=aid)='rejected','durée serveur trop longue rejetée');
 -- Seule la fixture remet le même objet en attente pour le cas valide suivant.
 update private.audio_answers set state='pending' where id=aid;
 perform public.verify_answer_audio(aid,12000);
 perform ts24.as_user(b);
 perform ts24.ok(public.get_answer_audio(aid)->>'error'='unavailable','avant validation : audio A inaccessible B');
 perform ts24.as_user(a);
 perform ts24.ok((public.play_move(sid,1,act,'answer',jsonb_build_object('choice','share','audio_id',aid))->>'ok')::boolean,'A valide audio');
 perform ts24.ok((public.play_move(sid,1,act,'answer',jsonb_build_object('choice','share','audio_id',aid))->>'repeated')::boolean,'double clic exact idempotent');
 perform ts24.ok(public.play_move(sid,1,gen_random_uuid(),'answer','{"choice":"share","text":"écraser"}')->>'error'='already_submitted','second clic distinct ne remplace pas réponse');
 perform ts24.as_user(b);
 perform ts24.ok(public.get_answer_audio(aid)->>'error'='unavailable','avant révélation inaccessible B');
 perform ts24.ok(position(aid::text in public.get_session_state(sid)::text)=0,'identifiant audio A absent du payload B');
 perform ts24.ok((public.play_move(sid,1,gen_random_uuid(),'answer','{"choice":"share","text":"Réponse B"}')->>'ok')::boolean,'B valide texte');
 perform ts24.ok((public.get_answer_audio(aid)->>'ok')::boolean,'après révélation accès B');
 set local role authenticated;
 perform ts24.ok((select count(*) from storage.objects where bucket_id='answer-audio' and name=path)=0,'aucune lecture directe donc aucun lien signé client');
 reset role;
 perform ts24.as_user(c);
 perform ts24.ok(public.get_answer_audio(aid)->>'error'='unavailable','C exclu');
 perform ts24.as_user(a);
 perform public.set_answer_shared(sid,1,false);
 perform ts24.as_user(b);
 perform ts24.ok(public.get_answer_audio(aid)->>'error'='unavailable','retrait partage effectif');
 perform ts24.as_user(a); perform public.set_answer_shared(sid,1,true);
 update private.audio_answers set expires_at=now()-interval '1 second' where id=aid;
 perform ts24.ok(public.get_answer_audio(aid)->>'error'='unavailable','échéance autoritaire même avant worker');
 perform public.finish_audio_expiration(aid);
 perform ts24.ok(exists(select 1 from private.audio_answers where id=aid),'pas de suppression metadata avant objet');
 -- Shim jetable : simule le succès de l’API Storage, pas une procédure de production.
 delete from storage.objects where bucket_id='answer-audio' and name=path;
 perform public.finish_audio_expiration(aid);
 perform ts24.ok(not exists(select 1 from private.audio_answers where id=aid),'métadonnées expirées supprimées après objet');
 perform ts24.ok(position(aid::text in public.get_session_state(sid)::text)=0,'références audio retirées des réponses après nettoyage');
 -- 101 réservations non téléversées : la seconde collecte atteint le job restant.
 insert into private.audio_answers(id,session_id,round_no,user_id,path,mime)
 select gen_random_uuid(),sid,1,a,'test-rotation/'||i::text,'audio/webm' from generate_series(1,101) i;
 jobs1:=public.audio_worker_jobs(); jobs2:=public.audio_worker_jobs();
 perform ts24.ok(jsonb_array_length(jobs1)=100,'lot worker borné');
 perform ts24.ok((select count(distinct j->>'id') from jsonb_array_elements(jobs1||jobs2) j)=101,'aucune famine après 100 objets absents');
 perform ts24.ok(not has_function_privilege('authenticated','public.verify_answer_audio(uuid,integer)','execute'),'navigateur ne peut vérifier sa durée');
end $$;
select 'TOUS LES TESTS AUDIO SONT PASSÉS';
rollback;
