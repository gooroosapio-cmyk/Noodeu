-- Version additive du tirage général. Ne change ni les textes, ni les positions, ni les licences.
-- Les sessions anciennes conservent leur config et leur moteur. Aucun scheduler.
alter function private.board_setup5(public.game_sessions,jsonb) rename to board_setup5_before_mixed;
create function private.board_setup5(s public.game_sessions,cfg jsonb) returns jsonb
language plpgsql security definer set search_path='' as $$
declare queue jsonb; ci integer; cy integer; it jsonb; bank_name text;
begin
 if not coalesce((cfg#>>'{pack,mixed_queue}')::boolean,false) then
  return private.board_setup5_before_mixed(s,cfg);
 end if;
 if s.current_round<=1 then
  select coalesce(max(cycle),1) into cy from private.pack_draws where couple_id=s.couple_id and game_id=s.game_id;
  -- Une exclusion personnelle de l'un des deux suffit, sans exposer son auteur au partenaire.
  for attempt in 1..2 loop
   select jsonb_agg(jsonb_build_array(x.bank,x.idx)) into queue from (
    select cb.bank,cb.idx from public.content_banks cb
    where cb.bank in (select jsonb_array_elements_text(cfg#>'{pack,pool}'))
     and private.pack_card_ok(s.id,cb.bank,cb.value,private.adult_allowed(s.id))
     -- Sans annotation de thèmes, ne pas promettre de respecter une exclusion inconnue.
     and (cardinality(private.excluded_tags(s.id))=0 or
       (jsonb_typeof(cb.value->'topic_tags')='array' and not exists(
        select 1 from jsonb_array_elements_text(cb.value->'topic_tags') tag where tag=any(private.excluded_tags(s.id)))))
     and not exists(select 1 from public.item_feedback f join public.session_players p on p.user_id=f.user_id
       where p.session_id=s.id and f.bank=cb.bank and f.item_id=cb.value->>'id' and f.value='trop_intime')
     and not exists(select 1 from private.pack_draws d where d.couple_id=s.couple_id and d.game_id=s.game_id
       and d.cycle=cy and d.item_id=cb.bank||':'||(cb.value->>'id'))
    order by random() limit greatest(1,least(20,coalesce((s.settings->>'questions')::int,10)))) x;
   exit when queue is not null;
   cy:=cy+1;
  end loop;
  if queue is null then raise exception 'not_enough_cards'; end if;
  update public.game_sessions set total_rounds=jsonb_array_length(queue) where id=s.id;
  ci:=0;
 else
  select r.card->'queue',(r.card->>'index')::int+1,(r.card->>'cycle')::int into queue,ci,cy
   from public.session_rounds r where r.session_id=s.id and r.round_no=s.current_round-1;
 end if;
 -- Question supprimée par l'administration après le tirage : sautée (intégration Admin).
 loop
  exit when ci>=jsonb_array_length(queue);
  bank_name:=queue->ci->>0;
  select value into it from public.content_banks where bank=bank_name and idx=(queue->ci->>1)::int;
  exit when it is not null;
  ci:=ci+1;
 end loop;
 if it is null then raise exception 'not_enough_cards'; end if;
 insert into private.pack_draws(couple_id,game_id,cycle,item_id) values(s.couple_id,s.game_id,cy,bank_name||':'||(it->>'id')) on conflict do nothing;
 return jsonb_build_object('mech','pack_conversation','index',ci,'count',jsonb_array_length(queue),'queue',queue,'cycle',cy,'random',true,
 'set_no',null,'set_size',null,'first',1+ci%2,'response','open','scales','{}'::jsonb,
 'item',jsonb_build_object('id',it->>'id','text',it->>'text_fr','kind',it->>'kind','bank',bank_name,
 'response',it->>'response_type','position',it->'source_position','options',it->'options_ordered','adult',coalesce((it->>'adult')::boolean,false)),
 'status','{}'::jsonb,'answers',null,'done',false,'_secret','{"seats":{}}'::jsonb);
end $$;
revoke all on function private.board_setup5(public.game_sessions,jsonb) from public,anon,authenticated;
insert into public.game_versions(game_id,version,rules,config,published_at)
select g.id,v.version+1,
 jsonb_set(jsonb_set(v.rules,'{objective}',to_jsonb('Des questions variées pour échanger, y compris des questions À huis clos.'::text)),
 '{how_to,1}',to_jsonb('Les questions libres de Se découvrir et À huis clos sont tirées au hasard, sans répétition avant épuisement de la banque disponible.'::text)),
 jsonb_set(jsonb_set(v.config,'{pack,mixed_queue}','true'),'{pack,pool}',
 (select jsonb_agg(bank order by bank) from (
  select distinct bank from jsonb_array_elements_text((v.config#>'{pack,pool}')||
   '["q_hc_envies","q_hc_parler","q_hc_corps","q_hc_protection","q_hc_plaisir","q_hc_envies_plus","q_hc_intimite_plus","q_hc_complements"]'::jsonb) b(bank)
  where bank not in ('q_aron','q_series')
 ) banks)),now()
from public.games g join public.game_versions v on v.game_id=g.id and v.version=g.current_version where g.id='ND-Q-RND1';
update public.games set current_version=(select max(version) from public.game_versions where game_id='ND-Q-RND1'),
 adult_available=true,content_level='standard',promise='Questions variées, y compris À huis clos.',hook='Questions variées, y compris À huis clos.' where id='ND-Q-RND1';
