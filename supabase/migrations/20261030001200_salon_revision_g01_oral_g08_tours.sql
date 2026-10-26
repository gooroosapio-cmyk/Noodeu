-- Refonte rouge (26/10/2026), règles serveur. Migration non destructive : aucune colonne ni ligne supprimée,
-- les séances déjà commencées gardent leur version de règles et les anciens appels restent acceptés.
-- 1. Salon : révision de configuration. Chaque changement de réglage ou de préférence crée une révision ;
--    une validation n'est valable que pour la révision acceptée. Le lancement est une action distincte de
--    l'hôte (créateur de la séance), atomique et idempotente.
-- 2. G01 Action ou vérité : plus de réponse écrite. « C'est répondu » / « C'est fait » sans texte.
-- 3. G08 Deux vérités et un mensonge : retour au tour par tour (un écrit, l'autre devine), 3, 5 ou 7 tours.

-- 1. Révision des réglages ---------------------------------------------------------------------------------
alter table public.game_sessions add column if not exists settings_rev integer not null default 0;
alter table public.session_players add column if not exists ready_rev integer;

-- Tout changement effectif des réglages du salon produit une nouvelle révision, quelle que soit la fonction
-- qui l'écrit (update_session_settings existante, version 900 ou antérieure).
create or replace function private.settings_revision() returns trigger
language plpgsql set search_path = '' as $$
begin
  if new.status = 'lobby' and new.settings::text is distinct from old.settings::text then
    new.settings_rev := old.settings_rev + 1;
  end if;
  return new;
end $$;
drop trigger if exists game_sessions_settings_rev on public.game_sessions;
create trigger game_sessions_settings_rev before update of settings on public.game_sessions
  for each row execute function private.settings_revision();

-- Les préférences par joueur (thèmes exclus, +18) font partie de la configuration acceptée.
create or replace function private.prefs_revision() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  update public.game_sessions set settings_rev = settings_rev + 1
    where id = new.session_id and status = 'lobby';
  update public.session_players set ready_at = null, ready_rev = null
    where session_id = new.session_id
      and exists (select 1 from public.game_sessions g where g.id = new.session_id and g.status = 'lobby');
  return new;
end $$;
drop trigger if exists session_prefs_rev on public.session_prefs;
create trigger session_prefs_rev after insert or update on public.session_prefs
  for each row execute function private.prefs_revision();

-- Démarrage effectif, partagé par le lancement de l'hôte. Reprend la logique de public.set_ready en ligne.
create or replace function private.start_lobby_session(p_session uuid) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  s public.game_sessions;
  cfg jsonb;
  wanted int;
begin
  select * into s from public.game_sessions where id = p_session for update;
  cfg := private.version_config(s);
  wanted := coalesce((s.settings ->> (cfg ->> 'rounds_setting'))::int, (cfg ->> 'rounds')::int, 1);
  -- Banque filtrée trop petite : on réduit le nombre de cartes (jamais d'élargissement silencieux des thèmes).
  if cfg #>> '{draw,deck}' = 'true' then
    wanted := least(wanted, private.deck_available(s));
    if wanted < 1 then
      update public.session_players set ready_at = null, ready_rev = null where session_id = p_session;
      perform private.bump_session(p_session, 'ready');
      return jsonb_build_object('ok', false, 'error', 'not_enough_cards');
    end if;
  end if;
  update public.game_sessions set status = 'playing', started_at = now(), current_round = 1, total_rounds = wanted
    where id = p_session returning * into s;
  insert into public.session_rounds (session_id, round_no, card) values (p_session, 1, private.draw_round_card(s, cfg));
  perform private.bump_session(p_session, 'started');
  return jsonb_build_object('ok', true, 'status', 'playing');
end $$;

-- Valider (ou retirer) son accord sur une révision précise. Ne lance jamais la partie.
create or replace function public.set_ready_rev(p_session uuid, p_ready boolean, p_rev integer) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  r record;
begin
  select * into r from private.lock_session(p_session);
  if (r.s).status <> 'lobby' then
    return jsonb_build_object('ok', true, 'status', (r.s).status);
  end if;
  if p_ready and p_rev is distinct from (r.s).settings_rev then
    return jsonb_build_object('ok', false, 'error', 'settings_changed', 'settings_rev', (r.s).settings_rev);
  end if;
  update public.session_players
    set ready_at = case when p_ready then coalesce(ready_at, now()) end,
        ready_rev = case when p_ready then (r.s).settings_rev end
    where session_id = p_session and seat = r.seat;
  perform private.bump_session(p_session, 'ready');
  return jsonb_build_object('ok', true, 'status', 'lobby', 'settings_rev', (r.s).settings_rev);
end $$;

-- Siège de l'hôte : le créateur de la séance, sinon le siège 1 (anciennes séances sans créateur connu).
create or replace function private.host_seat(s public.game_sessions) returns integer
language sql stable security definer set search_path = '' as $$
  select coalesce((select p.seat from public.session_players p where p.session_id = s.id and p.user_id = s.created_by), 1)
$$;

-- Lancer : réservé à l'hôte, deux joueurs présents dans la séance et d'accord sur la même révision.
-- Le verrou de ligne sérialise les doubles clics ; un second appel trouve la partie lancée et répond ok.
create or replace function public.launch_session(p_session uuid, p_rev integer) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  r record;
  agreed int;
begin
  select * into r from private.lock_session(p_session);
  if (r.s).status <> 'lobby' then
    return jsonb_build_object('ok', true, 'status', (r.s).status, 'already', true);
  end if;
  if r.seat <> private.host_seat(r.s) then
    return jsonb_build_object('ok', false, 'error', 'not_host');
  end if;
  if p_rev is distinct from (r.s).settings_rev then
    return jsonb_build_object('ok', false, 'error', 'settings_changed', 'settings_rev', (r.s).settings_rev);
  end if;
  select count(*) into agreed from public.session_players
    where session_id = p_session and user_id is not null and ready_at is not null and ready_rev = (r.s).settings_rev;
  if agreed <> 2 then
    return jsonb_build_object('ok', false, 'error', 'not_ready');
  end if;
  return private.start_lobby_session(p_session);
end $$;

-- Instantané : révision courante, siège de l'hôte et révision acceptée par chaque joueur.
-- La fonction existante est conservée telle quelle sous un autre nom et enrichie ici.
do $$
begin
  if not exists (select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
                 where n.nspname = 'private' and p.proname = 'get_session_state_base') then
    alter function public.get_session_state(uuid) set schema private;
    alter function private.get_session_state(uuid) rename to get_session_state_base;
  end if;
end $$;
revoke execute on function private.get_session_state_base(uuid) from public, anon, authenticated;

create or replace function public.get_session_state(p_session uuid) returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare
  base jsonb := private.get_session_state_base(p_session);
  s public.game_sessions;
begin
  if not coalesce((base ->> 'ok')::boolean, false) then return base; end if;
  select * into s from public.game_sessions where id = p_session;
  return jsonb_set(jsonb_set(base, '{session}', (base -> 'session') || jsonb_build_object(
      'settings_rev', s.settings_rev, 'host_seat', private.host_seat(s))),
    '{players}', coalesce((select jsonb_agg(pl || jsonb_build_object('ready_rev', sp.ready_rev) order by (pl ->> 'seat')::int)
                           from jsonb_array_elements(base -> 'players') pl
                           left join public.session_players sp on sp.session_id = p_session and sp.seat = (pl ->> 'seat')::int),
                          '[]'::jsonb));
end $$;

revoke execute on function public.set_ready_rev(uuid, boolean, integer), public.launch_session(uuid, integer),
  public.get_session_state(uuid) from public, anon;
grant execute on function public.set_ready_rev(uuid, boolean, integer), public.launch_session(uuid, integer),
  public.get_session_state(uuid) to authenticated;
revoke execute on function private.start_lobby_session(uuid), private.host_seat(public.game_sessions) from public, anon, authenticated;

-- 2. G01 : réponse orale -------------------------------------------------------------------------------------
-- Le moteur existant est conservé sous un autre nom ; le nouveau traite « mark_done » puis lui délègue tout le reste
-- (submit_text et submit_action restent acceptés pour les clients déjà ouverts et l'historique).
do $$
begin
  if not exists (select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
                 where n.nspname = 'private' and p.proname = 'board_apply7_before_oral') then
    alter function private.board_apply7(text, jsonb, jsonb, integer, text, jsonb, uuid) rename to board_apply7_before_oral;
  end if;
  if not exists (select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
                 where n.nspname = 'private' and p.proname = 'board_bot7_before_oral') then
    alter function private.board_bot7(text, jsonb, jsonb, integer) rename to board_bot7_before_oral;
  end if;
end $$;

create or replace function private.board_apply7(m text, c jsonb, sec jsonb, seat integer, typ text, p jsonb, p_session uuid)
returns jsonb language plpgsql security definer set search_path = '' as $$
begin
  if m = 'nd_truth_dare' and typ = 'mark_done' then
    if (c ->> 'active')::int <> seat then perform private.mv('not_your_turn'); end if;
    if c ->> 'phase' <> 'respond' or coalesce(c ->> 'kind', '') not in ('truth', 'dare') then perform private.mv('phase'); end if;
    -- Réponse dite dans l'appel : seul l'état est conservé, jamais de texte ni de preuve.
    return private.res(c || jsonb_build_object('done', true, 'phase', 'reveal', 'response',
      jsonb_build_object('status', case when c ->> 'kind' = 'truth' then 'answered' else 'done' end, 'oral', true)), sec);
  end if;
  return private.board_apply7_before_oral(m, c, sec, seat, typ, p, p_session);
end $$;

create or replace function private.board_bot7(m text, c jsonb, sec jsonb, seat integer)
returns jsonb language plpgsql security definer set search_path = '' as $$
begin
  if m = 'nd_truth_dare' and not coalesce((c ->> 'done')::boolean, false)
     and (c ->> 'active')::int = seat and c ->> 'phase' = 'respond' then
    return '{"type": "mark_done", "payload": {}}';
  end if;
  return private.board_bot7_before_oral(m, c, sec, seat);
end $$;
revoke execute on function private.board_apply7_before_oral(text, jsonb, jsonb, integer, text, jsonb, uuid),
  private.board_bot7_before_oral(text, jsonb, jsonb, integer) from public, anon, authenticated;

with v as (select * from public.game_versions where game_id = 'nd-action-verite'
           and version = (select current_version from public.games where id = 'nd-action-verite'))
insert into public.game_versions (game_id, version, rules, config, published_at)
select 'nd-action-verite', v.version + 1,
  v.rules || jsonb_build_object(
    'how_to', jsonb_build_array(
      'Le premier joueur est tiré au sort, puis vous alternez à chaque manche.',
      'À ton tour, choisis Vérité ou Action : la carte n''est tirée qu''après ton choix. Tu peux changer de carte, du même type.',
      'Tu réponds ou tu réalises l''action à voix haute, dans votre appel ou votre conversation : rien n''est écrit dans le jeu.',
      'Appuie sur « C''est répondu » (Vérité) ou « C''est fait » (Action). Passer clôt la manche sans pénalité. Aucun score.'),
    'privacy', 'Aucune réponse n''est écrite ni enregistrée : seul l''état « répondu » ou « fait » est conservé. Aucune preuve n''est jamais demandée.'),
  v.config || jsonb_build_object('answer', 'oral', 'version', 'noodeu-g01-1.3.0'),
  now()
from v where coalesce(v.config ->> 'answer', '') <> 'oral';
update public.games set current_version = (select max(version) from public.game_versions where game_id = 'nd-action-verite'),
  updated_at = now() where id = 'nd-action-verite';

-- 3. G08 : tour par tour, 3, 5 ou 7 tours -----------------------------------------------------------------------
-- Le moteur alterné (version 1) existe toujours dans board_apply7 : il suffit de publier une version sans « mode ».
-- Les séances en écriture simultanée déjà créées gardent leur version.
with v as (select * from public.game_versions where game_id = 'nd-deux-verites-mensonge'
           and version = (select current_version from public.games where id = 'nd-deux-verites-mensonge'))
insert into public.game_versions (game_id, version, rules, config, published_at)
select 'nd-deux-verites-mensonge', v.version + 1,
  jsonb_build_object(
    'objective', 'À tour de rôle, l''un écrit trois affirmations sur soi dont un mensonge ; l''autre devine lequel.',
    'how_to', jsonb_build_array(
      'Le premier joueur est tiré au sort, puis les rôles s''échangent à chaque tour.',
      'Celui qui écrit saisit trois affirmations (240 caractères au plus) et désigne en secret son mensonge, puis les verrouille.',
      'L''autre attend ou discute sans rien pouvoir lire ; il voit ensuite les trois affirmations et choisit celle qu''il croit fausse.',
      'Révélation : 1 point pour le devineur s''il trouve le mensonge, sinon 1 point pour celui qui a écrit. Passer ne compte pas.'),
    'details', jsonb_build_array(
      'Nombre de tours réglable dans le salon : 3, 5 ou 7.',
      'Adaptation Noodeu : écriture personnelle obligatoire ; aucune biographie tirée du générateur.',
      'Référence de mécanique : Deux vérités et un mensonge — PsyCat Games (https://psycatgames.com/fr/app/2-truths-1-lie/).'),
    'privacy', 'Les affirmations ne sont envoyées à l''autre qu''une fois verrouillées ; le mensonge reste secret jusqu''à la révélation.',
    'step_texts', '{}'::jsonb),
  (v.config - 'mode') || jsonb_build_object('turn', 'alternate', 'rounds', 5, 'version', 'noodeu-g08-3.0.0',
    'settings', jsonb_build_object('cartes', jsonb_build_object('label', 'Nombre de tours', 'default', 5, 'options', jsonb_build_array(3, 5, 7)))),
  now()
from v where coalesce(v.config ->> 'version', '') <> 'noodeu-g08-3.0.0';
update public.games set current_version = (select max(version) from public.game_versions where game_id = 'nd-deux-verites-mensonge'),
  updated_at = now() where id = 'nd-deux-verites-mensonge';
