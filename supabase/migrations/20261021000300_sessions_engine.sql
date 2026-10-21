-- Noodeu · Moteur de parties.
-- La base fait autorité sur toutes les transitions : participation, début, manche active,
-- réponses, révélation, fin et clôture. Le navigateur ne fait qu'appeler ces fonctions.
-- Les réponses d'un ou d'une partenaire ne sont lisibles qu'après la révélation de la manche.

create table public.game_sessions (
  id uuid primary key default gen_random_uuid(),
  couple_id uuid not null references public.couples (id) on delete cascade,
  game_id text not null references public.games (id),
  game_version int not null,
  created_by uuid references auth.users (id) on delete set null,
  -- lobby : salon d'attente ; playing / paused : en cours ; ended : résultats visibles, salon ouvert ;
  -- closed : terminée et rangée ; abandoned : quittée avant la fin.
  status text not null default 'lobby' check (status in ('lobby', 'playing', 'paused', 'ended', 'closed', 'abandoned')),
  settings jsonb not null default '{}',
  current_round int not null default 0,
  total_rounds int not null default 1 check (total_rounds between 1 and 50),
  paused_by uuid references auth.users (id) on delete set null,
  state_version bigint not null default 1,
  created_at timestamptz not null default now(),
  started_at timestamptz,
  ended_at timestamptz,
  closed_at timestamptz,
  updated_at timestamptz not null default now(),
  foreign key (game_id, game_version) references public.game_versions (game_id, version)
);
-- Une seule partie ouverte par couple : empêche les doublons (double clic, deux onglets, deux téléphones).
create unique index game_sessions_one_open_per_couple on public.game_sessions (couple_id)
  where status in ('lobby', 'playing', 'paused', 'ended');
create index game_sessions_couple_time on public.game_sessions (couple_id, created_at desc);

create table public.session_players (
  session_id uuid not null references public.game_sessions (id) on delete cascade,
  user_id uuid references auth.users (id) on delete set null,
  seat int not null check (seat in (1, 2)),
  ready_at timestamptz,
  keep_memory boolean not null default false,
  primary key (session_id, seat)
);
create unique index session_players_user on public.session_players (session_id, user_id);

create table public.session_rounds (
  session_id uuid not null references public.game_sessions (id) on delete cascade,
  round_no int not null check (round_no > 0),
  card jsonb not null,          -- copie figée des cartes : une modification éditoriale ne la change pas
  started_at timestamptz not null default now(),
  revealed_at timestamptz,
  primary key (session_id, round_no)
);

create table public.session_answers (
  id uuid primary key default gen_random_uuid(),
  session_id uuid not null,
  round_no int not null,
  step text not null,
  user_id uuid references auth.users (id) on delete set null,
  seat int not null check (seat in (1, 2)),
  payload jsonb,
  skipped boolean not null default false,
  created_at timestamptz not null default now(),
  foreign key (session_id, round_no) references public.session_rounds (session_id, round_no) on delete cascade,
  unique (session_id, round_no, step, seat)  -- une seule réponse par étape : pas de doublon possible
);

-- Salon privé (décision 4B+D) : messages liés à la partie, effacés à sa clôture.
create table public.session_messages (
  id uuid primary key default gen_random_uuid(),
  session_id uuid not null references public.game_sessions (id) on delete cascade,
  user_id uuid references auth.users (id) on delete set null,
  client_id uuid not null,
  kind text not null default 'text' check (kind in ('text')),
  body text not null check (char_length(body) between 1 and 1000),
  created_at timestamptz not null default now(),
  unique (session_id, client_id)
);
create index session_messages_session on public.session_messages (session_id, created_at);

create trigger game_sessions_touch before update on public.game_sessions
  for each row execute function private.touch_updated_at();

-- ---------------------------------------------------------------------------
-- Accès
-- ---------------------------------------------------------------------------
create function private.session_couple(p_session uuid) returns uuid
language sql stable security definer set search_path = '' as $$
  select couple_id from public.game_sessions where id = p_session
$$;

create function private.can_read_answer(p_session uuid, p_round int, p_user uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select p_user = auth.uid()
    or (private.is_member(private.session_couple(p_session), true)
        and exists (select 1 from public.session_rounds r
                    where r.session_id = p_session and r.round_no = p_round and r.revealed_at is not null))
$$;

grant execute on function private.session_couple(uuid), private.can_read_answer(uuid, int, uuid) to authenticated;

alter table public.game_sessions enable row level security;
alter table public.session_players enable row level security;
alter table public.session_rounds enable row level security;
alter table public.session_answers enable row level security;
alter table public.session_messages enable row level security;

create policy sessions_read on public.game_sessions for select to authenticated
  using (private.is_member(couple_id, true));
create policy players_read on public.session_players for select to authenticated
  using (private.is_member(private.session_couple(session_id), true));
create policy rounds_read on public.session_rounds for select to authenticated
  using (private.is_member(private.session_couple(session_id), true));
create policy answers_read on public.session_answers for select to authenticated
  using (private.can_read_answer(session_id, round_no, user_id));
create policy messages_read on public.session_messages for select to authenticated
  using (private.is_member(private.session_couple(session_id)));

revoke all on public.game_sessions, public.session_players, public.session_rounds,
  public.session_answers, public.session_messages from anon, authenticated;
grant select on public.game_sessions, public.session_players, public.session_rounds,
  public.session_answers, public.session_messages to authenticated;

-- ---------------------------------------------------------------------------
-- Signaux temps réel : ils annoncent un changement, sans aucun contenu secret.
-- Les clients relisent ensuite l'état autorisé via get_session_state().
-- ---------------------------------------------------------------------------
create function private.bump_session(p_session uuid, p_kind text) returns void
language plpgsql security definer set search_path = '' as $$
declare
  s public.game_sessions;
begin
  update public.game_sessions set state_version = state_version + 1 where id = p_session returning * into s;
  perform realtime.send(jsonb_build_object('session_id', s.id, 'v', s.state_version, 'kind', p_kind, 'status', s.status),
    'state', 'session:' || s.id::text, true);
  perform realtime.send(jsonb_build_object('session_id', s.id, 'status', s.status, 'game_id', s.game_id),
    'session', 'couple:' || s.couple_id::text, true);
end $$;

-- Charge la partie et vérifie que l'appelant y joue (membre actif). Verrouille la ligne :
-- les actions simultanées des deux partenaires sont traitées l'une après l'autre.
create function private.lock_session(p_session uuid, out s public.game_sessions, out seat int)
language plpgsql security definer set search_path = '' as $$
begin
  select * into s from public.game_sessions where id = p_session for update;
  if s.id is null or not private.is_member(s.couple_id) then
    raise exception 'session_not_found';
  end if;
  select p.seat into seat from public.session_players p where p.session_id = p_session and p.user_id = auth.uid();
  if seat is null then raise exception 'session_not_found'; end if;
end $$;

-- Tire les cartes d'une manche selon la mécanique. Copie figée dans session_rounds.card.
create function private.draw_round_card(s public.game_sessions, cfg jsonb) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  deck_size int;
  allow_intimate boolean;
  words jsonb;
begin
  select bool_and(p.intimate_opt_in) into allow_intimate
    from public.session_players sp join public.profiles p on p.id = sp.user_id where sp.session_id = s.id;

  if cfg ->> 'mechanic' = 'portrait_words' then
    deck_size := coalesce((s.settings ->> 'deck_size')::int, (cfg #>> '{settings,deck_size,default}')::int, 12);
    select jsonb_agg(jsonb_build_object('id', c.id, 'f', c.content ->> 'f', 'm', c.content ->> 'm') order by random())
      into words
      from (select * from public.game_cards
            where game_id = s.game_id and status = 'published' and kind = 'word'
              and (content_level = 'standard' or coalesce(allow_intimate, false))
            order by random() limit deck_size) c;
    if words is null or jsonb_array_length(words) < (cfg ->> 'pick')::int then
      raise exception 'not_enough_cards';
    end if;
    return jsonb_build_object('words', words);
  end if;
  raise exception 'unknown_mechanic';
end $$;

create function private.version_config(s public.game_sessions) returns jsonb
language sql stable security definer set search_path = '' as $$
  select config from public.game_versions where game_id = s.game_id and version = s.game_version
$$;

-- Valide la réponse d'une étape. Renvoie la charge utile normalisée.
create function private.validate_payload(cfg jsonb, step jsonb, card jsonb, payload jsonb) returns jsonb
language plpgsql immutable set search_path = '' as $$
declare
  picked text[];
  allowed text[];
  pick int;
begin
  if step ->> 'kind' = 'pick_words' then
    pick := (cfg ->> 'pick')::int;
    if jsonb_typeof(payload -> 'words') <> 'array' then raise exception 'invalid_answer'; end if;
    select array_agg(distinct v) into picked from jsonb_array_elements_text(payload -> 'words') v;
    select array_agg(w ->> 'id') into allowed from jsonb_array_elements(card -> 'words') w;
    if coalesce(array_length(picked, 1), 0) <> pick
       or jsonb_array_length(payload -> 'words') <> pick
       or not (picked <@ allowed) then
      raise exception 'invalid_answer';
    end if;
    return jsonb_build_object('words', to_jsonb(picked));
  end if;
  raise exception 'unknown_step';
end $$;

-- Efface le salon et, sauf accord des deux pour garder le souvenir, les réponses.
create function private.purge_session(p_session uuid, p_keep_answers boolean) returns void
language plpgsql security definer set search_path = '' as $$
begin
  delete from public.session_messages where session_id = p_session;
  if not p_keep_answers then
    delete from public.session_answers where session_id = p_session;
  end if;
end $$;

-- ---------------------------------------------------------------------------
-- Fonctions appelées par l'application
-- ---------------------------------------------------------------------------

-- Lancer (ou retrouver) une partie. Idempotent : un double clic renvoie la même partie.
create function public.create_session(p_game text) returns jsonb
language plpgsql security definer set search_path = '' as $$
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
  if g.id is null then return jsonb_build_object('ok', false, 'error', 'game_unavailable'); end if;
  if g.content_level = 'intime' and exists (
      select 1 from public.couple_members cm join public.profiles p on p.id = cm.user_id
      where cm.couple_id = c and cm.left_at is null and not p.intimate_opt_in) then
    return jsonb_build_object('ok', false, 'error', 'content_not_enabled');
  end if;

  perform pg_advisory_xact_lock(hashtext('couple-session:' || c::text));

  -- Les parties terminées dont les résultats sont encore affichés sont rangées automatiquement.
  for ended in select id from public.game_sessions where couple_id = c and status = 'ended' loop
    perform public.close_session(ended.id);
  end loop;

  select * into existing from public.game_sessions
    where couple_id = c and status in ('lobby', 'playing', 'paused');
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
  -- Siège 1 : la personne qui lance la partie.
  insert into public.session_players (session_id, user_id, seat)
    select new_id, cm.user_id, case when cm.user_id = me then 1 else 2 end
    from public.couple_members cm where cm.couple_id = c and cm.left_at is null;
  perform private.bump_session(new_id, 'created');
  return jsonb_build_object('ok', true, 'session_id', new_id, 'existing', false);
end $$;

create function public.update_session_settings(p_session uuid, p_settings jsonb) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  r record;
  cfg jsonb;
  k text;
  val jsonb;
  merged jsonb;
begin
  select * into r from private.lock_session(p_session);
  if (r.s).status <> 'lobby' then return jsonb_build_object('ok', false, 'error', 'not_in_lobby'); end if;
  cfg := private.version_config(r.s);
  merged := (r.s).settings;
  for k, val in select * from jsonb_each(coalesce(p_settings, '{}')) loop
    if not (cfg -> 'settings' -> k -> 'options') @> jsonb_build_array(val) then
      return jsonb_build_object('ok', false, 'error', 'invalid_settings');
    end if;
    merged := merged || jsonb_build_object(k, val);
  end loop;
  if merged = (r.s).settings then return jsonb_build_object('ok', true); end if;
  update public.game_sessions set settings = merged where id = p_session;
  -- Un réglage modifié demande une nouvelle confirmation des deux.
  update public.session_players set ready_at = null where session_id = p_session;
  perform private.bump_session(p_session, 'settings');
  return jsonb_build_object('ok', true);
end $$;

-- Confirmer sa disponibilité. Quand les deux sont prêts, la base démarre la partie.
create function public.set_ready(p_session uuid, p_ready boolean) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  r record;
  all_ready boolean;
begin
  select * into r from private.lock_session(p_session);
  if (r.s).status <> 'lobby' then
    return jsonb_build_object('ok', true, 'status', (r.s).status); -- déjà démarrée : action répétée sans effet
  end if;
  update public.session_players set ready_at = case when p_ready then coalesce(ready_at, now()) end
    where session_id = p_session and seat = r.seat;
  select count(*) = 2 and bool_and(ready_at is not null) into all_ready
    from public.session_players where session_id = p_session and user_id is not null;
  if all_ready then
    update public.game_sessions set status = 'playing', started_at = now(), current_round = 1 where id = p_session;
    insert into public.session_rounds (session_id, round_no, card)
      values (p_session, 1, private.draw_round_card(r.s, private.version_config(r.s)));
  end if;
  perform private.bump_session(p_session, case when all_ready then 'started' else 'ready' end);
  return jsonb_build_object('ok', true, 'status', case when all_ready then 'playing' else 'lobby' end);
end $$;

-- Enregistrer une réponse (ou passer). Idempotent ; révèle la manche quand les deux ont terminé.
create function public.submit_answer(p_session uuid, p_round int, p_step text, p_payload jsonb, p_skip boolean default false)
returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  r record;
  cfg jsonb;
  steps jsonb;
  cur_step jsonb;
  step_index int;
  rnd public.session_rounds;
  normalized jsonb;
  prev public.session_answers;
  done_count int;
  revealed boolean := false;
begin
  select * into r from private.lock_session(p_session);
  if (r.s).status = 'paused' then return jsonb_build_object('ok', false, 'error', 'paused'); end if;
  if (r.s).status <> 'playing' then return jsonb_build_object('ok', false, 'error', 'not_playing'); end if;
  if p_round <> (r.s).current_round then return jsonb_build_object('ok', false, 'error', 'stale_round'); end if;

  cfg := private.version_config(r.s);
  steps := cfg -> 'steps';
  select e.value, e.ordinality - 1 into cur_step, step_index
    from jsonb_array_elements(steps) with ordinality e where e.value ->> 'key' = p_step;
  if cur_step is null then return jsonb_build_object('ok', false, 'error', 'unknown_step'); end if;

  select * into rnd from public.session_rounds where session_id = p_session and round_no = p_round;
  if rnd.revealed_at is not null then return jsonb_build_object('ok', false, 'error', 'already_revealed'); end if;

  -- Les étapes se font dans l'ordre (ex. : ton portrait avant celui de ton ou ta partenaire).
  if step_index > 0 and not exists (
      select 1 from public.session_answers a where a.session_id = p_session and a.round_no = p_round
        and a.seat = r.seat and a.step = steps -> (step_index - 1) ->> 'key') then
    return jsonb_build_object('ok', false, 'error', 'previous_step_missing');
  end if;

  if p_skip then
    normalized := null;
  else
    normalized := private.validate_payload(cfg, cur_step, rnd.card, p_payload);
  end if;

  select * into prev from public.session_answers a
    where a.session_id = p_session and a.round_no = p_round and a.step = p_step and a.seat = r.seat;
  if prev.id is not null then
    if prev.skipped = p_skip and prev.payload is not distinct from normalized then
      return jsonb_build_object('ok', true, 'repeated', true);
    end if;
    return jsonb_build_object('ok', false, 'error', 'already_submitted');
  end if;

  insert into public.session_answers (session_id, round_no, step, user_id, seat, payload, skipped)
    values (p_session, p_round, p_step, auth.uid(), r.seat, normalized, p_skip);

  select count(*) into done_count from public.session_answers where session_id = p_session and round_no = p_round;
  if done_count >= 2 * jsonb_array_length(steps) then
    revealed := true;
    update public.session_rounds set revealed_at = now() where session_id = p_session and round_no = p_round;
    if p_round >= (r.s).total_rounds then
      update public.game_sessions set status = 'ended', ended_at = now() where id = p_session;
    end if;
  end if;
  perform private.bump_session(p_session, case when revealed then 'revealed' else 'answer' end);
  return jsonb_build_object('ok', true, 'revealed', revealed);
end $$;

-- Passer à la manche suivante après une révélation. p_round évite d'avancer deux fois.
create function public.next_round(p_session uuid, p_from_round int) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  r record;
begin
  select * into r from private.lock_session(p_session);
  if (r.s).status <> 'playing' or (r.s).current_round <> p_from_round then
    return jsonb_build_object('ok', true, 'repeated', true);
  end if;
  if not exists (select 1 from public.session_rounds where session_id = p_session and round_no = p_from_round and revealed_at is not null) then
    return jsonb_build_object('ok', false, 'error', 'not_revealed');
  end if;
  update public.game_sessions set current_round = p_from_round + 1 where id = p_session;
  insert into public.session_rounds (session_id, round_no, card)
    values (p_session, p_from_round + 1, private.draw_round_card(r.s, private.version_config(r.s)));
  perform private.bump_session(p_session, 'round');
  return jsonb_build_object('ok', true);
end $$;

create function public.set_paused(p_session uuid, p_paused boolean) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  r record;
begin
  select * into r from private.lock_session(p_session);
  if p_paused and (r.s).status = 'playing' then
    update public.game_sessions set status = 'paused', paused_by = auth.uid() where id = p_session;
  elsif not p_paused and (r.s).status = 'paused' then
    update public.game_sessions set status = 'playing', paused_by = null where id = p_session;
  else
    return jsonb_build_object('ok', true, 'repeated', true);
  end if;
  perform private.bump_session(p_session, 'pause');
  return jsonb_build_object('ok', true);
end $$;

-- Garder ce souvenir (décision 10B) : les réponses ne sont conservées que si les deux le demandent.
create function public.set_keep_memory(p_session uuid, p_keep boolean) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  r record;
begin
  select * into r from private.lock_session(p_session);
  if (r.s).status <> 'ended' then return jsonb_build_object('ok', false, 'error', 'not_ended'); end if;
  update public.session_players set keep_memory = p_keep where session_id = p_session and seat = r.seat;
  perform private.bump_session(p_session, 'memory');
  return jsonb_build_object('ok', true);
end $$;

-- Ranger une partie terminée : efface le salon, et les réponses sauf accord des deux.
create function public.close_session(p_session uuid) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  r record;
  keep boolean;
begin
  select * into r from private.lock_session(p_session);
  if (r.s).status <> 'ended' then return jsonb_build_object('ok', true, 'repeated', true); end if;
  select count(*) = 2 and bool_and(keep_memory) into keep from public.session_players where session_id = p_session;
  perform private.purge_session(p_session, keep);
  update public.game_sessions set status = 'closed', closed_at = now() where id = p_session;
  perform private.bump_session(p_session, 'closed');
  return jsonb_build_object('ok', true, 'kept', keep);
end $$;

-- Quitter une partie non terminée. Rien n'est conservé.
create function public.abandon_session(p_session uuid) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  r record;
begin
  select * into r from private.lock_session(p_session);
  if (r.s).status not in ('lobby', 'playing', 'paused') then
    return jsonb_build_object('ok', true, 'repeated', true);
  end if;
  perform private.purge_session(p_session, false);
  update public.game_sessions set status = 'abandoned', closed_at = now() where id = p_session;
  perform private.bump_session(p_session, 'abandoned');
  return jsonb_build_object('ok', true);
end $$;

-- Message du salon. client_id rend l'envoi idempotent (réessai après coupure).
create function public.send_session_message(p_session uuid, p_client_id uuid, p_body text) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  r record;
  m public.session_messages;
  body text := trim(coalesce(p_body, ''));
begin
  select * into r from private.lock_session(p_session);
  if (r.s).status not in ('lobby', 'playing', 'paused', 'ended') then
    return jsonb_build_object('ok', false, 'error', 'session_closed');
  end if;
  if char_length(body) = 0 or char_length(body) > 1000 then
    return jsonb_build_object('ok', false, 'error', 'invalid_message');
  end if;
  insert into public.session_messages (session_id, user_id, client_id, body)
    values (p_session, auth.uid(), p_client_id, body)
    on conflict (session_id, client_id) do nothing
    returning * into m;
  if m.id is null then
    select * into m from public.session_messages where session_id = p_session and client_id = p_client_id;
    return jsonb_build_object('ok', true, 'id', m.id, 'repeated', true);
  end if;
  perform realtime.send(jsonb_build_object('id', m.id, 'user_id', m.user_id, 'client_id', m.client_id,
      'body', m.body, 'created_at', m.created_at),
    'chat', 'session:' || p_session::text, true);
  return jsonb_build_object('ok', true, 'id', m.id);
end $$;

-- État complet autorisé pour l'appelant. Les réponses du ou de la partenaire n'y figurent
-- qu'une fois la manche révélée ; avant, seul « a répondu / a passé » est visible.
create function public.get_session_state(p_session uuid) returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare
  s public.game_sessions;
  me uuid := auth.uid();
  my_seat int;
begin
  select * into s from public.game_sessions where id = p_session;
  if s.id is null or not private.is_member(s.couple_id, true) then
    return jsonb_build_object('ok', false, 'error', 'session_not_found');
  end if;
  select seat into my_seat from public.session_players where session_id = p_session and user_id = me;

  return jsonb_build_object(
    'ok', true,
    'session', jsonb_build_object(
      'id', s.id, 'game_id', s.game_id, 'game_version', s.game_version, 'status', s.status,
      'settings', s.settings, 'current_round', s.current_round, 'total_rounds', s.total_rounds,
      'paused_by', s.paused_by, 'state_version', s.state_version, 'created_at', s.created_at,
      'started_at', s.started_at, 'ended_at', s.ended_at, 'closed_at', s.closed_at,
      'read_only', not private.is_member(s.couple_id)),
    'my_seat', my_seat,
    'game', (select jsonb_build_object('title', g.title, 'mechanic', g.mechanic, 'rules', v.rules, 'config', v.config)
             from public.games g join public.game_versions v on v.game_id = g.id and v.version = s.game_version
             where g.id = s.game_id),
    'players', (select coalesce(jsonb_agg(jsonb_build_object(
                  'seat', sp.seat, 'user_id', sp.user_id, 'is_me', sp.user_id = me,
                  'display_name', coalesce(nullif(pr.display_name, ''), cm.display_name_snapshot, ''),
                  'word_form', coalesce(pr.word_form, 'n'),
                  'ready', sp.ready_at is not null, 'keep_memory', sp.keep_memory) order by sp.seat), '[]')
                from public.session_players sp
                left join public.profiles pr on pr.id = sp.user_id
                left join public.couple_members cm on cm.couple_id = s.couple_id and cm.user_id = sp.user_id
                where sp.session_id = s.id),
    'rounds', (select coalesce(jsonb_agg(jsonb_build_object(
                 'round_no', rd.round_no, 'card', rd.card, 'revealed', rd.revealed_at is not null,
                 'answers', (select coalesce(jsonb_agg(jsonb_build_object(
                                'step', a.step, 'seat', a.seat, 'skipped', a.skipped,
                                'payload', case when a.seat = my_seat or rd.revealed_at is not null then a.payload end)
                              order by a.seat, a.created_at), '[]')
                             from public.session_answers a
                             where a.session_id = s.id and a.round_no = rd.round_no)
               ) order by rd.round_no), '[]')
               from public.session_rounds rd where rd.session_id = s.id)
  );
end $$;

-- Partie ouverte du couple (pour l'accueil).
create function public.get_open_session() returns jsonb
language sql stable security definer set search_path = '' as $$
  select coalesce((select jsonb_build_object('id', s.id, 'game_id', s.game_id, 'status', s.status,
                     'title', g.title, 'updated_at', s.updated_at)
                   from public.game_sessions s join public.games g on g.id = s.game_id
                   where s.couple_id = private.my_couple_id() and s.status in ('lobby', 'playing', 'paused', 'ended')
                   limit 1), 'null'::jsonb)
$$;

-- La séparation abandonne aussi la partie en cours (remplace la version de la migration 100).
create or replace function public.leave_couple() returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  c uuid := private.my_couple_id();
  other uuid;
  open_session uuid;
begin
  if c is null then return jsonb_build_object('ok', true); end if;
  for open_session in select id from public.game_sessions where couple_id = c and status in ('lobby', 'playing', 'paused', 'ended') loop
    perform private.purge_session(open_session, false);
    update public.game_sessions set status = 'abandoned', closed_at = now() where id = open_session;
    perform private.bump_session(open_session, 'abandoned');
  end loop;
  select user_id into other from public.couple_members where couple_id = c and user_id <> auth.uid() and left_at is null;
  update public.couples set status = 'separated', separated_at = now() where id = c;
  update public.couple_members set left_at = now() where couple_id = c and left_at is null;
  perform private.notify_user(other, 'couple', jsonb_build_object('status', 'separated'));
  return jsonb_build_object('ok', true);
end $$;

revoke execute on all functions in schema public from public, anon;
grant execute on function public.create_session(text), public.update_session_settings(uuid, jsonb),
  public.set_ready(uuid, boolean), public.submit_answer(uuid, int, text, jsonb, boolean),
  public.next_round(uuid, int), public.set_paused(uuid, boolean), public.set_keep_memory(uuid, boolean),
  public.close_session(uuid), public.abandon_session(uuid), public.send_session_message(uuid, uuid, text),
  public.get_session_state(uuid), public.get_open_session(), public.leave_couple() to authenticated;
revoke execute on function private.bump_session(uuid, text), private.lock_session(uuid),
  private.draw_round_card(public.game_sessions, jsonb), private.version_config(public.game_sessions),
  private.validate_payload(jsonb, jsonb, jsonb, jsonb), private.purge_session(uuid, boolean)
  from public, anon, authenticated;
