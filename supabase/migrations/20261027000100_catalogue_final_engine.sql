-- Catalogue final : moteur des packs (cartes +18 sautées sans l'accord des deux, questionnaire aléatoire de 5, 10 ou
-- 20 questions tiré dans la rubrique) et progression (pack terminé = toutes ses cartes non +18 réalisées ensemble).

-- Carte de pack proposable : +18 seulement avec l'accord des deux, intensité dans le plafond commun de la partie.
create or replace function private.pack_card_ok(p_session uuid, p_bank text, v jsonb, p_adult_ok boolean) returns boolean
language sql stable security definer set search_path = '' as $$
  select (p_adult_ok or not coalesce((v ->> 'adult')::boolean, false))
     and private.intensity_rank(coalesce((select m.intensity from public.content_meta m where m.bank = p_bank and m.item_id = v ->> 'id'), 'soft'))
         <= private.session_cap(p_session) $$;
revoke execute on function private.pack_card_ok(uuid, text, jsonb, boolean) from public, anon, authenticated;

create or replace function private.board_setup5(s public.game_sessions, cfg jsonb) returns jsonb
language plpgsql volatile security definer set search_path = '' as $$
declare
  m text := cfg ->> 'mechanic';
  p jsonb := cfg -> 'pack';
  t jsonb := cfg -> 'test';
  n int;
  ci int;
  set_size int;
  it jsonb;
  items jsonb;
  adult_ok boolean;
  queue jsonb;
  nxt int;
begin
  if m = 'pack_conversation' then
    adult_ok := private.adult_allowed(s.id);
    if coalesce((p ->> 'random')::boolean, false) then
      -- Questionnaire aléatoire : tirage unique au début (questions libres de la rubrique, +18 et intensité respectés),
      -- liste gardée sur chaque carte ; aucune progression de pack.
      if s.current_round <= 1 then
        select jsonb_agg(jsonb_build_array(x.bank, x.idx)) into queue from (
          select cb.bank, cb.idx from public.content_banks cb
          where cb.bank in (select jsonb_array_elements_text(p -> 'pool'))
            and private.pack_card_ok(s.id, cb.bank, cb.value, adult_ok)
          order by random() limit greatest(1, least(20, coalesce((s.settings ->> 'questions')::int, 10)))) x;
        if queue is null then raise exception 'not_enough_cards'; end if;
        update public.game_sessions set total_rounds = jsonb_array_length(queue) where id = s.id;
        ci := 0;
      else
        select card -> 'queue', (card ->> 'index')::int + 1 into queue, ci
          from public.session_rounds where session_id = s.id and round_no = s.current_round - 1;
      end if;
      select value into it from public.content_banks where bank = queue -> ci ->> 0 and content_banks.idx = (queue -> ci ->> 1)::int;
      if it is null then raise exception 'bank_missing'; end if;
      return jsonb_build_object('mech', m, 'index', ci, 'count', jsonb_array_length(queue), 'queue', queue, 'random', true,
        'set_no', null, 'set_size', null, 'first', 1 + ci % 2, 'response', 'open', 'scales', '{}'::jsonb,
        'item', jsonb_build_object('id', it ->> 'id', 'text', it ->> 'text_fr', 'kind', it ->> 'kind', 'bank', queue -> ci ->> 0,
                                   'response', it ->> 'response_type', 'position', it -> 'source_position',
                                   'options', it -> 'options_ordered', 'adult', coalesce((it ->> 'adult')::boolean, false)),
        'status', '{}'::jsonb, 'answers', null, 'done', false,
        '_secret', jsonb_build_object('seats', '{}'::jsonb));
    end if;
    n := (p ->> 'count')::int;
    set_size := (p ->> 'set_size')::int;
    if s.current_round <= 1 then
      select next_index into ci from private.pack_progress where couple_id = s.couple_id and game_id = s.game_id;
      ci := coalesce(ci, 0);
      if ci >= n then ci := 0; end if;
    else
      select (card ->> 'index')::int + 1 into ci from public.session_rounds where session_id = s.id and round_no = s.current_round - 1;
    end if;
    -- Cartes +18 d'un pack : sautées tant que les deux ne les ont pas acceptées ; cartes plus intenses que le réglage
    -- le plus doux des deux : sautées aussi. L'ordre du pack est conservé.
    select min(cb.idx) into nxt from public.content_banks cb
      where cb.bank = cfg ->> 'bank' and cb.idx >= ci and private.pack_card_ok(s.id, cb.bank, cb.value, adult_ok);
    if nxt is null and s.current_round <= 1 then
      select min(cb.idx) into nxt from public.content_banks cb
        where cb.bank = cfg ->> 'bank' and private.pack_card_ok(s.id, cb.bank, cb.value, adult_ok);
    end if;
    if nxt is null then raise exception 'not_enough_cards'; end if;
    ci := nxt;
    if s.current_round <= 1 then
      -- Séance : jusqu'à la fin de la série (Aron, séries de 12) ou du pack, en ne comptant que les cartes proposées.
      -- 50 cartes au plus par séance (limite des parties) ; la suivante reprend après.
      update public.game_sessions set total_rounds = least(50, greatest(1, (select count(*) from public.content_banks cb
          where cb.bank = cfg ->> 'bank' and cb.idx >= ci
            and cb.idx < case when set_size is null then n else (ci / set_size + 1) * set_size end
            and private.pack_card_ok(s.id, cb.bank, cb.value, adult_ok))))
        where id = s.id;
    end if;
    select value into it from public.content_banks where bank = cfg ->> 'bank' and content_banks.idx = ci;
    if it is null then raise exception 'bank_missing'; end if;
    return jsonb_build_object('mech', m, 'index', ci, 'count', n,
      'set_no', case when set_size is null then null else ci / set_size + 1 end, 'set_size', set_size,
      'first', 1 + ci % 2, 'response', p ->> 'response', 'scales', p -> 'scales',
      'item', jsonb_build_object('id', it ->> 'id', 'text', it ->> 'text_fr', 'kind', it ->> 'kind',
                                 'response', it ->> 'response_type', 'position', it -> 'source_position',
                                 'options', it -> 'options_ordered', 'theme', it ->> 'theme',
                                 'adult', coalesce((it ->> 'adult')::boolean, false)),
      'status', '{}'::jsonb, 'answers', null, 'done', false,
      '_secret', jsonb_build_object('seats', '{}'::jsonb));
  elsif m = 'test_form' then
    items := private.bank_items(cfg ->> 'bank');
    if jsonb_array_length(items) <> (t ->> 'count')::int then raise exception 'bank_missing'; end if;
    return jsonb_build_object('mech', m, 'count', jsonb_array_length(items), 'input', t ->> 'input', 'scales', t -> 'scales',
      'page_size', t -> 'page_size', 'axes', t -> 'axes', 'reserves', t -> 'reserves',
      'items', (select jsonb_agg(jsonb_build_object('id', i ->> 'id', 'text', i ->> 'text_fr', 'position', i -> 'source_position',
                                                    'scale', i ->> 'scale_id', 'response', i ->> 'response_type',
                                                    'kind', i ->> 'kind', 'note', i -> 'note') order by o)
                from jsonb_array_elements(items) with ordinality e(i, o)),
      'completed', '{}'::jsonb, 'declined', '{}'::jsonb, 'shared', '{}'::jsonb, 'done', false,
      '_secret', jsonb_build_object('seats', '{}'::jsonb));
  end if;
  raise exception 'unknown_mechanic';
end $$;

create or replace function private.board_apply5(m text, c jsonb, sec jsonb, seat int, typ text, p jsonb, p_session uuid) returns jsonb
language plpgsql volatile security definer set search_path = '' as $$
declare
  me text := seat::text;
  oth text := (3 - seat)::text;
  s public.game_sessions;
  cfg jsonb;
  choice text;
  txt text;
  val jsonb;
  ans jsonb;
  items jsonb;
  it jsonb;
  k text;
  merged jsonb;
  res jsonb;
begin
  select * into s from public.game_sessions where id = p_session;
  cfg := private.version_config(s);

  if m = 'pack_conversation' then
    if typ <> 'answer' then perform private.mv('invalid_move'); end if;
    choice := p ->> 'choice';
    if choice not in ('share', 'private', 'pass') then perform private.mv('invalid_move'); end if;
    txt := nullif(btrim(coalesce(p ->> 'text', '')), '');
    if txt is not null and char_length(txt) > 500 then perform private.mv('invalid_text'); end if;
    val := p -> 'value';
    if val = 'null'::jsonb then val := null; end if;
    if val is not null and not exists (select 1 from jsonb_array_elements(c -> 'item' -> 'options') o where o -> 'value' = val) then
      perform private.mv('invalid_move');
    end if;
    if choice = 'share' and txt is null and val is null then perform private.mv('empty_answer'); end if;
    ans := case when choice = 'pass' then jsonb_build_object('choice', 'pass')
                else jsonb_strip_nulls(jsonb_build_object('choice', choice, 'text', txt, 'value', val)) end;
    sec := jsonb_set(sec, '{seats}', coalesce(sec -> 'seats', '{}') || jsonb_build_object(me, jsonb_build_object('answer', ans)));
    c := jsonb_set(c, array['status', me], '"done"');
    if c -> 'status' ? oth then
      -- Révélation : seules les réponses partagées sont envoyées ; « gardé pour soi » et « passé » sans contenu.
      c := c || jsonb_build_object('done', true, 'answers', jsonb_build_object(
        '1', private.pack_public(sec #> '{seats,1,answer}'), '2', private.pack_public(sec #> '{seats,2,answer}')));
      if not coalesce((c ->> 'random')::boolean, false) then
      insert into private.pack_progress (couple_id, game_id, next_index, cards_done)
        values (s.couple_id, s.game_id, (c ->> 'index')::int + 1, 1)
        on conflict (couple_id, game_id) do update set next_index = excluded.next_index,
          cards_done = pack_progress.cards_done + 1, updated_at = now();
      end if;
    end if;
    return private.res(c, sec);

  elsif m = 'test_form' then
    if c -> 'completed' ? me or c -> 'declined' ? me then perform private.mv('already_submitted'); end if;
    items := private.bank_items(cfg ->> 'bank');
    if typ in ('save', 'complete') then
      if jsonb_typeof(coalesce(p -> 'answers', '{}')) <> 'object' then perform private.mv('invalid_move'); end if;
      merged := coalesce(sec #> array['seats', me, 'answers'], '{}');
      for k in select jsonb_object_keys(coalesce(p -> 'answers', '{}')) loop
        select i into it from jsonb_array_elements(items) i where i ->> 'id' = k;
        if it is null or not private.test_value_ok(cfg -> 'test', it, p -> 'answers' -> k) then perform private.mv('invalid_option'); end if;
        merged := merged || jsonb_build_object(k, p -> 'answers' -> k);
      end loop;
      sec := jsonb_set(sec, '{seats}', coalesce(sec -> 'seats', '{}') || jsonb_build_object(me,
        coalesce(sec #> array['seats', me], '{}') || jsonb_build_object('answers', merged, 'page', coalesce(p -> 'page', sec #> array['seats', me, 'page']))));
      if typ = 'save' then return private.res(c, sec); end if;
      res := private.test_scores(cfg -> 'test', items, merged);
      sec := jsonb_set(sec, array['seats', me, 'result'], res);
      c := jsonb_set(c, array['completed', me], 'true');
      if coalesce((p ->> 'share')::boolean, false) and res ->> 'status' = 'complete' then
        c := jsonb_set(c, array['shared', me], res -> 'scores');
      end if;
    elsif typ = 'decline' then
      c := jsonb_set(c, array['declined', me], 'true');
    else
      perform private.mv('invalid_move');
    end if;
    if (c -> 'completed' ? oth or c -> 'declined' ? oth) then c := c || '{"done": true}'; end if;
    return private.res(c, sec);
  end if;
  perform private.mv('invalid_move');
  return null;
end $$;

create or replace function public.get_progress() returns jsonb
language plpgsql stable security definer set search_path = '' as $$
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
                           where cb.bank = v.config ->> 'bank' and not coalesce((cb.value ->> 'adult')::boolean, false)),
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
end $$;

-- Deux vérités et un mensonge : une amorce du pack G08 pour s'inspirer (les joueurs écrivent toujours leurs phrases).
-- Amorces +18 seulement si les deux ont accepté les cartes +18 de la partie.
create or replace function public.get_two_truths_idea(p_session uuid) returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare
  s public.game_sessions;
  txt text;
begin
  select * into s from public.game_sessions where id = p_session;
  if s.id is null or not private.is_member(s.couple_id) then return jsonb_build_object('ok', false, 'error', 'session_not_found'); end if;
  select cb.value ->> 'text' into txt from public.content_banks cb
    where cb.bank = 'conv_two_truths_ideas' and (not coalesce((cb.value ->> 'adult')::boolean, false) or private.adult_allowed(p_session))
    order by random() limit 1;
  if txt is null then return jsonb_build_object('ok', false, 'error', 'no_card'); end if;
  return jsonb_build_object('ok', true, 'text', txt);
end $$;
revoke execute on function public.get_two_truths_idea(uuid) from public, anon;
grant execute on function public.get_two_truths_idea(uuid) to authenticated;

-- « Plus tard » et métadonnées des cartes : la banque peut venir de la carte (questionnaire aléatoire).
create or replace function public.save_for_later(p_session uuid, p_round int) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  r record;
  rd public.session_rounds;
  cfg jsonb;
  item text;
  v_bank text;
begin
  select * into r from private.lock_session(p_session);
  cfg := private.version_config(r.s);
  select * into rd from public.session_rounds where session_id = p_session and round_no = p_round;
  item := coalesce(rd.card #>> '{item,id}', rd.card ->> 'card_id');
  -- Questionnaire aléatoire : la banque est portée par la carte.
  v_bank := coalesce(rd.card #>> '{item,bank}', cfg ->> 'bank');
  if item is null or v_bank is null or coalesce((rd.card ->> 'redacted')::boolean, false) then
    return jsonb_build_object('ok', false, 'error', 'not_allowed');
  end if;
  insert into public.later_items (user_id, bank, item_id, game_id) values (auth.uid(), v_bank, item, (r.s).game_id)
    on conflict (user_id, bank, item_id) do nothing;
  return jsonb_build_object('ok', true);
end $$;

create or replace function public.get_session_meta(p_session uuid) returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare
  s public.game_sessions;
  cfg jsonb;
begin
  select * into s from public.game_sessions where id = p_session;
  if s.id is null or not private.is_member(s.couple_id, true) then return jsonb_build_object('ok', false, 'error', 'session_not_found'); end if;
  cfg := private.version_config(s);
  return jsonb_build_object('ok', true, 'bank', cfg ->> 'bank',
    'items', (select coalesce(jsonb_object_agg(m.item_id, jsonb_strip_nulls(jsonb_build_object('intensity', m.intensity,
                'duration_kind', m.duration_kind, 'minutes_min', m.minutes_min, 'minutes_max', m.minutes_max,
                'long_followup', m.long_followup, 'formats', to_jsonb(m.formats)))), '{}')
              from public.content_meta m
              where (m.bank, m.item_id) in (
                select coalesce(rd.card #>> '{item,bank}', cfg ->> 'bank'), coalesce(rd.card #>> '{item,id}', rd.card ->> 'card_id')
                from public.session_rounds rd
                where rd.session_id = p_session and not coalesce((rd.card ->> 'redacted')::boolean, false))));
end $$;
