-- Test de pureté : indice sur 100 et Non sur 72, partage des réponses seulement au clic final. Transaction annulée.
begin;
create schema t15;
create function t15.as_user(p uuid) returns void language plpgsql as $$
begin perform set_config('request.jwt.claims', json_build_object('sub', p, 'role', 'authenticated')::text, true); end $$;
create function t15.ok(cond boolean, msg text) returns void language plpgsql as $$
begin if cond is distinct from true then raise exception 'ÉCHEC : %', msg; end if; end $$;
create function t15.uid(s uuid, seat int) returns uuid language sql as $$ select user_id from public.session_players where session_id = s and seat = $2 $$;
create function t15.mv(s uuid, seat int, typ text, p jsonb default '{}') returns jsonb language plpgsql as $$
begin
  perform t15.as_user(t15.uid(s, seat));
  return public.play_move(s, 1, gen_random_uuid(), typ, p);
end $$;
-- n premières questions à « Non » (0), les autres à « Oui » (1), sur les questions [from, to].
create function t15.answers(n_non int, upto int default 72) returns jsonb language sql as $$
  select jsonb_object_agg(value ->> 'id', case when (value ->> 'source_position')::int <= n_non then 0 else 1 end)
  from public.content_banks where bank = 'q_rice' and (value ->> 'source_position')::int <= upto $$;
grant usage on schema t15 to authenticated;
grant execute on all functions in schema t15 to authenticated;

insert into auth.users (id, email, raw_user_meta_data) values
  ('00000000-0000-4000-a000-0000000000a5', 'joueur-a5@noodeu.invalid', '{"display_name":"A"}'),
  ('00000000-0000-4000-a000-0000000000b5', 'joueur-b5@noodeu.invalid', '{"display_name":"B"}');
do $$
declare r jsonb;
begin
  perform t15.as_user('00000000-0000-4000-a000-0000000000a5');
  r := public.create_invitation();
  perform t15.as_user('00000000-0000-4000-a000-0000000000b5');
  perform public.claim_invitation(r ->> 'code');
  perform t15.as_user('00000000-0000-4000-a000-0000000000a5');
  perform public.respond_to_claim((r ->> 'id')::uuid, true);
end $$;

do $$
declare s uuid; card jsonb; v text;
begin
  perform t15.as_user('00000000-0000-4000-a000-0000000000a5');
  s := (public.create_session('ND-Q-011') ->> 'session_id')::uuid;
  perform public.set_ready(s, true);
  perform t15.as_user('00000000-0000-4000-a000-0000000000b5');
  perform public.set_ready(s, true);
  -- A enregistre une page : rien n'est visible pour B.
  perform t15.ok((t15.mv(s, 1, 'save', jsonb_build_object('answers', t15.answers(5, 10), 'page', 1)) ->> 'ok')::boolean, 'page enregistrée');
  perform t15.as_user(t15.uid(s, 2));
  v := public.get_session_state(s)::text;
  perform t15.ok(position('C2-01-001' in coalesce((public.get_session_state(s) #> '{rounds,0,card,shared}')::text, '')) = 0
                 and (public.get_session_state(s) #> '{rounds,0,private,answers}') is null, 'aucune réponse de A visible avant la fin');
  -- A termine avec 50 Non sur 72 et le partage (défaut) : 69/100, 50/72 et réponses montrées.
  perform t15.ok((t15.mv(s, 1, 'complete', jsonb_build_object('answers', t15.answers(50), 'page', 7, 'share', true)) ->> 'ok')::boolean, 'A termine');
  card := (select r.card from public.session_rounds r where session_id = s and round_no = 1);
  perform t15.ok((card #>> '{shared,1,indice}')::int = 69 and (card #>> '{shared,1,non}')::int = 50, 'indice 69/100 et 50 Non sur 72');
  perform t15.ok(jsonb_typeof(card #> '{shared,1,answers}') = 'object' and (select count(*) from jsonb_object_keys(card #> '{shared,1,answers}')) = 72,
                 'réponses montrées au clic final');
  -- B passe une question et termine sans partager : résultat incomplet, rien de montré.
  perform t15.ok((t15.mv(s, 2, 'complete', jsonb_build_object('answers', t15.answers(30, 71), 'page', 7, 'share', false)) ->> 'ok')::boolean, 'B termine');
  card := (select r.card from public.session_rounds r where session_id = s and round_no = 1);
  perform t15.ok(not (card -> 'shared' ? '2'), 'B : rien de partagé');
  perform t15.as_user(t15.uid(s, 2));
  perform t15.ok(public.get_session_state(s) #>> '{rounds,0,private,result,status}' = 'incomplete'
                 and (public.get_session_state(s) #>> '{rounds,0,private,result,answered}')::int = 71, 'B : résultat incomplet 71/72');
  -- A retire son partage.
  perform t15.as_user(t15.uid(s, 1));
  perform t15.ok((public.set_answer_shared(s, 1, false) ->> 'ok')::boolean, 'A retire le partage');
  perform t15.ok(not ((select r.card from public.session_rounds r where session_id = s and round_no = 1) -> 'shared' ? '1'), 'partage retiré');
end $$;

select 'TOUS LES TESTS DU TEST DE PURETÉ SONT PASSÉS';
rollback;
