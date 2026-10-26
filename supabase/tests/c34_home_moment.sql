-- Uniquement sur PostgreSQL jetable. Aucun compte réel.
begin;
create schema ts27;
create function ts27.as_user(p uuid) returns void language sql as $$ select set_config('request.jwt.claims', json_build_object('sub', p, 'role', 'authenticated')::text, true) $$;
create function ts27.ok(c boolean, msg text) returns void language plpgsql as $$ begin if c is distinct from true then raise exception 'ÉCHEC : %', msg; end if; end $$;
create function ts27.pair(a uuid, b uuid) returns uuid language plpgsql as $$ declare r jsonb; begin
 perform ts27.as_user(a); r := public.create_invitation(); perform ts27.as_user(b); perform public.claim_invitation(r->>'code');
 perform ts27.as_user(a); return (public.respond_to_claim((r->>'id')::uuid,true)->>'couple_id')::uuid; end $$;
grant usage on schema ts27 to authenticated;
grant execute on all functions in schema ts27 to authenticated;
insert into auth.users(id,email,raw_user_meta_data) values
('00000000-0000-4000-a000-000000000027','a27@noodeu.invalid','{"display_name":"A"}'),
('00000000-0000-4000-b000-000000000027','b27@noodeu.invalid','{"display_name":"B"}'),
('00000000-0000-4000-c000-000000000027','c27@noodeu.invalid','{"display_name":"C"}');
do $$ declare a uuid:='00000000-0000-4000-a000-000000000027'; b uuid:='00000000-0000-4000-b000-000000000027'; c uuid:='00000000-0000-4000-c000-000000000027'; ab uuid; ac uuid; sid uuid; first_draw jsonb; second_draw jsonb; before_count bigint;
begin
 ab:=ts27.pair(a,b); perform ts27.as_user(a);
 first_draw:=public.get_home_moment(ab);
 perform ts27.ok((first_draw->>'ok')::boolean and first_draw->>'question' is not null,'question disponible');
 perform ts27.ok((first_draw->>'games_played')::int=0,'aucune progression inventée');
 perform ts27.ok((first_draw->>'eligible_count')::int=60,'60 questions réelles éligibles au plafond moyen');
 update public.profiles set max_intensity='soft' where id=a;
 perform ts27.ok((select count(*) from private.home_candidates(ab))=57,'57 questions au plafond soft');
 update public.profiles set max_intensity='moyen' where id=a;
 perform ts27.ok(first_draw->>'source'='existing_catalogue','catalogue existant, pas banque originale de repli');
 perform ts27.ok(first_draw->>'rights_status'='commercial_rights_unconfirmed','réserve de droits conservée');
 perform ts27.ok(not exists(select 1 from private.home_candidates(ab) where bank not in ('q_complicite','q_recul','q_emotions','q_reconfort')),'tests, Aron, séries, tiers réservés et intime exclus');
 perform ts27.as_user(b);second_draw:=public.get_home_moment(ab);
 perform ts27.ok(first_draw->>'question'=second_draw->>'question','même question A et B');
 perform ts27.ok(first_draw->>'expires_at'=second_draw->>'expires_at','même échéance serveur');
 perform ts27.as_user(c);perform ts27.ok(not(public.get_home_moment(ab)->>'ok')::boolean,'tiers rejeté');
 ac:=ts27.pair(a,c);perform ts27.as_user(a);perform public.get_home_moment(ac);
 perform ts27.ok((select count(*)=2 from private.home_moments where couple_id in (ab,ac)),'deux espaces indépendants');
 perform ts27.as_user(b);perform ts27.ok(not(public.get_home_moment(ac)->>'ok')::boolean,'B ne lit pas AC');
 select count(*) into before_count from public.game_sessions;
 update private.home_moments set slot=slot-1 where couple_id=ab;
 second_draw:=public.get_home_moment(ab);
 perform ts27.ok(first_draw->>'question'<>second_draw->>'question','pas de répétition immédiate');
 perform ts27.ok((select count(*) from public.game_sessions)=before_count,'aucune partie créée ou modifiée');
 insert into public.item_feedback(user_id,bank,item_id,value) values(b,second_draw->>'bank',second_draw->>'item_id','trop_intime');
 perform ts27.ok(public.get_home_moment(ab)->>'question' is null,'retour privé B masque la carte immédiatement');
 perform ts27.ok((public.get_home_moment(ab)->>'eligible_count')::int=59,'retour privé réellement exclu du pool');
 sid:=(public.create_session('ND-Q-RND1')->>'session_id')::uuid;
 update public.session_prefs set excluded_topics=array['desir'] where session_id=sid and user_id=b;
 perform ts27.ok((public.get_home_moment(ab)->>'eligible_count')::int=0,'thèmes exclus et cartes non annotées respectés');
 update public.session_prefs set excluded_topics='{}' where session_id=sid;
 update public.content_meta set review=true where bank in ('q_complicite','q_recul','q_emotions','q_reconfort');
 perform ts27.ok(public.get_home_moment(ab)->>'question' is null,'contenu retiré non exposé');
 update private.home_moments set slot=slot-1 where couple_id=ab;
 perform ts27.ok(public.get_home_moment(ab)->>'question' is null,'banque vide sans question fictive');
 perform ts27.ok(not has_function_privilege('anon','public.get_home_moment(uuid)','execute'),'anonyme interdit');
 perform ts27.ok(not has_table_privilege('authenticated','private.home_moments','select'),'tirages inaccessibles directement');
end $$;
rollback;
