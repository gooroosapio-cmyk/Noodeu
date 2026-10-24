-- Tests des parcours : majorité déclarée, plafond d'intensité commun, filtre +18, pause à double reprise,
-- « Plus tard », favoris et retours privés, question du jour partagée, progression, défi léger et rappels doux.
-- Transaction annulée à la fin : aucune donnée ne reste.
begin;

create schema t11;
create function t11.as_user(p uuid) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', json_build_object('sub', p, 'role', 'authenticated')::text, true);
end $$;
create function t11.ok(cond boolean, msg text) returns void language plpgsql as $$
begin
  if cond is distinct from true then raise exception 'ÉCHEC : %', msg; end if;
end $$;
create function t11.card(s uuid) returns jsonb language sql as $$
  select card from public.session_rounds r join public.game_sessions g on g.id = r.session_id and r.round_no = g.current_round where g.id = s $$;
create function t11.uid(s uuid, seat int) returns uuid language sql as $$
  select user_id from public.session_players where session_id = s and seat = $2 $$;
create function t11.mv(s uuid, seat int, typ text, p jsonb default '{}') returns jsonb language plpgsql as $$
begin
  perform t11.as_user(t11.uid(s, seat));
  return public.play_move(s, (select current_round from public.game_sessions where id = s), gen_random_uuid(), typ, p);
end $$;
create function t11.start(gid text, adult boolean default false) returns uuid language plpgsql as $$
declare s uuid;
begin
  update public.game_sessions set status = 'abandoned' where status in ('lobby', 'playing', 'paused', 'ended');
  perform t11.as_user('00000000-0000-4000-a000-0000000000a1');
  s := (public.create_session(gid) ->> 'session_id')::uuid;
  if adult then
    perform public.set_session_prefs(s, true, '{}');
    perform t11.as_user('00000000-0000-4000-a000-0000000000b1');
    perform public.set_session_prefs(s, true, '{}');
    perform t11.as_user('00000000-0000-4000-a000-0000000000a1');
  end if;
  perform public.set_ready(s, true);
  perform t11.as_user('00000000-0000-4000-a000-0000000000b1');
  perform public.set_ready(s, true);
  return s;
end $$;

grant usage on schema t11 to authenticated;
grant execute on all functions in schema t11 to authenticated;

insert into auth.users (id, email, raw_user_meta_data) values
  ('00000000-0000-4000-a000-0000000000a1', 'joueur-a1@noodeu.invalid', '{"display_name":"A"}'),
  ('00000000-0000-4000-a000-0000000000b1', 'joueur-b1@noodeu.invalid', '{"display_name":"B"}'),
  ('00000000-0000-4000-a000-0000000000c1', 'solo-c1@noodeu.invalid', '{"display_name":"C"}');
do $$
declare r jsonb;
begin
  perform t11.as_user('00000000-0000-4000-a000-0000000000a1');
  r := public.create_invitation();
  perform t11.as_user('00000000-0000-4000-a000-0000000000b1');
  perform public.claim_invitation(r ->> 'code');
  perform t11.as_user('00000000-0000-4000-a000-0000000000a1');
  perform public.respond_to_claim((r ->> 'id')::uuid, true);
end $$;

-- ===== Classement =====
do $$ begin
  perform t11.ok((select count(*) from public.content_meta) = 804, 'questions classées (catalogue final, hors tests standardisés)');
  perform t11.ok(not exists (select 1 from public.content_meta m join public.content_banks cb on cb.bank = m.bank and cb.value ->> 'id' = m.item_id
                             where coalesce((cb.value ->> 'adult')::boolean, false) <> m.adult), '+18 du classement = +18 du kit');
  perform t11.ok(not exists (select 1 from public.content_meta where bank like 'q_rice' or bank in ('q_ipip', 'q_qsi', 'q_spn', 'q_aairs', 'q_csi', 'q_ecrrs')),
                 'tests standardisés jamais classés question par question');
  perform t11.ok(not exists (select 1 from public.content_meta where bank = 'q_aron' and standalone), 'Aron (ordre imposé) jamais en question du jour');
  perform t11.ok((select count(*) from public.games where status = 'published' and intensity is null) = 0, 'chaque activité classée');
  perform t11.ok(not exists (select 1 from public.content_banks cb where cb.bank = 'q_aron'
                             and cb.value ->> 'text_fr' is distinct from (select value ->> 'text_fr' from public.content_banks x where x.bank = cb.bank and x.idx = cb.idx)),
                 'textes inchangés');
end $$;

-- ===== Majorité et préférences =====
do $$
declare f jsonb;
begin
  begin
    update public.profiles set intimate_opt_in = true where id = '00000000-0000-4000-a000-0000000000a1';
    perform t11.ok(false, '+18 sans majorité déclarée refusé');
  exception when raise_exception then
    perform t11.ok(sqlerrm = 'adult_confirmation_required', 'majorité exigée');
  end;
  update public.profiles set reminders = '{"enabled": true, "per_week": 50, "quiet_start": 30, "quiet_end": 9}' where id = '00000000-0000-4000-a000-0000000000a1';
  perform t11.ok((select (reminders ->> 'per_week')::int = 3 and (reminders ->> 'quiet_start')::int = 23 from public.profiles
                  where id = '00000000-0000-4000-a000-0000000000a1'), 'rappels plafonnés à 3 par semaine');
  update public.profiles set max_intensity = 'hot' where id = '00000000-0000-4000-a000-0000000000a1';
  update public.profiles set max_intensity = 'soft' where id = '00000000-0000-4000-a000-0000000000b1';
  perform t11.as_user('00000000-0000-4000-a000-0000000000a1');
  f := public.get_my_filters();
  perform t11.ok(f ->> 'my_max' = 'hot' and (f ->> 'duo_cap')::int = 1 and not (f ->> 'duo_adult')::boolean, 'plafond commun = le plus bas des deux');
  perform t11.ok(public.create_session('ND-Q-P01') ->> 'error' = 'filtered_out', 'pack Moyen refusé si l''un accepte seulement Soft');
  update public.profiles set max_intensity = 'moyen' where id = '00000000-0000-4000-a000-0000000000b1';
end $$;

-- ===== Plafond dans les tirages et +18 =====
do $$
declare s uuid; i int; x jsonb; hot boolean;
begin
  update public.profiles set intimate_opt_in = true, adult_confirmed_at = now() where id in ('00000000-0000-4000-a000-0000000000a1', '00000000-0000-4000-a000-0000000000b1');
  s := t11.start('N2-003', true);
  perform t11.ok(private.adult_allowed(s), 'deux accords +18 dans le salon');
  for i in 1..60 loop
    x := private.conv_draw(s, 'conv_never');
    perform t11.ok(not exists (select 1 from public.content_meta m where m.bank = 'conv_never'
                               and m.item_id = x ->> 'id' and m.intensity = 'hot'),
                   'jamais de carte Hot si l''un accepte au plus Moyen, même avec les deux +18');
  end loop;
  update public.profiles set max_intensity = 'hot' where id = '00000000-0000-4000-a000-0000000000b1';
  hot := false;
  for i in 1..300 loop
    x := private.conv_draw(s, 'conv_never');
    hot := hot or exists (select 1 from public.content_meta m where m.bank = 'conv_never' and m.item_id = x ->> 'id' and m.intensity = 'hot');
  end loop;
  perform t11.ok(hot, 'Hot tirable quand les deux l''acceptent');
  perform t11.as_user(t11.uid(s, 2));
  perform public.set_session_prefs(s, false, '{}');
  for i in 1..60 loop
    perform t11.ok(not coalesce((private.conv_draw(s, 'conv_never') ->> 'adult')::boolean, false), 'retrait +18 : aucune carte +18 tirée');
  end loop;
end $$;

-- ===== Pause à double reprise, chronos suspendus =====
do $$
declare s uuid; c jsonb; before_deadline timestamptz; r jsonb;
begin
  s := t11.start('N2-083');
  c := t11.card(s);
  before_deadline := (c ->> 'deadline_at')::timestamptz;
  perform t11.as_user(t11.uid(s, 1));
  perform public.set_paused(s, true);
  perform t11.ok(t11.mv(s, 2, 'lock_gesture', '{"gesture": "rock"}') ->> 'error' = 'paused', 'aucun coup pendant la pause');
  update public.game_sessions set pause_state = jsonb_set(pause_state, '{paused_at}', to_jsonb(now() - interval '45 seconds')) where id = s;
  perform t11.as_user(t11.uid(s, 1));
  r := public.set_paused(s, false);
  perform t11.ok((r ->> 'waiting')::boolean and (select status from public.game_sessions where id = s) = 'paused', 'une seule demande de reprise ne suffit pas');
  perform t11.ok((public.get_session_state(s) #>> '{session,pause_state,resume,0}') = '1', 'demande de reprise visible');
  perform t11.as_user(t11.uid(s, 2));
  r := public.set_paused(s, false);
  perform t11.ok((r ->> 'resumed')::boolean and (select status from public.game_sessions where id = s) = 'playing', 'reprise avec l''accord des deux');
  perform t11.ok((t11.card(s) ->> 'deadline_at')::timestamptz = before_deadline + interval '45 seconds', 'échéance décalée de la durée de la pause');
  perform t11.as_user(t11.uid(s, 1));
  r := public.finish_session(s);
  perform t11.ok((r ->> 'ok')::boolean and (select status from public.game_sessions where id = s) = 'ended', 'Arrêter termine pour les deux');
end $$;

-- ===== Plus tard, favoris, retours : strictement personnels =====
do $$
declare s uuid; items jsonb; notes int;
begin
  s := t11.start('ND-Q-P03');
  notes := (select count(*) from public.notifications);
  perform t11.as_user(t11.uid(s, 1));
  perform t11.ok((public.save_for_later(s, 1) ->> 'ok')::boolean, 'question mise de côté');
  perform t11.ok((public.save_for_later(s, 1) ->> 'ok')::boolean, 'double appel sans doublon');
  items := public.get_my_items();
  perform t11.ok(jsonb_array_length(items -> 'later') = 1 and items #>> '{later,0,view,text}' = t11.card(s) #>> '{item,text}', 'texte retrouvé');
  insert into public.item_favorites (user_id, kind, bank, item_id) values (auth.uid(), 'question', 'conv_never', 'C3-03-001');
  insert into public.item_feedback (user_id, bank, item_id, value) values (auth.uid(), 'conv_never', 'C3-03-001', 'trop_intime');
  perform t11.as_user(t11.uid(s, 2));
  set local role authenticated;
  perform t11.ok((select count(*) from public.later_items) = 0 and (select count(*) from public.item_favorites) = 0
                 and (select count(*) from public.item_feedback) = 0, 'rien de visible pour le partenaire');
  perform t11.ok(jsonb_array_length(public.get_my_items() -> 'later') = 0, 'pas de « Plus tard » partagé');
  reset role;
  perform t11.ok((select count(*) from public.notifications) = notes, 'aucune relance envoyée au partenaire');
  perform t11.as_user(t11.uid(s, 1));
  perform t11.ok((public.get_session_meta(s) #>> array['items', t11.card(s) #>> '{item,id}', 'duration_kind']) = 'discussion', 'durée de la carte');
end $$;

-- ===== Question du jour =====
do $$
declare d1 jsonb; d2 jsonb; d3 jsonb; solo jsonb; k int;
begin
  perform t11.as_user('00000000-0000-4000-a000-0000000000a1');
  d1 := public.get_daily(null, null, 'Europe/Paris');
  perform t11.as_user('00000000-0000-4000-a000-0000000000b1');
  d2 := public.get_daily(null, null, 'America/Montreal');
  perform t11.ok(d1 ->> 'item_id' = d2 ->> 'item_id' and (d1 ->> 'shared')::boolean, 'même question pour les deux');
  perform t11.ok((select timezone from public.couples where id = private.my_couple_id()) = 'Europe/Paris', 'fuseau du duo conservé');
  perform t11.ok((d1 ->> 'day')::date = (now() at time zone 'Europe/Paris')::date, 'journée selon le fuseau du duo');
  perform t11.ok(exists (select 1 from public.content_meta m where m.bank = d1 ->> 'bank' and m.item_id = d1 ->> 'item_id'
                         and m.standalone and not m.review and not m.adult), 'question autonome, relue, non +18 par défaut');
  perform t11.ok(public.get_daily() ->> 'item_id' = d1 ->> 'item_id', 'conservée pour la journée');
  d3 := public.get_daily('theme', 'Recul et quotidien');
  perform t11.ok((select theme from public.content_meta where bank = d3 ->> 'bank' and item_id = d3 ->> 'item_id') = 'Recul et quotidien', 'tirage thématique');
  perform t11.as_user('00000000-0000-4000-a000-0000000000a1');
  perform t11.ok(public.get_daily() ->> 'item_id' = d3 ->> 'item_id', 'changement de thème visible par les deux');
  -- Pas de répétition récente : 20 jours simulés.
  for k in 1..20 loop
    insert into public.daily_cards (scope, day, bank, item_id) select 'c:' || private.my_couple_id()::text, current_date - k, bank, item_id
      from public.content_meta m where standalone and not review and not adult
        and not exists (select 1 from public.daily_cards t where t.scope = 'c:' || private.my_couple_id()::text
                        and t.bank = m.bank and t.item_id = m.item_id)
      order by random() limit 1 on conflict do nothing;
  end loop;
  perform t11.ok(not exists (select 1 from public.daily_cards a join public.daily_cards b on a.scope = b.scope and a.bank = b.bank
                             and a.item_id = b.item_id and a.day < b.day where a.scope = 'c:' || private.my_couple_id()::text
                             and b.day = (now() at time zone 'Europe/Paris')::date), 'pas de répétition sur 90 jours');
  perform t11.as_user('00000000-0000-4000-a000-0000000000c1');
  solo := public.get_daily(null, null, 'Europe/Brussels');
  perform t11.ok((solo ->> 'ok')::boolean and not (solo ->> 'shared')::boolean, 'question du jour aussi en solo');
end $$;

-- ===== Progression : compteurs seulement, une question passée n'est pas répondue =====
do $$
declare s uuid; p jsonb;
begin
  s := t11.start('ND-Q-P13');
  perform t11.mv(s, 1, 'answer', '{"choice": "private", "value": 1}');
  perform t11.mv(s, 2, 'answer', '{"choice": "pass"}');
  perform t11.as_user(t11.uid(s, 1));
  p := public.get_progress() -> 'games' -> 'ND-Q-P13';
  perform t11.ok((p ->> 'viewed')::int >= 1 and (p ->> 'passed')::int = 1 and (p ->> 'answered')::int = 0, 'passée ≠ répondue');
  perform t11.ok(position('"value"' in p::text) = 0 and position('private' in p::text) = 0, 'aucune réponse dans la progression');
  perform t11.ok(not (p ->> 'completed')::boolean, 'pack non terminé');
end $$;

-- ===== Défi léger et rappels doux =====
do $$
declare c jsonb; n int;
begin
  perform t11.as_user('00000000-0000-4000-a000-0000000000a1');
  c := public.get_light_challenge();
  perform t11.ok((c ->> 'ok')::boolean and exists (select 1 from public.content_meta where bank = c ->> 'bank' and item_id = c ->> 'item_id'
                 and intensity = 'soft' and not adult and 'defi' = any(formats)), 'défi léger : Soft, non +18');
  delete from public.daily_cards where scope like 'c:%' and day = current_date;
  update public.profiles set reminders = '{"enabled": true, "per_week": 1, "quiet_start": 0, "quiet_end": 0}', timezone = 'UTC'
    where id = '00000000-0000-4000-a000-0000000000b1';
  delete from public.daily_cards where scope = 'c:' || private.my_couple_id()::text and day = (now() at time zone 'UTC')::date;
  n := private.send_gentle_reminders();
  perform t11.ok(exists (select 1 from public.notifications where user_id = '00000000-0000-4000-a000-0000000000b1' and type = 'gentle_reminder' and data = '{}'),
                 'rappel sans contenu');
  perform private.send_gentle_reminders();
  perform t11.ok((select count(*) from public.notifications where user_id = '00000000-0000-4000-a000-0000000000b1' and type = 'gentle_reminder') = 1,
                 'plafond et espacement respectés');
  perform t11.ok(not exists (select 1 from public.notifications where user_id = '00000000-0000-4000-a000-0000000000c1' and type = 'gentle_reminder'),
                 'aucun rappel sans activation');
end $$;

-- ===== Réglages personnels invisibles du partenaire =====
do $$
declare denied boolean := false; nm text;
begin
  perform t11.as_user('00000000-0000-4000-a000-0000000000a1');
  set local role authenticated;
  select display_name into nm from public.profiles where id = '00000000-0000-4000-a000-0000000000b1';
  perform t11.ok(nm is not null, 'nom du partenaire lisible');
  begin
    perform max_intensity from public.profiles where id = '00000000-0000-4000-a000-0000000000b1';
  exception when insufficient_privilege then denied := true;
  end;
  perform t11.ok(denied, 'intensité du partenaire illisible');
  perform t11.ok(public.get_my_prefs() ->> 'max_intensity' is not null, 'mes réglages lisibles par moi');
  update public.profiles set country = 'FR', max_intensity = 'soft' where id = auth.uid();
  perform t11.ok(public.get_my_prefs() ->> 'country' = 'FR', 'mes réglages modifiables par moi');
  update public.profiles set country = 'BE' where id = '00000000-0000-4000-a000-0000000000b1';
  reset role;
  perform t11.ok((select country is distinct from 'BE' from public.profiles where id = '00000000-0000-4000-a000-0000000000b1'),
                 'réglages du partenaire non modifiables');
end $$;

select 'TOUS LES TESTS PARCOURS SONT PASSÉS';
rollback;
