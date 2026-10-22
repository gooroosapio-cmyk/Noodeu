-- Partenaire automatique pour la phase de test (temporaire, à retirer à l'audit final).
-- Un compte inscrit dans private.test_autoplayers est toujours prêt dans le salon et répond seul
-- à ses étapes, avec des réponses de test, dès que l'autre joueur agit. Il passe par les mêmes
-- fonctions que l'application (set_ready, submit_answer) : mêmes validations, même révélation.
-- Aucun compte n'est inscrit par cette migration : l'inscription se fait à la main sur la base.
-- Retrait : vider private.test_autoplayers (le mécanisme ne fait alors plus rien), puis supprimer le compte.

create table if not exists private.test_autoplayers (
  user_id uuid primary key references auth.users (id) on delete cascade,
  note text,
  created_at timestamptz not null default now()
);

-- k index distincts tirés au hasard dans [0, n).
create or replace function private.bot_sample(n int, k int) returns int[]
language sql volatile set search_path = '' as $$
  select coalesce(array_agg(x), '{}') from (select x from generate_series(0, n - 1) x order by random() limit greatest(k, 0)) s
$$;

create or replace function private.bot_rand(n int) returns int
language sql volatile set search_path = '' as $$ select floor(random() * greatest(n, 1))::int $$;

-- Réponse de test valide pour une étape (null si le robot ne sait pas répondre).
create or replace function private.bot_payload(st jsonb, card jsonb, p_session uuid, p_round int, p_seat int) returns jsonb
language plpgsql volatile security definer set search_path = '' as $$
declare
  k text := st ->> 'kind';
  prm jsonb := coalesce(st -> 'params', '{}');
  n int;
  cnt int;
  arr jsonb := '[]';
  items int[] := '{}';
  x int;
  total int := 0;
  cost int;
  ref jsonb;
  pool int[];
begin
  case k
  when 'text' then
    return jsonb_build_object('text', left('Réponse de test de Kalou.', coalesce((prm ->> 'max')::int, 200)));
  when 'choice' then
    return jsonb_build_object('choice', private.bot_rand(jsonb_array_length(card -> 'choices')));
  when 'yes_no' then
    return jsonb_build_object('answer', case when random() < 0.5 then 'yes' else 'no' end);
  when 'pick' then
    n := jsonb_array_length(card -> (prm ->> 'list'));
    cnt := least(greatest(coalesce((prm ->> 'min')::int, 1), 1), (prm ->> 'max')::int, n);
    return jsonb_build_object('items', to_jsonb(private.bot_sample(n, cnt)));
  when 'objects' then
    foreach x in array private.bot_sample(jsonb_array_length(card -> 'objects'), (prm ->> 'count')::int) loop
      arr := arr || jsonb_build_array(jsonb_build_object('i', x));
    end loop;
    return jsonb_build_object('items', arr, 'bg', private.bot_rand((prm ->> 'backgrounds')::int));
  when 'sky' then
    return jsonb_build_object('symbols', to_jsonb(private.bot_sample(jsonb_array_length(card -> 'symbols'), 1)),
      'energy', private.bot_rand(jsonb_array_length(card -> 'energies')));
  when 'frise' then
    for x in 0 .. jsonb_array_length(card -> 'prompts') - 1 loop
      arr := arr || jsonb_build_array(jsonb_build_object('p', x, 'title', 'Souvenir de test ' || (x + 1)));
    end loop;
    return jsonb_build_object('order', 'chrono', 'entries', arr);
  when 'gesture' then
    return jsonb_build_object('action', private.bot_rand(jsonb_array_length(card -> 'actions')), 'text', 'Petit geste de test.');
  when 'buy', 'common' then
    if k = 'common' then
      select array_agg(distinct (v::text)::int) into pool
        from public.session_answers a, jsonb_array_elements(a.payload -> 'items') v
        where a.session_id = p_session and a.round_no = p_round and a.step = (prm ->> 'from');
      select coalesce(array_agg(v order by random()), '{}') into pool from unnest(pool) v;
    else
      pool := private.bot_sample(jsonb_array_length(card -> 'activities'), jsonb_array_length(card -> 'activities'));
    end if;
    foreach x in array coalesce(pool, '{}') loop
      cost := (card -> 'activities' -> x -> 'v' ->> 'cost')::int;
      if total + cost <= (prm ->> 'budget')::int and cardinality(items) < coalesce((prm ->> 'max_items')::int, 12) then
        items := items || x; total := total + cost;
      end if;
    end loop;
    if cardinality(items) = 0 then return null; end if;
    return jsonb_build_object('items', to_jsonb(items));
  when 'place' then
    cnt := (prm ->> 'count')::int;
    pool := private.bot_sample(jsonb_array_length(card -> 'objects'), cnt);
    for x in 1 .. cardinality(pool) loop
      arr := arr || jsonb_build_array(jsonb_build_object('i', pool[x], 'x', (p_seat - 1) * 3 + (x - 1) % 3, 'y', (x - 1) % 4));
    end loop;
    return jsonb_build_object('objects', arr);
  when 'light' then
    return jsonb_build_object('light', private.bot_rand(jsonb_array_length(card -> 'lights')),
      'ambiance', private.bot_rand(jsonb_array_length(card -> 'ambiances')));
  when 'agree' then
    return jsonb_build_object('pick', 1 + private.bot_rand(2));
  when 'gift' then
    return jsonb_build_object('paper', private.bot_rand(jsonb_array_length(card -> 'papers')),
      'ribbon', private.bot_rand(jsonb_array_length(card -> 'ribbons')),
      'object', private.bot_rand(jsonb_array_length(card -> 'objects')), 'word', 'Un petit mot de test.');
  when 'page' then
    return jsonb_build_object('text', 'Page de test de Kalou.');
  when 'cover_pick' then
    return jsonb_build_object('text', 'Couverture de test');
  when 'line' then
    return jsonb_build_object('text', 'Une ligne de test.');
  when 'fields' then
    for x in 1 .. (prm ->> 'count')::int loop
      arr := arr || jsonb_build_array(jsonb_build_object('text', left('Champ de test ' || x, coalesce((prm ->> 'max')::int, 80)), 'shared', true));
    end loop;
    return jsonb_build_object('fields', arr);
  when 'share' then
    return jsonb_build_object('topic', private.bot_rand(jsonb_array_length(card -> coalesce(prm ->> 'list', 'topics'))),
      'text', 'Une histoire de test racontée par Kalou.');
  when 'confirm' then
    return jsonb_build_object('ok', true);
  when 'reaction' then
    if prm ? 'options' then return jsonb_build_object('option', private.bot_rand(jsonb_array_length(prm -> 'options'))); end if;
    return jsonb_build_object('text', 'Réaction de test.');
  when 'surprise' then
    ref := private.round_answer(p_session, p_round, prm ->> 'from', 3 - p_seat);
    if jsonb_array_length(coalesce(ref -> 'items', '[]')) > 0 then return jsonb_build_object('i', ref -> 'items' -> 0); end if;
    if jsonb_array_length(coalesce(ref -> 'custom', '[]')) > 0 then return jsonb_build_object('c', 0); end if;
    return null;
  when 'zones' then
    n := jsonb_array_length(card -> 'labels');
    foreach x in array private.bot_sample(n, least((prm ->> 'max')::int, 3)) loop
      arr := arr || jsonb_build_array(jsonb_build_object('i', x, 'z', private.bot_rand(3)));
    end loop;
    return jsonb_build_object('places', arr);
  when 'ask' then
    ref := private.round_answer(p_session, p_round, prm ->> 'from', 3 - p_seat);
    if jsonb_array_length(coalesce(ref -> 'places', '[]')) = 0 then return null; end if;
    return jsonb_build_object('label', ref -> 'places' -> 0 -> 'i', 'text', 'Question de test ?');
  else
    return null;
  end case;
end $$;

-- Une action du robot (déjà connecté sous son identité). Renvoie false quand il n'a plus rien à faire.
create or replace function private.bot_step(p_session uuid, p_seat int) returns boolean
language plpgsql security definer set search_path = '' as $$
declare
  s public.game_sessions;
  cfg jsonb;
  rnd public.session_rounds;
  st jsonb;
  p jsonb;
  res jsonb;
  list_key text;
begin
  select * into s from public.game_sessions where id = p_session;
  if s.status = 'lobby' then
    -- Mêmes préférences de partie que l'autre joueur (+18 et thèmes à éviter) : le robot ne bloque rien.
    update public.session_prefs b set adult = h.adult, excluded_topics = h.excluded_topics, updated_at = now()
      from public.session_prefs h
      where b.session_id = p_session and b.seat = p_seat and h.session_id = p_session and h.seat = 3 - p_seat
        and (b.adult, b.excluded_topics) is distinct from (h.adult, h.excluded_topics);
    if exists (select 1 from public.session_players where session_id = p_session and seat = p_seat and ready_at is null) then
      res := public.set_ready(p_session, true);
      return coalesce((res ->> 'ok')::boolean, false);
    end if;
    return false;
  end if;
  if s.status not in ('playing', 'ended') then return false; end if;
  cfg := private.version_config(s);
  if cfg ->> 'engine' is distinct from 'rounds' then return false; end if;
  select * into rnd from public.session_rounds where session_id = p_session and round_no = s.current_round;
  if rnd.session_id is null then return false; end if;

  if rnd.revealed_at is null then
    if s.status <> 'playing' then return false; end if;
    list_key := 'steps';
  elsif rnd.revealed_at <= now() then
    list_key := 'after';
  else
    return false; -- capsule encore fermée
  end if;

  for st in select e.value from jsonb_array_elements(coalesce(cfg -> list_key, '[]')) e loop
    if not (p_seat = any(private.step_seats(st, rnd.card))) then continue; end if;
    if exists (select 1 from public.session_answers a where a.session_id = p_session and a.round_no = rnd.round_no
               and a.step = st ->> 'key' and a.seat = p_seat) then
      continue;
    end if;
    if st ? 'after' and not exists (select 1 from public.session_answers a where a.session_id = p_session
                                    and a.round_no = rnd.round_no and a.step = st ->> 'after') then
      return false; -- il attend l'autre
    end if;
    p := private.bot_payload(st, rnd.card, p_session, rnd.round_no, p_seat);
    res := case when p is null then null else public.submit_answer(p_session, rnd.round_no, st ->> 'key', p, false) end;
    if coalesce((res ->> 'ok')::boolean, false) then return true; end if;
    if coalesce((st ->> 'skippable')::boolean, false) then
      res := public.submit_answer(p_session, rnd.round_no, st ->> 'key', null, true);
      return coalesce((res ->> 'ok')::boolean, false);
    end if;
    return false;
  end loop;
  return false;
end $$;

-- Fait jouer les robots de la partie après chaque action d'un joueur humain.
create or replace function private.autoplay(p_session uuid) returns void
language plpgsql security definer set search_path = '' as $$
declare
  me uuid := auth.uid();
  bot record;
  old_claims text;
  old_sub text;
  guard int;
begin
  if me is null or exists (select 1 from private.test_autoplayers where user_id = me) then return; end if;
  for bot in select sp.user_id, sp.seat from public.session_players sp
             join private.test_autoplayers t on t.user_id = sp.user_id where sp.session_id = p_session loop
    old_claims := current_setting('request.jwt.claims', true);
    old_sub := current_setting('request.jwt.claim.sub', true);
    begin
      perform set_config('request.jwt.claims', jsonb_build_object('sub', bot.user_id, 'role', 'authenticated')::text, true);
      perform set_config('request.jwt.claim.sub', bot.user_id::text, true);
      guard := 0;
      while guard < 40 and private.bot_step(p_session, bot.seat) loop
        guard := guard + 1;
      end loop;
    exception when others then
      null; -- le robot ne doit jamais bloquer l'action du joueur humain
    end;
    perform set_config('request.jwt.claims', coalesce(old_claims, ''), true);
    perform set_config('request.jwt.claim.sub', coalesce(old_sub, ''), true);
  end loop;
end $$;

-- Point d'accroche : chaque action d'une partie passe par bump_session.
create or replace function private.bump_session(p_session uuid, p_kind text) returns void
language plpgsql security definer set search_path = '' as $$
declare
  s public.game_sessions;
begin
  update public.game_sessions set state_version = state_version + 1 where id = p_session returning * into s;
  perform realtime.send(jsonb_build_object('session_id', s.id, 'v', s.state_version, 'kind', p_kind, 'status', s.status),
    'state', 'session:' || s.id::text, true);
  perform realtime.send(jsonb_build_object('session_id', s.id, 'status', s.status, 'game_id', s.game_id),
    'session', 'couple:' || s.couple_id::text, true);
  if exists (select 1 from private.test_autoplayers) then
    perform private.autoplay(p_session);
  end if;
end $$;

-- Pas de « revoke » ici (l'outil de migration en ligne les bloque) : le schéma private n'est pas exposé
-- par l'API, et la table n'accorde aucun droit aux rôles anon/authenticated.
