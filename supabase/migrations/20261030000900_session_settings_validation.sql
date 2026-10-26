-- Réglages du salon : valider l'objet entier contre la version figée de la séance.
-- Une clé absente du schéma ne doit pas échapper au refus via une condition SQL NULL.
-- L'égalité JSON exacte conserve les types et refuse les sous-objets d'une option.
create or replace function public.update_session_settings(p_session uuid, p_settings jsonb) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  r record;
  definitions jsonb;
  options jsonb;
  k text;
  val jsonb;
  canonical jsonb;
  merged jsonb;
begin
  select * into r from private.lock_session(p_session);
  if (r.s).status <> 'lobby' then return jsonb_build_object('ok', false, 'error', 'not_in_lobby'); end if;
  if jsonb_typeof(p_settings) is distinct from 'object' then
    return jsonb_build_object('ok', false, 'error', 'invalid_settings');
  end if;

  definitions := coalesce(private.version_config(r.s) -> 'settings', '{}'::jsonb);
  if jsonb_typeof(definitions) is distinct from 'object' then
    return jsonb_build_object('ok', false, 'error', 'invalid_settings');
  end if;
  merged := (r.s).settings;
  for k, val in select * from jsonb_each(p_settings) loop
    if not (definitions ? k) then
      return jsonb_build_object('ok', false, 'error', 'invalid_settings');
    end if;
    options := definitions -> k -> 'options';
    if jsonb_typeof(options) is distinct from 'array' then
      return jsonb_build_object('ok', false, 'error', 'invalid_settings');
    end if;
    select allowed.value into canonical from jsonb_array_elements(options) as allowed(value)
      where allowed.value = val limit 1;
    if not found then
      return jsonb_build_object('ok', false, 'error', 'invalid_settings');
    end if;
    -- JSONB juge 4.0 égal à 4 : garder la forme déclarée permet ensuite le cast entier
    -- de rounds_setting au démarrage, sans accepter une chaîne de caractères "4".
    merged := merged || jsonb_build_object(k, canonical);
  end loop;

  -- Aucun changement persistant avant la validation de toutes les clés du patch.
  -- Comparer aussi la représentation numérique : un ancien salon peut déjà stocker
  -- 4.0, égal à 4 en JSONB mais inutilisable par le cast entier du démarrage.
  if merged::text = (r.s).settings::text then return jsonb_build_object('ok', true); end if;
  update public.game_sessions set settings = merged where id = p_session;
  update public.session_players set ready_at = null where session_id = p_session;
  perform private.bump_session(p_session, 'settings');
  return jsonb_build_object('ok', true);
end $$;
