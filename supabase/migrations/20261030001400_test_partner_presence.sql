-- Partenaire automatique de test : il n'ouvre jamais d'onglet, donc n'a pas de présence temps réel.
-- L'instantané signale ce joueur (test_partner) pour que l'écran le considère toujours présent dans le salon.
-- Ne concerne que les comptes de private.test_autoplayers ; non destructif (enveloppe la fonction en place).
do $$
begin
  if not exists (select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
                 where n.nspname = 'private' and p.proname = 'get_session_state_rev') then
    alter function public.get_session_state(uuid) set schema private;
    alter function private.get_session_state(uuid) rename to get_session_state_rev;
  end if;
end $$;
revoke execute on function private.get_session_state_rev(uuid) from public, anon, authenticated;

create or replace function public.get_session_state(p_session uuid) returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare
  base jsonb := private.get_session_state_rev(p_session);
begin
  if not coalesce((base ->> 'ok')::boolean, false) or not exists (select 1 from private.test_autoplayers) then return base; end if;
  return jsonb_set(base, '{players}', coalesce((select jsonb_agg(case
      when exists (select 1 from private.test_autoplayers t where t.user_id::text = pl ->> 'user_id')
      then pl || '{"test_partner": true}'::jsonb else pl end order by (pl ->> 'seat')::int)
    from jsonb_array_elements(base -> 'players') pl), '[]'::jsonb));
end $$;
revoke execute on function public.get_session_state(uuid) from public, anon;
grant execute on function public.get_session_state(uuid) to authenticated;
