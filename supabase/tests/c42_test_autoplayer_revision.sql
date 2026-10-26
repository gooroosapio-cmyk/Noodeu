-- Partenaire automatique de test et salon à révision : toujours prêt sur la révision courante, jamais de
-- démarrage silencieux, lancement seulement par l'hôte, textes de test aléatoires. Base jetable ; annulé.
begin;

create schema t42;
create function t42.as_user(p uuid) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', json_build_object('sub', p, 'role', 'authenticated')::text, true);
end $$;
create function t42.ok(cond boolean, msg text) returns void language plpgsql as $$
begin
  if cond is distinct from true then raise exception 'ÉCHEC : %', msg; end if;
end $$;
create function t42.rev(s uuid) returns int language sql as $$ select settings_rev from public.game_sessions where id = s $$;
create function t42.bot_agreed(s uuid, bot uuid) returns boolean language sql as $$
  select ready_at is not null and ready_rev = t42.rev(s) from public.session_players where session_id = s and user_id = bot $$;

insert into auth.users (id, email, raw_user_meta_data) values
  ('00000000-0000-4000-a000-0000000000a2', 'humain-a42@noodeu.invalid', '{"display_name":"A"}'),
  ('00000000-0000-4000-a000-0000000000b2', 'robot-b42@noodeu.invalid', '{"display_name":"Kalou"}');
insert into private.test_autoplayers (user_id, note) values ('00000000-0000-4000-a000-0000000000b2', 'test c42');
do $$
declare r jsonb;
begin
  perform t42.as_user('00000000-0000-4000-a000-0000000000a2');
  r := public.create_invitation();
  perform t42.as_user('00000000-0000-4000-a000-0000000000b2');
  perform public.claim_invitation(r ->> 'code');
  perform t42.as_user('00000000-0000-4000-a000-0000000000a2');
  perform public.respond_to_claim((r ->> 'id')::uuid, true);
end $$;

do $$
declare
  a uuid := '00000000-0000-4000-a000-0000000000a2';
  bot uuid := '00000000-0000-4000-a000-0000000000b2';
  s uuid; r jsonb; rev1 int; card jsonb;
begin
  -- Salon ouvert par l'humain : le robot valide la révision courante dès la création.
  perform t42.as_user(a);
  s := (public.create_session('nd-deux-verites-mensonge') ->> 'session_id')::uuid;
  perform t42.ok(t42.bot_agreed(s, bot), 'robot prêt sur la révision courante');
  perform t42.ok((select bool_and(coalesce((pl ->> 'test_partner')::boolean, false) = ((pl ->> 'user_id')::uuid = bot))
                  from jsonb_array_elements(public.get_session_state(s) -> 'players') pl), 'instantané : seul le robot est signalé');
  -- L'humain valide : aucun démarrage silencieux.
  r := public.set_ready_rev(s, true, t42.rev(s));
  perform t42.ok((select status from public.game_sessions where id = s) = 'lobby', 'pas de démarrage sans Lancer');
  -- Réglage modifié : nouvelle révision, le robot revalide aussitôt, l'humain doit revalider.
  r := public.update_session_settings(s, '{"cartes":3}');
  rev1 := t42.rev(s);
  perform t42.ok(t42.bot_agreed(s, bot), 'robot revalide la nouvelle révision');
  perform t42.ok((select ready_at is null from public.session_players where session_id = s and user_id = a), 'humain à revalider');
  r := public.launch_session(s, rev1);
  perform t42.ok(r ->> 'error' = 'not_ready', 'pas de lancement sans la validation de l''humain');
  r := public.set_ready_rev(s, true, rev1);
  perform t42.ok((select status from public.game_sessions where id = s) = 'lobby', 'toujours pas de démarrage silencieux');
  r := public.launch_session(s, rev1);
  perform t42.ok(r ->> 'status' = 'playing', 'l''hôte humain lance');
  -- Le robot joue son tour : s'il écrit, trois affirmations de test distinctes.
  card := (select rd.card from public.session_rounds rd where rd.session_id = s and rd.round_no = 1);
  if (card ->> 'author')::int = (select seat from public.session_players where session_id = s and user_id = bot) then
    perform t42.ok(card ->> 'phase' = 'guess' and jsonb_array_length(card -> 'statements') = 3
                   and (select bool_and(x ->> 'text' like '[Test]%') from jsonb_array_elements(card -> 'statements') x)
                   and (select count(distinct x ->> 'text') = 3 from jsonb_array_elements(card -> 'statements') x),
                   'robot auteur : trois phrases de test distinctes');
  else
    perform t42.ok(card ->> 'phase' = 'write', 'humain auteur : le robot attend');
  end if;
  perform public.abandon_session(s);

  -- Salon ouvert depuis le compte du robot : il lance quand l'humain a validé.
  perform t42.as_user(bot);
  s := (public.create_session('nd-action-verite') ->> 'session_id')::uuid;
  perform t42.as_user(a);
  r := public.set_ready_rev(s, true, t42.rev(s));
  perform t42.ok((select status from public.game_sessions where id = s) = 'playing', 'robot hôte : lancement après la validation de l''humain');
  perform t42.ok((select count(*) from public.session_rounds where session_id = s) = 1, 'une seule manche');
end $$;

select 'C42 PASS : PARTENAIRE DE TEST TOUJOURS PRÊT SUR LA RÉVISION, SANS DÉMARRAGE SILENCIEUX, TEXTES ALÉATOIRES';
rollback;
