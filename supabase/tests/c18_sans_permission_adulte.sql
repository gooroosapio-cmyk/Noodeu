-- Tests du retrait des permissions +18 : aucune activation dans les Réglages ni accord dans le salon, aucun plafond
-- d'intensité ; les cartes +18 font partie du jeu. Transaction annulée à la fin : aucune donnée ne reste.
begin;

create schema t13;
create function t13.as_user(p uuid) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', json_build_object('sub', p, 'role', 'authenticated')::text, true);
end $$;
create function t13.ok(cond boolean, msg text) returns void language plpgsql as $$
begin
  if cond is distinct from true then raise exception 'ÉCHEC : %', msg; end if;
end $$;
-- Lancement sans aucune préférence +18 : création puis « prêt » des deux.
create function t13.start(gid text) returns uuid language plpgsql as $$
declare s uuid; r jsonb;
begin
  update public.game_sessions set status = 'abandoned' where status in ('lobby', 'playing', 'paused', 'ended');
  perform t13.as_user('00000000-0000-4000-a000-0000000000a3');
  r := public.create_session(gid);
  perform t13.ok(r ->> 'session_id' is not null, gid || ' : création sans permission (' || coalesce(r ->> 'error', '') || ')');
  s := (r ->> 'session_id')::uuid;
  perform public.set_ready(s, true);
  perform t13.as_user('00000000-0000-4000-a000-0000000000b3');
  r := public.set_ready(s, true);
  perform t13.ok((r ->> 'status') = 'playing', gid || ' : lancement sans accord +18 (' || coalesce(r ->> 'error', '') || ')');
  return s;
end $$;
grant usage on schema t13 to authenticated;
grant execute on all functions in schema t13 to authenticated;

insert into auth.users (id, email, raw_user_meta_data) values
  ('00000000-0000-4000-a000-0000000000a3', 'joueur-a3@noodeu.invalid', '{"display_name":"A"}'),
  ('00000000-0000-4000-a000-0000000000b3', 'joueur-b3@noodeu.invalid', '{"display_name":"B"}');
do $$
declare r jsonb;
begin
  perform t13.as_user('00000000-0000-4000-a000-0000000000a3');
  r := public.create_invitation();
  perform t13.as_user('00000000-0000-4000-a000-0000000000b3');
  perform public.claim_invitation(r ->> 'code');
  perform t13.as_user('00000000-0000-4000-a000-0000000000a3');
  perform public.respond_to_claim((r ->> 'id')::uuid, true);
end $$;

do $$
declare s uuid; f jsonb;
begin
  perform t13.ok((select intimate_opt_in and max_intensity = 'hot' from public.profiles where id = '00000000-0000-4000-a000-0000000000a3'),
                 'nouveau profil : +18 actif, sans plafond');
  -- Même avec d'anciens réglages restrictifs, rien n'est bloqué.
  update public.profiles set intimate_opt_in = false, max_intensity = 'soft'
    where id in ('00000000-0000-4000-a000-0000000000a3', '00000000-0000-4000-a000-0000000000b3');

  -- Pack contenant des cartes +18 : toutes les cartes dans la séance.
  s := t13.start('ND-Q-P15');
  perform t13.ok(private.adult_allowed(s), 'contenu +18 actif sans accord');
  perform t13.ok((select total_rounds from public.game_sessions where id = s) = 50, 'pack : toutes les cartes, +18 comprises (50 au plus)');

  -- Activité À huis clos : se lance sans activation ni accord.
  s := t13.start('ND-Q-011');

  -- Activité « hot » malgré un plafond Soft enregistré : se lance.
  s := t13.start('ND-Q-H01');

  -- Jeu de conversation : les cartes +18 sont tirées sans accord.
  s := t13.start('N2-003');
  perform t13.ok(exists (select 1 from generate_series(1, 80) where (private.conv_draw(s, 'conv_never', null, '{}') ->> 'adult')::boolean),
                 'conversation : cartes +18 tirées sans accord');

  perform t13.ok(not exists (select 1 from public.game_versions v join public.games g on g.id = v.game_id and g.current_version = v.version where v.rules::text ~ 'activez tous les deux|dans Réglages et dans le salon|de \+18\.'),
                 'règles : plus aucune mention d''activation du +18');
  perform t13.as_user('00000000-0000-4000-a000-0000000000a3');
  f := public.get_my_filters();
  perform t13.ok((f ->> 'duo_cap')::int = 3 and (f ->> 'duo_adult')::boolean, 'filtres : aucun plafond, +18 actif');
end $$;

select 'TOUS LES TESTS SANS PERMISSION +18 SONT PASSÉS';
rollback;
