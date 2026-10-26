-- Uniquement PostgreSQL jetable : utilisateurs fictifs, transaction annulée.
begin;
create schema fxlobby;
create function fxlobby.as_user(p uuid) returns void language sql as $$ select set_config('request.jwt.claims',json_build_object('sub',p,'role','authenticated')::text,true) $$;
insert into auth.users(id,email,raw_user_meta_data) values
('11111111-1111-4111-8111-111111111111','maya-lobby@noodeu.invalid','{"display_name":"Maya"}'),
('22222222-2222-4222-8222-222222222222','alex-lobby@noodeu.invalid','{"display_name":"Alex"}');
create temp table lobbyout(name text,state jsonb);
do $$ declare inv jsonb;s uuid;g record;c jsonb;mv jsonb;res jsonb;n int;actor_seat int;rno int;begin
perform fxlobby.as_user('11111111-1111-4111-8111-111111111111');inv:=public.create_invitation();
perform fxlobby.as_user('22222222-2222-4222-8222-222222222222');perform public.claim_invitation(inv->>'code');
perform fxlobby.as_user('11111111-1111-4111-8111-111111111111');perform public.respond_to_claim((inv->>'id')::uuid,true);
for g in select id from public.games where id in ('N2-076','N2-079','N2-083','nd-de-chanceux','N2-078') loop
s:=(public.create_session(g.id)->>'session_id')::uuid;
perform public.set_ready(s,true);
perform fxlobby.as_user('22222222-2222-4222-8222-222222222222');perform public.set_ready(s,true);
perform fxlobby.as_user('11111111-1111-4111-8111-111111111111');
n:=0;
while (select status from public.game_sessions where id=s)='playing' and n<600 loop
 select r.card,r.round_no into c,rno from public.session_rounds r join public.game_sessions gs on gs.id=r.session_id and gs.current_round=r.round_no where gs.id=s;
 if (c->>'done')::boolean then
  perform fxlobby.as_user('11111111-1111-4111-8111-111111111111');
  insert into lobbyout values('progress-'||lower(g.id)||'-reveal-'||rno,public.get_session_state(s));
  perform public.next_round(s,rno);
 else
  foreach actor_seat in array array[1,2] loop
   mv:=private.board_bot_any(c->>'mech',c,(select secret from private.round_secrets where session_id=s and round_no=rno),actor_seat);
   if mv is not null then
    perform fxlobby.as_user((select user_id from public.session_players where session_id=s and session_players.seat=actor_seat));
    res:=public.play_move(s,rno,gen_random_uuid(),mv->>'type',coalesce(mv->'payload','{}'));
    if (res->>'ok')::boolean is not true then raise exception 'Coup rejeté % %',g.id,res;end if;
    exit;
   end if;
  end loop;
 end if;
 n:=n+1;
end loop;
if (select status from public.game_sessions where id=s)<>'ended' then raise exception 'Non terminé %',g.id;end if;
perform fxlobby.as_user('11111111-1111-4111-8111-111111111111');
insert into lobbyout values('progress-'||lower(g.id)||'-results',public.get_session_state(s));
perform public.close_session(s);
end loop;
end $$;
select json_build_object('name',name,'state',state)::text from lobbyout;
rollback;
