-- Changement de mot de passe côté serveur, en une seule opération liée au jeton de l'appelant.
-- Remplace la vérification par reconnexion dans le navigateur : aucune session n'est ouverte ni remplacée,
-- un changement de compte pendant l'opération ne peut pas viser un autre compte, et une réponse tardive
-- ne reconnecte personne. Essais limités (5 échecs / 15 min). Aucune donnée existante modifiée.

create table private.password_attempts (
  user_id uuid not null references auth.users(id) on delete cascade,
  success boolean not null,
  created_at timestamptz not null default now()
);
create index password_attempts_user on private.password_attempts(user_id, created_at desc);
alter table private.password_attempts enable row level security;

create function public.change_password(p_current text, p_new text) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  me uuid := auth.uid();
  hash text;
  failures int;
begin
  if me is null then return jsonb_build_object('ok', false, 'error', 'not_authenticated'); end if;
  -- bcrypt n'utilise que les 72 premiers octets : au-delà, refus explicite plutôt que troncature silencieuse.
  if p_new is null or char_length(p_new) < 8 or octet_length(p_new) > 72 then
    return jsonb_build_object('ok', false, 'error', 'weak_password'); end if;
  select count(*) into failures from private.password_attempts
    where user_id = me and not success and created_at > now() - interval '15 minutes';
  if failures >= 5 then return jsonb_build_object('ok', false, 'error', 'too_many_attempts'); end if;

  select encrypted_password into hash from auth.users where id = me for update;
  if hash is null or hash = '' or p_current is null or extensions.crypt(p_current, hash) is distinct from hash then
    insert into private.password_attempts(user_id, success) values (me, false);
    return jsonb_build_object('ok', false, 'error', 'wrong_password');
  end if;
  if extensions.crypt(p_new, hash) = hash then return jsonb_build_object('ok', false, 'error', 'same_password'); end if;

  update auth.users set encrypted_password = extensions.crypt(p_new, extensions.gen_salt('bf', 10)), updated_at = now()
    where id = me;
  insert into private.password_attempts(user_id, success) values (me, true);
  return jsonb_build_object('ok', true);
end $$;

revoke all on function public.change_password(text, text) from public, anon;
grant execute on function public.change_password(text, text) to authenticated;
