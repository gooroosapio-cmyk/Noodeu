-- Uniquement sur PostgreSQL jetable. Aucun compte réel.
begin;
create schema ts25;
create function ts25.as_user(p uuid) returns void language sql as $$ select set_config('request.jwt.claims', json_build_object('sub', p, 'role', 'authenticated')::text, true) $$;
create function ts25.ok(c boolean, msg text) returns void language plpgsql as $$ begin if c is distinct from true then raise exception 'ÉCHEC : %', msg; end if; end $$;
create function ts25.pair(a uuid, b uuid) returns uuid language plpgsql as $$ declare r jsonb; begin
 perform ts25.as_user(a); r := public.create_invitation(); perform ts25.as_user(b); perform public.claim_invitation(r->>'code');
 perform ts25.as_user(a); return (public.respond_to_claim((r->>'id')::uuid,true)->>'couple_id')::uuid; end $$;
grant usage on schema ts25 to authenticated;
grant execute on all functions in schema ts25 to authenticated;
insert into auth.users(id,email,raw_user_meta_data) values
('00000000-0000-4000-a000-000000000025','a25@noodeu.invalid','{"display_name":"A"}'),
('00000000-0000-4000-b000-000000000025','b25@noodeu.invalid','{"display_name":"B"}'),
('00000000-0000-4000-c000-000000000025','c25@noodeu.invalid','{"display_name":"C"}');
do $$ declare a uuid:='00000000-0000-4000-a000-000000000025'; b uuid:='00000000-0000-4000-b000-000000000025';
 s uuid; ab uuid; ids text[]:='{}'; card jsonb; snapshot jsonb; q jsonb; i integer; seen text[]; bank_name text; cfg jsonb;
begin
 ab:=ts25.pair(a,b); perform ts25.as_user(a); s:=(public.create_session('ND-Q-P21')->>'session_id')::uuid;
 perform public.set_ready(s,true); perform ts25.as_user(b); perform public.set_ready(s,true);
 snapshot:=public.get_session_state(s); q:=snapshot#>'{rounds,0,card,queue}';
 perform ts25.ok(jsonb_array_length(q)>1,'file créée côté serveur');
 perform ts25.ok((select count(*)=count(distinct v) from jsonb_array_elements(q) v),'aucun doublon file');
 perform ts25.ok(public.get_session_state(s)#>'{rounds,0,card,queue}'=q,'reconnexion conserve file');
 for i in 1..5 loop
  select r.card into card from public.session_rounds r where r.session_id=s and round_no=i;
  perform ts25.ok(not(card#>>'{item,id}'=any(ids)),'nouvelle carte jamais répétée');ids:=array_append(ids,card#>>'{item,id}');
  perform ts25.as_user(a); perform public.play_move(s,i,gen_random_uuid(),'answer','{"choice":"private","text":"A"}');
  perform ts25.as_user(b); perform public.play_move(s,i,gen_random_uuid(),'answer','{"choice":"private","text":"B"}');
  perform public.next_round(s,i);
 end loop;
 perform ts25.as_user(a);
 perform ts25.ok((public.get_progress()#>>'{games,ND-Q-P21,cards_done}')::integer=5,'progression par IDs répondus ensemble');
 -- Abandon puis nouvelle séance : ne rejoue aucune carte déjà tirée.
 select array_agg(item_id) into seen from private.pack_draws where couple_id=ab and game_id='ND-Q-P21';
 perform public.abandon_session(s);
 s:=(public.create_session('ND-Q-P21')->>'session_id')::uuid;
 perform public.set_ready(s,true);perform ts25.as_user(b);perform public.set_ready(s,true);perform ts25.as_user(a);
 select r.card into card from public.session_rounds r where r.session_id=s and round_no=1;
 perform ts25.ok(not(card#>>'{item,id}'=any(seen)),'pas de répétition après abandon/recréation');
 perform ts25.ok((public.get_progress()#>>'{games,ND-Q-P21,cards_done}')::integer=5,'abandon ne réinitialise pas réponses accomplies');
 -- Fixture réduit l'attente : marque les cartes éligibles restantes comme tirées dans le cycle courant.
 select v.config into cfg from public.games g join public.game_versions v on v.game_id=g.id and v.version=g.current_version where g.id='ND-Q-P21';
 bank_name:=cfg->>'bank';
 insert into private.pack_draws(couple_id,game_id,cycle,item_id)
 select ab,'ND-Q-P21',1,cb.value->>'id' from public.content_banks cb where cb.bank=bank_name
 and private.pack_card_ok(s,cb.bank,cb.value,private.adult_allowed(s)) on conflict do nothing;
 perform public.abandon_session(s);
 s:=(public.create_session('ND-Q-P21')->>'session_id')::uuid;
 perform public.set_ready(s,true);perform ts25.as_user(b);perform public.set_ready(s,true);perform ts25.as_user(a);
 select r.card into card from public.session_rounds r where r.session_id=s and round_no=1;
 perform ts25.ok((card->>'cycle')::integer=2,'cycle suivant seulement après épuisement');
 perform ts25.ok((select count(*)=count(distinct v) from jsonb_array_elements(card->'queue') v),'nouveau cycle sans doublon interne');
 perform ts25.ok(not exists(select 1 from private.pack_progress where couple_id=ab and game_id='ND-Q-P21'),'pas de corruption de next_index');
 perform ts25.ok(not exists(select 1 from public.games g join public.game_versions v on v.game_id=g.id and v.version=g.current_version
  where (g.mechanic='test_form' or g.id in ('ND-Q-P01','ND-Q-P20')) and v.config#>>'{pack,random_order}'='true'),'exceptions structurées intactes');
 perform ts25.ok(not exists(select 1 from public.games g join public.game_versions v on v.game_id=g.id and v.version=g.current_version
  where g.id='ND-Q-RND1' and (v.config#>'{pack,pool}') ? 'q_series'),'séries progressives exclues du mode mélangé');
end $$;
select 'TOUS LES TESTS TIRAGE ET PROGRESSION SONT PASSÉS';
rollback;
