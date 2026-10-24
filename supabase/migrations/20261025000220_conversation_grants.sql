-- Fonctions de partie réservées aux comptes connectés (défense en profondeur : lock_session refuse déjà
-- tout appel sans joueur authentifié).
revoke execute on function public.play_move(uuid, int, uuid, text, jsonb) from public, anon;
revoke execute on function public.round_after(uuid, int, text, jsonb) from public, anon;
revoke execute on function public.set_session_prefs(uuid, boolean, text[]) from public, anon;
grant execute on function public.play_move(uuid, int, uuid, text, jsonb), public.round_after(uuid, int, text, jsonb),
  public.set_session_prefs(uuid, boolean, text[]) to authenticated;
