-- Tests du partenaire automatique de la phase de test : toujours prêt, répond seul à ses étapes,
-- passe par les validations normales, ne fait rien quand aucun compte n'est inscrit.
-- Transaction annulée à la fin : aucune donnée ne reste.
begin;

create schema t3;
create function t3.as_user(p uuid) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', json_build_object('sub', p, 'role', 'authenticated')::text, true);
end $$;
create function t3.ok(cond boolean, msg text) returns void language plpgsql as $$
begin
  if cond is distinct from true then raise exception 'ÉCHEC : %', msg; end if;
end $$;

insert into auth.users (id, email, raw_user_meta_data) values
  ('00000000-0000-4000-a000-0000000000a1', 'humain@noodeu.invalid', '{"display_name":"Humain"}'),
  ('00000000-0000-4000-a000-0000000000b1', 'robot@noodeu.invalid', '{"display_name":"Robot"}');

do $$
declare r jsonb;
begin
  perform t3.as_user('00000000-0000-4000-a000-0000000000a1');
  r := public.create_invitation();
  perform t3.as_user('00000000-0000-4000-a000-0000000000b1');
  perform public.claim_invitation(r ->> 'code');
  perform t3.as_user('00000000-0000-4000-a000-0000000000a1');
  perform public.respond_to_claim((r ->> 'id')::uuid, true);
end $$;

-- Sans inscription : le partenaire n'est pas prêt tout seul.
do $$
declare s uuid;
begin
  perform t3.as_user('00000000-0000-4000-a000-0000000000a1');
  s := (public.create_session('N2-002') ->> 'session_id')::uuid;
  perform t3.ok((select ready_at is null from public.session_players where session_id = s and seat = 2), 'aucun robot sans inscription');
  update public.game_sessions set status = 'abandoned' where id = s;
end $$;

insert into private.test_autoplayers (user_id, note) values ('00000000-0000-4000-a000-0000000000b1', 'test');

-- Chaque activité jouable : l'humain joue seul, le robot suit, la partie va jusqu'au bout.
do $$
declare
  g record;
  s uuid;
  sess public.game_sessions;
  n int;
  guard int;
  rd public.session_rounds;
begin
  for g in select g2.id from public.games g2 join public.game_categories gc on gc.id = g2.category_id
           where g2.implementation = 'playable' and gc.family_no = 1 order by g2.sort loop
    perform t3.as_user('00000000-0000-4000-a000-0000000000a1');
    s := (public.create_session(g.id) ->> 'session_id')::uuid;
    perform t3.ok((select ready_at is not null from public.session_players where session_id = s and seat = 2), g.id || ' : robot prêt dans le salon');
    perform t3.ok(auth.uid() = '00000000-0000-4000-a000-0000000000a1', g.id || ' : identité rendue après le robot');
    perform public.set_ready(s, true);
    select * into sess from public.game_sessions where id = s;
    perform t3.ok(sess.status = 'playing', g.id || ' : partie lancée');
    for n in 1 .. sess.total_rounds loop
      guard := 0;
      while guard < 20 and private.bot_step(s, 1) loop guard := guard + 1; end loop;
      select * into rd from public.session_rounds where session_id = s and round_no = n;
      perform t3.ok(rd.revealed_at is not null, g.id || ' : manche ' || n || ' révélée');
      if rd.revealed_at <= now() then
        guard := 0;
        while guard < 20 and private.bot_step(s, 1) loop guard := guard + 1; end loop;
        perform t3.ok(not exists (
          select 1 from public.game_sessions gs, public.game_versions v, jsonb_array_elements(coalesce(v.config -> 'after', '[]')) st,
                        unnest(private.step_seats(st, rd.card)) x(seat_no)
          where gs.id = s and v.game_id = gs.game_id and v.version = gs.game_version
            and not exists (select 1 from public.session_answers a where a.session_id = s and a.round_no = n
                            and a.step = st ->> 'key' and a.seat = x.seat_no)), g.id || ' : étapes après révélation faites');
      end if;
      if n < sess.total_rounds then perform public.next_round(s, n); end if;
    end loop;
    perform t3.ok((select status from public.game_sessions where id = s) = 'ended', g.id || ' : partie terminée');
    perform t3.ok((select count(*) from public.session_answers where session_id = s and seat = 2
                   and user_id = '00000000-0000-4000-a000-0000000000b1') > 0, g.id || ' : réponses enregistrées au nom du robot');
    perform public.close_session(s);
  end loop;
end $$;

-- Préférences de partie recopiées sur celles de l'humain.
do $$
declare s uuid;
begin
  perform t3.as_user('00000000-0000-4000-a000-0000000000a1');
  s := (public.create_session('N2-002') ->> 'session_id')::uuid;
  update public.session_prefs set excluded_topics = '{passe}' where session_id = s and seat = 1;
  perform private.bump_session(s, 'prefs');
  perform t3.ok((select excluded_topics = '{passe}' from public.session_prefs where session_id = s and seat = 2), 'préférences recopiées');
end $$;

select 'TOUS LES TESTS DU PARTENAIRE AUTOMATIQUE SONT PASSÉS' as resultat;
rollback;
