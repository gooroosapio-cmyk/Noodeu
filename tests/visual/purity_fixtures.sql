begin;
create schema fxtheme;
create function fxtheme.user_id(p uuid) returns void language sql as $$ select set_config('request.jwt.claims',json_build_object('sub',p,'role','authenticated')::text,true) $$;
create function fxtheme.answers(n integer,upto integer default 72) returns jsonb language sql as $$ select jsonb_object_agg(value->>'id',case when (value->>'source_position')::integer<=n then 0 else 1 end) from public.content_banks where bank='q_rice' and (value->>'source_position')::integer<=upto $$;
insert into auth.users(id,email,raw_user_meta_data) values
('11111111-1111-4111-8111-111111111111','maya-theme@noodeu.invalid','{"display_name":"Maya"}'),
('22222222-2222-4222-8222-222222222222','alex-theme@noodeu.invalid','{"display_name":"Alex"}');
create temp table themeout(name text,state jsonb);
do $$ declare inv jsonb;s uuid;begin
perform fxtheme.user_id('11111111-1111-4111-8111-111111111111');inv:=public.create_invitation();
perform fxtheme.user_id('22222222-2222-4222-8222-222222222222');perform public.claim_invitation(inv->>'code');
perform fxtheme.user_id('11111111-1111-4111-8111-111111111111');perform public.respond_to_claim((inv->>'id')::uuid,true);
s:=(public.create_session('ND-Q-011')->>'session_id')::uuid;perform public.set_ready(s,true);
perform fxtheme.user_id('22222222-2222-4222-8222-222222222222');perform public.set_ready(s,true);
perform fxtheme.user_id('11111111-1111-4111-8111-111111111111');
perform public.play_move(s,1,gen_random_uuid(),'save',jsonb_build_object('answers',fxtheme.answers(40,60),'page',6));
insert into themeout values('test-rice',public.get_session_state(s));
perform public.play_move(s,1,gen_random_uuid(),'save',jsonb_build_object('answers',fxtheme.answers(50),'page',7));
insert into themeout values('test-rice2-fin',public.get_session_state(s));
perform public.play_move(s,1,gen_random_uuid(),'complete',jsonb_build_object('answers',fxtheme.answers(50),'page',7,'share',true));
insert into themeout values('test-rice2-resultat',public.get_session_state(s));
end $$;
select json_build_object('name',name,'state',state)::text from themeout;
rollback;
