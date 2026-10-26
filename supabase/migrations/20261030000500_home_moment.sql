-- PRÉPARÉE uniquement. Banque originale Noodeu, générale, sans contenus tiers ou intimes.
-- Pas de cron, pas de mutation des questions/réponses des parties existantes.
create table private.home_questions (
 id integer primary key,
 question text not null,
 enabled boolean not null default true,
 provenance text not null default 'Texte original créé pour Noodeu, octobre 2026'
);
alter table private.home_questions enable row level security;
insert into private.home_questions(id,question) values
 (1,'Quel petit détail a rendu ta journée plus agréable ?'),
 (2,'Quel endroit aimerais-tu me faire découvrir ?'),
 (3,'Quelle activité toute simple aimerais-tu essayer à deux ?'),
 (4,'Quelle chanson te donne envie de sourire ?'),
 (5,'Quel souvenir de promenade aimerais-tu raconter ?'),
 (6,'Quel repas aimerais-tu préparer ensemble ?'),
 (7,'Quel talent aimerais-tu apprendre juste pour le plaisir ?'),
 (8,'Quelle couleur décrit le mieux ton humeur du moment ?'),
 (9,'Quelle découverte récente t’a surpris agréablement ?'),
 (10,'À quoi ressemblerait ton dimanche idéal sans programme ?'),
 (11,'Quel objet du quotidien trouves-tu particulièrement ingénieux ?'),
 (12,'Quelle petite tradition aimerais-tu inventer à deux ?');
create table private.home_moments (
 couple_id uuid primary key references public.couples(id),
 slot bigint not null,
 question_id integer references private.home_questions(id)
);
alter table private.home_moments enable row level security;
revoke all on private.home_questions, private.home_moments from public, anon, authenticated;
create function public.get_home_moment(p_couple uuid) returns jsonb
language plpgsql security definer set search_path='' as $$
declare stamp timestamptz:=clock_timestamp(); hour_slot bigint:=floor(extract(epoch from stamp)/3600);
 current_draw private.home_moments; picked integer; question_text text; played integer;
begin
 if not private.is_member(p_couple) then return jsonb_build_object('ok',false,'error','not_found'); end if;
 perform pg_advisory_xact_lock(hashtext('home-hour:'||p_couple::text));
 select * into current_draw from private.home_moments where couple_id=p_couple;
 if current_draw.slot is distinct from hour_slot then
  select q.id into picked from private.home_questions q where q.enabled
   and q.id is distinct from current_draw.question_id
   order by random() limit 1;
  insert into private.home_moments(couple_id,slot,question_id) values(p_couple,hour_slot,picked)
   on conflict(couple_id) do update set slot=excluded.slot,question_id=excluded.question_id;
 else picked:=current_draw.question_id;
 end if;
 select question into question_text from private.home_questions where id=picked and enabled;
 select count(distinct game_id) into played from public.game_sessions where couple_id=p_couple and status in ('ended','closed');
 return jsonb_build_object('ok',true,'question',question_text,'games_played',played,
  'server_now',stamp,'expires_at',to_timestamp((hour_slot+1)*3600));
end $$;
revoke all on function public.get_home_moment(uuid) from public,anon;
grant execute on function public.get_home_moment(uuid) to authenticated;
