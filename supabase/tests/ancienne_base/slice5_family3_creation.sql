-- Tests de la famille 3 (dessin et création) : secrets, règles particulières (budget de traits, moitié du miroir,
-- maison et chemin, tangram par surfaces), puis les 18 activités jouées jusqu'au bout avec le robot de test.
-- Transaction annulée à la fin : aucune donnée ne reste.
begin;

create schema t5;
create function t5.as_user(p uuid) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', json_build_object('sub', p, 'role', 'authenticated')::text, true);
end $$;
create function t5.ok(cond boolean, msg text) returns void language plpgsql as $$
begin
  if cond is distinct from true then raise exception 'ÉCHEC : %', msg; end if;
end $$;
create function t5.err(res jsonb, expected text, msg text) returns void language plpgsql as $$
begin
  if res ->> 'error' is distinct from expected then raise exception 'ÉCHEC : % (attendu %, obtenu %)', msg, expected, res; end if;
end $$;
create function t5.card(s uuid) returns jsonb language sql as $$
  select card from public.session_rounds r join public.game_sessions g on g.id = r.session_id and r.round_no = g.current_round where g.id = s $$;
create function t5.sec(s uuid) returns jsonb language sql as $$
  select secret from private.round_secrets r join public.game_sessions g on g.id = r.session_id and r.round_no = g.current_round where g.id = s $$;
create function t5.mv(s uuid, typ text, p jsonb default '{}') returns jsonb language sql as $$
  select public.play_move(s, (select current_round from public.game_sessions where id = s), gen_random_uuid(), typ, p) $$;
create function t5.start(gid text) returns uuid language plpgsql as $$
declare s uuid;
begin
  perform t5.as_user('00000000-0000-4000-a000-0000000000a5');
  s := (public.create_session(gid) ->> 'session_id')::uuid;
  perform public.set_ready(s, true);
  perform t5.as_user('00000000-0000-4000-a000-0000000000b5');
  perform public.set_ready(s, true);
  perform t5.as_user('00000000-0000-4000-a000-0000000000a5');
  return s;
end $$;
-- Coup « humain » : stratégie du robot (en se faisant passer pour l'autre au dernier coup), validation finale sinon.
create function t5.solve(m text, c jsonb, sec jsonb, seat int) returns jsonb language plpgsql as $$
declare mv jsonb;
begin
  mv := private.board_bot3(m, c || jsonb_build_object('last', jsonb_build_object('seat', 3 - seat)), sec, seat);
  if mv is null and m in ('pixel_art', 'emblem', 'flipbook', 'weaving') and not coalesce(c -> 'validated' ? seat::text, false) then
    if m = 'emblem' and not (c -> 'slots' ? '1' and c -> 'slots' ? '2') then return null; end if;
    mv := '{"type": "validate"}';
  end if;
  return mv;
end $$;

insert into auth.users (id, email, raw_user_meta_data) values
  ('00000000-0000-4000-a000-0000000000a5', 'joueur-a5@noodeu.invalid', '{"display_name":"A"}'),
  ('00000000-0000-4000-a000-0000000000b5', 'joueur-b5@noodeu.invalid', '{"display_name":"B"}');
do $$
declare r jsonb;
begin
  perform t5.as_user('00000000-0000-4000-a000-0000000000a5');
  r := public.create_invitation();
  perform t5.as_user('00000000-0000-4000-a000-0000000000b5');
  perform public.claim_invitation(r ->> 'code');
  perform t5.as_user('00000000-0000-4000-a000-0000000000a5');
  perform public.respond_to_claim((r ->> 'id')::uuid, true);
end $$;

-- ===== 1. Règles particulières (sans robot) ======================================
do $$
declare s uuid; c jsonb; sec jsonb; i int; st jsonb; pc jsonb;
begin
  perform t5.ok((select count(*) from public.games g join public.game_categories gc on gc.id = g.category_id
                 where g.implementation = 'playable' and gc.family_no = 3) = 18, '18 activités jouables (famille 3)');

  -- Dessine, je devine : l'objet n'est visible que par celui qui dessine ; pas de proposition sans dessin.
  s := t5.start('N2-031');
  sec := t5.sec(s);
  perform t5.ok(position(sec #>> '{solution,target}' in t5.card(s)::text) = 0, 'objet absent de l''état public');
  perform t5.as_user('00000000-0000-4000-a000-0000000000b5');
  perform t5.ok(public.get_session_state(s) -> 'rounds' -> 0 -> 'private' = 'null'::jsonb, 'B ne voit pas l''objet');
  perform t5.err(t5.mv(s, 'guess', '{"text": "x"}'), 'wait_drawing', 'proposition refusée tant qu''il n''y a pas de dessin');
  perform t5.err(t5.mv(s, 'stroke', '{"s": {"c": 0, "w": 1, "p": [[0.1, 0.1]]}}'), 'not_your_turn', 'B ne dessine pas');
  perform t5.as_user('00000000-0000-4000-a000-0000000000a5');
  perform t5.err(t5.mv(s, 'stroke', '{"s": {"c": 0, "w": 1, "p": [[1.5, 0.1]]}}'), 'invalid_drawing', 'trait hors cadre refusé');
  perform t5.ok((t5.mv(s, 'stroke', '{"s": {"c": 0, "w": 1, "p": [[0.1, 0.1], [0.5, 0.5]]}}') ->> 'ok')::boolean, 'trait accepté');
  perform t5.as_user('00000000-0000-4000-a000-0000000000b5');
  perform t5.mv(s, 'guess', jsonb_build_object('text', upper(sec #>> '{solution,target}')));
  perform t5.ok((t5.card(s) ->> 'success')::boolean, 'objet trouvé');
  update public.game_sessions set status = 'abandoned' where id = s;

  -- Dix traits : la gomme consomme aussi un trait ; au-delà de dix, refus.
  s := t5.start('N2-040');
  for i in 1 .. 9 loop perform t5.mv(s, 'stroke', '{"s": {"c": 0, "w": 1, "p": [[0.2, 0.2]]}}'); end loop;
  perform t5.mv(s, 'undo');
  perform t5.ok((t5.card(s) ->> 'used')::int = 10 and jsonb_array_length(t5.card(s) -> 'strokes') = 8, 'gomme comptée');
  perform t5.err(t5.mv(s, 'stroke', '{"s": {"c": 0, "w": 1, "p": [[0.2, 0.2]]}}'), 'no_strokes_left', 'onzième trait refusé');
  update public.game_sessions set status = 'abandoned' where id = s;

  -- Miroir : traits dans la moitié gauche uniquement.
  s := t5.start('N2-041');
  perform t5.err(t5.mv(s, 'stroke', '{"s": {"c": 0, "w": 1, "p": [[0.2, 0.2], [0.7, 0.3]]}}'), 'left_half', 'trait à droite refusé');
  update public.game_sessions set status = 'abandoned' where id = s;

  -- Île : une maison doit toucher un chemin.
  s := t5.start('N2-045');
  c := t5.card(s);
  update public.session_rounds set card = jsonb_set(card, '{hands,1}', '["maison", "chemin droit", "eau"]')
    where session_id = s and round_no = 1;
  perform t5.err(t5.mv(s, 'place', '{"h": 0, "i": 7}'), 'house_needs_path', 'maison sans chemin refusée');
  perform t5.err(t5.mv(s, 'place', '{"h": 1, "i": 0}'), 'not_adjacent', 'tuile isolée refusée');
  perform t5.ok((t5.mv(s, 'place', '{"h": 1, "i": 7}') ->> 'ok')::boolean, 'chemin posé');
  update public.game_sessions set status = 'abandoned' where id = s;

  -- Tangram : couverture exacte par surfaces ; pièces superposées = non résolu.
  s := t5.start('N2-036');
  c := t5.card(s);
  for pc in select * from jsonb_array_elements(c -> 'pieces') loop
    perform t5.mv(s, 'place', jsonb_build_object('id', pc -> 'id', 'x', 1 + (select min((q ->> 0)::int) from jsonb_array_elements(pc -> 'base') q),
                                                   'y', 1 + (select min((q ->> 1)::int) from jsonb_array_elements(pc -> 'base') q), 'rot', 0, 'flip', false));
  end loop;
  perform t5.ok((t5.card(s) ->> 'success')::boolean, 'carré reformé');
  c := t5.card(s) || '{"done": false}';
  c := jsonb_set(c, '{pieces,0,x}', c -> 'pieces' -> 1 -> 'x');
  perform t5.ok(not private.tg_solved(jsonb_set(jsonb_set(c, '{pieces,0,y}', '2'), '{pieces,0,x}', '1')), 'pièce déplacée : plus résolu');
  perform t5.err(t5.mv(s, 'place', '{"id": 0, "x": 9, "y": 9, "rot": 0}'), 'not_playing', 'partie finie : plus de coup');
  update public.game_sessions set status = 'abandoned' where id = s;

  -- Tangram : seul le parallélogramme se retourne ; hors plateau refusé.
  s := t5.start('N2-036');
  c := t5.card(s);
  i := (select (p ->> 'id')::int from jsonb_array_elements(c -> 'pieces') p where not (p ->> 'flippable')::boolean limit 1);
  perform t5.err(t5.mv(s, 'place', jsonb_build_object('id', i, 'x', 0, 'y', 0, 'rot', 0, 'flip', true)), 'no_flip', 'retournement refusé');
  perform t5.err(t5.mv(s, 'place', jsonb_build_object('id', i, 'x', 9, 'y', 9, 'rot', 0)), 'outside', 'hors plateau refusé');
  update public.game_sessions set status = 'abandoned' where id = s;

  -- Portrait en gommettes et personnage plié : rien de l'autre avant la fin.
  s := t5.start('N2-038');
  perform t5.mv(s, 'submit', '{"items": [{"s": 0, "x": 0.5, "y": 0.5, "r": 30}]}');
  perform t5.as_user('00000000-0000-4000-a000-0000000000b5');
  st := public.get_session_state(s);
  perform t5.ok(st -> 'rounds' -> 0 -> 'card' -> 'portraits' = 'null'::jsonb and st -> 'rounds' -> 0 -> 'private' -> 'items' is null,
                'portrait de A invisible pour B');
  update public.game_sessions set status = 'abandoned' where id = s;
  s := t5.start('N2-034');
  perform t5.mv(s, 'band', '{"band": 0, "strokes": [{"c": 1, "w": 1, "p": [[0.917, 0.917], [0.6, 0.6]]}]}');
  perform t5.as_user('00000000-0000-4000-a000-0000000000b5');
  perform t5.ok(position('0.917' in (public.get_session_state(s) -> 'rounds' -> 0)::text) = 0, 'bande de A invisible pour B');
  perform t5.err(t5.mv(s, 'band', '{"band": 0, "strokes": [{"c": 1, "w": 1, "p": [[0.4, 0.4]]}]}'), 'not_your_turn', 'B ne dessine pas la tête');
  update public.game_sessions set status = 'abandoned' where id = s;

  -- Dessin dicté : le modèle reste chez le guide.
  s := t5.start('N2-033');
  perform t5.as_user('00000000-0000-4000-a000-0000000000b5');
  perform t5.ok(public.get_session_state(s) -> 'rounds' -> 0 -> 'private' = 'null'::jsonb
                and not (t5.card(s) ? 'model'), 'modèle invisible pour le dessinateur');
  update public.game_sessions set status = 'abandoned' where id = s;
end $$;

-- ===== 2. Les 18 activités jusqu'au bout, avec le robot de test ==================
insert into private.test_autoplayers (user_id, note) values ('00000000-0000-4000-a000-0000000000b5', 'test');
do $$
declare g record; s uuid; sess public.game_sessions; c jsonb; mv jsonb; res jsonb; guard int; n int;
begin
  for g in select g2.id, g2.mechanic from public.games g2 join public.game_categories gc on gc.id = g2.category_id
           where g2.implementation = 'playable' and gc.family_no = 3 order by g2.sort loop
    s := t5.start(g.id);
    guard := 0;
    loop
      guard := guard + 1;
      if guard > 500 then raise exception 'ÉCHEC : % bloqué (carte %)', g.id, t5.card(s); end if;
      select * into sess from public.game_sessions where id = s;
      exit when sess.status <> 'playing';
      c := t5.card(s);
      if (c ->> 'done')::boolean then perform public.next_round(s, sess.current_round); continue; end if;
      mv := t5.solve(g.mechanic, c, t5.sec(s), 1);
      if mv is null then raise exception 'ÉCHEC : % sans coup possible pour A (carte %)', g.id, c; end if;
      res := t5.mv(s, mv ->> 'type', coalesce(mv -> 'payload', '{}'));
      if not coalesce((res ->> 'ok')::boolean, false) then raise exception 'ÉCHEC : % coup refusé % → % (carte %)', g.id, mv, res, c; end if;
    end loop;
    select * into sess from public.game_sessions where id = s;
    perform t5.ok(sess.status = 'ended' and sess.result is not null, g.id || ' : partie terminée avec résultat');
    select count(*) into n from public.session_rounds where session_id = s and revealed_at is not null;
    perform t5.ok(n = sess.total_rounds, g.id || ' : toutes les manches finies');
    perform t5.ok(private.version_config(sess) ->> 'turn' = 'free'
                  or exists (select 1 from private.board_moves where session_id = s and seat = 2), g.id || ' : le robot a joué');
    perform public.close_session(s);
  end loop;
end $$;

select 'TOUS LES TESTS FAMILLE 3 SONT PASSÉS' as resultat;
rollback;
