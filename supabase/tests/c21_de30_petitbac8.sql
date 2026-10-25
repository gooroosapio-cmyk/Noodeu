-- Dé chanceux à 30 et Petit bac à 8 rubriques. Transaction annulée.
begin;
create schema t16;
create function t16.as_user(p uuid) returns void language plpgsql as $$
begin perform set_config('request.jwt.claims', json_build_object('sub', p, 'role', 'authenticated')::text, true); end $$;
create function t16.ok(cond boolean, msg text) returns void language plpgsql as $$
begin if cond is distinct from true then raise exception 'ÉCHEC : %', msg; end if; end $$;
create function t16.uid(s uuid, seat int) returns uuid language sql as $$ select user_id from public.session_players where session_id = s and seat = $2 $$;
create function t16.card(s uuid) returns jsonb language sql as $$
  select card from public.session_rounds r join public.game_sessions g on g.id = r.session_id and r.round_no = g.current_round where g.id = s $$;
create function t16.mv(s uuid, seat int, typ text, p jsonb default '{}') returns jsonb language plpgsql as $$
begin
  perform t16.as_user(t16.uid(s, seat));
  return public.play_move(s, (select current_round from public.game_sessions where id = s), gen_random_uuid(), typ, p);
end $$;
create function t16.start(gid text, settings jsonb default null) returns uuid language plpgsql as $$
declare s uuid;
begin
  update public.game_sessions set status = 'abandoned' where status in ('lobby', 'playing', 'paused', 'ended');
  perform t16.as_user('00000000-0000-4000-a000-0000000000a6');
  s := (public.create_session(gid) ->> 'session_id')::uuid;
  if settings is not null then perform public.update_session_settings(s, settings); end if;
  perform public.set_ready(s, true);
  perform t16.as_user('00000000-0000-4000-a000-0000000000b6');
  perform public.set_ready(s, true);
  return s;
end $$;
grant usage on schema t16 to authenticated;
grant execute on all functions in schema t16 to authenticated;

insert into auth.users (id, email, raw_user_meta_data) values
  ('00000000-0000-4000-a000-0000000000a6', 'joueur-a6@noodeu.invalid', '{"display_name":"A"}'),
  ('00000000-0000-4000-a000-0000000000b6', 'joueur-b6@noodeu.invalid', '{"display_name":"B"}');
do $$
declare r jsonb;
begin
  perform t16.as_user('00000000-0000-4000-a000-0000000000a6');
  r := public.create_invitation();
  perform t16.as_user('00000000-0000-4000-a000-0000000000b6');
  perform public.claim_invitation(r ->> 'code');
  perform t16.as_user('00000000-0000-4000-a000-0000000000a6');
  perform public.respond_to_claim((r ->> 'id')::uuid, true);
end $$;

-- ===== Dé chanceux : 30 points conservés =====
do $$
declare s uuid; turn int; c jsonb;
begin
  s := t16.start('nd-de-chanceux');
  c := t16.card(s);
  perform t16.ok((c ->> 'target')::int = 30, 'objectif 30');
  turn := (c ->> 'turn')::int;
  -- 24 conservés et 6 en cours : pas de victoire avant « Conserver ».
  update public.session_rounds set card = jsonb_set(card || '{"turn_total": 6}', array['banked', turn::text], '24')
    where session_id = s and round_no = 1;
  perform t16.ok(not coalesce((t16.card(s) ->> 'done')::boolean, false), 'pas de victoire sans conserver');
  perform t16.ok((t16.mv(s, turn, 'hold') ->> 'ok')::boolean, 'conserver');
  c := t16.card(s);
  perform t16.ok((c ->> 'done')::boolean and (c ->> 'winner')::int = turn and (c #>> array['banked', turn::text])::int = 30, 'victoire à 30/30 en conservant');
  perform t16.ok((t16.mv(s, 3 - turn, 'roll') ->> 'ok')::boolean is not true, 'aucun coup après la victoire');
end $$;

do $$
declare s uuid; turn int; c jsonb;
begin
  s := t16.start('nd-de-chanceux');
  turn := (t16.card(s) ->> 'turn')::int;
  update public.session_rounds set card = jsonb_set(card || '{"turn_total": 6}', array['banked', turn::text], '28')
    where session_id = s and round_no = 1;
  perform t16.mv(s, turn, 'hold');
  c := t16.card(s);
  perform t16.ok((c ->> 'done')::boolean and (c #>> array['banked', turn::text])::int = 34, 'dépassement : 34/30, victoire');
  perform t16.ok((t16.mv(s, 3 - turn, 'hold') ->> 'error') is not null, 'conserver hors tour refusé');
end $$;

-- ===== Petit bac : 8 rubriques, Stop après huit champs, 180 s au salon =====
do $$
declare s uuid; c jsonb; letter text; r jsonb; k text; drafts jsonb := '{}';
begin
  s := t16.start('N2-018', '{"timer": 180}');
  perform t16.mv(s, 1, 'round_loaded');
  perform t16.mv(s, 2, 'round_loaded');
  c := t16.card(s);
  perform t16.ok(jsonb_array_length(c -> 'categories') = 8 and c -> 'categories' ->> 2 = 'metier' and c -> 'categories' ->> 7 = 'celebrite',
                 '8 rubriques dans l''ordre ligne par ligne');
  perform t16.ok(abs(extract(epoch from ((c ->> 'deadline_at')::timestamptz - (c ->> 'started_at')::timestamptz)) - 180) < 2, 'échéance 180 s');
  letter := c ->> 'letter';
  perform t16.ok(letter = any(private.pb_letters('petit_bac_huit', 8)), 'lettre couverte dans les 8 rubriques');
  -- Sept champs seulement : Stop refusé.
  for k in select jsonb_array_elements_text(c -> 'categories') loop
    drafts := drafts || jsonb_build_object(k, jsonb_build_object('text', letter || 'xemple', 'draft_revision', 1));
  end loop;
  update public.session_rounds set card = jsonb_set(card, '{stop_after}', to_jsonb(now() - interval '1 second')) where session_id = s and round_no = 1;
  r := t16.mv(s, 1, 'stop', jsonb_build_object('drafts', drafts - 'celebrite'));
  perform t16.ok(r ->> 'error' = 'fields_missing', 'Stop refusé avec 7 champs');
  r := t16.mv(s, 1, 'stop', jsonb_build_object('drafts', drafts || jsonb_build_object('celebrite', jsonb_build_object('text', letter || 'xemple', 'draft_revision', 2))));
  perform t16.ok((r ->> 'ok')::boolean and t16.card(s) ->> 'phase' = 'validation', 'Stop avec 8 champs : manche gelée');
  perform t16.ok((select count(*) from jsonb_object_keys(t16.card(s) #> '{answers,1}')) = 8, '8 réponses classées');
  perform t16.ok((t16.mv(s, 2, 'save_field', jsonb_build_object('category_id', 'animal', 'text', 'x', 'draft_revision', 5)) ->> 'error') = 'phase',
                 'écriture refusée après le gel');
end $$;

select 'TOUS LES TESTS DÉ À 30 ET PETIT BAC À 8 SONT PASSÉS';
rollback;
