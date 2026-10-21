-- Noodeu · Autorisation des canaux temps réel (Supabase Realtime, canaux privés).
-- Sujets :
--   user:<uid>        notifications personnelles (invitation reçue, réponse, séparation)
--   couple:<id>       statut d'une partie du couple, présence en ligne
--   session:<id>      signaux de la partie + messages du salon, présence dans la partie
-- Les navigateurs peuvent RECEVOIR la diffusion et PUBLIER leur présence, mais pas diffuser
-- eux-mêmes : seuls les signaux émis par la base font foi.

create function private.can_join_topic(p_topic text) returns boolean
language plpgsql stable security definer set search_path = '' as $$
declare
  prefix text := split_part(p_topic, ':', 1);
  ref uuid;
begin
  begin
    ref := split_part(p_topic, ':', 2)::uuid;
  exception when others then
    return false;
  end;
  if prefix = 'user' then
    return ref = auth.uid();
  elsif prefix = 'couple' then
    return private.is_member(ref);
  elsif prefix = 'session' then
    return private.is_member(private.session_couple(ref));
  end if;
  return false;
end $$;
grant execute on function private.can_join_topic(text) to authenticated;

create policy noodeu_receive on realtime.messages for select to authenticated
  using (realtime.messages.extension in ('broadcast', 'presence')
         and private.can_join_topic((select realtime.topic())));

create policy noodeu_presence on realtime.messages for insert to authenticated
  with check (realtime.messages.extension = 'presence'
              and private.can_join_topic((select realtime.topic())));
