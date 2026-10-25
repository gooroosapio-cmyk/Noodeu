-- Uniquement PostgreSQL jetable : utilisateurs fictifs, transaction annulée.
begin;
create schema fxlobby;
create function fxlobby.as_user(p uuid) returns void language sql as $$ select set_config('request.jwt.claims',json_build_object('sub',p,'role','authenticated')::text,true) $$;
insert into auth.users(id,email,raw_user_meta_data) values
('11111111-1111-4111-8111-111111111111','maya-lobby@noodeu.invalid','{"display_name":"Maya"}'),
('22222222-2222-4222-8222-222222222222','alex-lobby@noodeu.invalid','{"display_name":"Alex"}');
create temp table lobbyout(name text,state jsonb);
do $$ declare inv jsonb;s uuid;g record;begin
perform fxlobby.as_user('11111111-1111-4111-8111-111111111111');inv:=public.create_invitation();
perform fxlobby.as_user('22222222-2222-4222-8222-222222222222');perform public.claim_invitation(inv->>'code');
perform fxlobby.as_user('11111111-1111-4111-8111-111111111111');perform public.respond_to_claim((inv->>'id')::uuid,true);
for g in select id from public.games where id in ('N2-076','N2-079','N2-078','N2-023','N2-083','nd-de-chanceux','N2-018','nd-cite-trois','N2-002','ND-Q-011','ND-Q-P01') loop
s:=(public.create_session(g.id)->>'session_id')::uuid;
if s is null then raise exception 'Salon absent %',g.id;end if;
insert into lobbyout values('lobby-'||lower(g.id),public.get_session_state(s));
perform public.abandon_session(s);
end loop;
end $$;
select json_build_object('name',name,'state',state)::text from lobbyout;
rollback;
