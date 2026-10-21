-- Tests de la première tranche : association, confidentialité, partie complète, doublons, reprise.
-- Tout s'exécute dans une transaction annulée à la fin : aucune donnée ne reste en base.
-- Local :   psql -v ON_ERROR_STOP=1 -f supabase/tests/slice1_security_and_game.sql
-- Supabase : coller le fichier dans l'éditeur SQL (ou via l'outil MCP execute_sql).
begin;

create schema t;
grant usage on schema t to authenticated;

create function t.login(p uuid) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', json_build_object('sub', p, 'role', 'authenticated')::text, true);
  execute 'set local role authenticated';
end $$;

create function t.logout() returns void language plpgsql as $$
begin
  execute 'reset role';
  perform set_config('request.jwt.claims', '', true);
end $$;

create function t.ok(cond boolean, msg text) returns void language plpgsql as $$
begin
  if cond is distinct from true then raise exception 'ÉCHEC : %', msg; end if;
end $$;

create function t.err(res jsonb, expected text, msg text) returns void language plpgsql as $$
begin
  if res ->> 'error' is distinct from expected then
    raise exception 'ÉCHEC : % (attendu %, obtenu %)', msg, expected, res;
  end if;
end $$;
grant execute on all functions in schema t to authenticated;

create table t.ids (k text primary key, v text);
grant all on t.ids to authenticated;

insert into auth.users (id, email, raw_user_meta_data) values
  ('00000000-0000-4000-a000-00000000000a', 'test-a@noodeu.invalid', '{"display_name":"Test A"}'),
  ('00000000-0000-4000-a000-00000000000b', 'test-b@noodeu.invalid', '{"display_name":"Test B"}'),
  ('00000000-0000-4000-a000-00000000000c', 'test-c@noodeu.invalid', '{"display_name":"Test C"}'),
  ('00000000-0000-4000-a000-00000000000d', 'test-d@noodeu.invalid', '{"display_name":"Test D"}');

-- ===== 1. Invitations =====================================================
do $$
declare r1 jsonb; r2 jsonb;
begin
  perform t.login('00000000-0000-4000-a000-00000000000a');
  r1 := public.create_invitation();
  r2 := public.create_invitation();
  perform t.ok(r1 ->> 'code' = r2 ->> 'code', 'une invitation répétée renvoie le même code');
  insert into t.ids values ('code_a', r1 ->> 'code'), ('inv_a', r1 ->> 'id');
  perform t.err(public.preview_invitation(r1 ->> 'code'), 'own_invitation', 'rejoindre sa propre invitation');
  perform t.logout();
end $$;

do $$
declare code text := (select v from t.ids where k = 'code_a');
begin
  perform t.login('00000000-0000-4000-a000-00000000000c');
  perform t.err(public.preview_invitation('ZZZZ-ZZZZ'), 'invalid_code', 'code invalide');
  perform t.logout();

  perform t.login('00000000-0000-4000-a000-00000000000b');
  perform t.ok((public.preview_invitation(lower(replace(code, '-', ''))) ->> 'inviter_name') = 'Test A',
               'aperçu avec un code saisi en minuscules sans tiret');
  perform t.ok((public.claim_invitation(code) ->> 'ok')::boolean, 'B demande à rejoindre');
  perform t.ok((public.claim_invitation(code) ->> 'ok')::boolean, 'demande répétée sans erreur');
  perform t.logout();

  perform t.login('00000000-0000-4000-a000-00000000000c');
  perform t.err(public.claim_invitation(code), 'already_used', 'invitation déjà prise par quelqu''un d''autre');
  perform t.logout();
end $$;

do $$
begin
  perform t.login('00000000-0000-4000-a000-00000000000a');
  perform t.ok(public.get_invitation_status() #>> '{outgoing,claimer_name}' = 'Test B', 'A voit le prénom de B qui demande à rejoindre');
  perform t.logout();
  perform t.login('00000000-0000-4000-a000-00000000000b');
  perform t.ok(public.get_invitation_status() #>> '{incoming,inviter_name}' = 'Test A', 'B voit le prénom de A');
  perform t.ok((public.get_invitation_status() -> 'outgoing') = 'null'::jsonb, 'B n''a pas d''invitation envoyée');
  perform t.logout();
  perform t.login('00000000-0000-4000-a000-00000000000c');
  perform t.ok(public.get_invitation_status() = '{"incoming": null, "outgoing": null}'::jsonb, 'C ne voit rien');
  perform t.logout();
end $$;

do $$
declare inv uuid := (select v::uuid from t.ids where k = 'inv_a'); r1 jsonb; r2 jsonb;
begin
  perform t.login('00000000-0000-4000-a000-00000000000a');
  r1 := public.respond_to_claim(inv, true);
  r2 := public.respond_to_claim(inv, true);
  perform t.ok((r1 ->> 'ok')::boolean and r1 ->> 'couple_id' = r2 ->> 'couple_id', 'acceptation idempotente');
  perform t.ok((select count(*) from public.couple_members where couple_id = (r1 ->> 'couple_id')::uuid) = 2, 'couple de deux');
  insert into t.ids values ('couple', r1 ->> 'couple_id');
  perform t.err(public.create_invitation(), 'you_are_already_paired', 'personne déjà associée');
  perform t.logout();
end $$;

-- Invitation expirée et tentatives répétées.
insert into public.invitations (inviter_id, code, expires_at)
  values ('00000000-0000-4000-a000-00000000000c', 'EXPR-2345', now() - interval '1 minute');

do $$
declare i int;
begin
  perform t.login('00000000-0000-4000-a000-00000000000d');
  perform t.err(public.preview_invitation('EXPR-2345'), 'expired', 'invitation expirée');
  for i in 1..7 loop perform public.preview_invitation('NOPE-NOPE'); end loop;
  perform t.err(public.preview_invitation('EXPR-2345'), 'too_many_attempts', 'blocage après essais répétés');
  perform t.logout();
end $$;

-- ===== 2. Un compte extérieur ne voit rien du couple =========================
do $$
begin
  perform t.login('00000000-0000-4000-a000-00000000000c');
  perform t.ok((select count(*) from public.couples) = 0, 'C ne voit aucun couple');
  perform t.ok((select count(*) from public.couple_members) = 0, 'C ne voit aucun membre');
  perform t.ok((select count(*) from public.profiles) = 1, 'C ne voit que son propre profil');
  perform t.ok((select count(*) from public.invitations where inviter_id <> auth.uid()) = 0, 'C ne voit pas les invitations des autres');
  perform t.logout();
  perform t.login('00000000-0000-4000-a000-00000000000b');
  perform t.ok((select count(*) from public.profiles) = 2, 'B voit son profil et celui de A');
  perform t.logout();
end $$;

-- ===== 3. Partie complète ======================================================
do $$
declare r1 jsonb; r2 jsonb;
begin
  perform t.login('00000000-0000-4000-a000-00000000000a');
  r1 := public.create_session('portrait-en-cinq-mots');
  r2 := public.create_session('portrait-en-cinq-mots');
  perform t.ok(r1 ->> 'session_id' = r2 ->> 'session_id', 'double lancement : une seule partie');
  insert into t.ids values ('s1', r1 ->> 'session_id');
  perform t.ok((public.update_session_settings((r1 ->> 'session_id')::uuid, '{"deck_size": 16}') ->> 'ok')::boolean, 'réglage valide');
  perform t.err(public.update_session_settings((r1 ->> 'session_id')::uuid, '{"deck_size": 99}'), 'invalid_settings', 'réglage invalide refusé');
  perform t.logout();

  perform t.login('00000000-0000-4000-a000-00000000000b');
  r2 := public.create_session('portrait-en-cinq-mots');
  perform t.ok(r2 ->> 'session_id' = r1 ->> 'session_id' and (r2 ->> 'existing')::boolean, 'B rejoint la même partie');
  perform t.logout();
end $$;

do $$
declare s uuid := (select v::uuid from t.ids where k = 's1'); failed boolean := false;
begin
  perform t.login('00000000-0000-4000-a000-00000000000c');
  perform t.err(public.get_session_state(s), 'session_not_found', 'C ne lit pas la partie');
  begin
    perform public.set_ready(s, true);
  exception when others then failed := sqlerrm = 'session_not_found';
  end;
  perform t.ok(failed, 'C ne peut pas agir sur la partie');
  perform t.ok(not private.can_join_topic('session:' || s), 'C ne peut pas écouter le canal de la partie');
  perform t.logout();

  perform t.login('00000000-0000-4000-a000-00000000000a');
  perform t.ok(public.set_ready(s, true) ->> 'status' = 'lobby', 'A prêt, en attente de B');
  perform t.ok(private.can_join_topic('session:' || s), 'A écoute le canal de la partie');
  perform t.logout();

  perform t.login('00000000-0000-4000-a000-00000000000b');
  perform t.ok(public.set_ready(s, true) ->> 'status' = 'playing', 'B prêt : la partie démarre');
  perform t.ok(public.set_ready(s, true) ->> 'status' = 'playing', 'confirmation répétée sans effet');
  perform t.ok((select count(*) from public.session_rounds where session_id = s) = 1, 'une seule manche créée');
  perform t.ok(jsonb_array_length((public.get_session_state(s) -> 'rounds' -> 0 -> 'card' -> 'words')) = 16, 'réglage appliqué : 16 mots');
  perform t.logout();
end $$;

do $$
declare s uuid := (select v::uuid from t.ids where k = 's1'); words jsonb; five jsonb; four jsonb; other jsonb; failed boolean := false;
begin
  perform t.login('00000000-0000-4000-a000-00000000000a');
  words := public.get_session_state(s) -> 'rounds' -> 0 -> 'card' -> 'words';
  select jsonb_agg(w -> 'id') into five from (select w from jsonb_array_elements(words) w limit 5) x;
  select jsonb_agg(w -> 'id') into four from (select w from jsonb_array_elements(words) w limit 4) x;
  select jsonb_agg(w -> 'id') into other from (select w from jsonb_array_elements(words) w offset 5 limit 5) x;
  insert into t.ids values ('a_self', five::text);

  perform t.err(public.submit_answer(s, 1, 'guess', jsonb_build_object('words', five)), 'previous_step_missing', 'ordre des étapes');
  begin
    perform public.submit_answer(s, 1, 'self', jsonb_build_object('words', four));
  exception when others then failed := sqlerrm = 'invalid_answer';
  end;
  perform t.ok(failed, 'quatre mots refusés');
  perform t.ok((public.submit_answer(s, 1, 'self', jsonb_build_object('words', five)) ->> 'ok')::boolean, 'A enregistre son portrait');
  perform t.ok((public.submit_answer(s, 1, 'self', jsonb_build_object('words', five)) ->> 'repeated')::boolean, 'envoi répété idempotent');
  perform t.err(public.submit_answer(s, 1, 'self', jsonb_build_object('words', other)), 'already_submitted', 'pas de seconde réponse');
  perform t.ok((public.submit_answer(s, 1, 'guess', jsonb_build_object('words', other)) ->> 'ok')::boolean, 'A enregistre sa supposition');
  perform t.ok((select count(*) from public.session_answers where session_id = s) = 2, 'deux réponses, aucun doublon');
  perform t.logout();

  -- Confidentialité avant révélation
  perform t.login('00000000-0000-4000-a000-00000000000b');
  perform t.ok((select count(*) from public.session_answers where session_id = s) = 0, 'B ne lit pas les réponses de A dans la table');
  perform t.ok((select count(*) from jsonb_array_elements(public.get_session_state(s) -> 'rounds' -> 0 -> 'answers') a
                where a -> 'payload' <> 'null'::jsonb) = 0, 'B ne reçoit aucun contenu de A via l''API');
  perform t.ok((select count(*) from jsonb_array_elements(public.get_session_state(s) -> 'rounds' -> 0 -> 'answers')) = 2,
               'B sait seulement que A a répondu');
  perform t.logout();
  perform t.ok((select count(*) from realtime.messages where payload::text like '%words%' or payload::text like '%portrait.%') = 0,
               'aucun mot ne transite par le temps réel');
  -- Sur Supabase, les messages ne sont stockés que si le service Realtime a déjà créé la partition du jour.
  if (select count(*) from realtime.messages where topic = 'session:' || s) = 0 then
    raise notice 'Signaux temps réel non observables ici (partition Realtime absente) : vérification de contenu non concluante.';
  end if;
end $$;

-- Pause : aucune réponse acceptée pendant la pause
do $$
declare s uuid := (select v::uuid from t.ids where k = 's1');
begin
  perform t.login('00000000-0000-4000-a000-00000000000b');
  perform public.set_paused(s, true);
  perform t.err(public.submit_answer(s, 1, 'self', null, true), 'paused', 'réponse refusée en pause');
  perform public.set_paused(s, false);
  perform t.ok((public.submit_answer(s, 1, 'self', null, true) ->> 'ok')::boolean, 'B passe son portrait');
  perform t.ok((public.submit_answer(s, 1, 'guess', jsonb_build_object('words',
      (select v::jsonb from t.ids where k = 'a_self'))) ->> 'revealed')::boolean,
    'la dernière réponse déclenche la révélation');
  perform t.ok((public.get_session_state(s) -> 'session' ->> 'status') = 'ended', 'partie terminée');
  perform t.ok((select count(*) from jsonb_array_elements(public.get_session_state(s) -> 'rounds' -> 0 -> 'answers') a
                where a ->> 'seat' = '1' and a -> 'payload' <> 'null'::jsonb) = 2, 'après révélation, B lit les réponses de A');
  perform t.logout();
end $$;

-- Chat du duo : envoi idempotent, non-lus réels, invisible pour un tiers ; clôture de partie sans souvenir
do $$
declare s uuid := (select v::uuid from t.ids where k = 's1'); cid uuid := gen_random_uuid();
begin
  perform t.login('00000000-0000-4000-a000-00000000000a');
  perform public.send_duo_message(cid, 'Coucou');
  perform public.send_duo_message(cid, 'Coucou');
  perform t.ok((select count(*) from public.duo_messages) = 1, 'message répété enregistré une fois');
  perform t.ok(public.get_chat_unread() = 0, 'mes propres messages ne sont pas des non-lus');
  perform public.set_keep_memory(s, true);
  perform t.logout();

  perform t.login('00000000-0000-4000-a000-00000000000c');
  perform t.ok((select count(*) from public.duo_messages) = 0, 'C ne lit pas le chat');
  perform t.ok((select count(*) from public.notifications) = 0, 'C ne lit aucune notification des autres');
  perform t.logout();

  perform t.login('00000000-0000-4000-a000-00000000000b');
  perform t.ok(public.get_chat_unread() = 1, 'B a un message non lu');
  perform t.ok((select count(*) from public.notifications where type = 'message' and read_at is null) = 1, 'B a une notification de message');
  perform public.mark_chat_read((select v::uuid from t.ids where k = 'couple'));
  perform t.ok(public.get_chat_unread() = 0, 'lecture enregistrée');
  perform t.ok((select count(*) from public.notifications where type = 'message' and read_at is null) = 0, 'notification de message lue');
  perform t.ok((select count(*) from public.notifications where type = 'game_proposed') = 1, 'B a été prévenu de la partie proposée');
  perform t.ok(not (public.close_session(s) ->> 'kept')::boolean, 'sans accord des deux, rien n''est gardé');
  perform t.logout();
  perform t.ok((select count(*) from public.session_answers where session_id = s) = 0, 'réponses effacées');
end $$;

-- Seconde partie gardée en souvenir, puis séparation
do $$
declare s uuid; words jsonb; five jsonb; u uuid;
begin
  perform t.login('00000000-0000-4000-a000-00000000000a');
  s := (public.create_session('portrait-en-cinq-mots') ->> 'session_id')::uuid;
  perform t.ok(s <> (select v::uuid from t.ids where k = 's1'), 'nouvelle partie après clôture');
  insert into t.ids values ('s2', s);
  perform t.logout();
  foreach u in array array['00000000-0000-4000-a000-00000000000a', '00000000-0000-4000-a000-00000000000b']::uuid[] loop
    perform t.login(u); perform public.set_ready(s, true); perform t.logout();
  end loop;
  foreach u in array array['00000000-0000-4000-a000-00000000000a', '00000000-0000-4000-a000-00000000000b']::uuid[] loop
    perform t.login(u);
    words := public.get_session_state(s) -> 'rounds' -> 0 -> 'card' -> 'words';
    select jsonb_agg(w -> 'id') into five from (select w from jsonb_array_elements(words) w limit 5) x;
    perform public.submit_answer(s, 1, 'self', jsonb_build_object('words', five));
    perform public.submit_answer(s, 1, 'guess', jsonb_build_object('words', five));
    perform t.logout();
  end loop;
  foreach u in array array['00000000-0000-4000-a000-00000000000a', '00000000-0000-4000-a000-00000000000b']::uuid[] loop
    perform t.login(u);
    perform t.ok((public.set_keep_memory(s, true) ->> 'ok')::boolean, 'vote « garder ce souvenir » après la fin');
    perform t.logout();
  end loop;
  perform t.login('00000000-0000-4000-a000-00000000000a');
  perform t.ok((public.close_session(s) ->> 'kept')::boolean, 'souvenir gardé avec l''accord des deux');
  perform t.ok((select count(*) from public.session_answers where session_id = s) = 4, 'réponses conservées');
  perform public.leave_couple();
  perform t.ok(private.my_couple_id() is null, 'séparation effective');
  perform t.ok((public.get_session_state(s) -> 'session' ->> 'read_only')::boolean, 'historique en lecture seule après séparation');
  perform t.err(public.create_session('portrait-en-cinq-mots'), 'no_couple', 'plus de nouvelle partie sans couple');
  perform t.logout();
end $$;

-- ===== 4. Duos : archive A–B, nouveau duo A–C, isolement, reprise de A–B =========
create function t.pair(inviter uuid, claimer uuid) returns uuid language plpgsql as $f$
declare code text; inv uuid; res jsonb;
begin
  perform t.login(inviter);
  res := public.create_invitation(); code := res ->> 'code'; inv := (res ->> 'id')::uuid;
  perform t.logout();
  perform t.login(claimer);
  perform t.ok((public.claim_invitation(code) ->> 'ok')::boolean, 'demande pour rejoindre');
  perform t.logout();
  perform t.login(inviter);
  res := public.respond_to_claim(inv, true);
  perform t.logout();
  if not (res ->> 'ok')::boolean then raise exception 'ÉCHEC : association %', res; end if;
  return (res ->> 'couple_id')::uuid;
end $f$;

do $$
declare ab uuid := (select v::uuid from t.ids where k = 'couple'); ac uuid; ab2 uuid; code text; res jsonb;
begin
  -- B a été prévenu de la fin du duo par A
  perform t.login('00000000-0000-4000-a000-00000000000b');
  perform t.ok((select count(*) from public.notifications where type = 'duo_ended') = 1, 'B prévenu de la fin du duo');
  perform t.ok(jsonb_array_length(public.get_my_duos()) = 1 and not (public.get_my_duos() -> 0 ->> 'active')::boolean, 'B voit A–B archivé');
  perform t.err(public.send_duo_message(gen_random_uuid(), 'encore là ?'), 'no_couple', 'archive : écriture impossible');
  perform t.logout();

  -- A invite C
  ac := t.pair('00000000-0000-4000-a000-00000000000a', '00000000-0000-4000-a000-00000000000c');
  perform t.ok(ac <> ab, 'A–C est un nouveau duo');
  perform t.login('00000000-0000-4000-a000-00000000000a');
  perform t.ok(jsonb_array_length(public.get_my_duos()) = 2, 'A retrouve A–B (archivé) et A–C (actif)');
  perform t.ok((public.get_my_duos() -> 0 ->> 'active')::boolean and (public.get_my_duos() -> 0 ->> 'id')::uuid = ac, 'A–C en tête, actif');
  perform t.ok((select count(*) from public.game_favorites) >= 0, 'favoris personnels toujours lisibles');
  perform public.send_duo_message(gen_random_uuid(), 'Salut C');
  perform t.logout();

  perform t.login('00000000-0000-4000-a000-00000000000c');
  perform t.ok(jsonb_array_length(public.get_my_duos()) = 1, 'C ne voit que son duo avec A');
  perform t.ok((select count(*) from public.duo_messages where couple_id = ab) = 0, 'C ne lit pas les messages A–B');
  perform t.ok((select count(*) from public.duo_messages) = 1, 'C lit le message de son duo');
  perform t.ok((select count(*) from public.game_sessions where couple_id = ab) = 0, 'C ne voit pas les parties A–B');
  perform t.ok((select count(*) from public.profiles where display_name = 'Test B') = 0, 'C ne voit pas le profil de B');
  perform t.err(public.get_session_state((select v::uuid from t.ids where k = 's2')), 'session_not_found', 'C ne lit pas une partie A–B par adresse directe');
  perform t.ok(not private.can_join_topic('couple:' || ab), 'C ne peut pas écouter le canal A–B');
  perform t.logout();

  perform t.login('00000000-0000-4000-a000-00000000000b');
  perform t.ok((select count(*) from public.duo_messages where couple_id = ac) = 0, 'B ne lit pas les messages A–C');
  perform t.ok((select count(*) from public.profiles where display_name = 'Test C') = 0, 'B ne voit pas le profil de C');
  -- B tente de reprendre avec A pendant que A est en duo avec C
  res := public.create_invitation(); code := res ->> 'code';
  perform t.logout();
  perform t.login('00000000-0000-4000-a000-00000000000a');
  perform t.err(public.claim_invitation(code), 'you_are_already_paired', 'A doit d''abord terminer A–C');
  perform public.leave_couple();
  perform t.ok((public.claim_invitation(code) ->> 'ok')::boolean, 'A demande à reprendre avec B');
  perform t.logout();
end $$;

do $$
declare ab uuid := (select v::uuid from t.ids where k = 'couple'); inv uuid;
begin
  perform t.login('00000000-0000-4000-a000-00000000000b');
  select id into inv from public.invitations where inviter_id = auth.uid() and status = 'claimed';
  perform t.ok((public.respond_to_claim(inv, true) ->> 'couple_id')::uuid = ab, 'A–B retrouve le même espace');
  perform t.ok((select count(*) from public.duo_episodes where couple_id = ab) = 2, 'un nouvel épisode est créé');
  perform t.ok((select count(*) from public.duo_messages where couple_id = ab) = 1, 'l''historique A–B est retrouvé');
  perform t.ok((select count(*) from public.duo_messages where body = 'Salut C') = 0, 'aucun mélange avec A–C');
  perform t.logout();
  perform t.login('00000000-0000-4000-a000-00000000000c');
  perform t.ok((select count(*) from public.notifications where type = 'duo_ended') = 1, 'C prévenu de la fin de A–C');
  perform t.ok((select count(*) from public.duo_messages) = 1, 'C garde la lecture de son archive');
  perform t.logout();
end $$;

-- Code régénéré : l'ancien ne fonctionne plus
do $$
declare old text; fresh text;
begin
  perform t.login('00000000-0000-4000-a000-00000000000d');
  old := public.create_invitation() ->> 'code';
  fresh := public.regenerate_invitation() ->> 'code';
  perform t.ok(old <> fresh, 'nouveau code différent');
  perform t.logout();
  delete from private.invitation_attempts;
  perform t.login('00000000-0000-4000-a000-00000000000c');
  perform t.err(public.preview_invitation(old), 'revoked', 'ancien code invalidé');
  perform t.ok((public.preview_invitation(fresh) ->> 'ok')::boolean, 'nouveau code valide');
  perform t.logout();
end $$;

-- Photos : chacun écrit dans son dossier ; un tiers ne lit pas la photo
insert into storage.objects (bucket_id, name, owner) values ('avatars', '00000000-0000-4000-a000-00000000000b/p.webp', '00000000-0000-4000-a000-00000000000b');
do $$
begin
  perform t.login('00000000-0000-4000-a000-00000000000c');
  perform t.ok((select count(*) from storage.objects where bucket_id = 'avatars') = 0, 'C ne voit pas la photo de B');
  begin
    insert into storage.objects (bucket_id, name) values ('avatars', '00000000-0000-4000-a000-00000000000b/x.webp');
    raise exception 'ÉCHEC : C a écrit dans le dossier de B';
  exception when insufficient_privilege then null;
  end;
  perform t.logout();
  perform t.login('00000000-0000-4000-a000-00000000000a');
  perform t.ok((select count(*) from storage.objects where bucket_id = 'avatars') = 1, 'A voit la photo de B');
  perform t.logout();
end $$;

select 'TOUS LES TESTS SONT PASSÉS' as resultat;
rollback;
