-- Correction additive du Home : contenu existant prioritaire, aucun import ni licence réécrite.
-- C1/C2 restent jouables en phase de test ; droits commerciaux à confirmer (DECISIONS.md).
-- Les 12 textes de 005 restent conservés mais ne servent plus de source automatique.
alter table private.home_moments add column bank text;
alter table private.home_moments add column item_id text;
create function private.home_candidates(p_couple uuid)
returns table(bank text,item_id text,question text)
language sql stable security definer set search_path='' as $$
 select m.bank,m.item_id,cb.value->>'text_fr'
 from public.content_meta m join public.content_banks cb on cb.bank=m.bank and cb.value->>'id'=m.item_id
 where m.bank in ('q_complicite','q_recul','q_emotions','q_reconfort')
 and m.standalone and not m.review and not m.adult
 and not coalesce((cb.value->>'adult')::boolean,false)
 and cb.value->>'kind'='question' and cb.value->>'response_type'='open'
 and nullif(btrim(cb.value->>'text_fr'),'') is not null
 and private.intensity_rank(m.intensity)<=coalesce((select min(private.intensity_rank(p.max_intensity)) from public.couple_members cm join public.profiles p on p.id=cm.user_id where cm.couple_id=p_couple and cm.left_at is null),1)
 and exists(select 1 from public.games g join public.game_versions v on v.game_id=g.id and v.version=g.current_version
   where g.status='published' and g.mechanic='pack_conversation' and g.content_level<>'intime' and v.config->>'bank'=m.bank)
 and not exists(select 1 from public.item_feedback f join public.couple_members cm on cm.user_id=f.user_id
   where cm.couple_id=p_couple and cm.left_at is null and f.bank=m.bank and f.item_id=m.item_id and f.value='trop_intime')
 -- Conserver conservativement les exclusions des membres dans les séances de CE duo.
 -- Une carte sans annotation est exclue si une préférence de thème existe.
 and not exists(select 1 from public.session_prefs sp join public.game_sessions gs on gs.id=sp.session_id
   join public.couple_members cm on cm.user_id=sp.user_id and cm.couple_id=p_couple and cm.left_at is null
   where gs.couple_id=p_couple and cardinality(sp.excluded_topics)>0
   and (jsonb_typeof(cb.value->'topic_tags') is distinct from 'array' or exists(
     select 1 from jsonb_array_elements_text(cb.value->'topic_tags') tag where tag=any(sp.excluded_topics))))
$$;
revoke all on function private.home_candidates(uuid) from public,anon,authenticated;
create or replace function public.get_home_moment(p_couple uuid) returns jsonb
language plpgsql security definer set search_path='' as $$
declare stamp timestamptz:=clock_timestamp(); hour_slot bigint:=floor(extract(epoch from stamp)/3600);
 current_draw private.home_moments; picked record; question_text text; played integer; eligible integer;
begin
 if not private.is_member(p_couple) then return jsonb_build_object('ok',false,'error','not_found'); end if;
 perform pg_advisory_xact_lock(hashtext('home-hour:'||p_couple::text));
 select * into current_draw from private.home_moments where couple_id=p_couple;
 select count(*) into eligible from private.home_candidates(p_couple);
 if current_draw.slot is distinct from hour_slot or (current_draw.bank is null and current_draw.question_id is not null) then
  select * into picked from private.home_candidates(p_couple) q
   where (q.bank,q.item_id) is distinct from (current_draw.bank,current_draw.item_id) order by random() limit 1;
  insert into private.home_moments(couple_id,slot,question_id,bank,item_id) values(p_couple,hour_slot,null,picked.bank,picked.item_id)
   on conflict(couple_id) do update set slot=excluded.slot,question_id=null,bank=excluded.bank,item_id=excluded.item_id
   returning * into current_draw;
 end if;
 select q.question into question_text from private.home_candidates(p_couple) q where q.bank=current_draw.bank and q.item_id=current_draw.item_id;
 select count(distinct game_id) into played from public.game_sessions where couple_id=p_couple and status in ('ended','closed');
 return jsonb_build_object('ok',true,'question',question_text,'games_played',played,'eligible_count',eligible,
  'source','existing_catalogue','rights_status','commercial_rights_unconfirmed','bank',current_draw.bank,'item_id',current_draw.item_id,
  'server_now',stamp,'expires_at',to_timestamp((hour_slot+1)*3600));
end $$;
