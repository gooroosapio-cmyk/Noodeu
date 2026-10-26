-- Partenaire automatique de test (comptes de private.test_autoplayers uniquement) adapté au salon à révision
-- (migration 20261030001200). Non destructive : le moteur existant est conservé sous un autre nom et délégué.
-- 1. Salon : le robot valide la révision courante (set_ready_rev) et revalide après tout changement ; l'ancien
--    set_ready (qui lançait seul la partie) n'est plus appelé. S'il est l'hôte, il lance quand les deux ont validé.
-- 2. Réponses aléatoires : en plus des choix déjà tirés au hasard, les textes de test sont tirés dans une liste.

do $$
begin
  if not exists (select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
                 where n.nspname = 'private' and p.proname = 'bot_step_before_rev') then
    alter function private.bot_step(uuid, integer) rename to bot_step_before_rev;
  end if;
  if not exists (select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
                 where n.nspname = 'private' and p.proname = 'bot_payload_before_rev') then
    alter function private.bot_payload(jsonb, jsonb, uuid, integer, integer) rename to bot_payload_before_rev;
  end if;
end $$;

-- Phrases de test, visiblement fictives.
create or replace function private.bot_phrase() returns text
language sql volatile set search_path = '' as $$
  select (array[
    '[Test] Un week-end au bord de la mer, sans téléphone.',
    '[Test] Un dîner improvisé avec ce qu''il reste dans le frigo.',
    '[Test] Une longue promenade au lever du soleil.',
    '[Test] Apprendre à danser ensemble, même mal.',
    '[Test] Une soirée jeux de société et chocolat chaud.',
    '[Test] Revoir notre film préféré pour la dixième fois.',
    '[Test] Un pique-nique dans un parc inconnu.',
    '[Test] Écrire une liste de rêves à réaliser à deux.'
  ])[1 + floor(random() * 8)::int]
$$;

create or replace function private.bot_payload(st jsonb, card jsonb, p_session uuid, p_round integer, p_seat integer)
returns jsonb language plpgsql volatile security definer set search_path = '' as $$
declare
  p jsonb := private.bot_payload_before_rev(st, card, p_session, p_round, p_seat);
begin
  if st ->> 'kind' = 'text' and p ? 'text' then
    p := jsonb_set(p, '{text}', to_jsonb(left(private.bot_phrase(), coalesce((st #>> '{params,max}')::int, 200))));
  end if;
  return p;
end $$;

-- Jeux de conversation : textes de test variés (phrase à compléter, prédiction, trois affirmations distinctes).
create or replace function private.board_bot7(m text, c jsonb, sec jsonb, seat integer)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  mv jsonb;
  three text[];
begin
  if m = 'nd_truth_dare' and not coalesce((c ->> 'done')::boolean, false)
     and (c ->> 'active')::int = seat and c ->> 'phase' = 'respond' then
    return '{"type": "mark_done", "payload": {}}';
  end if;
  mv := private.board_bot7_before_oral(m, c, sec, seat);
  if mv ->> 'type' = 'lock' and mv -> 'payload' ? 'text' then
    mv := jsonb_set(mv, '{payload,text}', to_jsonb(private.bot_phrase()));
  elsif mv ->> 'type' = 'publish_three' then
    select array_agg(x) into three from (select distinct private.bot_phrase() x from generate_series(1, 40) limit 3) s;
    if cardinality(three) = 3 then
      mv := jsonb_set(mv, '{payload,statements}', jsonb_build_array(
        jsonb_build_object('id', 's1', 'text', three[1]), jsonb_build_object('id', 's2', 'text', three[2]),
        jsonb_build_object('id', 's3', 'text', three[3])));
    end if;
  end if;
  return mv;
end $$;

create or replace function private.bot_step(p_session uuid, p_seat integer)
returns boolean language plpgsql security definer set search_path = '' as $$
declare
  s public.game_sessions;
  res jsonb;
begin
  select * into s from public.game_sessions where id = p_session;
  if s.status is distinct from 'lobby' then
    return private.bot_step_before_rev(p_session, p_seat);
  end if;
  -- Mêmes préférences que l'autre joueur (thèmes, +18), comme avant ; un changement crée une révision.
  update public.session_prefs b set adult = h.adult, excluded_topics = h.excluded_topics, updated_at = now()
    from public.session_prefs h
    where b.session_id = p_session and b.seat = p_seat and h.session_id = p_session and h.seat = 3 - p_seat
      and (b.adult, b.excluded_topics) is distinct from (h.adult, h.excluded_topics);
  select * into s from public.game_sessions where id = p_session;
  -- Toujours prêt : valide la révision courante, jamais une ancienne.
  if exists (select 1 from public.session_players where session_id = p_session and seat = p_seat
             and (ready_at is null or ready_rev is distinct from s.settings_rev)) then
    res := public.set_ready_rev(p_session, true, s.settings_rev);
    return coalesce((res ->> 'ok')::boolean, false);
  end if;
  -- Hôte : lance dès que les deux joueurs ont validé la même révision (jamais à la place de l'hôte humain).
  if p_seat = private.host_seat(s) and (select count(*) from public.session_players where session_id = p_session
      and user_id is not null and ready_at is not null and ready_rev = s.settings_rev) = 2 then
    res := public.launch_session(p_session, s.settings_rev);
    return coalesce((res ->> 'ok')::boolean, false) and res ->> 'status' = 'playing' and not coalesce((res ->> 'already')::boolean, false);
  end if;
  return false;
end $$;

revoke execute on function private.bot_step(uuid, integer), private.bot_step_before_rev(uuid, integer),
  private.bot_payload(jsonb, jsonb, uuid, integer, integer), private.bot_payload_before_rev(jsonb, jsonb, uuid, integer, integer),
  private.bot_phrase(), private.board_bot7(text, jsonb, jsonb, integer) from public, anon, authenticated;
