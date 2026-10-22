-- Tests de la famille 2 (moteur plateau) : secrets jamais exposés, tour de jeu, coups refusés sans effet,
-- coup renvoyé sans double effet, scores, et les 18 activités jouées jusqu'au bout (un humain + le robot de test).
-- Transaction annulée à la fin : aucune donnée ne reste.
begin;

create schema t4;
grant usage on schema t4 to authenticated;
create function t4.as_user(p uuid) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', json_build_object('sub', p, 'role', 'authenticated')::text, true);
end $$;
create function t4.ok(cond boolean, msg text) returns void language plpgsql as $$
begin
  if cond is distinct from true then raise exception 'ÉCHEC : %', msg; end if;
end $$;
create function t4.err(res jsonb, expected text, msg text) returns void language plpgsql as $$
begin
  if res ->> 'error' is distinct from expected then raise exception 'ÉCHEC : % (attendu %, obtenu %)', msg, expected, res; end if;
end $$;
create function t4.card(s uuid) returns jsonb language sql as $$
  select card from public.session_rounds r join public.game_sessions g on g.id = r.session_id and r.round_no = g.current_round where g.id = s $$;
create function t4.sec(s uuid) returns jsonb language sql as $$
  select secret from private.round_secrets r join public.game_sessions g on g.id = r.session_id and r.round_no = g.current_round where g.id = s $$;
create function t4.round(s uuid) returns int language sql as $$ select current_round from public.game_sessions where id = s $$;
create function t4.mv(s uuid, typ text, p jsonb default '{}') returns jsonb language sql as $$
  select public.play_move(s, t4.round(s), gen_random_uuid(), typ, p) $$;
-- Coup « humain » valide : la stratégie du robot, ou la solution pour les jeux libres où le robot attend.
create function t4.solve(m text, c jsonb, sec jsonb, seat int) returns jsonb language plpgsql as $$
declare sol jsonb := sec -> 'solution';
begin
  if (c ->> 'done')::boolean then return null; end if;
  case m
  when 'anagram' then return jsonb_build_object('type', 'propose', 'payload', jsonb_build_object('word', sol -> 'accepted' ->> 0));
  when 'syllables' then return jsonb_build_object('type', 'submit', 'payload', jsonb_build_object('order', sol -> 'order'));
  when 'rebus' then return jsonb_build_object('type', 'propose', 'payload', jsonb_build_object('text', sol ->> 'answer'));
  when 'convergence' then
    if c -> 'submitted' ? seat::text then return null; end if;
    return jsonb_build_object('type', 'submit', 'payload', '{"word": "lien"}'::jsonb);
  else
    return private.board_bot(m, c || jsonb_build_object('last', jsonb_build_object('seat', 3 - seat)), sec, seat);
  end case;
end $$;
grant execute on all functions in schema t4 to authenticated;

insert into auth.users (id, email, raw_user_meta_data) values
  ('00000000-0000-4000-a000-0000000000a4', 'joueur-a4@noodeu.invalid', '{"display_name":"A"}'),
  ('00000000-0000-4000-a000-0000000000b4', 'joueur-b4@noodeu.invalid', '{"display_name":"B"}');
do $$
declare r jsonb;
begin
  perform t4.as_user('00000000-0000-4000-a000-0000000000a4');
  r := public.create_invitation();
  perform t4.as_user('00000000-0000-4000-a000-0000000000b4');
  perform public.claim_invitation(r ->> 'code');
  perform t4.as_user('00000000-0000-4000-a000-0000000000a4');
  perform public.respond_to_claim((r ->> 'id')::uuid, true);
end $$;

-- ===== 1. Catalogue et secrets (sans robot) =====================================
do $$
declare s uuid; st jsonb; c jsonb; r jsonb; aid uuid := gen_random_uuid(); rev int;
begin
  perform t4.ok((select count(*) from public.games g join public.game_categories gc on gc.id = g.category_id
                 where g.implementation = 'playable' and gc.family_no = 2) = 18, '18 activités jouables (famille 2)');
  perform t4.as_user('00000000-0000-4000-a000-0000000000a4');
  s := (public.create_session('N2-016') ->> 'session_id')::uuid;
  perform public.set_ready(s, true);
  perform t4.as_user('00000000-0000-4000-a000-0000000000b4');
  perform public.set_ready(s, true);
  c := t4.card(s);
  perform t4.ok(c ->> 'phase' = 'clue' and (c ->> 'giver')::int = 1, 'manche 1 : A fait deviner');
  perform t4.ok(position(t4.sec(s) #>> '{solution,target}' in c::text) = 0, 'le mot à deviner n''est pas dans la carte publique');
  st := public.get_session_state(s);
  perform t4.ok(st -> 'rounds' -> 0 -> 'private' = 'null'::jsonb and st -> 'rounds' -> 0 -> 'solution' = 'null'::jsonb,
                'B ne voit ni le mot ni la solution');
  perform t4.err(t4.mv(s, 'clue', '{"text": "un indice"}'), 'not_your_turn', 'B ne peut pas donner l''indice');
  perform t4.as_user('00000000-0000-4000-a000-0000000000a4');
  st := public.get_session_state(s);
  perform t4.ok(st -> 'rounds' -> 0 -> 'private' ->> 'target' = t4.sec(s) #>> '{solution,target}', 'A voit le mot à faire deviner');
  -- Mot interdit, même accordé, et mot à deviner : refusés sans effet.
  rev := coalesce((t4.card(s) ->> 'rev')::int, 0);
  perform t4.err(t4.mv(s, 'clue', jsonb_build_object('text', 'pense à ' || (t4.sec(s) #>> '{solution,forbidden,0}') || 's')),
                 'forbidden_word', 'mot interdit au pluriel refusé');
  perform t4.err(t4.mv(s, 'clue', jsonb_build_object('text', upper(t4.sec(s) #>> '{solution,target}'))), 'forbidden_word', 'mot cible refusé');
  perform t4.ok(coalesce((t4.card(s) ->> 'rev')::int, 0) = rev, 'un coup refusé ne change rien');
  -- Même coup envoyé deux fois : un seul effet.
  r := public.play_move(s, 1, aid, 'clue', '{"text": "Je te suis partout"}');
  perform t4.ok((r ->> 'ok')::boolean, 'indice accepté');
  r := public.play_move(s, 1, aid, 'clue', '{"text": "Je te suis partout"}');
  perform t4.ok((r ->> 'repeated')::boolean and jsonb_array_length(t4.card(s) -> 'clues') = 1, 'coup renvoyé sans double effet');
  perform t4.err(public.play_move(s, 2, gen_random_uuid(), 'guess', '{"text": "x"}'), 'stale_round', 'manche périmée refusée');
  -- Lecture directe des secrets impossible pour un joueur.
  begin
    set local role authenticated;
    perform count(*) from private.round_secrets;
    reset role;
    raise exception 'ÉCHEC : secrets lisibles en direct';
  exception when insufficient_privilege then
    reset role;
  end;
  perform t4.as_user('00000000-0000-4000-a000-0000000000b4');
  perform t4.ok((t4.mv(s, 'guess', jsonb_build_object('text', initcap(t4.sec(s) #>> '{solution,target}') || 's')) ->> 'ok')::boolean, 'réponse');
  c := t4.card(s);
  perform t4.ok((c ->> 'done')::boolean and (c ->> 'success')::boolean and (c ->> 'points')::int = 1, 'trouvé (pluriel et majuscule acceptés)');
  st := public.get_session_state(s);
  perform t4.ok(st -> 'rounds' -> 0 -> 'solution' ->> 'target' is not null, 'solution visible après la manche');
  perform t4.err(t4.mv(s, 'guess', '{"text": "encore"}'), 'round_over', 'plus de coup après la fin de manche');
  perform public.next_round(s, 1);
  perform t4.ok((t4.card(s) ->> 'giver')::int = 2, 'rôles inversés à la manche 2');
  update public.game_sessions set status = 'abandoned' where id = s;
end $$;

-- ===== 2. Règles particulières =================================================
do $$
declare s uuid; c jsonb; sec jsonb; r jsonb;
begin
  perform t4.as_user('00000000-0000-4000-a000-0000000000a4');
  -- Anagramme : lettres différentes refusées ; toute anagramme du lexique acceptée.
  s := (public.create_session('N2-017') ->> 'session_id')::uuid;
  perform public.set_ready(s, true);
  perform t4.as_user('00000000-0000-4000-a000-0000000000b4'); perform public.set_ready(s, true);
  c := t4.card(s); sec := t4.sec(s);
  perform t4.ok(array_to_string(array(select jsonb_array_elements_text(c -> 'letters')), '') <> sec #>> '{solution,accepted,0}',
                'lettres vraiment mélangées');
  perform t4.err(t4.mv(s, 'propose', jsonb_build_object('word', repeat('z', (c ->> 'len')::int))), 'wrong_letters', 'autres lettres refusées');
  perform t4.err(t4.mv(s, 'propose', '{"word": "ab"}'), 'wrong_length', 'mauvaise longueur refusée');
  r := t4.mv(s, 'propose', jsonb_build_object('word', lower(sec #>> '{solution,accepted,0}')));
  perform t4.ok((t4.card(s) ->> 'success')::boolean, 'anagramme trouvée');
  update public.game_sessions set status = 'abandoned' where id = s;

  -- Mot masqué : lettre déjà essayée sans erreur ; six erreurs terminent.
  perform t4.as_user('00000000-0000-4000-a000-0000000000a4');
  s := (public.create_session('N2-023') ->> 'session_id')::uuid;
  perform public.set_ready(s, true);
  perform t4.as_user('00000000-0000-4000-a000-0000000000b4'); perform public.set_ready(s, true);
  perform t4.as_user('00000000-0000-4000-a000-0000000000a4');
  sec := t4.sec(s);
  perform t4.ok((t4.mv(s, 'letter', jsonb_build_object('letter', substr(sec #>> '{solution,letters}', 1, 1))) ->> 'ok')::boolean, 'bonne lettre');
  c := t4.card(s);
  perform t4.ok(c -> 'mask' ->> 0 is not null and (c ->> 'errors')::int = 0, 'lettre révélée');
  perform t4.as_user('00000000-0000-4000-a000-0000000000b4');
  perform t4.err(t4.mv(s, 'letter', jsonb_build_object('letter', substr(sec #>> '{solution,letters}', 1, 1))), 'already_tried', 'lettre déjà essayée');
  perform t4.ok((t4.card(s) ->> 'errors')::int = 0, 'sans erreur comptée');
  update public.game_sessions set status = 'abandoned' where id = s;

  -- Indice unique : un mot du plateau est refusé comme indice.
  perform t4.as_user('00000000-0000-4000-a000-0000000000a4');
  s := (public.create_session('N2-029') ->> 'session_id')::uuid;
  perform public.set_ready(s, true);
  perform t4.as_user('00000000-0000-4000-a000-0000000000b4'); perform public.set_ready(s, true);
  perform t4.as_user('00000000-0000-4000-a000-0000000000a4');
  c := t4.card(s);
  perform t4.err(t4.mv(s, 'clue', jsonb_build_object('word', c -> 'words' ->> 0)), 'board_word', 'mot du plateau refusé');
  perform t4.err(t4.mv(s, 'clue', '{"word": "deux mots"}'), 'one_word', 'un seul mot');
  perform t4.as_user('00000000-0000-4000-a000-0000000000b4');
  perform t4.ok(public.get_session_state(s) -> 'rounds' -> 0 -> 'private' = 'null'::jsonb, 'B ne voit pas les rôles des mots');
  update public.game_sessions set status = 'abandoned' where id = s;

  -- Bac : grille cachée avant confirmation des deux.
  perform t4.as_user('00000000-0000-4000-a000-0000000000a4');
  s := (public.create_session('N2-018') ->> 'session_id')::uuid;
  perform public.set_ready(s, true);
  perform t4.as_user('00000000-0000-4000-a000-0000000000b4'); perform public.set_ready(s, true);
  perform t4.as_user('00000000-0000-4000-a000-0000000000a4');
  perform t4.ok((t4.mv(s, 'submit', '{"words": ["Zèbre secret", "", "", ""]}') ->> 'ok')::boolean, 'grille envoyée');
  perform t4.ok(position('secret' in t4.card(s)::text) = 0, 'grille de A absente de la carte publique');
  perform t4.as_user('00000000-0000-4000-a000-0000000000b4');
  perform t4.ok(position('secret' in public.get_session_state(s)::text) = 0, 'B ne voit pas la grille de A');
  update public.game_sessions set status = 'abandoned' where id = s;
end $$;

-- ===== 3. Les 18 activités jusqu'au bout, avec le robot de test ==================
insert into private.test_autoplayers (user_id, note) values ('00000000-0000-4000-a000-0000000000b4', 'test');
do $$
declare g record; s uuid; sess public.game_sessions; c jsonb; mv jsonb; res jsonb; guard int; n int;
begin
  for g in select g2.id, g2.mechanic from public.games g2 join public.game_categories gc on gc.id = g2.category_id
           where g2.implementation = 'playable' and gc.family_no = 2 order by g2.sort loop
    perform t4.as_user('00000000-0000-4000-a000-0000000000a4');
    s := (public.create_session(g.id) ->> 'session_id')::uuid;
    perform public.set_ready(s, true);
    select * into sess from public.game_sessions where id = s;
    perform t4.ok(sess.status = 'playing', g.id || ' : partie lancée');
    guard := 0;
    loop
      guard := guard + 1;
      if guard > 400 then raise exception 'ÉCHEC : % bloqué (manche %, carte %)', g.id, t4.round(s), t4.card(s); end if;
      select * into sess from public.game_sessions where id = s;
      exit when sess.status <> 'playing';
      c := t4.card(s);
      if (c ->> 'done')::boolean then
        perform public.next_round(s, sess.current_round);
        continue;
      end if;
      mv := t4.solve(g.mechanic, c, t4.sec(s), 1);
      if mv is null then raise exception 'ÉCHEC : % sans coup possible pour A (carte %)', g.id, c; end if;
      res := t4.mv(s, mv ->> 'type', coalesce(mv -> 'payload', '{}'));
      if not coalesce((res ->> 'ok')::boolean, false) then
        raise exception 'ÉCHEC : % coup refusé % → % (carte %)', g.id, mv, res, c;
      end if;
    end loop;
    select * into sess from public.game_sessions where id = s;
    perform t4.ok(sess.status = 'ended' and sess.result is not null, g.id || ' : partie terminée avec résultat');
    select count(*) into n from public.session_rounds where session_id = s and revealed_at is not null;
    perform t4.ok(n = sess.total_rounds, g.id || ' : toutes les manches finies');
    perform t4.ok(private.version_config(sess) ->> 'turn' = 'free'
                  or exists (select 1 from private.board_moves where session_id = s and seat = 2), g.id || ' : le robot a joué');
    perform t4.ok(auth.uid() = '00000000-0000-4000-a000-0000000000a4', g.id || ' : identité rendue');
    perform public.close_session(s);
  end loop;
end $$;

select 'TOUS LES TESTS FAMILLE 2 SONT PASSÉS' as resultat;
rollback;
