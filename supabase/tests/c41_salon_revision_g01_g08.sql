-- Refonte rouge : révision des réglages, lancement par l'hôte (atomique, idempotent), G01 sans texte,
-- G08 tour par tour en 3/5/7 tours sans fuite du mensonge. Base locale jetable ; transaction annulée.
begin;

create schema t41;
create function t41.as_user(p uuid) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', json_build_object('sub', p, 'role', 'authenticated')::text, true);
end $$;
create function t41.ok(cond boolean, msg text) returns void language plpgsql as $$
begin
  if cond is distinct from true then raise exception 'ÉCHEC : %', msg; end if;
end $$;
create function t41.uid(s uuid, seat int) returns uuid language sql as $$
  select user_id from public.session_players where session_id = s and seat = $2 $$;
create function t41.mv(s uuid, seat int, typ text, p jsonb default '{}') returns jsonb language plpgsql as $$
begin
  perform t41.as_user(t41.uid(s, seat));
  return public.play_move(s, (select current_round from public.game_sessions where id = s), gen_random_uuid(), typ, p);
end $$;
create function t41.view(s uuid, seat int) returns jsonb language plpgsql as $$
begin
  perform t41.as_user(t41.uid(s, seat));
  return public.get_session_state(s);
end $$;
create function t41.card(s uuid) returns jsonb language sql as $$
  select card from public.session_rounds r join public.game_sessions g on g.id = r.session_id and r.round_no = g.current_round where g.id = s $$;
create function t41.rev(s uuid) returns int language sql as $$ select settings_rev from public.game_sessions where id = s $$;

insert into auth.users (id, email, raw_user_meta_data) values
  ('00000000-0000-4000-a000-0000000000a1', 'hote-a41@noodeu.invalid', '{"display_name":"A"}'),
  ('00000000-0000-4000-a000-0000000000b1', 'invite-b41@noodeu.invalid', '{"display_name":"B"}');
do $$
declare r jsonb;
begin
  perform t41.as_user('00000000-0000-4000-a000-0000000000a1');
  r := public.create_invitation();
  perform t41.as_user('00000000-0000-4000-a000-0000000000b1');
  perform public.claim_invitation(r ->> 'code');
  perform t41.as_user('00000000-0000-4000-a000-0000000000a1');
  perform public.respond_to_claim((r ->> 'id')::uuid, true);
end $$;

-- 1. Salon -----------------------------------------------------------------------------------------------------
do $$
declare
  a uuid := '00000000-0000-4000-a000-0000000000a1';
  b uuid := '00000000-0000-4000-a000-0000000000b1';
  s uuid; r jsonb; st jsonb; rev0 int; rev1 int; rounds int;
begin
  perform t41.as_user(a);
  s := (public.create_session('nd-deux-verites-mensonge') ->> 'session_id')::uuid;
  perform t41.ok((select settings = '{"cartes":5}'::jsonb from public.game_sessions where id = s), 'G08 : 5 tours par défaut');
  perform t41.ok((select private.version_config(g) #> '{settings,cartes,options}' = '[3,5,7]'::jsonb from public.game_sessions g where g.id = s),
                 'G08 : 3, 5 ou 7 tours');
  rev0 := t41.rev(s);
  st := t41.view(s, 2);
  perform t41.ok((st #>> '{session,settings_rev}')::int = rev0 and (st #>> '{session,host_seat}')::int = 1
                 and st -> 'players' -> 0 ? 'ready_rev', 'instantané : révision, hôte et révision acceptée');

  -- Deux validations ne lancent rien : le lancement reste une action de l'hôte.
  perform t41.as_user(a);
  r := public.set_ready_rev(s, true, rev0);
  perform t41.ok((r ->> 'ok')::boolean, 'A valide la révision courante');
  r := public.launch_session(s, rev0);
  perform t41.ok(r ->> 'error' = 'not_ready', 'pas de lancement avec une seule validation');
  perform t41.as_user(b);
  r := public.set_ready_rev(s, true, rev0);
  perform t41.ok((select status from public.game_sessions where id = s) = 'lobby', 'aucun démarrage silencieux après les deux validations');
  r := public.launch_session(s, rev0);
  perform t41.ok(r ->> 'error' = 'not_host', 'seul l''hôte lance');

  -- Un réglage modifié après validation crée une révision et remet les deux à non prêts.
  perform t41.as_user(a);
  r := public.update_session_settings(s, '{"cartes":7}');
  rev1 := t41.rev(s);
  perform t41.ok(rev1 = rev0 + 1, 'nouvelle révision');
  perform t41.ok(not exists (select 1 from public.session_players where session_id = s and ready_at is not null), 'les deux validations sont invalidées');
  r := public.update_session_settings(s, '{"cartes":7}');
  perform t41.ok(t41.rev(s) = rev1, 'un patch identique ne crée pas de révision');
  r := public.set_ready_rev(s, true, rev0);
  perform t41.ok(r ->> 'error' = 'settings_changed', 'valider une ancienne révision est refusé');
  perform t41.ok(not exists (select 1 from public.session_players where session_id = s and ready_at is not null), 'refus sans effet');

  -- Préférences de séance : elles aussi changent la révision et retirent les validations.
  r := public.set_ready_rev(s, true, rev1);
  perform t41.as_user(b);
  r := public.set_ready_rev(s, true, rev1);
  perform t41.ok((public.set_session_prefs(s, false, array['passe']) ->> 'ok')::boolean, 'préférences modifiées');
  perform t41.ok(t41.rev(s) = rev1 + 1, 'préférences : nouvelle révision');
  perform t41.ok(not exists (select 1 from public.session_players where session_id = s and ready_at is not null), 'préférences : validations retirées');
  rev1 := t41.rev(s);
  r := public.set_ready_rev(s, true, rev1);
  perform t41.as_user(a);
  r := public.set_ready_rev(s, true, rev1);
  r := public.launch_session(s, rev1 - 1);
  perform t41.ok(r ->> 'error' = 'settings_changed', 'lancement d''une révision périmée refusé');

  -- Lancement, puis double clic : une seule partie, une seule manche.
  r := public.launch_session(s, rev1);
  perform t41.ok((r ->> 'ok')::boolean and r ->> 'status' = 'playing', 'lancement par l''hôte');
  r := public.launch_session(s, rev1);
  perform t41.ok((r ->> 'ok')::boolean and (r ->> 'already')::boolean, 'second lancement idempotent');
  select count(*) into rounds from public.session_rounds where session_id = s;
  perform t41.ok(rounds = 1 and (select total_rounds from public.game_sessions where id = s) = 7, 'une manche, 7 tours');
  r := public.set_ready_rev(s, false, rev1);
  perform t41.ok((select status from public.game_sessions where id = s) = 'playing', 'retirer sa validation après le lancement est sans effet');
end $$;

-- 2. G08 tour par tour : rien ne fuit avant le verrouillage, le mensonge jamais avant la révélation ----------------
do $$
declare s uuid; author int; guesser int; v text; r jsonb;
begin
  s := (select id from public.game_sessions where game_id = 'nd-deux-verites-mensonge' and status = 'playing' order by created_at desc limit 1);
  perform t41.ok(not (t41.card(s) ? 'mode') and t41.card(s) ->> 'phase' = 'write', 'G08 v3 : écriture par un seul joueur');
  author := (t41.card(s) ->> 'author')::int; guesser := 3 - author;
  perform t41.ok((t41.card(s) ->> 'guesser')::int = guesser, 'rôles auteur et devineur');
  r := t41.mv(s, guesser, 'publish_three', jsonb_build_object('confirmed_truths', true, 'lie_statement_id', 's1', 'statements',
        '[{"id":"s1","text":"x un"},{"id":"s2","text":"x deux"},{"id":"s3","text":"x trois"}]'::jsonb));
  perform t41.ok(r ->> 'error' = 'not_your_turn', 'pas d''écriture simultanée');
  r := t41.mv(s, author, 'publish_three', jsonb_build_object('confirmed_truths', true, 'lie_statement_id', 's2', 'statements',
        '[{"id":"s1","text":"Secret un"},{"id":"s2","text":"Secret deux"},{"id":"s3","text":"Secret trois"}]'::jsonb));
  perform t41.ok((r ->> 'ok')::boolean, 'l''auteur verrouille ses propositions');
  v := t41.view(s, guesser)::text;
  perform t41.ok(position('Secret deux' in v) > 0 and position('"lie"' in v) = 0, 'le devineur lit les trois textes, jamais le mensonge');
  r := t41.mv(s, author, 'lock_guess', '{"statement_id":"s1"}');
  perform t41.ok(r ->> 'error' = 'not_your_turn', 'l''auteur ne devine pas');
  r := t41.mv(s, guesser, 'lock_guess', '{"statement_id":"s2"}');
  perform t41.ok(t41.card(s) ->> 'phase' = 'reveal' and (t41.card(s) ->> 'found')::boolean and t41.card(s) ->> 'lie' = 's2', 'révélation');
  perform t41.as_user(t41.uid(s, 1));
  perform public.abandon_session(s);
end $$;

-- 3. G01 : C'est répondu / C'est fait, sans texte --------------------------------------------------------------
do $$
declare
  a uuid := '00000000-0000-4000-a000-0000000000a1';
  b uuid := '00000000-0000-4000-a000-0000000000b1';
  s uuid; r jsonb; active int;
begin
  perform t41.as_user(a);
  s := (public.create_session('nd-action-verite') ->> 'session_id')::uuid;
  perform t41.ok((select private.version_config(g) ->> 'answer' = 'oral' from public.game_sessions g where g.id = s), 'G01 : version orale');
  perform public.set_ready_rev(s, true, t41.rev(s));
  perform t41.as_user(b);
  perform public.set_ready_rev(s, true, t41.rev(s));
  perform t41.as_user(a);
  perform public.launch_session(s, t41.rev(s));
  active := (t41.card(s) ->> 'active')::int;
  r := t41.mv(s, active, 'mark_done');
  perform t41.ok(r ->> 'error' = 'phase', 'rien à valider avant le choix');
  r := t41.mv(s, active, 'choose_kind', '{"kind":"truth"}');
  r := t41.mv(s, 3 - active, 'mark_done');
  perform t41.ok(r ->> 'error' = 'not_your_turn', 'l''autre observe');
  r := t41.mv(s, active, 'replace_card');
  perform t41.ok(t41.card(s) ->> 'kind' = 'truth', 'changer de carte garde le type choisi');
  r := t41.mv(s, active, 'mark_done', '{"text":"ne doit pas être gardé"}');
  perform t41.ok((t41.card(s) ->> 'done')::boolean and t41.card(s) #>> '{response,status}' = 'answered'
                 and not (t41.card(s) -> 'response' ? 'text'), 'C''est répondu, sans texte conservé');
end $$;

select 'C41 PASS : RÉVISION DU SALON, LANCEMENT HÔTE IDEMPOTENT, G08 TOUR PAR TOUR SANS FUITE, G01 SANS TEXTE';
rollback;
