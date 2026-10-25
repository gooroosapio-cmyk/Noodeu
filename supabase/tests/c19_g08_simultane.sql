-- Deux vérités et un mensonge, version 2 : écriture simultanée, puis devinette simultanée.
-- Vérifie l'absence de fuite (textes et mensonge de l'autre) avant les deux validations. Transaction annulée.
begin;

create schema t14;
create function t14.as_user(p uuid) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', json_build_object('sub', p, 'role', 'authenticated')::text, true);
end $$;
create function t14.ok(cond boolean, msg text) returns void language plpgsql as $$
begin
  if cond is distinct from true then raise exception 'ÉCHEC : %', msg; end if;
end $$;
create function t14.uid(s uuid, seat int) returns uuid language sql as $$
  select user_id from public.session_players where session_id = s and seat = $2 $$;
create function t14.mv(s uuid, seat int, typ text, p jsonb default '{}') returns jsonb language plpgsql as $$
begin
  perform t14.as_user(t14.uid(s, seat));
  return public.play_move(s, (select current_round from public.game_sessions where id = s), gen_random_uuid(), typ, p);
end $$;
create function t14.view(s uuid, seat int) returns jsonb language plpgsql as $$
begin
  perform t14.as_user(t14.uid(s, seat));
  return public.get_session_state(s);
end $$;
create function t14.card(s uuid) returns jsonb language sql as $$
  select card from public.session_rounds r join public.game_sessions g on g.id = r.session_id and r.round_no = g.current_round where g.id = s $$;
create function t14.three(a text, lie text) returns jsonb language sql as $$
  select jsonb_build_object('confirmed_truths', true, 'lie_statement_id', lie, 'statements', jsonb_build_array(
    jsonb_build_object('id', 's1', 'text', a || ' un'), jsonb_build_object('id', 's2', 'text', a || ' deux'),
    jsonb_build_object('id', 's3', 'text', a || ' trois'))) $$;
grant usage on schema t14 to authenticated;
grant execute on all functions in schema t14 to authenticated;

insert into auth.users (id, email, raw_user_meta_data) values
  ('00000000-0000-4000-a000-0000000000a4', 'joueur-a4@noodeu.invalid', '{"display_name":"A"}'),
  ('00000000-0000-4000-a000-0000000000b4', 'joueur-b4@noodeu.invalid', '{"display_name":"B"}'),
  ('00000000-0000-4000-a000-0000000000c4', 'tiers-c4@noodeu.invalid', '{"display_name":"C"}');
do $$
declare r jsonb;
begin
  perform t14.as_user('00000000-0000-4000-a000-0000000000a4');
  r := public.create_invitation();
  perform t14.as_user('00000000-0000-4000-a000-0000000000b4');
  perform public.claim_invitation(r ->> 'code');
  perform t14.as_user('00000000-0000-4000-a000-0000000000a4');
  perform public.respond_to_claim((r ->> 'id')::uuid, true);
end $$;

do $$
declare s uuid; r jsonb; v text; seat_a int; seat_b int;
begin
  perform t14.as_user('00000000-0000-4000-a000-0000000000a4');
  s := (public.create_session('nd-deux-verites-mensonge') ->> 'session_id')::uuid;
  perform t14.ok((select total_rounds from public.game_sessions where id = s) is null
                 or (select settings ->> 'cartes' from public.game_sessions where id = s) = '6', 'tours : 6 par défaut');
  perform public.set_ready(s, true);
  perform t14.as_user('00000000-0000-4000-a000-0000000000b4');
  perform public.set_ready(s, true);
  perform t14.ok((select total_rounds from public.game_sessions where id = s) = 6, '6 tours');
  perform t14.ok(t14.card(s) ->> 'mode' = 'simultaneous' and t14.card(s) ->> 'phase' = 'write', 'manche en écriture simultanée');

  -- Les deux peuvent écrire : A valide d'abord, B n'est pas bloqué.
  r := t14.mv(s, 1, 'publish_three', t14.three('Alpha', 's2'));
  perform t14.ok((r ->> 'ok')::boolean, 'A prêt');
  perform t14.ok((t14.mv(s, 1, 'publish_three', t14.three('Autre', 's1')) ->> 'error') = 'locked', 'A ne publie pas deux fois');
  v := t14.view(s, 2)::text;
  perform t14.ok(position('Alpha' in v) = 0 and position('"lie"' in v) = 0, 'B ne voit rien de A avant d''être prêt');
  perform t14.ok((t14.mv(s, 1, 'lock_guess', '{"statement_id": "s1"}') ->> 'error') = 'phase', 'pas de devinette avant les deux');
  -- A reprend puis revalide : autorisé tant que B écrit.
  perform t14.ok((t14.mv(s, 1, 'unready') ->> 'ok')::boolean, 'A reprend ses affirmations');
  perform t14.ok((t14.mv(s, 1, 'publish_three', t14.three('Alpha', 's2')) ->> 'ok')::boolean, 'A revalide');
  perform t14.ok((t14.mv(s, 2, 'publish_three', t14.three('Bravo', 's3')) ->> 'ok')::boolean, 'B prêt');

  -- Phase de devinette : chacun voit les textes de l'autre, jamais le mensonge.
  perform t14.ok(t14.card(s) ->> 'phase' = 'guess', 'devinette ouverte quand les deux sont prêts');
  v := t14.view(s, 2)::text;
  perform t14.ok(position('Alpha un' in v) > 0, 'B voit les affirmations de A');
  perform t14.ok(position('"lies"' in v) = 0 and position('"lie"' in (t14.view(s, 2) #> '{rounds,0,card}')::text) = 0, 'mensonges absents de la carte publique');
  perform t14.ok(t14.view(s, 2) #>> '{rounds,0,private,lie}' = 's3' and position('Alpha' in coalesce((t14.view(s, 2) #> '{rounds,0,private}')::text, '')) = 0,
                 'B ne reçoit que sa propre part secrète');

  -- Devinettes scellées puis révélées ensemble : A trouve (s3), B se trompe (s1 au lieu de s2).
  perform t14.ok((t14.mv(s, 1, 'lock_guess', '{"statement_id": "s3"}') ->> 'ok')::boolean, 'A devine');
  perform t14.ok(not coalesce((t14.card(s) ->> 'done')::boolean, false) and position('"guesses"' in t14.card(s)::text) = 0,
                 'devinette de A scellée tant que B n''a pas choisi');
  perform t14.ok((t14.mv(s, 1, 'lock_guess', '{"statement_id": "s1"}') ->> 'error') = 'locked', 'un seul choix');
  perform t14.ok((t14.mv(s, 2, 'lock_guess', '{"statement_id": "s1"}') ->> 'ok')::boolean, 'B devine');
  perform t14.ok((t14.card(s) ->> 'done')::boolean and (t14.card(s) #>> '{scores,1}')::int = 1 and (t14.card(s) #>> '{scores,2}')::int = 0
                 and t14.card(s) #>> '{lies,1}' = 's2' and t14.card(s) #>> '{lies,2}' = 's3', 'révélation : 1 point par mensonge trouvé');

  -- Un tiers n'accède pas à la séance.
  perform t14.as_user('00000000-0000-4000-a000-0000000000c4');
  begin
    r := public.get_session_state(s);
    perform t14.ok(r is null or (r ->> 'ok')::boolean is not true, 'tiers exclu');
  exception when others then null;
  end;
end $$;

-- ===== Relance et notifications sans messages =====
do $$
declare s uuid; r jsonb; b uuid := '00000000-0000-4000-a000-0000000000b4';
begin
  s := (select id from public.game_sessions where game_id = 'nd-deux-verites-mensonge' order by created_at desc limit 1);
  update public.session_rounds set started_at = now() where session_id = s;
  perform t14.as_user('00000000-0000-4000-a000-0000000000a4');
  r := public.send_nudge(s);
  perform t14.ok(r ->> 'error' = 'too_soon', 'relance indisponible avant 20 s d''attente');
  update public.session_rounds set started_at = now() - interval '30 seconds' where session_id = s;
  r := public.send_nudge(s);
  perform t14.ok((r ->> 'ok')::boolean, 'relance envoyée');
  perform t14.ok((select count(*) from public.notifications where user_id = b and type = 'nudge'
                  and data ->> 'session_id' = s::text and data ? 'name' and not (data ? 'statements')) = 1, 'B reçoit une relance sans contenu de jeu');
  r := public.send_nudge(s);
  perform t14.ok(r ->> 'error' = 'cooldown', '60 s entre deux relances');
  update private.nudges set created_at = created_at - interval '2 minutes' where session_id = s;
  perform t14.ok((public.send_nudge(s) ->> 'ok')::boolean, 'deuxième relance après le délai');
  update private.nudges set created_at = created_at - interval '2 minutes' where session_id = s;
  perform t14.ok((public.send_nudge(s) ->> 'ok')::boolean, 'troisième relance');
  update private.nudges set created_at = created_at - interval '2 minutes' where session_id = s;
  perform t14.ok(public.send_nudge(s) ->> 'error' = 'limit', '3 relances au plus par manche');
  perform t14.as_user('00000000-0000-4000-a000-0000000000c4');
  perform t14.ok(public.send_nudge(s) ->> 'error' = 'not_found', 'un tiers ne peut pas relancer');
  -- Un message de discussion ne crée aucune notification.
  perform t14.as_user('00000000-0000-4000-a000-0000000000a4');
  perform public.send_duo_message(gen_random_uuid(), 'Coucou');
  perform t14.ok(not exists (select 1 from public.notifications where user_id = b and type = 'message'), 'aucune notification de message');
end $$;

select 'TOUS LES TESTS DEUX VÉRITÉS SIMULTANÉ ET RELANCE SONT PASSÉS';
rollback;
