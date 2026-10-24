-- Tests de la famille 4 (mémoire et observation) : ce qui est à mémoriser reste privé et disparaît après
-- l'observation, réponses cachées jusqu'aux deux réponses, règles particulières, puis les 18 activités jouées
-- jusqu'au bout avec le robot de test. Transaction annulée à la fin : aucune donnée ne reste.
begin;

create schema t6;
create function t6.as_user(p uuid) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', json_build_object('sub', p, 'role', 'authenticated')::text, true);
end $$;
create function t6.ok(cond boolean, msg text) returns void language plpgsql as $$
begin
  if cond is distinct from true then raise exception 'ÉCHEC : %', msg; end if;
end $$;
create function t6.err(res jsonb, expected text, msg text) returns void language plpgsql as $$
begin
  if res ->> 'error' is distinct from expected then raise exception 'ÉCHEC : % (attendu %, obtenu %)', msg, expected, res; end if;
end $$;
create function t6.card(s uuid) returns jsonb language sql as $$
  select card from public.session_rounds r join public.game_sessions g on g.id = r.session_id and r.round_no = g.current_round where g.id = s $$;
create function t6.sec(s uuid) returns jsonb language sql as $$
  select secret from private.round_secrets r join public.game_sessions g on g.id = r.session_id and r.round_no = g.current_round where g.id = s $$;
create function t6.mv(s uuid, typ text, p jsonb default '{}') returns jsonb language sql as $$
  select public.play_move(s, (select current_round from public.game_sessions where id = s), gen_random_uuid(), typ, p) $$;
create function t6.start(gid text) returns uuid language plpgsql as $$
declare s uuid;
begin
  perform t6.as_user('00000000-0000-4000-a000-0000000000a6');
  s := (public.create_session(gid) ->> 'session_id')::uuid;
  perform public.set_ready(s, true);
  perform t6.as_user('00000000-0000-4000-a000-0000000000b6');
  perform public.set_ready(s, true);
  perform t6.as_user('00000000-0000-4000-a000-0000000000a6');
  return s;
end $$;
-- Coup « humain » : stratégie du robot, en se faisant passer pour l'autre au dernier coup (jeux libres).
create function t6.solve(m text, c jsonb, sec jsonb, seat int) returns jsonb language plpgsql as $$
declare mv jsonb;
begin
  mv := private.board_bot4(m, c || jsonb_build_object('last', jsonb_build_object('seat', 3 - seat)), sec, seat);
  if mv is null and m = 'split_memory' and not coalesce(c -> 'validated' ? seat::text, false) then mv := '{"type": "validate"}'; end if;
  return mv;
end $$;

insert into auth.users (id, email, raw_user_meta_data) values
  ('00000000-0000-4000-a000-0000000000a6', 'joueur-a6@noodeu.invalid', '{"display_name":"A"}'),
  ('00000000-0000-4000-a000-0000000000b6', 'joueur-b6@noodeu.invalid', '{"display_name":"B"}');
do $$
declare r jsonb;
begin
  perform t6.as_user('00000000-0000-4000-a000-0000000000a6');
  r := public.create_invitation();
  perform t6.as_user('00000000-0000-4000-a000-0000000000b6');
  perform public.claim_invitation(r ->> 'code');
  perform t6.as_user('00000000-0000-4000-a000-0000000000a6');
  perform public.respond_to_claim((r ->> 'id')::uuid, true);
end $$;

-- ===== 1. Secrets et règles particulières (sans robot) ===========================
do $$
declare s uuid; c jsonb; sec jsonb; st jsonb; i int; j int; k int;
begin
  perform t6.ok((select count(*) from public.games g join public.game_categories gc on gc.id = g.category_id
                 where g.implementation = 'playable' and gc.family_no = 4) = 18, '18 activités jouables (famille 4)');

  -- Paires : faces inconnues avant retournement ; paire ratée visible puis attente ; pas de troisième carte.
  s := t6.start('N2-046');
  c := t6.card(s); sec := t6.sec(s);
  perform t6.ok(c -> 'faces' = '{}'::jsonb and not (c ? 'cards'), 'faces cachées au départ');
  if (c ->> 'turn')::int = 2 then perform t6.as_user('00000000-0000-4000-a000-0000000000b6'); end if;
  select g into i from generate_series(1, 15) g where sec -> 'solution' -> 'cards' -> g <> sec -> 'solution' -> 'cards' -> 0 limit 1;
  perform t6.mv(s, 'flip', '{"i": 0}');
  perform t6.err(t6.mv(s, 'flip', '{"i": 0}'), 'already_revealed', 'même carte refusée');
  perform t6.mv(s, 'flip', jsonb_build_object('i', i));
  c := t6.card(s);
  perform t6.ok(c -> 'faces' = '{}'::jsonb and jsonb_array_length(c #> array['miss', (3 - (c ->> 'turn')::int)::text, 'faces']) = 2,
                'paire ratée : faces retirées mais visibles dans « miss »');
  perform t6.as_user(case when (c ->> 'turn')::int = 1 then '00000000-0000-4000-a000-0000000000a6'::uuid else '00000000-0000-4000-a000-0000000000b6'::uuid end);
  perform t6.err(t6.mv(s, 'flip', '{"i": 2}'), 'wait', 'pas de retournement pendant 1,2 s');
  update public.game_sessions set status = 'abandoned' where id = s;

  -- Mémoire : le plateau à mémoriser n'est que dans la part privée, retirée au coup « seen ».
  perform t6.as_user('00000000-0000-4000-a000-0000000000a6');
  s := t6.start('N2-051');
  sec := t6.sec(s);
  perform t6.ok(position((sec #>> '{solution,targets,0}') in (t6.card(s) -> 'count')::text) = 0 and not (t6.card(s) ? 'targets'), 'cibles absentes de l''état public');
  st := public.get_session_state(s);
  perform t6.ok(jsonb_array_length(st #> '{rounds,0,private,view,targets}') = 8, 'A voit les huit objets pendant l''observation');
  perform t6.err(t6.mv(s, 'answer', '{"items": [0,1,2,3,4,5,6,7]}'), 'watch_first', 'pas de réponse pendant l''observation');
  perform t6.mv(s, 'seen');
  perform t6.ok(public.get_session_state(s) #> '{rounds,0,private,view}' is null, 'plateau retiré après l''observation');
  perform t6.err(t6.mv(s, 'answer', '{"items": [0,1,2]}'), 'pick_count', 'exactement huit objets');
  perform t6.ok((t6.mv(s, 'answer', '{"items": [0,1,2,3,4,5,6,7]}') ->> 'ok')::boolean, 'réponse acceptée');
  perform t6.err(t6.mv(s, 'answer', '{"items": [0,1,2,3,4,5,6,7]}'), 'already_submitted', 'une seule réponse');
  perform t6.as_user('00000000-0000-4000-a000-0000000000b6');
  st := public.get_session_state(s);
  perform t6.ok(st #> '{rounds,0,card,answers}' = 'null'::jsonb and st #> '{rounds,0,card,scores,1}' = '0'::jsonb, 'réponse de A cachée à B');
  perform t6.mv(s, 'seen');
  perform t6.mv(s, 'answer', '{"items": [8,9,10,11,12,13,14,15]}');
  c := t6.card(s);
  select count(*) into k from generate_series(0, 7) g where (sec -> 'solution' -> 'targets') ? (c -> 'choices' ->> g);
  perform t6.ok((c ->> 'done')::boolean and (c #>> '{scores,1}')::int = k, 'score calculé sur le serveur');
  update public.game_sessions set status = 'abandoned' where id = s;

  -- Deux mémoires : chacun ne voit que sa moitié.
  perform t6.as_user('00000000-0000-4000-a000-0000000000a6');
  s := t6.start('N2-060');
  st := public.get_session_state(s);
  perform t6.ok(jsonb_array_length(st #> '{rounds,0,private,view}') = 4 and not (t6.card(s) ? 'positions'), 'A voit quatre positions seulement');
  perform t6.as_user('00000000-0000-4000-a000-0000000000b6');
  perform t6.ok(public.get_session_state(s) #> '{rounds,0,private,view}' <> st #> '{rounds,0,private,view}', 'B voit l''autre moitié');
  perform t6.err(t6.mv(s, 'validate'), 'not_finished', 'validation impossible avant d''avoir tout placé');
  perform t6.ok((t6.mv(s, 'hint') ->> 'ok')::boolean, 'une aide');
  perform t6.err(t6.mv(s, 'hint'), 'no_hint', 'une seule aide');
  update public.game_sessions set status = 'abandoned' where id = s;

  -- Suite lumineuse : une erreur ne finit pas la partie, deux oui.
  perform t6.as_user('00000000-0000-4000-a000-0000000000a6');
  s := t6.start('N2-052');
  perform t6.mv(s, 'seen');
  perform t6.mv(s, 'answer', '{"seq": [9]}');
  perform t6.ok(not (t6.card(s) -> 'finished' ? '1') and not (t6.card(s) -> 'seen' ? '1'), 'après une erreur : nouvelle observation');
  perform t6.mv(s, 'seen');
  perform t6.mv(s, 'answer', '{"seq": [9]}');
  perform t6.ok(t6.card(s) -> 'finished' ? '1', 'arrêt après deux erreurs');
  update public.game_sessions set status = 'abandoned' where id = s;

  -- Silhouette : la réponse est notée, l'indice n'est donné qu'une fois.
  s := t6.start('N2-130');
  perform t6.ok(jsonb_array_length(t6.card(s) -> 'labels') = 4, 'noms des choix fournis');
  perform t6.ok((t6.mv(s, 'hint') ->> 'ok')::boolean, 'indice');
  perform t6.err(t6.mv(s, 'hint'), 'no_hint', 'un seul indice');
  update public.game_sessions set status = 'abandoned' where id = s;

  -- Curseur : valeur hors de la ligne refusée.
  s := t6.start('N2-059');
  perform t6.mv(s, 'seen');
  perform t6.err(t6.mv(s, 'answer', '{"value": 140}'), 'invalid_move', 'curseur hors de 0..100');
  update public.game_sessions set status = 'abandoned' where id = s;
end $$;

-- ===== 2. Les 18 activités jusqu'au bout, avec le robot de test ==================
insert into private.test_autoplayers (user_id, note) values ('00000000-0000-4000-a000-0000000000b6', 'test');
do $$
declare g record; s uuid; sess public.game_sessions; c jsonb; mv jsonb; res jsonb; guard int; n int;
begin
  for g in select g2.id, g2.mechanic from public.games g2 join public.game_categories gc on gc.id = g2.category_id
           where g2.implementation = 'playable' and gc.family_no = 4 order by g2.sort loop
    s := t6.start(g.id);
    guard := 0;
    loop
      guard := guard + 1;
      if guard > 500 then raise exception 'ÉCHEC : % bloqué (carte %)', g.id, t6.card(s); end if;
      select * into sess from public.game_sessions where id = s;
      exit when sess.status <> 'playing';
      c := t6.card(s);
      if (c ->> 'done')::boolean then perform public.next_round(s, sess.current_round); continue; end if;
      mv := t6.solve(g.mechanic, c, t6.sec(s), 1);
      if mv is null then raise exception 'ÉCHEC : % sans coup possible pour A (carte %)', g.id, c; end if;
      res := t6.mv(s, mv ->> 'type', coalesce(mv -> 'payload', '{}'));
      -- Paire ratée du robot encore visible : on attend 1,2 s comme un joueur.
      if res ->> 'error' = 'wait' then perform pg_sleep(1.25); continue; end if;
      if not coalesce((res ->> 'ok')::boolean, false) then raise exception 'ÉCHEC : % coup refusé % → % (carte %)', g.id, mv, res, c; end if;
    end loop;
    select * into sess from public.game_sessions where id = s;
    perform t6.ok(sess.status = 'ended' and sess.result is not null, g.id || ' : partie terminée avec résultat');
    select count(*) into n from public.session_rounds where session_id = s and revealed_at is not null;
    perform t6.ok(n = sess.total_rounds, g.id || ' : toutes les manches finies');
    perform t6.ok(private.version_config(sess) ->> 'turn' = 'free'
                  or exists (select 1 from private.board_moves where session_id = s and seat = 2), g.id || ' : le robot a joué');
    perform public.close_session(s);
  end loop;
end $$;

select 'TOUS LES TESTS FAMILLE 4 SONT PASSÉS' as resultat;
rollback;
