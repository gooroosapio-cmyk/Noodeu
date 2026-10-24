-- Tests du catalogue final : banques écrasées, rubriques, cartes +18 sautées dans les packs, questionnaire aléatoire,
-- test de pureté sans score. Transaction annulée à la fin : aucune donnée ne reste.
begin;

create schema t12;
create function t12.as_user(p uuid) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', json_build_object('sub', p, 'role', 'authenticated')::text, true);
end $$;
create function t12.ok(cond boolean, msg text) returns void language plpgsql as $$
begin
  if cond is distinct from true then raise exception 'ÉCHEC : %', msg; end if;
end $$;
create function t12.card(s uuid) returns jsonb language sql as $$
  select card from public.session_rounds r join public.game_sessions g on g.id = r.session_id and r.round_no = g.current_round where g.id = s $$;
create function t12.uid(s uuid, seat int) returns uuid language sql as $$
  select user_id from public.session_players where session_id = s and seat = $2 $$;
create function t12.mv(s uuid, seat int, typ text, p jsonb default '{}') returns jsonb language plpgsql as $$
begin
  perform t12.as_user(t12.uid(s, seat));
  return public.play_move(s, (select current_round from public.game_sessions where id = s), gen_random_uuid(), typ, p);
end $$;
create function t12.start(gid text, adult boolean default false) returns uuid language plpgsql as $$
declare s uuid;
begin
  update public.game_sessions set status = 'abandoned' where status in ('lobby', 'playing', 'paused', 'ended');
  perform t12.as_user('00000000-0000-4000-a000-0000000000a2');
  s := (public.create_session(gid) ->> 'session_id')::uuid;
  if adult then
    perform public.set_session_prefs(s, true, '{}');
    perform t12.as_user('00000000-0000-4000-a000-0000000000b2');
    perform public.set_session_prefs(s, true, '{}');
    perform t12.as_user('00000000-0000-4000-a000-0000000000a2');
  end if;
  perform public.set_ready(s, true);
  perform t12.as_user('00000000-0000-4000-a000-0000000000b2');
  perform public.set_ready(s, true);
  return s;
end $$;

grant usage on schema t12 to authenticated;
grant execute on all functions in schema t12 to authenticated;

insert into auth.users (id, email, raw_user_meta_data) values
  ('00000000-0000-4000-a000-0000000000a2', 'joueur-a2@noodeu.invalid', '{"display_name":"A"}'),
  ('00000000-0000-4000-a000-0000000000b2', 'joueur-b2@noodeu.invalid', '{"display_name":"B"}'),
  ('00000000-0000-4000-a000-0000000000c2', 'solo-c2@noodeu.invalid', '{"display_name":"C"}');
do $$
declare r jsonb;
begin
  perform t12.as_user('00000000-0000-4000-a000-0000000000a2');
  r := public.create_invitation();
  perform t12.as_user('00000000-0000-4000-a000-0000000000b2');
  perform public.claim_invitation(r ->> 'code');
  perform t12.as_user('00000000-0000-4000-a000-0000000000a2');
  perform public.respond_to_claim((r ->> 'id')::uuid, true);
end $$;

-- ===== Catalogue et rubriques =====
do $$ begin
  perform t12.ok(not exists (select 1 from public.content_banks where value ->> 'id' like 'ARON36-%' or value ->> 'id' like 'G02-J%'
                             or value ->> 'id' like 'GOTTMAN_OPEN30-%' or value ->> 'id' like 'RICE100-%'), 'anciennes questions écrasées');
  perform t12.ok((select count(*) from public.content_banks where value ->> 'id' ~ '^C[1-5]-\d{2}-\d{3}$') = 805, '805 entrées du catalogue');
  perform t12.ok((select count(*) from public.content_banks where value ->> 'id' like 'PK-G%') = 120, 'packs G05, G08, G09, G10 : 4 × 30');
  perform t12.ok(not exists (select 1 from public.games where status = 'published' and category_id = 'nd-mieux-se-comprendre'),
                 'plus aucune activité dans « Mieux se comprendre »');
  perform t12.ok((select count(*) from public.games g join public.game_versions v on v.game_id = g.id and v.version = g.current_version
                  where g.status = 'published' and v.config ->> 'bank' is not null and not exists (
                    select 1 from public.content_banks cb where cb.bank = v.config ->> 'bank')) = 0, 'chaque activité a sa banque');
  perform t12.ok(not exists (select 1 from public.content_meta m where not exists (
                   select 1 from public.content_banks cb where cb.bank = m.bank and cb.value ->> 'id' = m.item_id)), 'aucun classement orphelin');
end $$;

-- ===== Pack avec cartes +18 : sautées sans l'accord des deux, ordre conservé =====
do $$
declare s uuid; i int; adult_seen boolean := false;
begin
  update public.profiles set intimate_opt_in = true, adult_confirmed_at = now(), max_intensity = 'hot'
    where id in ('00000000-0000-4000-a000-0000000000a2', '00000000-0000-4000-a000-0000000000b2');
  s := t12.start('ND-Q-P15');
  perform t12.ok((select total_rounds from public.game_sessions where id = s)
                 = (select count(*) from public.content_banks where bank = 'q_usu_roadtrip' and not (value ->> 'adult')::boolean),
                 'séance : seulement les cartes non +18');
  for i in 1..60 loop
    adult_seen := adult_seen or (t12.card(s) #>> '{item,adult}')::boolean;
    perform t12.mv(s, 1, 'answer', '{"choice": "pass"}');
    perform t12.mv(s, 2, 'answer', '{"choice": "pass"}');
    exit when (select current_round >= total_rounds from public.game_sessions where id = s);
    perform t12.as_user(t12.uid(s, 1));
    perform public.next_round(s, (select current_round from public.game_sessions where id = s));
  end loop;
  perform t12.ok(not adult_seen, 'aucune carte +18 sans accord');
  perform t12.ok((select array_agg((card ->> 'index')::int order by round_no) = array(select x from unnest(array_agg((card ->> 'index')::int order by round_no)) x order by x)
                  from public.session_rounds where session_id = s), 'ordre du pack conservé');
  s := t12.start('ND-Q-P15', true);
  perform t12.ok((select total_rounds from public.game_sessions where id = s) = 50, 'avec l''accord des deux : toutes les cartes (50 au plus par séance)');
end $$;

-- ===== Questionnaire aléatoire =====
do $$
declare s uuid; r jsonb; i int;
begin
  update public.profiles set max_intensity = 'moyen' where id = '00000000-0000-4000-a000-0000000000b2';
  perform t12.as_user('00000000-0000-4000-a000-0000000000a2');
  update public.game_sessions set status = 'abandoned' where status in ('lobby', 'playing', 'paused', 'ended');
  s := (public.create_session('ND-Q-RND1') ->> 'session_id')::uuid;
  perform t12.ok((public.update_session_settings(s, '{"questions": 7}') ->> 'ok')::boolean is not true, 'nombre hors 5/10/20 refusé');
  perform public.update_session_settings(s, '{"questions": 5}');
  perform public.set_ready(s, true);
  perform t12.as_user('00000000-0000-4000-a000-0000000000b2');
  perform public.set_ready(s, true);
  r := t12.card(s);
  perform t12.ok((select total_rounds from public.game_sessions where id = s) = 5 and jsonb_array_length(r -> 'queue') = 5, '5 questions tirées');
  perform t12.ok(not exists (select 1 from jsonb_array_elements(r -> 'queue') q join public.content_banks cb on cb.bank = q ->> 0 and cb.idx = (q ->> 1)::int
                             left join public.content_meta m on m.bank = cb.bank and m.item_id = cb.value ->> 'id'
                             where (cb.value ->> 'adult')::boolean or m.intensity = 'hot'
                                or cb.bank not in ('q_gottman_open', 'q_usu_roadtrip', 'q_series', 'q_complicite', 'q_recul', 'q_emotions', 'q_reconfort')),
                 'tirage : rubrique Se découvrir, ni +18 sans accord, ni au-delà du plafond, jamais Aron ni un test');
  for i in 1..5 loop
    perform t12.mv(s, 1, 'answer', '{"choice": "pass"}');
    perform t12.mv(s, 2, 'answer', '{"choice": "pass"}');
    exit when i = 5;
    perform t12.as_user(t12.uid(s, 1));
    perform public.next_round(s, i);
    perform t12.ok((t12.card(s) ->> 'index')::int = i and t12.card(s) -> 'queue' = r -> 'queue', 'suite de la même liste');
  end loop;
  perform t12.ok(not exists (select 1 from private.pack_progress where game_id = 'ND-Q-RND1'), 'aucune progression de pack');
  perform t12.as_user(t12.uid(s, 1));
  perform t12.ok((public.save_for_later(s, 5) ->> 'ok')::boolean, 'Plus tard accepté');
  perform t12.ok(exists (select 1 from public.later_items l
                   where l.user_id = auth.uid() and l.item_id = t12.card(s) #>> '{item,id}' and l.bank = t12.card(s) #>> '{item,bank}'),
                 '« Plus tard » dans un questionnaire aléatoire');
  perform t12.ok(not coalesce((select bool_or(public.get_two_truths_idea(s) ->> 'text' in (select value ->> 'text' from public.content_banks
                   where bank = 'conv_two_truths_ideas' and (value ->> 'adult')::boolean)) from generate_series(1, 20)), false),
                 'idées de Deux vérités : jamais +18 sans l''accord des deux');
end $$;

select 'TOUS LES TESTS DU CATALOGUE FINAL SONT PASSÉS';
rollback;
