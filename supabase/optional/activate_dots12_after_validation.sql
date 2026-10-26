-- FACULTATIF : hors migrations automatiques. À exécuter manuellement UNIQUEMENT
-- après validation du preview/client dots12-v1 et accord du propriétaire.
-- Prérequis : migrations jusqu'à010, catalogue historique N2-079 version1 publié.
-- Ce bloc unique est atomique, sans COMMIT interne : le test l'annule intégralement.
-- Il publie la version préparée et change uniquement le pointeur des futures
-- séances. Aucune séance, carte, règle ou configuration existante n'est modifiée.
-- Une version publiée devient immuable ; un retour de pointeur ne convertit pas
-- les séances12 déjà créées. Garder les deux moteurs et clients disponibles.
do $activate_dots12$
declare
  expected_legacy constant integer := 1;
  game public.games;
  legacy public.game_versions;
  target public.game_versions;
  candidates integer;
begin
  perform set_config('lock_timeout', '5s', true);
  select * into game from public.games where id = 'N2-079' for update;
  if not found or game.status <> 'published' or game.implementation <> 'playable'
     or game.mechanic <> 'dots_boxes' then
    raise exception 'dots12_activation_game_mismatch';
  end if;

  -- Empêche l'insertion concurrente d'une seconde version portant le même nom
  -- sémantique entre le décompte et la publication ; verrou bref, jamais de scan
  -- ni de verrou sur les tables de séances.
  lock table public.game_versions in share row exclusive mode;
  select count(*) into candidates from public.game_versions
    where game_id = game.id and config ->> 'version' = 'noodeu-m04-2.0.0';
  if candidates <> 1 then raise exception 'dots12_activation_target_not_unique'; end if;
  select * into target from public.game_versions
    where game_id = game.id and config ->> 'version' = 'noodeu-m04-2.0.0' for update;
  if target.config ->> 'frontend_contract' is distinct from 'dots12-v1'
     or not (target.config @> '{"code":"M04","engine":"board","mechanic":"dots_boxes","rounds":1,"score":"duel","turn":"alternate","parameters":{"dot_rows":12,"dot_columns":12,"boxes":121,"edges":264}}'::jsonb)
     or target.config #>> '{parameters,dot_rows}' is distinct from '12'
     or target.config #>> '{parameters,dot_columns}' is distinct from '12'
     or target.config #>> '{parameters,boxes}' is distinct from '121'
     or target.config #>> '{parameters,edges}' is distinct from '264'
     or target.version <= expected_legacy
     or to_regprocedure('private.db_setup12(public.game_sessions)') is null
     or to_regprocedure('private.db_edge_ok(text,integer,integer)') is null then
    raise exception 'dots12_activation_contract_mismatch';
  end if;

  if game.current_version = target.version then
    if target.published_at is null then raise exception 'dots12_activation_current_unpublished'; end if;
    raise notice 'DOTS12 ALREADY ACTIVE : version%, aucune écriture', target.version;
    return;
  end if;
  if game.current_version is distinct from expected_legacy or target.published_at is not null then
    raise exception 'dots12_activation_current_mismatch';
  end if;
  select * into legacy from public.game_versions
    where game_id = game.id and version = expected_legacy;
  if not found or legacy.published_at is null
     or legacy.config ->> 'version' is distinct from 'noodeu-c34-1.0.0'
     or not (legacy.config @> '{"parameters":{"dot_rows":5,"dot_columns":5,"boxes":16,"edges":40}}'::jsonb)
     or legacy.config #>> '{parameters,dot_rows}' is distinct from '5'
     or legacy.config #>> '{parameters,dot_columns}' is distinct from '5'
     or legacy.config #>> '{parameters,boxes}' is distinct from '16'
     or legacy.config #>> '{parameters,edges}' is distinct from '40' then
    raise exception 'dots12_activation_legacy_mismatch';
  end if;

  update public.game_versions set published_at = now()
    where game_id = game.id and version = target.version;
  -- games_touch actualise updated_at. Pas de compteur catalogue global.
  update public.games set current_version = target.version where id = game.id;
  raise notice 'DOTS12 ACTIVATED : version%, anciennes séances inchangées', target.version;
end
$activate_dots12$;
