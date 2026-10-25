-- PRÉPARATION uniquement. Fonction désactivée jusqu'à validation propriétaire du worker + nettoyage 24 h.
create table private.media_capabilities (id boolean primary key default true check(id), audio_enabled boolean not null default false);
insert into private.media_capabilities default values;
create table private.audio_answers (
 id uuid primary key, session_id uuid not null references public.game_sessions(id), round_no integer not null,
 user_id uuid not null, path text unique not null, mime text not null check(mime in ('audio/webm','audio/mp4','audio/ogg')),
 state text not null default 'pending' check(state in ('pending','verified','rejected')),
 duration_ms integer check(duration_ms between 1 and 30000), committed boolean not null default false,
 created_at timestamptz not null default now(), expires_at timestamptz not null default now()+interval '24 hours'
);
alter table private.audio_answers enable row level security;
alter table private.media_capabilities enable row level security;
create index audio_expiration on private.audio_answers(expires_at);
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values('answer-audio','answer-audio',false,1048576,array['audio/webm','audio/mp4','audio/ogg']);
create function public.get_audio_capability() returns jsonb language sql stable security definer set search_path='' as $$
 select jsonb_build_object('ok',true,'enabled', audio_enabled) from private.media_capabilities where id $$;
create function public.reserve_answer_audio(p_session uuid,p_round integer,p_id uuid,p_mime text) returns jsonb
language plpgsql security definer set search_path='' as $$
declare r record; c jsonb; a private.audio_answers; ext text;
begin
 if not (select audio_enabled from private.media_capabilities where id) then return jsonb_build_object('ok',false,'error','unavailable'); end if;
 select * into r from private.lock_session(p_session);
 if (r.s).status<>'playing' or (r.s).current_round<>p_round then return jsonb_build_object('ok',false,'error','stale_round'); end if;
 select card into c from public.session_rounds where session_id=p_session and round_no=p_round;
 if c->>'mech'<>'pack_conversation' or (case when jsonb_typeof(c#>'{item,options}')='array' then jsonb_array_length(c#>'{item,options}') else 0 end)>0 or c#>>'{item,response}'='true_false'
 or coalesce((c->>'done')::boolean,false) or c->'status' ? r.seat::text then return jsonb_build_object('ok',false,'error','not_allowed'); end if;
 if p_id is null or p_mime not in ('audio/webm','audio/mp4','audio/ogg') or p_mime is null then return jsonb_build_object('ok',false,'error','invalid_file'); end if;
 select * into a from private.audio_answers where id=p_id;
 if a.id is not null then
   if a.user_id<>auth.uid() or a.session_id<>p_session or a.round_no<>p_round or a.mime<>p_mime or a.expires_at<=now() then return jsonb_build_object('ok',false,'error','not_allowed'); end if;
   return jsonb_build_object('ok',true,'path',a.path,'expires_at',a.expires_at);
 end if;
 if (select count(*) from private.audio_answers where session_id=p_session and round_no=p_round and user_id=auth.uid())>=3 then return jsonb_build_object('ok',false,'error','limit'); end if;
 ext := split_part(p_mime,'/',2);
 insert into private.audio_answers(id,session_id,round_no,user_id,path,mime)
 values(p_id,p_session,p_round,auth.uid(),p_session::text||'/'||p_id::text||'.'||ext,p_mime) returning * into a;
 return jsonb_build_object('ok',true,'path',a.path,'expires_at',a.expires_at);
end $$;
create function private.can_upload_audio(p_path text) returns boolean language sql stable security definer set search_path='' as $$
 select exists(select 1 from private.audio_answers a join public.game_sessions s on s.id=a.session_id
 where a.path=p_path and a.user_id=auth.uid() and a.state='pending' and a.expires_at>now()
 and s.status='playing' and s.current_round=a.round_no and private.is_member(s.couple_id)) $$;
create function private.can_read_audio(p_path text) returns boolean language sql stable security definer set search_path='' as $$
 select exists(select 1 from private.audio_answers a join public.game_sessions s on s.id=a.session_id
 join public.session_rounds r on r.session_id=a.session_id and r.round_no=a.round_no
 join public.session_players p on p.session_id=a.session_id and p.user_id=a.user_id
 where a.path=p_path and a.state='verified' and a.expires_at>now() and private.is_member(s.couple_id)
 and s.status in ('playing','paused','ended') and (a.user_id=auth.uid() or
 (a.committed and r.revealed_at is not null and r.card#>>array['answers',p.seat::text,'choice']='share'
 and r.card#>>array['answers',p.seat::text,'audio_id']=a.id::text))) $$;
create policy answer_audio_insert on storage.objects for insert to authenticated
with check(bucket_id='answer-audio' and private.can_upload_audio(name));
-- Aucune policy SELECT client : empêche les URL signées à longue durée.
-- La fonction Edge read-answer-audio vérifie l'accès à chaque lecture puis transmet les octets sans cache.
create function public.get_answer_audio(p_id uuid) returns jsonb language plpgsql security definer set search_path='' as $$
declare a private.audio_answers;
begin
 select * into a from private.audio_answers where id=p_id;
 if a.id is null or not private.can_read_audio(a.path) then return jsonb_build_object('ok',false,'error','unavailable'); end if;
 return jsonb_build_object('ok',true,'path',a.path,'expires_at',a.expires_at,'duration_ms',a.duration_ms);
end $$;
-- Conserve intégralement le moteur courant (dont pureté), ajoute seulement la modalité libre audio.
alter function private.board_apply5(text,jsonb,jsonb,integer,text,jsonb,uuid) rename to board_apply5_before_audio;
create function private.board_apply5(m text,c jsonb,sec jsonb,seat integer,typ text,p jsonb,p_session uuid) returns jsonb
language plpgsql security definer set search_path='' as $$
declare a private.audio_answers; res jsonb; ans jsonb; sid uuid; rnd integer;
begin
 if m='pack_conversation' and c->'status' ? seat::text then perform private.mv('already_submitted'); end if;
 if not (p ? 'audio_id') then return private.board_apply5_before_audio(m,c,sec,seat,typ,p,p_session); end if;
 if m<>'pack_conversation' or typ<>'answer' or (case when jsonb_typeof(c#>'{item,options}')='array' then jsonb_array_length(c#>'{item,options}') else 0 end)>0
 or c#>>'{item,response}'='true_false' or p->>'choice' not in ('share','private') or p->>'choice' is null
 or p ? 'text' or p ? 'value' then perform private.mv('invalid_move'); end if;
 begin sid := (p->>'audio_id')::uuid; exception when invalid_text_representation then perform private.mv('invalid_move'); end;
 select current_round into rnd from public.game_sessions where id=p_session;
 select * into a from private.audio_answers where id=sid for update;
 if a.id is null or a.user_id<>auth.uid() or a.session_id<>p_session or a.round_no<>rnd
 or a.expires_at<=now() or a.state<>'verified' or a.committed
 or not exists(select 1 from storage.objects where bucket_id='answer-audio' and name=a.path) then perform private.mv('audio_not_ready'); end if;
 -- Le libellé permet de réutiliser le consentement partage existant. Aucun octet audio dans les réponses/coffres.
 res := private.board_apply5_before_audio(m,c,sec,seat,typ,jsonb_build_object('choice',p->>'choice','text','Réponse audio temporaire'),p_session);
 ans := res#>array['secret','seats',seat::text,'answer'];
 ans := ans || jsonb_build_object('audio_id',a.id,'expires_at',a.expires_at);
 res := jsonb_set(res,array['secret','seats',seat::text,'answer'],ans);
 if coalesce((res#>>'{card,done}')::boolean,false) then res := jsonb_set(res,array['card','answers',seat::text],private.pack_public(ans)); end if;
 update private.audio_answers set committed=true where id=a.id;
 return res;
end $$;
-- Interface de maintenance : service_role seulement. Aucun cron installé.
create function public.audio_worker_jobs() returns jsonb language sql security definer set search_path='' as $$
 select coalesce(jsonb_agg(to_jsonb(a)),'[]'::jsonb) from
 (select id,path,mime,state,expires_at from private.audio_answers where expires_at<=now() or state='pending' order by created_at limit 100) a $$;
create function public.verify_answer_audio(p_id uuid,p_duration_ms integer) returns void language plpgsql security definer set search_path='' as $$
begin
 update private.audio_answers set state=case when p_duration_ms between 1 and 30000 then 'verified' else 'rejected' end,
 duration_ms=case when p_duration_ms between 1 and 30000 then p_duration_ms else null end
 where id=p_id and state='pending' and expires_at>now();
end $$;
create function public.finish_audio_expiration(p_id uuid) returns void language plpgsql security definer set search_path='' as $$
declare a private.audio_answers; player_seat text;
begin
 select * into a from private.audio_answers where id=p_id and expires_at<=now() for update;
 if a.id is null or exists(select 1 from storage.objects where bucket_id='answer-audio' and name=a.path) then return; end if;
 select seat::text into player_seat from public.session_players where session_id=a.session_id and user_id=a.user_id;
 update private.round_secrets set secret=jsonb_set(secret,array['seats',player_seat,'answer'],
   (secret#>array['seats',player_seat,'answer'])-'audio_id'-'expires_at' || '{"text":"Audio expiré"}'::jsonb)
 where session_id=a.session_id and round_no=a.round_no and secret#>>array['seats',player_seat,'answer','audio_id']=a.id::text;
 update public.session_rounds set card=jsonb_set(card,array['answers',player_seat],
   (card#>array['answers',player_seat])-'audio_id'-'expires_at' || '{"text":"Audio expiré"}'::jsonb)
 where session_id=a.session_id and round_no=a.round_no and card#>>array['answers',player_seat,'audio_id']=a.id::text;
 update private.board_moves set payload=payload-'audio_id' where session_id=a.session_id and round_no=a.round_no and payload->>'audio_id'=a.id::text;
 -- Appeler uniquement après suppression de l'objet par l'API Storage, jamais DELETE storage.objects.
 delete from private.audio_answers expired where expired.id=p_id and expired.expires_at<=now()
 and not exists(select 1 from storage.objects o where o.bucket_id='answer-audio' and o.name=expired.path);
end $$;
revoke all on function public.get_audio_capability(), public.reserve_answer_audio(uuid,integer,uuid,text), public.get_answer_audio(uuid) from public,anon;
grant execute on function public.get_audio_capability(), public.reserve_answer_audio(uuid,integer,uuid,text), public.get_answer_audio(uuid) to authenticated;
revoke all on function private.can_read_audio(text),private.can_upload_audio(text) from public,anon;
grant execute on function private.can_read_audio(text),private.can_upload_audio(text) to authenticated;
revoke all on function private.board_apply5(text,jsonb,jsonb,integer,text,jsonb,uuid) from public,anon,authenticated;
revoke all on function public.audio_worker_jobs(),public.verify_answer_audio(uuid,integer),public.finish_audio_expiration(uuid) from public,anon,authenticated;
grant execute on function public.audio_worker_jobs(),public.verify_answer_audio(uuid,integer),public.finish_audio_expiration(uuid) to service_role;
