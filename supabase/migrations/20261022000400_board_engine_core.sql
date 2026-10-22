-- Moteur « plateau » (famille 2, Mots et répartie) : un état public partagé, des secrets par joueur gardés
-- côté serveur, des coups validés un par un. Le navigateur n'est jamais cru sur parole.
--
-- session_rounds.card  : état public de la manche (ce que les deux voient).
-- private.round_secrets : solution et secrets par siège (jamais lus en direct ; seule la part de l'appelant
--                         sort de get_session_state, et la solution une fois la manche finie).
-- private.board_moves   : journal des coups (identifiant d'action unique : un coup renvoyé n'a qu'un effet).

create table if not exists private.round_secrets (
  session_id uuid not null references public.game_sessions (id) on delete cascade,
  round_no int not null,
  secret jsonb not null default '{}',
  primary key (session_id, round_no)
);

create table if not exists private.board_moves (
  action_id uuid primary key,
  session_id uuid not null references public.game_sessions (id) on delete cascade,
  round_no int not null,
  seat int not null,
  type text not null,
  payload jsonb,
  created_at timestamptz not null default now()
);
create index if not exists board_moves_session on private.board_moves (session_id, round_no);

-- Le tirage d'une manche « plateau » renvoie la carte publique et, sous la clé _secret, la part privée :
-- elle est rangée ici avant l'écriture de la carte, qui ne la contient jamais.
create or replace function private.split_round_secret() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  if new.card ? '_secret' then
    insert into private.round_secrets (session_id, round_no, secret)
      values (new.session_id, new.round_no, new.card -> '_secret')
      on conflict (session_id, round_no) do update set secret = excluded.secret;
    new.card := new.card - '_secret';
  end if;
  return new;
end $$;

create or replace trigger session_rounds_split_secret before insert or update of card on public.session_rounds
  for each row execute function private.split_round_secret();

-- ---------------------------------------------------------------------------
-- Outils communs
-- ---------------------------------------------------------------------------
create or replace function private.mv(p_code text) returns void
language plpgsql immutable set search_path = '' as $$
begin
  raise exception 'move:%', p_code;
end $$;

-- Mot normalisé : minuscules, sans accents, lettres seules (« Étoile » → « etoile »).
create or replace function private.nrm(t text) returns text
language sql immutable set search_path = '' as $$
  select regexp_replace(
    translate(replace(replace(replace(replace(coalesce(t, ''), 'Œ', 'oe'), 'œ', 'oe'), 'Æ', 'ae'), 'æ', 'ae'),
              'ÀÂÄÁÃÅÇÉÈÊËÍÌÎÏÑÓÒÔÖÕÚÙÛÜÝŸàâäáãåçéèêëíìîïñóòôöõúùûüýÿ',
              'aaaaaaceeeeiiiinooooouuuuyyaaaaaaceeeeiiiinooooouuuuyy'),
    '[^a-z]', '', 'g')
$$;

create or replace function private.nrm_lower(t text) returns text
language sql immutable set search_path = '' as $$ select private.nrm(lower(t)) $$;

-- Racine pour refuser un mot et ses flexions (« valise », « valises »).
create or replace function private.stem(n text) returns text
language sql immutable set search_path = '' as $$
  select left(n, greatest(least(length(n), 4), length(n) - 2))
$$;

create or replace function private.sortl(n text) returns text
language sql immutable set search_path = '' as $$
  select coalesce(string_agg(c, '' order by c), '') from regexp_split_to_table(n, '') c where c <> ''
$$;

-- Lettres d'un mot (multiensemble) et opérations utiles.
create or replace function private.letters(n text) returns text[]
language sql immutable set search_path = '' as $$
  select coalesce(array_agg(c), '{}') from regexp_split_to_table(n, '') c where c <> ''
$$;

-- a moins b (une occurrence retirée par lettre de b). Null si b n'est pas contenu dans a.
create or replace function private.ms_minus(a text[], b text[]) returns text[]
language plpgsql immutable set search_path = '' as $$
declare
  res text[] := a;
  x text;
  pos int;
begin
  foreach x in array coalesce(b, '{}') loop
    pos := array_position(res, x);
    if pos is null then return null; end if;
    res := res[1:pos - 1] || res[pos + 1:];
  end loop;
  return res;
end $$;

create or replace function private.shuffle_int(n int) returns int[]
language sql volatile set search_path = '' as $$
  select coalesce(array_agg(x order by random()), '{}') from generate_series(0, n - 1) x
$$;

create or replace function private.rnd(n int) returns int
language sql volatile set search_path = '' as $$ select floor(random() * greatest(n, 1))::int $$;

-- Texte libre propre (longueur bornée).
create or replace function private.txt(p jsonb, k text, p_max int, p_required boolean default true) returns text
language plpgsql immutable set search_path = '' as $$
begin
  return private.clean_text(p, k, p_max, p_required);
exception when raise_exception then
  perform private.mv('invalid_text');
  return null;
end $$;

create or replace function private.int_in(p jsonb, k text, n int) returns int
language plpgsql immutable set search_path = '' as $$
begin
  return private.idx(p -> k, n);
exception when raise_exception then
  perform private.mv('invalid_move');
  return null;
end $$;

-- Lexique de la session : tous les mots livrés avec le kit (normalisés), pour valider les propositions.
create or replace function private.lexicon() returns text[]
language sql stable security definer set search_path = '' as $$
  select coalesce(array_agg(distinct w), '{}') from (
    select private.nrm_lower(value #>> '{}') w from public.content_banks where bank in ('words', 'chain') and jsonb_typeof(value) = 'string'
    union all select private.nrm_lower(value ->> 'target') from public.content_banks where bank = 'taboo'
    union all select private.nrm_lower(x) from public.content_banks, jsonb_array_elements_text(value -> 'forbidden') x where bank = 'taboo'
    union all select private.nrm_lower(x) from public.content_banks, jsonb_array_elements_text(value -> 'words') x where bank = 'rhymes'
    union all select private.nrm_lower(value ->> 'word') from public.content_banks where bank = 'syllables'
    union all select private.nrm_lower(x) from public.content_banks, jsonb_array_elements_text(value -> 'items') x where bank = 'intruders'
    union all select private.nrm_lower(x.value) from public.content_banks, jsonb_each_text(value -> 'examples') x where bank = 'categories'
    union all select private.nrm_lower(value ->> 'left') from public.content_banks where bank = 'pairs'
    union all select private.nrm_lower(value ->> 'right') from public.content_banks where bank = 'pairs'
    union all select private.nrm_lower(x) from public.content_banks, jsonb_array_elements_text(value -> 'path') x where bank = 'ladders'
    union all select private.nrm_lower(x) from public.content_banks, jsonb_array_elements_text(value -> 'accepted_words') x where bank = 'growth_levels'
    union all select private.nrm_lower(value ->> 'horizontal') from public.content_banks where bank = 'cross_levels'
    union all select private.nrm_lower(value ->> 'vertical') from public.content_banks where bank = 'cross_levels'
    union all select private.nrm_lower(x) from public.content_banks, jsonb_array_elements_text(value -> 'accepted') x where bank = 'rebus_levels'
  ) s where w <> ''
$$;

-- Index déjà tirés dans la partie pour une banque (pas de répétition tant qu'il en reste).
create or replace function private.used_idx(p_session uuid, p_bank text) returns int[]
language sql stable security definer set search_path = '' as $$
  select coalesce(array_agg(i), '{}') from (
    select (secret ->> 'idx')::int i from private.round_secrets where session_id = p_session and secret ->> 'bank' = p_bank and secret ? 'idx'
    union all
    select (x::text)::int from private.round_secrets, jsonb_array_elements(secret -> 'idxs') x
      where session_id = p_session and secret ->> 'bank' = p_bank) s
$$;

-- Une entrée de banque au hasard, en évitant celles déjà jouées dans la partie (et un filtre de longueur facultatif).
create or replace function private.pick_entry(p_session uuid, p_bank text, p_min int default null, p_max int default null) returns jsonb
language sql volatile security definer set search_path = '' as $$
  select jsonb_build_object('i', b.idx, 'v', b.value) from public.content_banks b
  where b.bank = p_bank and coalesce(b.content_version, '') <> 'retire'
    and (p_min is null or length(private.nrm_lower(b.value #>> '{}')) >= p_min)
    and (p_max is null or length(private.nrm_lower(b.value #>> '{}')) <= p_max)
  order by b.idx = any(private.used_idx(p_session, p_bank)), random()
  limit 1
$$;

-- ---------------------------------------------------------------------------
-- Tirage : la famille 1 garde son tirage ; le plateau passe par private.board_setup.
-- ---------------------------------------------------------------------------
create or replace function private.draw_round_card(s public.game_sessions, cfg jsonb) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  allow_intimate boolean;
  deck_size int;
  words jsonb;
  card jsonb := '{}';
  q public.game_cards;
  l jsonb;
  role_a int;
begin
  if cfg ->> 'mechanic' = 'portrait_words' then
    select bool_and(p.intimate_opt_in) into allow_intimate
      from public.session_players sp join public.profiles p on p.id = sp.user_id where sp.session_id = s.id;
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

  if cfg ->> 'engine' = 'board' then
    return private.board_setup(s, cfg);
  end if;
  if cfg ->> 'engine' <> 'rounds' then raise exception 'unknown_mechanic'; end if;

  if cfg #>> '{draw,deck}' = 'true' then
    select c.* into q from public.game_cards c
    where c.game_id = s.game_id and c.status = 'published' and c.kind = 'question'
      and (not c.adult or private.adult_allowed(s.id))
      and not (c.topic_tags && private.excluded_tags(s.id))
      and not exists (select 1 from public.session_rounds r where r.session_id = s.id and r.card ->> 'id' = c.id)
    order by exists (select 1 from public.session_rounds r join public.game_sessions gs on gs.id = r.session_id
                     where gs.couple_id = s.couple_id and gs.game_id = s.game_id
                       and gs.created_at > now() - interval '60 days' and r.card ->> 'id' = c.id),
             random()
    limit 1;
    if q.id is null then raise exception 'not_enough_cards'; end if;
    card := jsonb_build_object('id', q.id, 'text', q.content ->> 'text', 'choices', coalesce(q.content -> 'choices', '[]'),
                               'adult', q.adult, 'theme', q.theme, 'format', q.content ->> 'format');
  end if;

  for l in select * from jsonb_array_elements(coalesce(cfg #> '{draw,lists}', '[]')) loop
    card := card || jsonb_build_object(l ->> 'key', private.bank_sample(l ->> 'bank', (l ->> 'count')::int));
  end loop;
  card := card || coalesce(cfg #> '{draw,fixed}', '{}');

  role_a := case when cfg ->> 'roles' = 'alternate' then ((greatest(s.current_round, 1) - 1) % 2) + 1 else 1 end;
  return card || jsonb_build_object('role_a', role_a);
end $$;

-- ---------------------------------------------------------------------------
-- Jouer un coup
-- ---------------------------------------------------------------------------
create or replace function public.play_move(p_session uuid, p_round int, p_action uuid, p_type text, p_payload jsonb default '{}')
returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  r record;
  cfg jsonb;
  rd public.session_rounds;
  sec jsonb;
  res jsonb;
  new_card jsonb;
begin
  select * into r from private.lock_session(p_session);
  if p_action is null or p_type is null or char_length(p_type) > 20 then
    return jsonb_build_object('ok', false, 'error', 'invalid_move');
  end if;
  if exists (select 1 from private.board_moves where action_id = p_action) then
    return jsonb_build_object('ok', true, 'repeated', true);
  end if;
  if (r.s).status = 'paused' then return jsonb_build_object('ok', false, 'error', 'paused'); end if;
  if (r.s).status <> 'playing' then return jsonb_build_object('ok', false, 'error', 'not_playing'); end if;
  cfg := private.version_config(r.s);
  if cfg ->> 'engine' is distinct from 'board' then return jsonb_build_object('ok', false, 'error', 'not_allowed'); end if;
  if p_round <> (r.s).current_round then return jsonb_build_object('ok', false, 'error', 'stale_round'); end if;
  select * into rd from public.session_rounds where session_id = p_session and round_no = p_round;
  if rd.session_id is null then return jsonb_build_object('ok', false, 'error', 'stale_round'); end if;
  if rd.revealed_at is not null or coalesce((rd.card ->> 'done')::boolean, false) then
    return jsonb_build_object('ok', false, 'error', 'round_over');
  end if;
  select secret into sec from private.round_secrets where session_id = p_session and round_no = p_round;

  begin
    res := private.board_apply(cfg ->> 'mechanic', rd.card, coalesce(sec, '{}'), r.seat, p_type,
                               coalesce(p_payload, '{}'), p_session);
  exception when raise_exception then
    if sqlerrm like 'move:%' then
      return jsonb_build_object('ok', false, 'error', substr(sqlerrm, 6));
    end if;
    raise;
  end;

  new_card := (res -> 'card') || jsonb_build_object('rev', coalesce((rd.card ->> 'rev')::int, 0) + 1,
                                                    'last', jsonb_build_object('seat', r.seat, 'type', p_type));
  insert into private.board_moves (action_id, session_id, round_no, seat, type, payload)
    values (p_action, p_session, p_round, r.seat, p_type, p_payload);
  update public.session_rounds set card = new_card,
    revealed_at = case when coalesce((new_card ->> 'done')::boolean, false) then now() end
    where session_id = p_session and round_no = p_round;
  update private.round_secrets set secret = res -> 'secret' where session_id = p_session and round_no = p_round;
  if coalesce((new_card ->> 'done')::boolean, false) and p_round >= (r.s).total_rounds then
    update public.game_sessions set status = 'ended', ended_at = now(), result = private.compute_result(r.s, cfg)
      where id = p_session;
  end if;
  perform private.bump_session(p_session, case when (new_card ->> 'done')::boolean then 'revealed' else 'move' end);
  return jsonb_build_object('ok', true, 'info', res -> 'info');
end $$;

grant execute on function public.play_move(uuid, int, uuid, text, jsonb) to authenticated;

-- ---------------------------------------------------------------------------
-- Résultat de partie : points communs (coopération) ou par joueur (duel) pour le plateau.
-- ---------------------------------------------------------------------------
create or replace function private.compute_result(s public.game_sessions, cfg jsonb) returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare
  pts1 int := 0;
  pts2 int := 0;
  rd public.session_rounds;
  target jsonb;
  guess jsonb;
  role_a int;
  common int := 0;
begin
  if cfg ->> 'engine' = 'board' then
    select coalesce(sum((card ->> 'points')::int), 0), coalesce(sum((card #>> '{scores,1}')::int), 0),
           coalesce(sum((card #>> '{scores,2}')::int), 0)
      into common, pts1, pts2
      from public.session_rounds where session_id = s.id;
    if cfg ->> 'score' = 'duel' then
      return jsonb_build_object('points', jsonb_build_object('1', pts1, '2', pts2));
    end if;
    return jsonb_build_object('common', common,
      'rounds', (select count(*) from public.session_rounds where session_id = s.id and revealed_at is not null),
      'success', (select count(*) from public.session_rounds where session_id = s.id and (card ->> 'success')::boolean));
  end if;
  if cfg ->> 'score' = 'prediction' then
    for rd in select * from public.session_rounds where session_id = s.id and revealed_at is not null loop
      if coalesce((rd.card ->> 'adult')::boolean, false) then continue; end if;
      role_a := (rd.card ->> 'role_a')::int;
      target := private.round_answer(s.id, rd.round_no, 'choice', role_a);
      guess := private.round_answer(s.id, rd.round_no, 'guess', 3 - role_a);
      if jsonb_typeof(target -> 'choice') = 'number' and target -> 'choice' = guess -> 'choice' then
        if role_a = 1 then pts2 := pts2 + 1; else pts1 := pts1 + 1; end if;
      end if;
    end loop;
    return jsonb_build_object('points', jsonb_build_object('1', pts1, '2', pts2));
  end if;
  return jsonb_build_object('cards', (select count(*) from public.session_rounds where session_id = s.id and revealed_at is not null));
end $$;

-- ---------------------------------------------------------------------------
-- État de partie : pour le plateau, la part privée de l'appelant et, manche finie, la solution.
-- ---------------------------------------------------------------------------
create or replace function public.get_session_state(p_session uuid) returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare
  s public.game_sessions;
  me uuid := auth.uid();
  my_seat int;
  cfg jsonb;
begin
  select * into s from public.game_sessions where id = p_session;
  if s.id is null or not private.is_member(s.couple_id, true) then
    return jsonb_build_object('ok', false, 'error', 'session_not_found');
  end if;
  select seat into my_seat from public.session_players where session_id = p_session and user_id = me;
  cfg := private.version_config(s);

  return jsonb_build_object(
    'ok', true,
    'session', jsonb_build_object(
      'id', s.id, 'game_id', s.game_id, 'game_version', s.game_version, 'status', s.status,
      'settings', s.settings, 'current_round', s.current_round, 'total_rounds', s.total_rounds,
      'paused_by', s.paused_by, 'state_version', s.state_version, 'created_at', s.created_at,
      'started_at', s.started_at, 'ended_at', s.ended_at, 'closed_at', s.closed_at, 'result', s.result,
      'read_only', not private.is_member(s.couple_id)),
    'my_seat', my_seat,
    'my_prefs', (select jsonb_build_object('adult', sp.adult, 'excluded_topics', to_jsonb(sp.excluded_topics))
                 from public.session_prefs sp where sp.session_id = s.id and sp.user_id = me),
    'game', (select jsonb_build_object('title', g.title, 'mechanic', g.mechanic, 'rules', v.rules, 'config', v.config,
                                       'adult_available', g.adult_available, 'thumbnail', g.thumbnail)
             from public.games g join public.game_versions v on v.game_id = g.id and v.version = s.game_version
             where g.id = s.game_id),
    'players', (select coalesce(jsonb_agg(jsonb_build_object(
                  'seat', sp.seat, 'user_id', sp.user_id, 'is_me', sp.user_id = me,
                  'display_name', coalesce(nullif(pr.display_name, ''), cm.display_name_snapshot, ''),
                  'word_form', coalesce(pr.word_form, 'n'), 'avatar_path', pr.avatar_path,
                  'ready', sp.ready_at is not null, 'keep_memory', sp.keep_memory) order by sp.seat), '[]')
                from public.session_players sp
                left join public.profiles pr on pr.id = sp.user_id
                left join public.couple_members cm on cm.couple_id = s.couple_id and cm.user_id = sp.user_id
                where sp.session_id = s.id),
    'rounds', (select coalesce(jsonb_agg(jsonb_build_object(
                 'round_no', rd.round_no, 'card', rd.card,
                 'revealed', rd.revealed_at is not null and rd.revealed_at <= now(),
                 'reveal_at', case when rd.revealed_at > now() then rd.revealed_at end,
                 'private', (select rs.secret -> 'seats' -> my_seat::text from private.round_secrets rs
                             where rs.session_id = s.id and rs.round_no = rd.round_no),
                 'solution', (select rs.secret -> 'solution' from private.round_secrets rs
                              where rs.session_id = s.id and rs.round_no = rd.round_no
                                and rd.revealed_at is not null and rd.revealed_at <= now()),
                 'answers', (select coalesce(jsonb_agg(jsonb_build_object(
                                'step', a.step, 'seat', a.seat, 'skipped', a.skipped, 'revision', a.revision,
                                'payload', case
                                  when a.seat = my_seat then a.payload
                                  when (rd.revealed_at <= now())
                                       or exists (select 1 from jsonb_array_elements(coalesce(cfg -> 'steps', '[]')) st
                                                  where st ->> 'key' = a.step and st ->> 'visible' = 'immediate')
                                    then private.public_payload(
                                      (select st from jsonb_array_elements(coalesce(cfg -> 'steps', '[]') || coalesce(cfg -> 'after', '[]')) st
                                       where st ->> 'key' = a.step limit 1), a.payload)
                                end)
                              order by a.seat, a.created_at), '[]')
                             from public.session_answers a
                             where a.session_id = s.id and a.round_no = rd.round_no)
               ) order by rd.round_no), '[]')
               from public.session_rounds rd where rd.session_id = s.id)
  );
end $$;

-- ---------------------------------------------------------------------------
-- Partenaire automatique de test : il joue aussi au plateau (un coup à la fois).
-- ---------------------------------------------------------------------------
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
  mv jsonb;
begin
  select * into s from public.game_sessions where id = p_session;
  if s.status = 'lobby' then
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
  select * into rnd from public.session_rounds where session_id = p_session and round_no = s.current_round;
  if rnd.session_id is null then return false; end if;

  if cfg ->> 'engine' = 'board' then
    if s.status <> 'playing' or rnd.revealed_at is not null then return false; end if;
    mv := private.board_bot(cfg ->> 'mechanic', rnd.card,
                            coalesce((select secret from private.round_secrets where session_id = p_session and round_no = rnd.round_no), '{}'),
                            p_seat);
    if mv is null then return false; end if;
    res := public.play_move(p_session, rnd.round_no, gen_random_uuid(), mv ->> 'type', coalesce(mv -> 'payload', '{}'));
    return coalesce((res ->> 'ok')::boolean, false);
  end if;
  if cfg ->> 'engine' is distinct from 'rounds' then return false; end if;

  if rnd.revealed_at is null then
    if s.status <> 'playing' then return false; end if;
    list_key := 'steps';
  elsif rnd.revealed_at <= now() then
    list_key := 'after';
  else
    return false;
  end if;

  for st in select e.value from jsonb_array_elements(coalesce(cfg -> list_key, '[]')) e loop
    if not (p_seat = any(private.step_seats(st, rnd.card))) then continue; end if;
    if exists (select 1 from public.session_answers a where a.session_id = p_session and a.round_no = rnd.round_no
               and a.step = st ->> 'key' and a.seat = p_seat) then
      continue;
    end if;
    if st ? 'after' and not exists (select 1 from public.session_answers a where a.session_id = p_session
                                    and a.round_no = rnd.round_no and a.step = st ->> 'after') then
      return false;
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
