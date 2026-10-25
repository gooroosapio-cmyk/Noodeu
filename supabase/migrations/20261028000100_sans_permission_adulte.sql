-- Questions +18 : plus aucune permission. Elles font partie du jeu et de la conversation, pour tous les profils.
-- Plus d'accord +18 dans le salon ni dans les Réglages, plus de plafond d'intensité : toutes les cartes peuvent être
-- tirées. Le salon des activités concernées affiche seulement un message d'information (côté application).
-- Les colonnes intimate_opt_in, max_intensity et session_prefs.adult restent en place, sans effet.

create or replace function private.adult_allowed(p_session uuid)
 returns boolean language sql stable security definer set search_path to ''
as $function$ select true $function$;

create or replace function private.session_cap(p_session uuid)
 returns integer language sql stable security definer set search_path to ''
as $function$ select 3 $function$;

create or replace function private.couple_cap(p_couple uuid)
 returns integer language sql stable security definer set search_path to ''
as $function$ select 3 $function$;

-- Le +18 est actif pour tous : anciens profils compris, et par défaut pour les nouveaux.
alter table public.profiles alter column intimate_opt_in set default true;
alter table public.profiles alter column daily_adult set default true;
-- La majorité est déclarée à l'inscription : plus de seconde déclaration exigée pour le +18.
create or replace function private.profile_guard()
 returns trigger language plpgsql set search_path to ''
as $function$
begin
  if not new.intimate_opt_in then new.daily_adult := false; end if;
  if new.timezone is not null and not exists (select 1 from pg_catalog.pg_timezone_names where name = new.timezone) then
    new.timezone := old.timezone;
  end if;
  new.reminders := jsonb_build_object(
    'enabled', coalesce((new.reminders ->> 'enabled')::boolean, false),
    'per_week', least(3, greatest(1, coalesce((new.reminders ->> 'per_week')::int, 2))),
    'quiet_start', least(23, greatest(0, coalesce((new.reminders ->> 'quiet_start')::int, 21))),
    'quiet_end', least(23, greatest(0, coalesce((new.reminders ->> 'quiet_end')::int, 9))));
  return new;
end $function$;
update public.profiles set intimate_opt_in = true, daily_adult = true, max_intensity = 'hot';
alter table public.profiles alter column max_intensity set default 'hot';

CREATE OR REPLACE FUNCTION public.set_ready(p_session uuid, p_ready boolean)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  r record;
  all_ready boolean;
  cfg jsonb;
  wanted int;
  sess public.game_sessions;
begin
  select * into r from private.lock_session(p_session);
  if (r.s).status <> 'lobby' then
    return jsonb_build_object('ok', true, 'status', (r.s).status);
  end if;
  update public.session_players set ready_at = case when p_ready then coalesce(ready_at, now()) end
    where session_id = p_session and seat = r.seat;
  select count(*) = 2 and bool_and(ready_at is not null) into all_ready
    from public.session_players where session_id = p_session and user_id is not null;
  if all_ready then
    cfg := private.version_config(r.s);
    wanted := coalesce(((r.s).settings ->> (cfg ->> 'rounds_setting'))::int, (cfg ->> 'rounds')::int, 1);
    -- Banque filtrée trop petite : on réduit le nombre de cartes (jamais d'élargissement silencieux des thèmes).
    if cfg #>> '{draw,deck}' = 'true' then
      wanted := least(wanted, private.deck_available(r.s));
      if wanted < 1 then
        update public.session_players set ready_at = null where session_id = p_session;
        perform private.bump_session(p_session, 'ready');
        return jsonb_build_object('ok', false, 'error', 'not_enough_cards');
      end if;
    end if;
    update public.game_sessions set status = 'playing', started_at = now(), current_round = 1, total_rounds = wanted
      where id = p_session returning * into sess;
    insert into public.session_rounds (session_id, round_no, card) values (p_session, 1, private.draw_round_card(sess, cfg));
  end if;
  perform private.bump_session(p_session, case when all_ready then 'started' else 'ready' end);
  return jsonb_build_object('ok', true, 'status', case when all_ready then 'playing' else 'lobby' end);
end $function$;

CREATE OR REPLACE FUNCTION public.create_session(p_game text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  me uuid := auth.uid();
  c uuid := private.my_couple_id();
  g public.games;
  v public.game_versions;
  existing public.game_sessions;
  new_id uuid;
  ended record;
begin
  if c is null then return jsonb_build_object('ok', false, 'error', 'no_couple'); end if;
  select * into g from public.games where id = p_game and status = 'published';
  if g.id is null or g.implementation <> 'playable' then return jsonb_build_object('ok', false, 'error', 'game_unavailable'); end if;
  perform pg_advisory_xact_lock(hashtext('couple-session:' || c::text));
  for ended in select id from public.game_sessions where couple_id = c and status = 'ended' loop
    perform public.close_session(ended.id);
  end loop;

  select * into existing from public.game_sessions where couple_id = c and status in ('lobby', 'playing', 'paused');
  if existing.id is not null then
    if existing.game_id = p_game then
      return jsonb_build_object('ok', true, 'session_id', existing.id, 'existing', true);
    end if;
    return jsonb_build_object('ok', false, 'error', 'session_in_progress', 'session_id', existing.id, 'game_id', existing.game_id);
  end if;

  select * into v from public.game_versions where game_id = g.id and version = g.current_version and published_at is not null;
  if v.game_id is null then return jsonb_build_object('ok', false, 'error', 'game_unavailable'); end if;

  insert into public.game_sessions (couple_id, game_id, game_version, created_by, total_rounds, settings)
    values (c, g.id, v.version, me, coalesce((v.config ->> 'rounds')::int, 1),
            coalesce((select jsonb_object_agg(k, val -> 'default') from jsonb_each(v.config -> 'settings') as e(k, val)), '{}'))
    returning id into new_id;
  insert into public.session_players (session_id, user_id, seat)
    select new_id, cm.user_id, case when cm.user_id = me then 1 else 2 end
    from public.couple_members cm where cm.couple_id = c and cm.left_at is null;
  insert into public.session_prefs (session_id, seat, user_id)
    select session_id, seat, user_id from public.session_players where session_id = new_id;
  perform private.bump_session(new_id, 'created');
  return jsonb_build_object('ok', true, 'session_id', new_id, 'existing', false);
end $function$;

CREATE OR REPLACE FUNCTION public.get_my_filters()
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  me public.profiles;
  c uuid := private.my_couple_id();
begin
  select * into me from public.profiles where id = auth.uid();
  if me.id is null then return jsonb_build_object('ok', false, 'error', 'not_authenticated'); end if;
  return jsonb_build_object('ok', true,
    'my_max', me.max_intensity,
    'duo_cap', 3,
    'duo_adult', c is not null,
    'in_duo', c is not null);
end $function$;

CREATE OR REPLACE FUNCTION public.get_progress()
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  c uuid := private.my_couple_id();
begin
  if c is null then return jsonb_build_object('ok', true, 'games', '{}'::jsonb); end if;
  return jsonb_build_object('ok', true, 'games', coalesce((
    select jsonb_object_agg(g.id, x.p) from public.games g
    cross join lateral (
      select case
        when g.mechanic = 'pack_conversation' and not coalesce((g.meta ->> 'random')::boolean, false) then (
          select jsonb_build_object('kind', 'pack',
            'count', (v.config #>> '{pack,count}')::int,
            'cards_done', coalesce(pp.cards_done, 0),
            'completed', coalesce(pp.cards_done, 0) >= (select count(*) from public.content_banks cb
                           where cb.bank = v.config ->> 'bank'),
            'viewed', (select count(distinct rd.card #>> '{item,id}') from public.session_rounds rd join public.game_sessions gs on gs.id = rd.session_id
                       where gs.couple_id = c and gs.game_id = g.id),
            'answered', (select count(distinct rd.card #>> '{item,id}') from public.session_rounds rd join public.game_sessions gs on gs.id = rd.session_id
                         where gs.couple_id = c and gs.game_id = g.id and coalesce((rd.card ->> 'done')::boolean, false)
                           and rd.card #>> '{answers,1,choice}' in ('share', 'private') and rd.card #>> '{answers,2,choice}' in ('share', 'private')),
            'passed', (select count(distinct rd.card #>> '{item,id}') from public.session_rounds rd join public.game_sessions gs on gs.id = rd.session_id
                       where gs.couple_id = c and gs.game_id = g.id and coalesce((rd.card ->> 'done')::boolean, false)
                         and 'pass' in (rd.card #>> '{answers,1,choice}', rd.card #>> '{answers,2,choice}')))
          from public.game_versions v left join private.pack_progress pp on pp.couple_id = c and pp.game_id = g.id
          where v.game_id = g.id and v.version = g.current_version)
        when g.mechanic = 'test_form' then (
          select case when count(*) = 0 then null else jsonb_build_object('kind', 'test',
            'me', case when bool_or(rd.card -> 'completed' ? sp.seat::text) then 'completed'
                       when bool_or(rd.card -> 'declined' ? sp.seat::text) then 'declined' else 'started' end,
            -- Côté partenaire, seulement « terminé » ou non : un refus ou un abandon reste privé.
            'partner', case when bool_or(rd.card -> 'completed' ? (3 - sp.seat)::text) then 'completed' else 'pending' end) end
          from public.game_sessions gs join public.session_rounds rd on rd.session_id = gs.id
          join public.session_players sp on sp.session_id = gs.id and sp.user_id = auth.uid()
          where gs.couple_id = c and gs.game_id = g.id)
        else (
          select case when count(*) = 0 then null else jsonb_build_object('kind', 'game', 'played', count(*) filter (where gs.status in ('ended', 'closed')),
            'started', count(*)) end
          from public.game_sessions gs where gs.couple_id = c and gs.game_id = g.id and gs.status <> 'abandoned')
      end p) x
    where g.status = 'published' and x.p is not null
      and (g.mechanic <> 'pack_conversation' or (x.p ->> 'viewed')::int > 0 or (x.p ->> 'cards_done')::int > 0)), '{}'::jsonb));
end $function$;

CREATE OR REPLACE FUNCTION public.get_my_items()
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  adult_ok boolean := true;
begin
  if auth.uid() is null then return jsonb_build_object('ok', false, 'error', 'not_authenticated'); end if;
  return jsonb_build_object('ok', true,
    'later', (select coalesce(jsonb_agg(jsonb_build_object('bank', l.bank, 'item_id', l.item_id, 'game_id', l.game_id,
                'created_at', l.created_at, 'view', private.item_view(l.bank, l.item_id, adult_ok)) order by l.created_at desc), '[]')
              from public.later_items l where l.user_id = auth.uid()),
    'favorites', (select coalesce(jsonb_agg(jsonb_build_object('kind', f.kind, 'bank', f.bank, 'item_id', f.item_id,
                'created_at', f.created_at, 'view', private.item_view(f.bank, f.item_id, adult_ok)) order by f.created_at desc), '[]')
              from public.item_favorites f where f.user_id = auth.uid()));
end $function$;

-- Règles affichées : plus de phrase sur l'activation du +18 (le salon affiche à la place une simple information).
-- Les versions publiées sont immuables : nouvelle version pour chaque activité concernée.
create function pg_temp.sans18(a jsonb) returns jsonb language sql immutable as $f$
  select coalesce(jsonb_agg(case when x #>> '{}' = 'Les questions sont tirées au hasard parmi les questions libres de la rubrique, selon vos réglages d''intensité et de +18.'
                                 then to_jsonb('Les questions sont tirées au hasard parmi les questions libres de la rubrique.'::text) else x end order by o), '[]')
  from jsonb_array_elements(a) with ordinality as e(x, o)
  where x #>> '{}' not in ('Cartes +18 désactivées par défaut : elles n''apparaissent que si vous les activez tous les deux. Retirer ton accord est immédiat.',
                           'Consignes +18 désactivées par défaut : elles n''apparaissent que si vous les activez tous les deux. Retirer ton accord est immédiat.',
                           'Les cartes +18 ne sont proposées que si vous les avez activées tous les deux, dans Réglages et dans le salon.') $f$;
with cur as (
  select v.* from public.game_versions v join public.games g on g.id = v.game_id and g.current_version = v.version
  where v.rules::text ~ 'activez tous les deux|activées tous les deux, dans Réglages|réglages d''intensité et de \+18'),
ins as (
  insert into public.game_versions (game_id, version, rules, config, published_at)
  select c.game_id, (select max(version) from public.game_versions where game_id = c.game_id) + 1,
         c.rules || jsonb_build_object('details', pg_temp.sans18(coalesce(c.rules -> 'details', '[]')),
                                       'how_to', pg_temp.sans18(coalesce(c.rules -> 'how_to', '[]'))),
         c.config, now()
  from cur c returning game_id, version)
update public.games g set current_version = ins.version, updated_at = now() from ins where g.id = ins.game_id;
