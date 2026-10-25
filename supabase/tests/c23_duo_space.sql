-- Uniquement sur PostgreSQL jetable. Aucun compte réel.
begin;
create schema ts23;
create function ts23.as_user(p uuid) returns void language sql as $$ select set_config('request.jwt.claims', json_build_object('sub', p, 'role', 'authenticated')::text, true) $$;
create function ts23.ok(c boolean, msg text) returns void language plpgsql as $$ begin if c is distinct from true then raise exception 'ÉCHEC : %', msg; end if; end $$;
create function ts23.pair(a uuid, b uuid) returns uuid language plpgsql as $$ declare r jsonb; begin
 perform ts23.as_user(a); r := public.create_invitation(); perform ts23.as_user(b); perform public.claim_invitation(r->>'code');
 perform ts23.as_user(a); return (public.respond_to_claim((r->>'id')::uuid,true)->>'couple_id')::uuid; end $$;
grant usage on schema ts23 to authenticated;
grant execute on all functions in schema ts23 to authenticated;
insert into auth.users(id,email,raw_user_meta_data) values
('00000000-0000-4000-a000-000000000023','a23@noodeu.invalid','{"display_name":"A"}'),
('00000000-0000-4000-b000-000000000023','b23@noodeu.invalid','{"display_name":"B"}'),
('00000000-0000-4000-c000-000000000023','c23@noodeu.invalid','{"display_name":"C"}');
do $$ declare a uuid := '00000000-0000-4000-a000-000000000023'; b uuid := '00000000-0000-4000-b000-000000000023'; c uuid := '00000000-0000-4000-c000-000000000023';
 ab uuid; ac uuid; n uuid := gen_random_uuid(); path text; denied boolean := false; r jsonb;
begin
 ab := ts23.pair(a,b); ac := ts23.pair(a,c);
 perform ts23.as_user(a);
 perform ts23.ok((public.save_duo_note(ab,n,'Privé à A-B')->>'ok')::boolean,'A crée note');
 perform ts23.ok((public.save_duo_note(ab,n,'Privé à A-B')->>'ok')::boolean,'double clic idempotent');
 perform ts23.ok(jsonb_array_length(public.get_duo_space(ab)->'notes')=1,'une seule note');
 perform ts23.as_user(b);
 perform ts23.ok(public.get_duo_space(ab)#>>'{notes,0,body}'='Privé à A-B','B lit sa note');
 perform ts23.ok(public.get_duo_space(ac)->>'error'='not_found','B ne lit pas A-C');
 perform ts23.ok((public.save_duo_note(ab,n,'Modifiée par B',null,true,0)->>'ok')::boolean,'B coche');
 perform ts23.ok(public.save_duo_note(ab,n,'Écrasement périmé',null,false,0)->>'error'='conflict','conflit conservé');
 perform ts23.as_user(c);
 perform ts23.ok(public.get_duo_space(ab)->>'error'='not_found','C ne lit pas A-B');
 perform ts23.ok(public.save_duo_note(ab,gen_random_uuid(),'Intrusion')->>'error'='not_found','C ne peut écrire A-B');
 perform ts23.ok(public.save_duo_note(ac,n,'ID volé')->>'error'='not_found','ID note ne traverse pas les duos');
 perform ts23.as_user(a);
 perform ts23.ok(public.save_duo_note(ab,gen_random_uuid(),repeat('x',601))->>'error'='invalid_text','taille note contrôlée serveur');
 path := ab::text || '/' || gen_random_uuid()::text || '.webp';
 perform ts23.ok(public.set_duo_cover(ab,path,0)->>'error'='invalid_file','pas de couverture sans objet');
 set local role authenticated;
 insert into storage.objects(bucket_id,name) values('duo-covers',path);
 perform ts23.ok((public.set_duo_cover(ab,path,0)->>'ok')::boolean,'upload A-B autorisé');
 perform ts23.as_user(c);
 perform ts23.ok((select count(*) from storage.objects where bucket_id='duo-covers' and name=path)=0,'RLS cache objet à C');
 begin insert into storage.objects(bucket_id,name) values('duo-covers',ab::text || '/' || gen_random_uuid()::text || '.webp'); exception when insufficient_privilege then denied := true; end;
 perform ts23.ok(denied,'RLS refuse upload de C dans A-B');
 perform ts23.as_user(b);
 perform ts23.ok((select count(*) from storage.objects where bucket_id='duo-covers' and name=path)=1,'RLS B lit couverture A-B');
 reset role;
 perform ts23.ok((select not public and file_size_limit=2097152 and not ('image/svg+xml'=any(allowed_mime_types)) from storage.buckets where id='duo-covers'),'bucket privé MIME et taille');
end $$;
select 'TOUS LES TESTS ESPACE DUO SONT PASSÉS';
rollback;
