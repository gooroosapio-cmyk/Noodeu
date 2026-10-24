-- Tests des jeux de conversation (catégorie 3) : tirage sans remise, filtre +18 serveur, réponses scellées,
-- passage sans divulgation, « Continuer » des deux, verdict du sujet, Action ou Vérité, Deux vérités et un mensonge.
-- Transaction annulée à la fin : aucune donnée ne reste.
begin;

create schema t9;
create function t9.as_user(p uuid) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', json_build_object('sub', p, 'role', 'authenticated')::text, true);
end $$;
create function t9.ok(cond boolean, msg text) returns void language plpgsql as $$
begin
  if cond is distinct from true then raise exception 'ÉCHEC : %', msg; end if;
end $$;
create function t9.err(res jsonb, expected text, msg text) returns void language plpgsql as $$
begin
  if res ->> 'error' is distinct from expected then raise exception 'ÉCHEC : % (attendu %, obtenu %)', msg, expected, res; end if;
end $$;
create function t9.card(s uuid) returns jsonb language sql as $$
  select card from public.session_rounds r join public.game_sessions g on g.id = r.session_id and r.round_no = g.current_round where g.id = s $$;
create function t9.uid(s uuid, seat int) returns uuid language sql as $$
  select user_id from public.session_players where session_id = s and seat = $2 $$;
create function t9.mv(s uuid, seat int, typ text, p jsonb default '{}') returns jsonb language plpgsql as $$
begin
  perform t9.as_user(t9.uid(s, seat));
  return public.play_move(s, (select current_round from public.game_sessions where id = s), gen_random_uuid(), typ, p);
end $$;
create function t9.after(s uuid, seat int, typ text, p jsonb default '{}') returns jsonb language plpgsql as $$
begin
  perform t9.as_user(t9.uid(s, seat));
  return public.round_after(s, (select current_round from public.game_sessions where id = s), typ, p);
end $$;
create function t9.state(s uuid, seat int) returns jsonb language plpgsql as $$
begin
  perform t9.as_user(t9.uid(s, seat));
  return public.get_session_state(s);
end $$;
create function t9.start(gid text, settings jsonb default null, adult boolean default false) returns uuid language plpgsql as $$
declare s uuid;
begin
  update public.game_sessions set status = 'abandoned' where status in ('lobby', 'playing', 'paused', 'ended');
  perform t9.as_user('00000000-0000-4000-a000-0000000000a9');
  s := (public.create_session(gid) ->> 'session_id')::uuid;
  if settings is not null then perform public.update_session_settings(s, settings); end if;
  if adult then
    perform public.set_session_prefs(s, true, '{}');
    perform t9.as_user('00000000-0000-4000-a000-0000000000b9');
    perform public.set_session_prefs(s, true, '{}');
    perform t9.as_user('00000000-0000-4000-a000-0000000000a9');
  end if;
  perform public.set_ready(s, true);
  perform t9.as_user('00000000-0000-4000-a000-0000000000b9');
  perform public.set_ready(s, true);
  return s;
end $$;

insert into auth.users (id, email, raw_user_meta_data) values
  ('00000000-0000-4000-a000-0000000000a9', 'joueur-a9@noodeu.invalid', '{"display_name":"A"}'),
  ('00000000-0000-4000-a000-0000000000b9', 'joueur-b9@noodeu.invalid', '{"display_name":"B"}');
do $$
declare r jsonb;
begin
  perform t9.as_user('00000000-0000-4000-a000-0000000000a9');
  r := public.create_invitation();
  perform t9.as_user('00000000-0000-4000-a000-0000000000b9');
  perform public.claim_invitation(r ->> 'code');
  perform t9.as_user('00000000-0000-4000-a000-0000000000a9');
  perform public.respond_to_claim((r ->> 'id')::uuid, true);
end $$;

-- ===== Catalogue =====================================================================
do $$ begin
  perform t9.ok((select count(*) from public.games where category_id = 'nd-conversation-decouverte' and implementation = 'playable') = 8,
                '8 jeux de conversation jouables');
  perform t9.ok((select count(*) from public.content_banks where bank like 'conv_%') = 730, '730 cartes importées');
  perform t9.ok((select count(*) from public.content_banks where bank like 'conv_%' and not (value ? 'adult')) = 0, 'drapeau +18 sur chaque carte');
end $$;

-- ===== Je n'ai jamais : scellé, révélation, Continuer des deux, sans remise, standard seulement =====
do $$
declare s uuid; c jsonb; st jsonb; ids text[] := '{}'; i int;
begin
  s := t9.start('N2-003');
  c := t9.card(s);
  perform t9.ok(not (c ->> 'adult')::boolean and c -> 'options' -> 0 ->> 'id' = 'experienced', 'carte standard, options Déjà fait / Jamais');
  perform t9.err(t9.mv(s, 1, 'lock', '{"choice": "oui"}'), 'invalid_move', 'option inconnue refusée');
  perform t9.mv(s, 1, 'lock', '{"choice": "experienced"}');
  perform t9.err(t9.mv(s, 1, 'lock', '{"choice": "never"}'), 'locked', 'pas de changement après verrouillage');
  st := t9.state(s, 2);
  perform t9.ok(coalesce(st #> '{rounds,0,private}', 'null') = 'null' and not (st #> '{rounds,0,card}' ? 'answers')
                and st #> '{rounds,0,card,locked}' ? '1', 'B sait seulement que A a verrouillé');
  perform t9.mv(s, 2, 'lock', '{"choice": "never"}');
  c := t9.card(s);
  perform t9.ok((c ->> 'done')::boolean and c #>> '{answers,1,choice}' = 'experienced' and c #>> '{answers,2,choice}' = 'never', 'révélation commune');
  perform t9.ok((t9.after(s, 1, 'continue') ->> 'waiting')::boolean, 'premier Continuer : attente de l''autre');
  perform t9.ok((select current_round from public.game_sessions where id = s) = 1, 'pas de nouvelle carte avec un seul accord');
  perform t9.after(s, 2, 'continue');
  perform t9.ok((select current_round from public.game_sessions where id = s) = 2, 'deux accords : carte suivante');
  -- Passage : la manche se clôt sans révéler la réponse déjà scellée.
  perform t9.mv(s, 1, 'lock', '{"choice": "never"}');
  perform t9.mv(s, 2, 'skip_round');
  c := t9.card(s);
  perform t9.ok((c ->> 'skipped')::boolean and not (c ? 'answers'), 'passage : rien de révélé');
  perform t9.ok(coalesce(t9.state(s, 2) #> '{rounds,1,private}', 'null') = 'null' and not (t9.state(s, 2) #> '{rounds,1,card}' ? 'answers')
                and (select secret from private.round_secrets where session_id = s and round_no = 2) = '{"seats": {}}', 'réponse scellée de A jamais transmise, puis effacée');
  -- Sans remise sur 10 cartes, jamais de carte +18 sans accord.
  for i in 1..8 loop
    perform t9.after(s, 1, 'continue');
    perform t9.after(s, 2, 'continue');
    exit when (select status from public.game_sessions where id = s) <> 'playing';
    perform t9.mv(s, 1, 'skip_round');
  end loop;
  select array_agg(card ->> 'card_id') into ids from public.session_rounds where session_id = s;
  perform t9.ok(cardinality(ids) = (select count(distinct x) from unnest(ids) x), 'aucune carte répétée');
  perform t9.ok(not exists (select 1 from public.session_rounds where session_id = s and (card ->> 'adult')::boolean), 'aucune carte +18 sans accord');
  perform t9.ok((select status from public.game_sessions where id = s) = 'ended' and (select total_rounds from public.game_sessions where id = s) = 10,
                'fin au nombre de cartes choisi');
end $$;

-- ===== Accord +18 : cartes adultes possibles avec les deux accords ; retrait immédiat et purge =====
do $$
declare s uuid; c jsonb; adult_item jsonb;
begin
  update public.profiles set intimate_opt_in = true where id in ('00000000-0000-4000-a000-0000000000a9', '00000000-0000-4000-a000-0000000000b9');
  s := t9.start('N2-002', null, true);
  perform t9.ok(private.adult_allowed(s), 'deux accords +18 actifs');
  perform t9.ok((select count(*) from public.content_banks where bank = 'conv_dilemma' and (value ->> 'adult')::boolean) = 30
                and private.conv_draw(s, 'conv_dilemma') is not null, 'cartes +18 tirables');
  -- Carte en cours rendue adulte, A a déjà scellé : le retrait de B l'interrompt et efface tout.
  select value into adult_item from public.content_banks where bank = 'conv_dilemma' and (value ->> 'adult')::boolean limit 1;
  update public.session_rounds set card = card || private.conv_card(adult_item) where session_id = s and round_no = 1;
  perform t9.mv(s, 1, 'lock', jsonb_build_object('choice', adult_item -> 'options' -> 0 ->> 'id'));
  perform t9.as_user(t9.uid(s, 2));
  perform public.set_session_prefs(s, false, '{}');
  c := t9.card(s);
  perform t9.ok((c ->> 'redacted')::boolean and (c ->> 'interrupted')::boolean and not (c ? 'text') and not (c ? 'options'),
                'carte adulte interrompue, texte retiré');
  perform t9.ok(position(adult_item ->> 'text' in t9.state(s, 1)::text) = 0
                and (select secret from private.round_secrets where session_id = s and round_no = 1) = '{"seats": {}}', 'scellés effacés');
  perform t9.after(s, 1, 'continue');
  perform t9.after(s, 2, 'continue');
  perform t9.ok(not (t9.card(s) ->> 'adult')::boolean, 'suite en mode standard');
  update public.profiles set intimate_opt_in = false where id in ('00000000-0000-4000-a000-0000000000a9', '00000000-0000-4000-a000-0000000000b9');
end $$;

-- ===== Qui de nous deux ? / Tu préfères : valeurs contrôlées par le serveur =====
do $$
declare s uuid; c jsonb;
begin
  s := t9.start('nd-qui-de-nous-deux');
  perform t9.err(t9.mv(s, 1, 'lock', '{"seat": 3}'), 'invalid_move', 'cible hors du duo refusée');
  perform t9.mv(s, 1, 'lock', '{"seat": 1}');
  perform t9.mv(s, 2, 'lock', '{"seat": 1}');
  perform t9.ok(t9.card(s) -> 'answers' = '{"1": {"seat": 1}, "2": {"seat": 1}}', 'mêmes cibles possibles, y compris soi');
  s := t9.start('N2-002');
  c := t9.card(s);
  perform t9.err(t9.mv(s, 1, 'lock', '{"choice": "A"}'), 'invalid_move', 'option hors carte refusée');
  perform t9.ok((t9.mv(s, 1, 'lock', jsonb_build_object('choice', c -> 'options' -> 1 ->> 'id')) ->> 'ok')::boolean, 'option de la carte acceptée');
  perform t9.ok(c ? 'prompt', 'titre court de la carte transmis');
end $$;

-- ===== Devine ma réponse : rôles alternés, verdict du sujet seul, correction par différence =====
do $$
declare s uuid; c jsonb; subj int;
begin
  s := t9.start('N2-004', '{"cartes": 6}');
  c := t9.card(s);
  subj := (c ->> 'subject')::int;
  perform t9.ok((c ->> 'predictor')::int = 3 - subj, 'sujet et prédicteur');
  perform t9.err(t9.mv(s, 1, 'lock', '{"text": "   "}'), 'invalid_text', 'texte vide refusé');
  perform t9.mv(s, 1, 'lock', '{"text": "Des pâtes."}');
  perform t9.mv(s, 2, 'lock', '{"text": "Des pâtes, sans doute."}');
  perform t9.err(t9.after(s, 3 - subj, 'verdict', '{"matches": true}'), 'not_your_turn', 'seul le sujet juge');
  perform t9.after(s, subj, 'verdict', '{"matches": true}');
  perform t9.ok((t9.card(s) #>> array['scores', (3 - subj)::text])::int = 1, 'concordance : 1 point au prédicteur');
  perform t9.after(s, 1, 'continue');
  perform t9.after(s, subj, 'verdict', '{"matches": false}');
  c := t9.card(s);
  perform t9.ok((c #>> array['scores', (3 - subj)::text])::int = 0 and c -> 'continue' = '{}', 'correction : point retiré, Continuer remis à zéro');
  perform t9.after(s, subj, 'verdict', '{"matches": true}');
  perform t9.after(s, 1, 'continue');
  perform t9.after(s, 2, 'continue');
  perform t9.ok((t9.card(s) ->> 'subject')::int = 3 - subj, 'rôles alternés');
  perform t9.err(t9.after(s, 1, 'verdict', '{"matches": true}'), 'phase', 'pas de verdict avant révélation');
end $$;

-- ===== Action ou Vérité =====
do $$
declare s uuid; c jsonb; a int; first_id text;
begin
  s := t9.start('nd-action-verite');
  a := (t9.card(s) ->> 'active')::int;
  perform t9.ok(t9.card(s) ->> 'phase' = 'choice' and not (t9.card(s) ? 'text'), 'aucune carte avant le choix');
  perform t9.err(t9.mv(s, 3 - a, 'choose_kind', '{"kind": "truth"}'), 'not_your_turn', 'seul le joueur actif choisit');
  perform t9.mv(s, a, 'choose_kind', '{"kind": "truth"}');
  c := t9.card(s);
  first_id := c ->> 'card_id';
  perform t9.ok(c ->> 'kind' = 'truth' and c ->> 'phase' = 'respond' and not (c ->> 'adult')::boolean, 'vérité standard tirée après le choix');
  perform t9.mv(s, a, 'replace_card');
  c := t9.card(s);
  perform t9.ok(c ->> 'card_id' <> first_id and c -> 'seen' ? first_id and c ->> 'kind' = 'truth', 'carte changée, l''ancienne reste vue');
  perform t9.err(t9.mv(s, a, 'submit_action', '{"status": "done"}'), 'phase', 'pas d''action sur une vérité');
  perform t9.mv(s, a, 'submit_text', '{"text": "Oui, une fois."}');
  perform t9.ok(t9.card(s) #>> '{response,text}' = 'Oui, une fois.', 'réponse publiée');
  perform t9.err(t9.mv(s, a, 'replace_card'), 'round_over', 'remplacement après réponse refusé');
  perform t9.after(s, 1, 'continue'); perform t9.after(s, 2, 'continue');
  perform t9.ok((t9.card(s) ->> 'active')::int = 3 - a, 'joueur actif alterné');
  perform t9.mv(s, 3 - a, 'choose_kind', '{"kind": "dare"}');
  perform t9.mv(s, 3 - a, 'submit_action', '{"status": "done"}');
  perform t9.ok(t9.card(s) -> 'response' = '{"status": "done"}', 'action faite, sans preuve ni texte imposé');
end $$;

-- ===== Deux vérités et un mensonge =====
do $$
declare s uuid; c jsonb; au int;
begin
  s := t9.start('nd-deux-verites-mensonge', '{"cartes": 4}');
  au := (t9.card(s) ->> 'author')::int;
  perform t9.err(t9.mv(s, au, 'publish_three', '{"confirmed_truths": true, "lie_statement_id": "s2", "statements": [{"id": "s1", "text": "Un"}, {"id": "s2", "text": "un"}, {"id": "s3", "text": "Trois"}]}'),
                 'duplicate_text', 'affirmations identiques refusées');
  perform t9.err(t9.mv(s, au, 'publish_three', '{"confirmed_truths": true, "lie_statement_id": "s4", "statements": [{"id": "s1", "text": "Un"}, {"id": "s2", "text": "Deux"}, {"id": "s3", "text": "Trois"}]}'),
                 'invalid_move', 'mensonge désigné hors des trois');
  perform t9.err(t9.mv(s, 3 - au, 'publish_three', '{"confirmed_truths": true, "lie_statement_id": "s1", "statements": [{"id": "s1", "text": "Un"}, {"id": "s2", "text": "Deux"}, {"id": "s3", "text": "Trois"}]}'),
                 'not_your_turn', 'seul l''auteur publie');
  perform t9.mv(s, au, 'publish_three', '{"confirmed_truths": true, "lie_statement_id": "s2", "statements": [{"id": "s1", "text": "J''ai vu une baleine."}, {"id": "s2", "text": "Je parle japonais."}, {"id": "s3", "text": "J''adore le thé."}]}');
  perform t9.ok(position('lie' in (t9.state(s, 3 - au) -> 'rounds')::text) = 0, 'le mensonge reste secret pour celui qui devine');
  perform t9.ok(t9.state(s, au) #>> '{rounds,0,private,lie}' = 's2', 'l''auteur voit son indicateur privé');
  perform t9.mv(s, 3 - au, 'lock_guess', '{"statement_id": "s2"}');
  c := t9.card(s);
  perform t9.ok((c ->> 'found')::boolean and (c #>> array['scores', (3 - au)::text])::int = 1 and (c #>> array['scores', au::text])::int = 0, 'mensonge trouvé : 1 point au devineur');
end $$;

-- ===== Partenaire automatique : chaque jeu mené à son terme =====
do $$
declare s uuid; m text; seat int; n int; done boolean;
begin
  foreach m in array array['N2-003', 'N2-002', 'nd-qui-de-nous-deux', 'N2-004', 'nd-complete-phrase', 'nd-accord-desaccord', 'nd-action-verite', 'nd-deux-verites-mensonge'] loop
    s := t9.start(m);
    n := 0;
    while (select status from public.game_sessions where id = s) = 'playing' and n < 400 loop
      done := false;
      foreach seat in array array[1, 2] loop
        perform t9.as_user(t9.uid(s, seat));
        if private.bot_step(s, seat) then done := true; exit; end if;
      end loop;
      perform t9.ok(done, format('le robot avance (%s)', m));
      n := n + 1;
    end loop;
    perform t9.ok((select status from public.game_sessions where id = s) = 'ended', format('robot : partie %s menée à son terme', m));
  end loop;
end $$;

select 'TOUS LES TESTS CONVERSATION (LOT 3) SONT PASSÉS';
rollback;
