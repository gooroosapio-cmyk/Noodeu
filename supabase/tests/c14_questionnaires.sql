-- Tests du catalogue actuel (catégories 1 à 4) : import, conversations à carte commune (Se découvrir),
-- questionnaires individuels calculés sur le serveur (Mieux se comprendre), accès « À huis clos », partenaire de test.
-- Transaction annulée à la fin : aucune donnée ne reste.
begin;

create schema t7;
create function t7.as_user(p uuid) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', json_build_object('sub', p, 'role', 'authenticated')::text, true);
end $$;
create function t7.ok(cond boolean, msg text) returns void language plpgsql as $$
begin
  if cond is distinct from true then raise exception 'ÉCHEC : %', msg; end if;
end $$;
create function t7.err(res jsonb, expected text, msg text) returns void language plpgsql as $$
begin
  if res ->> 'error' is distinct from expected then raise exception 'ÉCHEC : % (attendu %, obtenu %)', msg, expected, res; end if;
end $$;
create function t7.card(s uuid) returns jsonb language sql as $$
  select card from public.session_rounds r join public.game_sessions g on g.id = r.session_id and r.round_no = g.current_round where g.id = s $$;
create function t7.mv(s uuid, typ text, p jsonb default '{}') returns jsonb language sql as $$
  select public.play_move(s, (select current_round from public.game_sessions where id = s), gen_random_uuid(), typ, p) $$;
create function t7.state(s uuid) returns jsonb language sql as $$ select public.get_session_state(s) $$;
create function t7.start(gid text) returns uuid language plpgsql as $$
declare s uuid;
begin
  perform t7.as_user('00000000-0000-4000-a000-0000000000a7');
  s := (public.create_session(gid) ->> 'session_id')::uuid;
  perform public.set_ready(s, true);
  perform t7.as_user('00000000-0000-4000-a000-0000000000b7');
  perform public.set_ready(s, true);
  perform t7.as_user('00000000-0000-4000-a000-0000000000a7');
  return s;
end $$;

insert into auth.users (id, email, raw_user_meta_data) values
  ('00000000-0000-4000-a000-0000000000a7', 'joueur-a7@noodeu.invalid', '{"display_name":"A"}'),
  ('00000000-0000-4000-a000-0000000000b7', 'joueur-b7@noodeu.invalid', '{"display_name":"B"}');
do $$
declare r jsonb;
begin
  perform t7.as_user('00000000-0000-4000-a000-0000000000a7');
  r := public.create_invitation();
  perform t7.as_user('00000000-0000-4000-a000-0000000000b7');
  perform public.claim_invitation(r ->> 'code');
  perform t7.as_user('00000000-0000-4000-a000-0000000000a7');
  perform public.respond_to_claim((r ->> 'id')::uuid, true);
end $$;

-- ===== 1. Catalogue importé =====================================================
do $$
begin
  perform t7.ok((select count(*) from public.game_categories where status = 'published') = 4, 'quatre catégories publiées');
  perform t7.ok((select count(*) from public.game_categories where status = 'archived') >= 8, 'anciennes familles archivées, pas effacées');
  perform t7.ok((select count(*) from public.games where status = 'published') = 30, '30 activités');
  perform t7.ok((select count(*) from public.games where implementation = 'playable') = 14, '14 jouables (7 packs + 7 tests)');
  perform t7.ok((select count(*) from public.games where category_id in ('nd-conversation-decouverte', 'nd-mini-jeux-interactifs')
                 and implementation = 'coming_soon') = 16, '16 jeux C3/C4 en « Bientôt »');
  perform t7.ok((select count(*) from public.content_banks where bank like 'q\_%') = 370, '370 items (171 + 199)');
  perform t7.ok((select count(*) from public.content_banks where bank = 'q_aron' and content_version = '4.0.0') = 36, 'Aron reste en 4.0.0');
  perform t7.ok((select count(*) from public.content_banks where bank = 'q_usu_roadtrip' and content_version = '5.0.0') = 55, 'USU55 reste en 5.0.0');
  perform t7.ok((select value ->> 'text_fr' from public.content_banks where bank = 'q_rice' and value ->> 'source_position' = '69') = '?',
                'Rice 69 conservé tel quel');
  perform t7.ok((select count(*) from public.games where content_level = 'intime') = 3, 'RICE100, QSI12 et SPN16 dans « À huis clos »');
  perform t7.ok((select meta ->> 'namespace' from public.games where id = 'N2-078') = 'noodeu_c34_v1'
                and (select meta ->> 'reference_code' from public.games where id = 'N2-078') = 'M07', 'M07 = bataille navale (namespace)');
  perform t7.as_user('00000000-0000-4000-a000-0000000000a7');
  perform t7.err(public.create_session('nd-action-verite'), 'game_unavailable', 'un jeu sans banque ne se lance pas');
end $$;

-- ===== 2. Se découvrir : carte commune, réponses privées, révélation, reprise ====================
do $$
declare s uuid; c jsonb; st jsonb;
begin
  s := t7.start('ND-Q-P01');
  c := t7.card(s);
  perform t7.ok((c ->> 'index')::int = 0 and c -> 'item' ->> 'id' = 'ARON36-FR04-001', 'Aron commence à la première carte');
  perform t7.ok((select total_rounds from public.game_sessions where id = s) = 12, 'séance limitée à la série en cours (12)');
  perform t7.err(t7.mv(s, 'answer', '{"choice": "share"}'), 'empty_answer', 'partager une réponse vide est refusé');
  perform t7.ok((t7.mv(s, 'answer', '{"choice": "share", "text": "Un secret de A"}') ->> 'ok')::boolean, 'A répond');
  perform t7.as_user('00000000-0000-4000-a000-0000000000b7');
  st := t7.state(s);
  perform t7.ok(position('Un secret de A' in st::text) = 0, 'B ne voit pas la réponse de A avant la fin');
  perform t7.ok(st #> '{rounds,0,card,status,1}' = '"done"'::jsonb, 'B voit seulement que A a terminé');
  perform t7.mv(s, 'answer', '{"choice": "private", "text": "Ma note de B"}');
  c := t7.card(s);
  perform t7.ok((c ->> 'done')::boolean and c #>> '{answers,1,text}' = 'Un secret de A' and c #> '{answers,2}' = '{"choice": "private"}'::jsonb,
                'révélation : la réponse partagée seulement');
  perform t7.ok(position('Ma note de B' in t7.state(s)::text) > 0, 'B retrouve sa propre réponse privée');
  perform t7.as_user('00000000-0000-4000-a000-0000000000a7');
  perform t7.ok(position('Ma note de B' in t7.state(s)::text) = 0, 'A ne voit jamais la réponse gardée par B');
  perform t7.ok((public.set_answer_shared(s, 1, false) ->> 'ok')::boolean and t7.card(s) #> '{answers,1}' = '{"choice": "private"}'::jsonb,
                'A retire son partage');
  perform public.next_round(s, 1);
  perform t7.ok((t7.card(s) ->> 'index')::int = 1, 'carte suivante dans l''ordre');
  perform t7.mv(s, 'answer', '{"choice": "pass"}');
  perform t7.as_user('00000000-0000-4000-a000-0000000000b7');
  perform t7.mv(s, 'answer', '{"choice": "pass"}');
  perform t7.ok(t7.card(s) #> '{answers,1}' = '{"choice": "pass"}'::jsonb, 'passer : aucune réponse, sans pénalité');
  perform public.end_pack_session(s);
  perform t7.ok((select status from public.game_sessions where id = s) = 'ended', 'fin de séance à tout moment');
  perform public.close_session(s);
  -- Reprise : la séance suivante commence à la troisième carte.
  s := t7.start('ND-Q-P01');
  perform t7.ok((t7.card(s) ->> 'index')::int = 2 and (select total_rounds from public.game_sessions where id = s) = 10,
                'reprise à la carte suivante, fin de série à 12');
  update public.game_sessions set status = 'abandoned' where id = s;

  -- Vrai / faux (Gottman) : sans cotation, la valeur doit faire partie des choix de la source.
  s := t7.start('ND-Q-P11');
  perform t7.err(t7.mv(s, 'answer', '{"choice": "share", "value": 3}'), 'invalid_move', 'valeur hors des choix Vrai/Faux');
  perform t7.ok((t7.mv(s, 'answer', '{"choice": "share", "value": 1}') ->> 'ok')::boolean, 'Vrai accepté');
  update public.game_sessions set status = 'abandoned' where id = s;
end $$;

-- ===== 3. Mieux se comprendre : calcul serveur, réponse manquante ≠ 0, partage ==================
do $$
declare s uuid; c jsonb; st jsonb; ans jsonb := '{}'; it jsonb; i int := 0;
begin
  -- CSI4 : somme, zéro valide.
  s := t7.start('ND-Q-022');
  c := t7.card(s);
  perform t7.ok(jsonb_array_length(c -> 'items') = 4 and not (c::text like '%reverse%'), 'items affichés, clé de cotation absente');
  perform t7.err(t7.mv(s, 'save', '{"answers": {"CSI4-2007-FR03-01": 9}}'), 'invalid_option', 'valeur hors échelle refusée');
  perform t7.mv(s, 'save', '{"answers": {"CSI4-2007-FR03-01": 0, "CSI4-2007-FR03-02": 0}, "page": 0}');
  perform t7.mv(s, 'complete', '{"answers": {"CSI4-2007-FR03-03": 0, "CSI4-2007-FR03-04": null}, "share": true}');
  st := t7.state(s);
  perform t7.ok(st #>> '{rounds,0,private,result,status}' = 'incomplete' and st #> '{rounds,0,card,shared,1}' is null,
                'une réponse passée empêche le calcul (pas de zéro implicite)');
  perform t7.as_user('00000000-0000-4000-a000-0000000000b7');
  perform t7.mv(s, 'complete', '{"answers": {"CSI4-2007-FR03-01": 0, "CSI4-2007-FR03-02": 0, "CSI4-2007-FR03-03": 0, "CSI4-2007-FR03-04": 0}}');
  st := t7.state(s);
  perform t7.ok(st #>> '{rounds,0,private,result,scores,satisfaction_relation}' = '0', 'zéro est une valeur valide (somme 0)');
  perform t7.ok(st #> '{rounds,0,card,shared,2}' is null, 'résultat non partagé par défaut');
  perform t7.ok((public.set_answer_shared(s, 1, true) ->> 'ok')::boolean, 'B partage son résultat après coup');
  perform t7.as_user('00000000-0000-4000-a000-0000000000a7');
  st := t7.state(s);
  perform t7.ok(st #>> '{rounds,0,card,shared,2,satisfaction_relation}' = '0' and position('CSI4-2007-FR03-04' in (st -> 'rounds' -> 0 -> 'private')::text) > 0
                and (st #> '{rounds,0,private,answers}') ? 'CSI4-2007-FR03-01', 'A voit le score partagé de B, jamais ses réponses');
  perform t7.ok(position('"CSI4-2007-FR03-04": 0' in st::text) = 0, 'réponses de B absentes de l''état de A');

  -- ECR-RS9 : moyennes avec inversions (items 1 à 4 inversés).
  s := t7.start('ND-Q-021');
  for it in select * from jsonb_array_elements(t7.card(s) -> 'items') loop
    ans := ans || jsonb_build_object(it ->> 'id', 7);
  end loop;
  perform t7.mv(s, 'complete', jsonb_build_object('answers', ans, 'share', false));
  st := t7.state(s);
  perform t7.ok((st #>> '{rounds,0,private,result,scores,evitement}')::numeric = 3 and (st #>> '{rounds,0,private,result,scores,anxiete}')::numeric = 7,
                'ECR : évitement (4×1 + 2×7)/6 = 3, anxiété 7');
  update public.game_sessions set status = 'abandoned' where id = s;

  -- AAIRS-8 : total facultatif avec distraction inversée.
  ans := '{}';
  s := t7.start('ND-Q-024');
  for it in select * from jsonb_array_elements(t7.card(s) -> 'items') loop
    ans := ans || jsonb_build_object(it ->> 'id', 6);
  end loop;
  perform t7.mv(s, 'complete', jsonb_build_object('answers', ans));
  st := t7.state(s);
  perform t7.ok((st #>> '{rounds,0,private,result,scores,attention}')::numeric = 6 and (st #>> '{rounds,0,private,result,scores,total_optionnel}')::numeric = 3.5,
                'AAIRS : attention 6, total facultatif 3,5');
  update public.game_sessions set status = 'abandoned' where id = s;
end $$;

-- ===== 4. À huis clos : activation personnelle puis accord de chacun ============================
do $$
declare s uuid; ans jsonb := '{}'; it jsonb; st jsonb;
begin
  perform t7.as_user('00000000-0000-4000-a000-0000000000a7');
  perform t7.err(public.create_session('ND-Q-011'), 'content_not_enabled', 'RICE100 refusé sans activation des deux profils');
  update public.profiles set intimate_opt_in = true where id in ('00000000-0000-4000-a000-0000000000a7', '00000000-0000-4000-a000-0000000000b7');
  s := (public.create_session('ND-Q-011') ->> 'session_id')::uuid;
  perform t7.err(public.set_ready(s, true), 'adult_consent_required', 'pas de lancement sans accord dans le salon');
  perform public.set_session_prefs(s, true, '{}');
  perform t7.ok((public.set_ready(s, true) ->> 'ok')::boolean, 'A prêt après son accord');
  perform t7.as_user('00000000-0000-4000-a000-0000000000b7');
  perform public.set_session_prefs(s, true, '{}');  -- changer ses réglages remet les deux joueurs « pas prêts »
  perform public.set_ready(s, true);
  perform t7.as_user('00000000-0000-4000-a000-0000000000a7');
  perform public.set_ready(s, true);
  perform t7.ok((select status from public.game_sessions where id = s) = 'playing', 'démarre avec les deux accords');
  perform t7.as_user('00000000-0000-4000-a000-0000000000a7');
  for it in select * from jsonb_array_elements(t7.card(s) -> 'items') loop
    ans := ans || jsonb_build_object(it ->> 'id', (it ->> 'position')::int <= 37);
  end loop;
  perform t7.mv(s, 'complete', jsonb_build_object('answers', ans));
  st := t7.state(s);
  perform t7.ok((st #>> '{rounds,0,private,result,scores,purete}')::int = 63, 'Rice : 37 cases cochées → 63');
  perform t7.ok(exists (select 1 from jsonb_array_elements(t7.card(s) -> 'items') i where i ->> 'text' = '?' and i ->> 'note' is not null),
                'item 69 affiché « ? » avec sa réserve');
  update public.game_sessions set status = 'abandoned' where id = s;
end $$;

-- ===== 5. Avec le partenaire automatique de test ==================================================
insert into private.test_autoplayers (user_id, note) values ('00000000-0000-4000-a000-0000000000b7', 'test');
do $$
declare s uuid; c jsonb; ans jsonb := '{}'; it jsonb;
begin
  perform t7.as_user('00000000-0000-4000-a000-0000000000a7');
  s := (public.create_session('ND-Q-P15') ->> 'session_id')::uuid;
  perform public.set_ready(s, true);
  perform t7.ok((select status from public.game_sessions where id = s) = 'playing', 'le robot se met prêt');
  perform t7.mv(s, 'answer', '{"choice": "share", "text": "Bonjour"}');
  perform t7.ok((t7.card(s) ->> 'done')::boolean and t7.card(s) #>> '{answers,2,choice}' = 'share', 'le robot répond après A');
  perform public.end_pack_session(s);
  perform public.close_session(s);
  s := (public.create_session('ND-Q-012') ->> 'session_id')::uuid;
  perform public.set_ready(s, true);
  for it in select * from jsonb_array_elements(t7.card(s) -> 'items') loop ans := ans || jsonb_build_object(it ->> 'id', 3); end loop;
  perform t7.mv(s, 'complete', jsonb_build_object('answers', ans, 'share', true));
  perform t7.ok((select status from public.game_sessions where id = s) = 'ended', 'IPIP : fin quand les deux ont terminé');
  perform t7.ok((select (result is not null) from public.game_sessions where id = s), 'résultat de session enregistré');
  perform t7.ok((select card #>> '{shared,1,extraversion}' from public.session_rounds where session_id = s) = '30', 'IPIP : 10 × 3 = 30');
end $$;

select 'TOUS LES TESTS CATÉGORIES 1 À 4 SONT PASSÉS' as resultat;
rollback;
