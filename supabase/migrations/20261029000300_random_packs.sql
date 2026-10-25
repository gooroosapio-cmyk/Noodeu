-- File aléatoire serveur persistante pour packs libres ; tests, Aron et séries progressives inchangés.
-- Aucun idx/source_position ni texte du catalogue n'est modifié.
create table private.pack_draws (
 couple_id uuid not null, game_id text not null, cycle integer not null, item_id text not null,
 drawn_at timestamptz not null default now(), primary key(couple_id,game_id,cycle,item_id)
);
alter table private.pack_draws enable row level security;
alter function private.board_setup5(public.game_sessions,jsonb) rename to board_setup5_before_shuffle;
create function private.board_setup5(s public.game_sessions,cfg jsonb) returns jsonb
language plpgsql security definer set search_path='' as $$
declare queue jsonb; ci integer; cy integer; it jsonb; card jsonb;
begin
 if cfg->>'mechanic'<>'pack_conversation' or not coalesce((cfg#>>'{pack,random_order}')::boolean,false) then
  return private.board_setup5_before_shuffle(s,cfg);
 end if;
 if s.current_round<=1 then
  select coalesce(max(cycle),1) into cy from private.pack_draws where couple_id=s.couple_id and game_id=s.game_id;
  select jsonb_agg(x.idx) into queue from (select cb.idx from public.content_banks cb where cb.bank=cfg->>'bank'
   and private.pack_card_ok(s.id,cb.bank,cb.value,private.adult_allowed(s.id))
   and not exists(select 1 from private.pack_draws d where d.couple_id=s.couple_id and d.game_id=s.game_id and d.cycle=cy and d.item_id=cb.value->>'id')
   order by random() limit 50) x;
  if queue is null then
   cy:=cy+1;
   select jsonb_agg(x.idx) into queue from (select cb.idx from public.content_banks cb where cb.bank=cfg->>'bank'
    and private.pack_card_ok(s.id,cb.bank,cb.value,private.adult_allowed(s.id)) order by random() limit 50) x;
  end if;
  if queue is null then raise exception 'not_enough_cards'; end if;
  update public.game_sessions set total_rounds=jsonb_array_length(queue) where id=s.id;
  ci:=0;
 else
  select r.card->'queue',(r.card->>'index')::integer+1,(r.card->>'cycle')::integer into queue,ci,cy
  from public.session_rounds r where r.session_id=s.id and r.round_no=s.current_round-1;
 end if;
 select value into it from public.content_banks where bank=cfg->>'bank' and idx=(queue->>ci)::integer;
 if it is null then raise exception 'not_enough_cards'; end if;
 insert into private.pack_draws(couple_id,game_id,cycle,item_id) values(s.couple_id,s.game_id,cy,it->>'id') on conflict do nothing;
 -- random=true évite d'écrire un index mélangé dans l'ancienne progression séquentielle.
 return jsonb_build_object('mech','pack_conversation','index',ci,'count',jsonb_array_length(queue),'queue',queue,'cycle',cy,'random',true,
  'set_no',null,'set_size',null,'first',1+ci%2,'response',cfg#>>'{pack,response}','scales',cfg#>'{pack,scales}',
  'item',jsonb_build_object('id',it->>'id','text',it->>'text_fr','kind',it->>'kind','bank',cfg->>'bank','response',it->>'response_type',
   'position',it->'source_position','options',it->'options_ordered','theme',it->>'theme','adult',coalesce((it->>'adult')::boolean,false)),
  'status','{}'::jsonb,'answers',null,'done',false,'_secret','{"seats":{}}'::jsonb);
end $$;
revoke all on function private.board_setup5(public.game_sessions,jsonb) from public,anon,authenticated;

-- Nouvelle version seulement : les parties commencées gardent leurs règles et leur ordre.
insert into public.game_versions(game_id,version,rules,config,published_at)
select v.game_id,v.version+1,
 jsonb_set(v.rules,'{how_to}',jsonb_build_array('Les cartes sont tirées au hasard, sans répétition avant épuisement du pack.',
 'Chacun répond en privé puis choisit de partager, garder pour soi ou passer. Les réponses partagées se révèlent ensemble.')),
 jsonb_set(v.config,'{pack,random_order}','true'),now()
from public.games g join public.game_versions v on v.game_id=g.id and v.version=g.current_version
where g.mechanic='pack_conversation' and v.config#>>'{pack,response}'='open'
 and not coalesce((v.config#>>'{pack,random}')::boolean,false)
 and v.config#>>'{pack,set_size}' is null and g.id not in ('ND-Q-P01','ND-Q-P20');
update public.games g set current_version=v.version from public.game_versions v where v.game_id=g.id and v.config#>>'{pack,random_order}'='true' and v.version>g.current_version;
-- P20, séries de cinq, exclu aussi des nouveaux questionnaires aléatoires ; versions antérieures conservées.
insert into public.game_versions(game_id,version,rules,config,published_at)
select v.game_id,v.version+1,v.rules,jsonb_set(v.config,'{pack,pool}',(v.config#>'{pack,pool}')-'q_series'),now()
from public.games g join public.game_versions v on v.game_id=g.id and v.version=g.current_version
where coalesce((v.config#>>'{pack,random}')::boolean,false) and (v.config#>'{pack,pool}') ? 'q_series';
update public.games g set current_version=(select max(version) from public.game_versions where game_id=g.id)
where g.id in ('ND-Q-RND1','ND-Q-RND2');

-- Progression dérivée des identifiants réellement répondus à deux, ancienne et nouvelle version ensemble.
alter function public.get_progress() rename to get_progress_before_shuffle;
create function public.get_progress() returns jsonb language plpgsql stable security definer set search_path='' as $$
declare res jsonb; g record; done_count integer; eligible integer; couple uuid:=private.my_couple_id();
begin
 res:=public.get_progress_before_shuffle();
 for g in select gg.id,v.config from public.games gg join public.game_versions v on v.game_id=gg.id and v.version=gg.current_version
 where v.config#>>'{pack,random_order}'='true' loop
  select count(distinct r.card#>>'{item,id}') into done_count from public.session_rounds r join public.game_sessions s on s.id=r.session_id
  where s.couple_id=couple and s.game_id=g.id and r.revealed_at is not null
   and r.card#>>'{answers,1,choice}' in ('share','private') and r.card#>>'{answers,2,choice}' in ('share','private');
  select count(*) into eligible from public.content_banks where bank=g.config->>'bank';
  if res#>array['games',g.id] is not null then
   res:=jsonb_set(res,array['games',g.id],(res#>array['games',g.id])||jsonb_build_object('cards_done',done_count,'completed',done_count>=eligible,'count',eligible));
  elsif done_count>0 then
   res:=jsonb_set(res,array['games',g.id],jsonb_build_object('kind','pack','cards_done',done_count,'answered',done_count,'completed',done_count>=eligible,'count',eligible,'viewed',done_count,'passed',0));
  end if;
 end loop;
 return res;
end $$;
revoke all on function public.get_progress() from public,anon;
grant execute on function public.get_progress() to authenticated;
