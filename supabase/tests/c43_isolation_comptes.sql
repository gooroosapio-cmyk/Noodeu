-- Audit d'isolation des comptes (uniquement sur PostgreSQL jetable, aucun compte réel).
-- Deux duos A–B et C–D. C (hors duo) tente chaque lecture et chaque fonction sur les données de A–B ;
-- B (partenaire) ne reçoit jamais le texte d'une réponse que A garde privée. Transaction annulée à la fin.
begin;
create schema t43;
create function t43.as_user(p uuid) returns void language sql as $$
  select set_config('request.jwt.claims', json_build_object('sub', p, 'role', 'authenticated')::text, true) $$;
create function t43.ok(c boolean, msg text) returns void language plpgsql as $$
begin if c is distinct from true then raise exception 'ÉCHEC : %', msg; end if; end $$;
create function t43.pair(a uuid, b uuid) returns uuid language plpgsql as $$
declare r jsonb; begin
  perform t43.as_user(a); r := public.create_invitation();
  perform t43.as_user(b); perform public.claim_invitation(r ->> 'code');
  perform t43.as_user(a); return (public.respond_to_claim((r ->> 'id')::uuid, true) ->> 'couple_id')::uuid;
end $$;
-- Refusé = exception, ou réponse sans ok=true, ou réponse vide.
create function t43.denied(q text) returns boolean language plpgsql as $$
declare r jsonb;
begin
  execute 'select to_jsonb((' || q || '))' into r;
  return r is null or r = 'null'::jsonb or coalesce((r ->> 'ok')::boolean, false) = false;
exception when undefined_function or undefined_table or syntax_error then raise; when others then return true;
end $$;
grant usage on schema t43 to authenticated;
grant execute on all functions in schema t43 to authenticated;

insert into auth.users (id, email, raw_user_meta_data) values
  ('00000000-0000-4000-a000-000000000043', 'a43@noodeu.invalid', '{"display_name":"A"}'),
  ('00000000-0000-4000-b000-000000000043', 'b43@noodeu.invalid', '{"display_name":"B"}'),
  ('00000000-0000-4000-c000-000000000043', 'c43@noodeu.invalid', '{"display_name":"C"}'),
  ('00000000-0000-4000-d000-000000000043', 'd43@noodeu.invalid', '{"display_name":"D"}');

do $$
declare
  a uuid := '00000000-0000-4000-a000-000000000043';
  b uuid := '00000000-0000-4000-b000-000000000043';
  c uuid := '00000000-0000-4000-c000-000000000043';
  d uuid := '00000000-0000-4000-d000-000000000043';
  ab uuid; cd uuid; s uuid; st jsonb; q text; fn text; n int;
  secret_text text := 'SECRET-PRIVE-DE-A-43';
begin
  ab := t43.pair(a, b);
  cd := t43.pair(c, d);
  perform t43.as_user(b); perform public.send_duo_message(gen_random_uuid(), 'Message intime A-B');
  perform t43.as_user(a); perform public.save_duo_note(ab, gen_random_uuid(), 'Note du duo A-B');

  -- Partie A–B : A garde une réponse privée, B partage la sienne.
  s := (public.create_session('ND-Q-P21') ->> 'session_id')::uuid;
  perform public.set_ready(s, true); perform t43.as_user(b); perform public.set_ready(s, true);
  perform t43.as_user(a);
  perform public.play_move(s, 1, gen_random_uuid(), 'answer', jsonb_build_object('choice', 'private', 'text', secret_text));
  perform t43.as_user(b);
  perform public.play_move(s, 1, gen_random_uuid(), 'answer', '{"choice":"share","text":"Réponse partagée de B"}');

  -- 1. Le partenaire ne voit jamais le texte gardé privé, ni pendant ni après la manche.
  st := public.get_session_state(s);
  perform t43.ok((st ->> 'ok')::boolean, 'B lit sa partie');
  perform t43.ok(position(secret_text in st::text) = 0, 'B ne reçoit pas la réponse privée de A (état de partie)');
  perform t43.ok(position(secret_text in coalesce(public.get_session_meta(s)::text, '')) = 0, 'ni dans les métadonnées');
  perform t43.ok(position(secret_text in coalesce(public.get_progress()::text, '')) = 0, 'ni dans la progression');
  perform t43.ok(position(secret_text in coalesce(public.get_my_items()::text, '')) = 0, 'ni dans ses éléments');
  perform public.next_round(s, 1);
  perform t43.ok(position(secret_text in public.get_session_state(s)::text) = 0, 'toujours absent après la manche');
  -- Le texte partagé par B reste lisible par A (comportement attendu du duo).
  perform t43.as_user(a);
  perform t43.ok(position('Réponse partagée de B' in public.get_session_state(s)::text) > 0, 'A lit la réponse partagée par B');

  -- 2. C (autre duo) : aucune ligne de A–B en lecture directe.
  set local role authenticated;
  perform t43.as_user(c);
  perform t43.ok((select count(*) from public.couples where id = ab) = 0, 'C ne voit pas le duo A-B');
  perform t43.ok((select count(*) from public.couple_members where couple_id = ab) = 0, 'ni ses membres');
  perform t43.ok((select count(*) from public.profiles where id in (a, b)) = 0, 'ni les profils de A et B');
  perform t43.ok((select count(*) from public.game_sessions where couple_id = ab) = 0, 'ni ses parties');
  perform t43.ok((select count(*) from public.session_players where session_id = s) = 0, 'ni ses joueurs');
  perform t43.ok((select count(*) from public.duo_messages where couple_id = ab) = 0, 'ni ses messages');
  perform t43.ok((select count(*) from public.duo_episodes where couple_id = ab) = 0, 'ni ses épisodes');
  perform t43.ok((select count(*) from public.notifications where user_id in (a, b)) = 0, 'ni leurs notifications');
  perform t43.ok((select count(*) from public.invitations where inviter_id in (a, b)) = 0, 'ni leurs invitations');
  perform t43.ok((select count(*) from public.game_favorites where user_id in (a, b)) = 0, 'ni leurs favoris');
  perform t43.ok((select count(*) from public.session_prefs where user_id in (a, b)) = 0, 'ni leurs réglages de partie');
  -- Tables sans droit de lecture directe : l'accès est refusé avant même les règles de ligne.
  begin
    perform 1 from public.session_answers limit 1;
    raise exception 'ÉCHEC : lecture directe de session_answers autorisée';
  exception when insufficient_privilege then null;
  end;
  begin
    perform 1 from private.round_secrets limit 1;
    raise exception 'ÉCHEC : lecture du schéma privé autorisée';
  exception when insufficient_privilege then null;
  end;
  -- Écritures directes refusées.
  begin
    update public.game_sessions set status = 'ended' where id = s;
    raise exception 'ÉCHEC : écriture directe autorisée';
  exception when insufficient_privilege then null;
  end;
  update public.profiles set display_name = 'Pirate' where id = a;
  reset role;
  perform t43.ok((select display_name from public.profiles where id = a) = 'A', 'C ne modifie pas le profil de A');
  set local role authenticated;
  perform t43.as_user(c);

  -- 3. C : chaque fonction appelée avec les identifiants de A–B est refusée.
  foreach q in array array[
    format('public.get_session_state(%L)', s), format('public.get_session_meta(%L)', s),
    format('public.get_two_truths_idea(%L)', s), format('public.get_home_moment(%L)', ab),
    format('public.get_duo_space(%L)', ab), format('public.save_duo_note(%L, %L, ''Intrusion'')', ab, gen_random_uuid()),
    format('public.mark_chat_read(%L)', ab), format('public.set_current_duo(%L)', ab),
    format('public.send_nudge(%L)', s), format('public.abandon_session(%L)', s), format('public.close_session(%L)', s),
    format('public.finish_session(%L)', s), format('public.end_pack_session(%L)', s), format('public.set_keep_memory(%L, true)', s),
    format('public.set_paused(%L, true)', s), format('public.set_ready(%L, true)', s), format('public.set_ready_rev(%L, true, 1)', s),
    format('public.launch_session(%L, 1)', s), format('public.next_round(%L, 2)', s), format('public.reroll_round(%L, 2)', s),
    format('public.round_after(%L, 1, ''x'', ''{}'')', s), format('public.play_move(%L, 2, %L, ''answer'', ''{}'')', s, gen_random_uuid()),
    format('public.submit_answer(%L, 2, ''x'', ''{}'', false)', s), format('public.save_for_later(%L, 1)', s),
    format('public.set_answer_shared(%L, 1, true)', s), format('public.set_session_prefs(%L, false, ''{}'')', s),
    format('public.update_session_settings(%L, ''{}'')', s)
  ] loop
    perform t43.ok(t43.denied(q), 'C refusé : ' || q);
  end loop;
  -- Quitter un duo dont on n'est pas membre : réponse « déjà fait », sans aucun effet.
  perform public.leave_duo(ab);
  reset role;
  perform t43.ok((select status from public.couples where id = ab) = 'active', 'C ne met pas fin au duo A-B');
  perform t43.ok((select count(*) from public.couple_members where couple_id = ab and left_at is null) = 2, 'A et B restent membres');
  set local role authenticated;
  perform t43.as_user(c);
  -- Les fonctions sans paramètre ne renvoient que les données de C.
  perform t43.ok(position(ab::text in public.get_my_duos()::text) = 0, 'get_my_duos de C sans A-B');
  perform t43.ok(position('Message intime' in coalesce(public.get_chat_unread()::text, '')) = 0, 'compteur de C sans contenu A-B');
  perform t43.ok(coalesce(public.get_open_session() ->> 'id', '') <> s::text, 'partie ouverte de C distincte');
  perform t43.ok(public.is_app_admin() is not true, 'C n''est pas administrateur');
  perform t43.ok(t43.denied('public.admin_list_questions()'), 'administration refusée à C');

  -- 4. Stockage : C ne lit ni l'avatar de A ni la couverture A–B.
  reset role;
  insert into storage.objects(bucket_id, name) values ('avatars', a::text || '/avatar.webp');
  set local role authenticated;
  perform t43.as_user(c);
  perform t43.ok((select count(*) from storage.objects where bucket_id = 'avatars' and name like a::text || '/%') = 0, 'C ne voit pas l''avatar de A');
  begin
    insert into storage.objects(bucket_id, name) values ('duo-covers', ab::text || '/' || gen_random_uuid()::text || '.webp');
    raise exception 'ÉCHEC : C dépose une couverture dans A-B';
  exception when insufficient_privilege or check_violation then null;
  end;
  perform t43.as_user(b);
  perform t43.ok((select count(*) from storage.objects where bucket_id = 'avatars' and name like a::text || '/%') = 1, 'B voit l''avatar de son partenaire');

  -- 5. Temps réel : C ne rejoint ni le canal de la partie ni celui du duo.
  perform t43.as_user(c);
  perform t43.ok(private.can_join_topic('session:' || s::text) is not true, 'C hors du canal de la partie');
  perform t43.ok(private.can_join_topic('couple:' || ab::text) is not true, 'C hors du canal du duo');
  perform t43.as_user(b);
  perform t43.ok(private.can_join_topic('session:' || s::text), 'B dans le canal de la partie');
  reset role;
  raise notice 'c43 isolation : OK';
end $$;
rollback;
