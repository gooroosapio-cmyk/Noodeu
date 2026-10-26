-- Administration des questions : accès réservé, modification, +18, ajout, suppression, parties préservées. Transaction annulée.
begin;
create schema t23;
create function t23.as_user(p uuid) returns void language plpgsql as $$
begin perform set_config('request.jwt.claims', json_build_object('sub', p, 'role', 'authenticated')::text, true); end $$;
create function t23.ok(cond boolean, msg text) returns void language plpgsql as $$
begin if cond is distinct from true then raise exception 'ÉCHEC : %', msg; end if; end $$;
grant usage on schema t23 to authenticated;
grant execute on all functions in schema t23 to authenticated;

insert into auth.users (id, email, raw_user_meta_data) values
  ('00000000-0000-4000-a000-0000000000a9', 'admin-a9@noodeu.invalid', '{"display_name":"Ada"}'),
  ('00000000-0000-4000-a000-0000000000b9', 'joueur-b9@noodeu.invalid', '{"display_name":"Bob"}');
insert into public.app_admins (user_id) values ('00000000-0000-4000-a000-0000000000a9');
do $$
declare r jsonb;
begin
  perform t23.as_user('00000000-0000-4000-a000-0000000000a9');
  r := public.create_invitation();
  perform t23.as_user('00000000-0000-4000-a000-0000000000b9');
  perform public.claim_invitation(r ->> 'code');
  perform t23.as_user('00000000-0000-4000-a000-0000000000a9');
  perform public.respond_to_claim((r ->> 'id')::uuid, true);
end $$;
create function t23.start(gid text) returns uuid language plpgsql as $$
declare s uuid;
begin
  perform t23.as_user('00000000-0000-4000-a000-0000000000a9');
  s := (public.create_session(gid) ->> 'session_id')::uuid;
  perform public.set_ready(s, true);
  perform t23.as_user('00000000-0000-4000-a000-0000000000b9');
  perform public.set_ready(s, true);
  perform t23.as_user('00000000-0000-4000-a000-0000000000a9');
  return s;
end $$;
create function t23.card(s uuid) returns jsonb language sql as $$
  select r.card from public.session_rounds r join public.game_sessions g on g.id = r.session_id and r.round_no = g.current_round where g.id = s $$;
grant execute on all functions in schema t23 to authenticated;

do $$
declare r jsonb; n0 int; q jsonb; nid text; s uuid; card jsonb; first_id text; v jsonb; i int;
begin
  -- Accès refusé à un compte ordinaire (lecture et écriture).
  perform t23.as_user('00000000-0000-4000-a000-0000000000b9');
  perform t23.ok(not public.is_app_admin(), 'B n''est pas administrateur');
  begin
    perform public.admin_list_questions();
    raise exception 'ÉCHEC : liste accessible à B';
  exception when raise_exception then
    if sqlerrm like 'ÉCHEC%' then raise; end if;
  end;
  r := public.admin_update_question('conv_target', (select value ->> 'id' from public.content_banks where bank = 'conv_target' order by idx limit 1), 'Piraté');
  perform t23.ok(r ->> 'error' = 'forbidden', 'modification refusée à B');
  perform t23.ok(not exists (select 1 from public.content_banks where value ->> 'text' = 'Piraté'), 'aucune modification par B');

  perform t23.as_user('00000000-0000-4000-a000-0000000000a9');
  perform t23.ok(public.is_app_admin(), 'Ada est administratrice');
  r := public.admin_list_questions();
  perform t23.ok((r ->> 'ok')::boolean and jsonb_array_length(r -> 'questions') > 900, 'liste complète');
  perform t23.ok(exists(select 1 from public.content_banks where bank='petit_bac_huit_unicode')
    and exists(select 1 from public.games g join public.game_versions gv on gv.game_id=g.id and gv.version=g.current_version
      where g.id='N2-018' and gv.config->>'bank'='petit_bac_huit_unicode'),'index Unicode actif : assertion non vacue');
  perform t23.ok(not exists (select 1 from jsonb_array_elements(r -> 'questions') x where x ->> 'bank' in
    ('hangman_words', 'petit_bac', 'petit_bac_huit', 'petit_bac_huit_unicode')), 'ni mots ni index, y compris banque Unicode');
  perform t23.ok(not exists(select 1 from private.admin_bank_map() where bank in
    ('hangman_words', 'petit_bac', 'petit_bac_huit', 'petit_bac_huit_unicode')), 'banques techniques absentes du mapping Admin');
  v := (select jsonb_agg(to_jsonb(cb) order by cb.idx) from public.content_banks cb where cb.bank='petit_bac_huit_unicode');
  r := public.admin_add_question('petit_bac_huit_unicode','Index réservé au moteur');
  perform t23.ok(r='{"ok":false,"error":"not_found"}'::jsonb,'index Unicode exclu aussi des écritures Admin');
  perform t23.ok((select jsonb_agg(to_jsonb(cb) order by cb.idx) from public.content_banks cb where cb.bank='petit_bac_huit_unicode')=v,
    'refus Admin sans mutation de l’index');
  r := public.admin_list_questions();
  q := (select x from jsonb_array_elements(r -> 'questions') x where x ->> 'bank' = 'q_hc_envies' limit 1);
  perform t23.ok(q ->> 'category' = 'À huis clos' and q ->> 'type' = 'pack', 'catégorie et type');

  -- Modification du texte et du +18.
  r := public.admin_update_question('conv_target', (select value ->> 'id' from public.content_banks where bank = 'conv_target' order by idx limit 1), '  Qui de nous deux   chante le plus faux ?  ');
  perform t23.ok((r ->> 'ok')::boolean, 'texte modifié');
  perform t23.ok((select value ->> 'text' from public.content_banks where bank = 'conv_target' order by idx limit 1) = 'Qui de nous deux chante le plus faux ?', 'texte nettoyé');
  r := public.admin_update_question('conv_target', (select value ->> 'id' from public.content_banks where bank = 'conv_target' order by idx limit 1), '   ');
  perform t23.ok(r ->> 'error' = 'invalid_text', 'texte vide refusé');
  first_id := (select value ->> 'id' from public.content_banks where bank = 'q_aron' order by idx limit 1);
  r := public.admin_set_question_adult('q_aron', first_id, true);
  perform t23.ok((select (value ->> 'adult')::boolean from public.content_banks where bank = 'q_aron' and value ->> 'id' = first_id), '+18 activé');
  perform public.admin_set_question_adult('q_aron', first_id, false);
  r := public.admin_update_question('q_aron', first_id, 'Nouvelle première question ?');
  perform t23.ok((select value ->> 'text_fr' from public.content_banks where bank = 'q_aron' and value ->> 'id' = first_id) = 'Nouvelle première question ?', 'text_fr modifié');
  -- Tu préfères : options modifiables, identifiants gardés.
  v := (select value from public.content_banks where bank = 'conv_dilemma' order by idx limit 1);
  r := public.admin_update_question('conv_dilemma', v ->> 'id', 'La mer ou la montagne ?', '["La mer", "La montagne"]');
  perform t23.ok((select value -> 'options' -> 1 ->> 'text' from public.content_banks where bank = 'conv_dilemma' and value ->> 'id' = v ->> 'id') = 'La montagne'
    and (select value -> 'options' -> 1 ->> 'id' from public.content_banks where bank = 'conv_dilemma' and value ->> 'id' = v ->> 'id') = v -> 'options' -> 1 ->> 'id', 'options du dilemme');
  r := public.admin_update_question('conv_dilemma', v ->> 'id', 'X ?', '["Seule"]');
  perform t23.ok(r ->> 'error' = 'invalid_options', 'dilemme à une option refusé');

  -- Ajouts selon le jeu.
  r := public.admin_add_question('conv_sentence', 'Ce qui me fait sourire le matin, c’est…', true);
  perform t23.ok((r ->> 'ok')::boolean, 'ajout phrase');
  perform t23.ok((select value ->> 'prefix' from public.content_banks where bank = 'conv_sentence' and value ->> 'id' = r ->> 'id') = 'Ce qui me fait sourire le matin, c’est', 'préfixe déduit');
  r := public.admin_add_question('conv_truth_dare', 'Montre ta dernière photo.');
  perform t23.ok(r ->> 'error' = 'invalid_kind', 'action ou vérité sans type refusé');
  r := public.admin_add_question('conv_truth_dare', 'Montre ta dernière photo.', false, null, 'dare');
  perform t23.ok((r ->> 'ok')::boolean, 'action ajoutée');
  r := public.admin_add_question('conv_never', 'Je n’ai jamais dormi dehors.');
  perform t23.ok((select value -> 'options' -> 0 ->> 'text' from public.content_banks where bank = 'conv_never' and value ->> 'id' = r ->> 'id') = 'Je l’ai déjà fait', 'options de Je n''ai jamais reprises');
  r := public.admin_add_question('conv_dilemma', 'Thé ou café ?', false, '["Thé", "Café"]');
  perform t23.ok((r ->> 'ok')::boolean, 'dilemme ajouté');
  r := public.admin_add_question('q_gottman_rituals', 'On a un rituel du dimanche.');
  perform t23.ok((select value ->> 'response_type' from public.content_banks where bank = 'q_gottman_rituals' and value ->> 'id' = r ->> 'id') = 'true_false', 'pack Vrai/Faux : même échelle');
  r := public.admin_add_question('q_emotions', 'Qu’est-ce qui t’apaise ?');
  perform t23.ok((select value ->> 'response_type' from public.content_banks where bank = 'q_emotions' and value ->> 'id' = r ->> 'id') = 'open'
    and not (select value ? 'options_ordered' from public.content_banks where bank = 'q_emotions' and value ->> 'id' = r ->> 'id'), 'pack libre : sans options copiées');

  -- Questionnaires notés : ni ajout ni suppression.
  r := public.admin_add_question('q_rice', 'Nouvelle ?');
  perform t23.ok(r ->> 'error' = 'locked_test', 'ajout dans un test refusé');
  r := public.admin_delete_question('q_rice', (select value ->> 'id' from public.content_banks where bank = 'q_rice' order by idx limit 1));
  perform t23.ok(r ->> 'error' = 'locked_test', 'suppression dans un test refusée');

  -- Pack : la question ajoutée est jouée (au-delà de l'ancien nombre fixe).
  select count(*) into n0 from public.content_banks where bank = 'q_gottman_roles';
  r := public.admin_add_question('q_gottman_roles', 'On se partage bien les tâches.');
  nid := r ->> 'id';
  delete from private.pack_progress;
  -- Suppression d'une question au milieu du pack : sautée, et conservée dans la corbeille.
  r := public.admin_delete_question('q_gottman_roles', (select value ->> 'id' from public.content_banks where bank = 'q_gottman_roles' order by idx offset 2 limit 1));
  perform t23.ok((r ->> 'ok')::boolean and exists (select 1 from private.question_trash where bank = 'q_gottman_roles'), 'suppression et corbeille');
  perform t23.ok(exists (select 1 from private.question_log where action = 'delete'), 'journal des modifications');
  s := t23.start('ND-Q-P12');
  perform t23.ok((select total_rounds from public.game_sessions where id = s) = n0, 'pack : 7 - 1 + 1 questions jouées');
  perform t23.ok(exists (select 1 from public.content_banks where bank = 'q_gottman_roles' and value ->> 'id' = nid and idx >= n0), 'ajout placé après l''ancien nombre fixe');
  perform public.abandon_session(s);

  -- Questionnaire aléatoire : une question tirée puis supprimée est sautée.
  s := t23.start('ND-Q-RND1');
  card := t23.card(s);
  r := public.admin_delete_question(card #>> '{queue,1,0}',
    (select value ->> 'id' from public.content_banks where bank = card #>> '{queue,1,0}' and idx = (card #>> '{queue,1,1}')::int));
  perform t23.ok((r ->> 'ok')::boolean, 'question suivante supprimée');
  perform public.play_move(s, 1, gen_random_uuid(), 'answer', '{"choice": "pass"}');
  perform t23.as_user('00000000-0000-4000-a000-0000000000b9');
  perform public.play_move(s, 1, gen_random_uuid(), 'answer', '{"choice": "pass"}');
  perform public.next_round(s, 1);
  perform t23.ok((t23.card(s) ->> 'index')::int = 2, 'question supprimée sautée');
end $$;
select 'TOUS LES TESTS ADMINISTRATION DES QUESTIONS SONT PASSÉS';
rollback;
