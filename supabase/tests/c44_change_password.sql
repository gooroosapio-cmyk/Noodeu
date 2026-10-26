-- Changement de mot de passe côté serveur (uniquement sur PostgreSQL jetable, aucun compte réel).
-- Transaction annulée à la fin.
begin;
create schema t44;
create function t44.as_user(p uuid) returns void language sql as $$
  select set_config('request.jwt.claims', case when p is null then '{}' else json_build_object('sub', p, 'role', 'authenticated')::text end, true) $$;
create function t44.ok(c boolean, msg text) returns void language plpgsql as $$
begin if c is distinct from true then raise exception 'ÉCHEC : %', msg; end if; end $$;
create function t44.matches(u uuid, pw text) returns boolean language sql as $$
  select encrypted_password = extensions.crypt(pw, encrypted_password) from auth.users where id = u $$;

insert into auth.users (id, email, encrypted_password, raw_user_meta_data) values
  ('00000000-0000-4000-a000-000000000044', 'a44@noodeu.invalid', extensions.crypt('ancien-mdp', extensions.gen_salt('bf')), '{"display_name":"A"}'),
  ('00000000-0000-4000-b000-000000000044', 'b44@noodeu.invalid', extensions.crypt('mdp-de-b', extensions.gen_salt('bf')), '{"display_name":"B"}');

do $$
declare
  a uuid := '00000000-0000-4000-a000-000000000044';
  b uuid := '00000000-0000-4000-b000-000000000044';
  r jsonb; i int;
begin
  -- Sans connexion : refus, et la fonction n'est pas appelable par anon.
  perform t44.ok(not has_function_privilege('anon', 'public.change_password(text,text)', 'execute'), 'anon sans accès');
  perform t44.as_user(null);
  perform t44.ok(public.change_password('x', 'nouveau-mdp') ->> 'error' = 'not_authenticated', 'refus sans jeton');

  perform t44.as_user(a);
  perform t44.ok(public.change_password('ancien-mdp', 'court') ->> 'error' = 'weak_password', '8 caractères minimum');
  perform t44.ok(public.change_password('ancien-mdp', repeat('é', 40)) ->> 'error' = 'weak_password', 'plus de 72 octets refusé');
  perform t44.ok(public.change_password('ancien-mdp', 'ancien-mdp') ->> 'error' = 'same_password', 'identique refusé');
  perform t44.ok(public.change_password('faux', 'nouveau-mdp') ->> 'error' = 'wrong_password', 'mauvais actuel refusé');
  perform t44.ok(t44.matches(a, 'ancien-mdp'), 'rien modifié après refus');

  r := public.change_password('ancien-mdp', 'nouveau-mdp');
  perform t44.ok((r ->> 'ok')::boolean, 'changement réussi');
  perform t44.ok(t44.matches(a, 'nouveau-mdp') and not t44.matches(a, 'ancien-mdp'), 'nouveau hachage bcrypt valide');
  perform t44.ok((select encrypted_password like '$2a$10$%' from auth.users where id = a), 'format bcrypt $2a$ attendu par Supabase Auth');
  -- Le jeton de A ne touche jamais B.
  perform t44.ok(t44.matches(b, 'mdp-de-b'), 'mot de passe de B inchangé');

  -- Limite d'essais : 5 échecs en 15 minutes bloquent, même avec le bon mot de passe.
  for i in 1..5 loop perform public.change_password('mauvais', 'autre-mdp-1'); end loop;
  perform t44.ok(public.change_password('nouveau-mdp', 'autre-mdp-1') ->> 'error' = 'too_many_attempts', 'blocage après 5 échecs');
  perform t44.ok(t44.matches(a, 'nouveau-mdp'), 'aucun changement pendant le blocage');
  -- Les échecs de A ne bloquent pas B.
  perform t44.as_user(b);
  perform t44.ok((public.change_password('mdp-de-b', 'mdp-de-b-2') ->> 'ok')::boolean, 'B non bloqué par les essais de A');
  -- Aucune lecture directe des essais.
  set local role authenticated;
  begin
    perform 1 from private.password_attempts;
    raise exception 'ÉCHEC : lecture des essais autorisée';
  exception when insufficient_privilege then null;
  end;
  reset role;
  raise notice 'c44 changement de mot de passe : OK';
end $$;
rollback;
