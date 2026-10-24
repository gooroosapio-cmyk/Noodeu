-- Tests des duos multiples : plusieurs duos actifs, bascule sans perte, cloisonnement strict entre duos,
-- fin de duo sans notification. Transaction annulée à la fin : aucune donnée ne reste.
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
-- Invitation complète : x invite, y rejoint, x accepte. Renvoie le duo.
create function t13.pair(x uuid, y uuid) returns uuid language plpgsql as $$
declare r jsonb; a jsonb;
begin
  perform t13.as_user(x);
  r := public.create_invitation();
  perform t13.as_user(y);
  perform public.claim_invitation(r ->> 'code');
  perform t13.as_user(x);
  a := public.respond_to_claim((r ->> 'id')::uuid, true);
  if not coalesce((a ->> 'ok')::boolean, false) then raise exception 'pair: %', a; end if;
  return (a ->> 'couple_id')::uuid;
end $$;
grant usage on schema t13 to authenticated;
grant execute on all functions in schema t13 to authenticated;

insert into auth.users (id, email, raw_user_meta_data) values
  ('00000000-0000-4000-a000-0000000000a3', 'a3@noodeu.invalid', '{"display_name":"A"}'),
  ('00000000-0000-4000-a000-0000000000b3', 'b3@noodeu.invalid', '{"display_name":"B"}'),
  ('00000000-0000-4000-a000-0000000000c3', 'c3@noodeu.invalid', '{"display_name":"C"}');

do $$
declare
  a uuid := '00000000-0000-4000-a000-0000000000a3';
  b uuid := '00000000-0000-4000-a000-0000000000b3';
  c uuid := '00000000-0000-4000-a000-0000000000c3';
  ab uuid; ac uuid; s_ab uuid; s_ac uuid; n int; r jsonb; denied boolean;
begin
  ab := t13.pair(a, b);
  perform t13.as_user(b);
  perform public.send_duo_message(gen_random_uuid(), 'Message dans le duo A-B');

  -- A ajoute un second duo, avec C, sans terminer le premier.
  n := (select count(*) from public.notifications where user_id = b);
  ac := t13.pair(a, c);
  perform t13.ok(ab <> ac, 'deux duos distincts');
  perform t13.ok((select count(*) from public.couples where id in (ab, ac) and status = 'active') = 2, 'les deux duos restent actifs');
  perform t13.ok((select count(*) from public.notifications where user_id = b) = n, 'B n''est pas prévenu du nouveau duo de A');
  perform t13.as_user(a);
  perform t13.ok(private.my_couple_id() = ac, 'A affiche le duo qu''il vient d''accepter');
  perform t13.as_user(b);
  perform t13.ok(private.my_couple_id() = ab, 'B garde son duo affiché');

  -- Une même paire ne peut pas ouvrir un second duo actif.
  perform t13.as_user(b);
  r := public.create_invitation();
  perform t13.as_user(a);
  perform t13.ok(public.claim_invitation(r ->> 'code') ->> 'error' = 'already_your_duo', 'pas de doublon de duo entre A et B');
  perform t13.as_user(b);
  perform public.revoke_invitation((r ->> 'id')::uuid);

  -- Parties ouvertes en même temps dans les deux duos ; bascule sans perte.
  perform t13.as_user(a);
  s_ac := (public.create_session('N2-076') ->> 'session_id')::uuid;
  perform t13.ok(public.set_current_duo(ab) ->> 'ok' = 'true', 'A bascule sur A-B');
  perform t13.ok(private.my_couple_id() = ab and (public.get_my_duos() -> 0 ->> 'id')::uuid = ab
                 and (public.get_my_duos() -> 0 ->> 'current')::boolean, 'duo affiché en premier, marqué courant');
  s_ab := (public.create_session('N2-083') ->> 'session_id')::uuid;
  perform t13.ok(s_ab is not null and s_ac is not null and s_ab <> s_ac, 'une partie ouverte dans chaque duo');
  perform t13.ok((public.get_open_session() ->> 'id')::uuid = s_ab, 'partie du duo affiché');
  perform public.set_current_duo(ac);
  perform t13.ok((public.get_open_session() ->> 'id')::uuid = s_ac
                 and (select status from public.game_sessions where id = s_ab) = 'lobby', 'retour sur A-C : rien de perdu dans A-B');
  perform t13.ok((select count(*) from public.duo_messages where couple_id = ab) = 1, 'messages de A-B conservés');
  perform t13.ok(exists (select 1 from jsonb_array_elements(public.get_my_duos()) d where (d ->> 'id')::uuid = ab and (d ->> 'unread')::int = 1),
                 'non-lus de l''autre duo signalés');

  -- Cloisonnement : B ne voit rien du duo A-C, C rien du duo A-B (tables et fonctions).
  perform t13.as_user(b);
  perform t13.ok(public.set_current_duo(ac) ->> 'error' = 'not_allowed', 'B ne peut pas afficher le duo A-C');
  perform t13.ok((public.get_session_state(s_ac) ->> 'error') = 'session_not_found', 'B ne lit pas la partie de A-C');
  perform t13.ok(not exists (select 1 from jsonb_array_elements(public.get_my_duos()) d where (d ->> 'id')::uuid = ac), 'B ne voit pas le duo A-C');
  set local role authenticated;
  perform t13.ok(not exists (select 1 from public.couples where id = ac), 'table des duos : A-C invisible pour B');
  perform t13.ok(not exists (select 1 from public.couple_members where couple_id = ac), 'membres de A-C invisibles pour B');
  perform t13.ok(not exists (select 1 from public.game_sessions where couple_id = ac), 'parties de A-C invisibles pour B');
  perform t13.ok(not exists (select 1 from public.profiles where id = c), 'profil de C invisible pour B');
  reset role;
  perform t13.as_user(c);
  set local role authenticated;
  perform t13.ok(not exists (select 1 from public.duo_messages where couple_id = ab), 'messages de A-B invisibles pour C');
  perform t13.ok(not exists (select 1 from public.game_sessions where couple_id = ab), 'parties de A-B invisibles pour C');
  perform t13.ok(not exists (select 1 from public.profiles where id = b), 'profil de B invisible pour C');
  reset role;
  denied := false;
  begin
    perform public.leave_duo(ab);
  exception when others then denied := true;
  end;
  perform t13.ok((select status from public.couples where id = ab) = 'active', 'C ne peut pas terminer le duo A-B');

  -- Fin d'un duo : aucune notification, l'autre duo continue.
  n := (select count(*) from public.notifications);
  perform t13.as_user(a);
  perform t13.ok((public.leave_duo(ac) ->> 'ok')::boolean, 'A termine le duo A-C');
  perform t13.ok((select count(*) from public.notifications) = n, 'aucune notification de fin de duo');
  perform t13.ok((select status from public.couples where id = ac) = 'separated' and (select status from public.couples where id = ab) = 'active',
                 'A-C archivé, A-B intact');
  perform t13.ok(private.my_couple_id() = ab, 'A revient automatiquement sur son autre duo');
  perform t13.as_user(c);
  perform t13.ok(private.my_couple_id() is null and exists (select 1 from jsonb_array_elements(public.get_my_duos()) d
                 where (d ->> 'id')::uuid = ac and not (d ->> 'active')::boolean), 'C garde l''historique en lecture seule');
  perform t13.ok(not exists (select 1 from public.notifications where type = 'duo_ended'), 'aucune notification « duo terminé »');
end $$;

select 'TOUS LES TESTS DUOS MULTIPLES SONT PASSÉS';
rollback;
