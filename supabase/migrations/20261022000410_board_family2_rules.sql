-- Famille 2 « Mots et répartie » : tirage et règles de chaque activité (moteur plateau).
-- Chaque fonction de règle reçoit l'état public (c), les secrets (sec), le siège qui joue, le type de coup et
-- ses données ; elle renvoie le nouvel état ou refuse le coup (private.mv) sans rien changer.

create or replace function private.push(a jsonb, v jsonb) returns jsonb
language sql immutable set search_path = '' as $$ select coalesce(a, '[]') || jsonb_build_array(v) $$;

create or replace function private.res(c jsonb, sec jsonb, info jsonb default null) returns jsonb
language sql immutable set search_path = '' as $$ select jsonb_build_object('card', c, 'secret', sec, 'info', info) $$;

create or replace function private.need_turn(c jsonb, seat int) returns void
language plpgsql immutable set search_path = '' as $$
begin
  if (c ->> 'turn')::int is distinct from seat then perform private.mv('not_your_turn'); end if;
end $$;

-- ===========================================================================
-- Tirage d'une manche
-- ===========================================================================
create or replace function private.board_setup(s public.game_sessions, cfg jsonb) returns jsonb
language plpgsql volatile security definer set search_path = '' as $$
declare
  m text := cfg ->> 'mechanic';
  rn int := greatest(s.current_round, 1);
  ra int := ((greatest(s.current_round, 1) - 1) % 2) + 1;   -- rôles alternés
  e jsonb;
  v jsonb;
  w text;
  arr jsonb := '[]';
  ids int[];
  perm int[];
  i int;
  j int;
  k int;
  lex text[];
  letters text;
  grid text[];
  placed jsonb := '[]';
  ok boolean;
  dir int;
  rev boolean;
  r0 int;
  c0 int;
  base text[] := array['A','E','I','O','R','S','T','N'];
  market text[] := '{}';
  need text[];
  add text[];
  examples jsonb := '[]';
  cats jsonb;
  idxs int[];
  roles jsonb;
  sol int[];
begin
  case m
  when 'taboo' then
    e := private.pick_entry(s.id, 'taboo'); v := e -> 'v';
    return jsonb_build_object('mech', m, 'giver', ra, 'guesser', 3 - ra, 'turn', ra, 'phase', 'clue',
      'clues', '[]'::jsonb, 'guesses', '[]'::jsonb, 'max', 3, 'done', false, 'success', false, 'points', 0,
      '_secret', jsonb_build_object('bank', 'taboo', 'idx', e -> 'i',
        'seats', jsonb_build_object(ra::text, v), 'solution', v));

  when 'anagram' then
    e := private.pick_entry(s.id, 'words', 4, 8);
    w := upper(private.nrm_lower(e #>> '{v}'));
    for k in 1 .. 30 loop
      select string_agg(c, '' order by random()) into letters from regexp_split_to_table(w, '') c;
      exit when letters <> w;
    end loop;
    lex := private.lexicon();
    select coalesce(jsonb_agg(distinct upper(x)), '[]') into arr from unnest(lex) x
      where length(x) = length(w) and private.sortl(x) = private.sortl(lower(w));
    return jsonb_build_object('mech', m, 'letters', to_jsonb(private.letters(letters)), 'len', length(w),
      'attempts', '[]'::jsonb, 'done', false, 'success', false, 'points', 0,
      '_secret', jsonb_build_object('bank', 'words', 'idx', e -> 'i',
        'solution', jsonb_build_object('word', e -> 'v', 'accepted', arr)));

  when 'categories' then
    select l into w from unnest(array['C','P','S','T']) l
      order by l = any(coalesce((select array_agg(secret ->> 'letter') from private.round_secrets where session_id = s.id), '{}')), random()
      limit 1;
    select jsonb_agg(b.value order by b.r), array_agg(b.idx order by b.r) into cats, idxs
      from (select value, idx, random() r from public.content_banks where bank = 'categories' order by random() limit 4) b;
    select jsonb_agg(x -> 'examples' ->> w) into examples from jsonb_array_elements(cats) x;
    return jsonb_build_object('mech', m, 'letter', w,
      'categories', (select jsonb_agg(x ->> 'category') from jsonb_array_elements(cats) x),
      'phase', 'write', 'submitted', '{}'::jsonb, 'judged', '{}'::jsonb, 'words', null,
      'done', false, 'scores', jsonb_build_object('1', 0, '2', 0),
      '_secret', jsonb_build_object('bank', 'categories', 'idxs', to_jsonb(idxs), 'letter', w, 'seats', '{}'::jsonb,
        'solution', jsonb_build_object('examples', examples)));

  when 'word_chain' then
    select jsonb_agg(value order by idx) into arr from public.content_banks where bank = 'chain';
    e := private.pick_entry(s.id, 'chain');
    return jsonb_build_object('mech', m, 'reserve', arr, 'chain', jsonb_build_array(jsonb_build_object('w', e -> 'v', 'seat', 0)),
      'turn', ra, 'passes', 0, 'target', 12, 'added', 0, 'done', false, 'success', false, 'points', 0,
      '_secret', jsonb_build_object('bank', 'chain', 'idx', e -> 'i', 'solution', '{}'::jsonb));

  when 'convergence' then
    e := private.pick_entry(s.id, 'pairs'); v := e -> 'v';
    return jsonb_build_object('mech', m, 'pair', jsonb_build_array(v -> 'left', v -> 'right'), 'history', '[]'::jsonb,
      'tour', 1, 'max', 5, 'submitted', '{}'::jsonb, 'done', false, 'success', false, 'points', 0,
      '_secret', jsonb_build_object('bank', 'pairs', 'idx', e -> 'i', 'seats', '{}'::jsonb, 'solution', '{}'::jsonb));

  when 'word_ladder' then
    e := private.pick_entry(s.id, 'ladders'); v := e -> 'v';
    return jsonb_build_object('mech', m, 'start', upper(v ->> 'start'), 'end', upper(v ->> 'end'), 'current', upper(v ->> 'start'),
      'chain', jsonb_build_array(upper(v ->> 'start')), 'turn', ra, 'hint', null, 'done', false, 'success', false, 'points', 0,
      '_secret', jsonb_build_object('bank', 'ladders', 'idx', e -> 'i',
        'solution', jsonb_build_object('path', (select jsonb_agg(upper(x)) from jsonb_array_elements_text(v -> 'path') x))));

  when 'word_search' then
    grid := array_fill(null::text, array[36]);
    idxs := '{}';
    for e in select jsonb_build_object('i', idx, 'v', value) from public.content_banks
             where bank = 'words' and length(private.nrm_lower(value #>> '{}')) between 3 and 6
             order by idx = any(private.used_idx(s.id, 'words')), random() loop
      exit when jsonb_array_length(placed) >= 5;
      w := upper(private.nrm_lower(e #>> '{v}'));
      if exists (select 1 from jsonb_array_elements(placed) p where p ->> 'w' = w) then continue; end if;
      ok := false;
      for k in 1 .. 60 loop
        dir := private.rnd(2); rev := random() < 0.35;
        r0 := private.rnd(case when dir = 1 then 7 - length(w) else 6 end);
        c0 := private.rnd(case when dir = 0 then 7 - length(w) else 6 end);
        ok := true;
        for i in 0 .. length(w) - 1 loop
          j := case when dir = 0 then r0 * 6 + c0 + i else (r0 + i) * 6 + c0 end;
          letters := substr(case when rev then reverse(w) else w end, i + 1, 1);
          if grid[j + 1] is not null and grid[j + 1] <> letters then ok := false; exit; end if;
        end loop;
        exit when ok;
      end loop;
      if not ok then continue; end if;
      for i in 0 .. length(w) - 1 loop
        j := case when dir = 0 then r0 * 6 + c0 + i else (r0 + i) * 6 + c0 end;
        grid[j + 1] := substr(case when rev then reverse(w) else w end, i + 1, 1);
      end loop;
      placed := private.push(placed, jsonb_build_object('w', w, 'r1', r0, 'c1', c0,
        'r2', case when dir = 1 then r0 + length(w) - 1 else r0 end, 'c2', case when dir = 0 then c0 + length(w) - 1 else c0 end));
      idxs := idxs || (e ->> 'i')::int;
    end loop;
    for i in 1 .. 36 loop
      if grid[i] is null then grid[i] := substr('AEIOURSTNLCMPDBGV', 1 + private.rnd(17), 1); end if;
    end loop;
    select jsonb_agg(string_agg) into arr from (
      select string_agg(grid[r * 6 + c + 1], '' order by c) from generate_series(0, 5) r, generate_series(0, 5) c group by r order by r) g;
    return jsonb_build_object('mech', m, 'size', 6, 'grid', arr,
      'words', (select jsonb_agg(p ->> 'w' order by p ->> 'w') from jsonb_array_elements(placed) p),
      'found', '[]'::jsonb, 'misses', 0, 'done', false, 'success', false, 'points', 0,
      '_secret', jsonb_build_object('bank', 'words', 'idxs', to_jsonb(idxs), 'solution', jsonb_build_object('placements', placed)));

  when 'masked_word' then
    e := private.pick_entry(s.id, 'words', 4, 8);
    w := upper(private.nrm_lower(e #>> '{v}'));
    select jsonb_agg(null::text) into arr from generate_series(1, length(w));
    return jsonb_build_object('mech', m, 'len', length(w), 'mask', arr, 'tried', '[]'::jsonb, 'wrong_words', '[]'::jsonb,
      'errors', 0, 'max', 6, 'turn', ra, 'hint_used', false, 'done', false, 'success', false, 'points', 0,
      '_secret', jsonb_build_object('bank', 'words', 'idx', e -> 'i',
        'solution', jsonb_build_object('word', e -> 'v', 'letters', w)));

  when 'syllables' then
    e := private.pick_entry(s.id, 'syllables'); v := e -> 'v';
    k := jsonb_array_length(v -> 'parts');
    -- Un fragment intrus à partir de la troisième manche.
    if rn >= 3 then
      select x into w from public.content_banks b, jsonb_array_elements_text(b.value -> 'parts') x
        where b.bank = 'syllables' and b.idx <> (e ->> 'i')::int and not (v -> 'parts') ? x order by random() limit 1;
    else
      w := null;
    end if;
    ids := private.shuffle_int(k + case when w is null then 0 else 1 end);
    -- tuiles : identifiants tirés au hasard (l'identifiant ne trahit pas la position)
    for k in 1 .. 20 loop
      perm := private.shuffle_int(cardinality(ids));
      exit when cardinality(ids) > 2 or perm <> (select array_agg(x order by x) from unnest(perm) x);
    end loop;
    select jsonb_agg(jsonb_build_object('id', ids[p + 1], 't', case when p < jsonb_array_length(v -> 'parts') then v -> 'parts' ->> p else w end)
                     order by array_position(perm, p))
      into arr from generate_series(0, cardinality(ids) - 1) p;
    return jsonb_build_object('mech', m, 'tiles', arr, 'attempts', 0, 'last', null, 'done', false, 'success', false, 'points', 0,
      '_secret', jsonb_build_object('bank', 'syllables', 'idx', e -> 'i',
        'solution', jsonb_build_object('word', v -> 'word', 'parts', v -> 'parts',
          'order', to_jsonb(ids[1:jsonb_array_length(v -> 'parts')]),
          'distractor', case when w is null then null else to_jsonb(ids[cardinality(ids)]) end)));

  when 'letter_market' then
    lex := private.lexicon();
    for w in select upper(x) from unnest(lex) x where length(x) between 4 and 8 order by random() loop
      need := private.ms_minus(private.letters(w), base);
      if need is null then
        -- lettres manquantes au-delà de la base
        need := private.letters(w);
        foreach letters in array base loop
          if array_position(need, letters) is not null then
            need := need[1:array_position(need, letters) - 1] || need[array_position(need, letters) + 1:];
          end if;
        end loop;
      end if;
      continue when cardinality(need) = 0 or cardinality(need) > 3;
      add := need;
      foreach letters in array market loop
        if array_position(add, letters) is not null then
          add := add[1:array_position(add, letters) - 1] || add[array_position(add, letters) + 1:];
        end if;
      end loop;
      continue when cardinality(market) + cardinality(add) > 8;
      market := market || add;
      examples := private.push(examples, to_jsonb(w));
      exit when jsonb_array_length(examples) >= 3 and cardinality(market) >= 5;
    end loop;
    while cardinality(market) < 8 loop
      market := market || substr('BCDFGLMPUV', 1 + private.rnd(10), 1);
    end loop;
    select jsonb_agg(jsonb_build_object('id', o - 1, 'l', l, 'cost', case when l in ('A','E','I','O','U','Y') then 2 else 1 end, 'owner', null)
                     order by o)
      into arr from unnest(market) with ordinality as t(l, o);
    return jsonb_build_object('mech', m, 'base', to_jsonb(base), 'market', arr, 'tokens', jsonb_build_object('1', 8, '2', 8),
      'buys', jsonb_build_object('1', 0, '2', 0), 'stopped', jsonb_build_object('1', false, '2', false), 'turn', ra,
      'phase', 'buy', 'submitted', '{}'::jsonb, 'words', null, 'done', false, 'scores', jsonb_build_object('1', 0, '2', 0),
      '_secret', jsonb_build_object('seats', '{}'::jsonb, 'solution', jsonb_build_object('examples', examples)));

  when 'semantic_intruder' then
    e := private.pick_entry(s.id, 'intruders'); v := e -> 'v';
    select jsonb_agg(x order by random()) into arr from jsonb_array_elements_text(v -> 'items') x;
    return jsonb_build_object('mech', m, 'category', v -> 'category', 'items', arr, 'submitted', '{}'::jsonb, 'picks', null,
      'done', false, 'scores', jsonb_build_object('1', 0, '2', 0),
      '_secret', jsonb_build_object('bank', 'intruders', 'idx', e -> 'i', 'seats', '{}'::jsonb,
        'solution', jsonb_build_object('answer', v -> 'answer', 'reason', v -> 'reason',
          'index', (select o - 1 from jsonb_array_elements_text(arr) with ordinality t(x, o) where x = v ->> 'answer'))));

  when 'telegram' then
    e := private.pick_entry(s.id, 'scenes');
    return jsonb_build_object('mech', m, 'sender', ra, 'receiver', 3 - ra, 'turn', ra, 'phase', 'write', 'telegram', null,
      'guess', null, 'verdict', null, 'scene', null, 'done', false, 'points', 0,
      '_secret', jsonb_build_object('bank', 'scenes', 'idx', e -> 'i',
        'seats', jsonb_build_object(ra::text, jsonb_build_object('scene', e -> 'v')), 'solution', jsonb_build_object('scene', e -> 'v')));

  when 'rhymes' then
    e := private.pick_entry(s.id, 'rhymes'); v := e -> 'v';
    return jsonb_build_object('mech', m, 'sound', v -> 'sound', 'count', jsonb_array_length(v -> 'words'), 'found', '[]'::jsonb,
      'turn', ra, 'passes', 0, 'hint', null, 'done', false, 'success', false, 'points', 0,
      '_secret', jsonb_build_object('bank', 'rhymes', 'idx', e -> 'i', 'solution', jsonb_build_object('words', v -> 'words')));

  when 'clue_grid' then
    select jsonb_agg(b.value order by b.r), array_agg(b.idx order by b.r) into arr, idxs
      from (select value, idx, random() r from public.content_banks where bank = 'words'
            order by idx = any(private.used_idx(s.id, 'words')), random() limit 12) b;
    perm := private.shuffle_int(12);
    select jsonb_agg(case when array_position(perm, p) <= 3 then 'target' when array_position(perm, p) = 4 then 'trap' else 'neutral' end
                     order by p)
      into roles from generate_series(0, 11) p;
    return jsonb_build_object('mech', m, 'giver', ra, 'guesser', 3 - ra, 'words', arr, 'revealed', '{}'::jsonb,
      'clues', '[]'::jsonb, 'tour', 1, 'max_tours', 3, 'picks_left', 0, 'phase', 'clue', 'turn', ra, 'found', 0,
      'done', false, 'success', false, 'points', 0,
      '_secret', jsonb_build_object('bank', 'words', 'idxs', to_jsonb(idxs),
        'seats', jsonb_build_object(ra::text, jsonb_build_object('roles', roles)), 'solution', jsonb_build_object('roles', roles)));

  when 'sentence_order' then
    e := private.pick_entry(s.id, 'sentences'); v := e -> 'v';
    k := jsonb_array_length(v);
    ids := private.shuffle_int(k);
    for i in 1 .. 30 loop
      perm := private.shuffle_int(k);
      exit when perm <> (select array_agg(x order by x) from unnest(perm) x);
    end loop;
    select jsonb_agg(jsonb_build_object('id', ids[p + 1], 't', v ->> p) order by p) into arr from generate_series(0, k - 1) p;
    return jsonb_build_object('mech', m, 'tiles', arr,
      'order', (select jsonb_agg(ids[p + 1] order by array_position(perm, p)) from generate_series(0, k - 1) p),
      'moves', 0, 'max', 10, 'turn', ra, 'agree', '{}'::jsonb, 'done', false, 'success', false, 'points', 0,
      '_secret', jsonb_build_object('bank', 'sentences', 'idx', e -> 'i',
        'solution', jsonb_build_object('order', to_jsonb(ids), 'text', (select string_agg(x, ' ') from jsonb_array_elements_text(v) x))));

  when 'word_growth' then
    e := private.pick_entry(s.id, 'growth_levels'); v := e -> 'v';
    return jsonb_build_object('mech', m, 'start', v -> 'start', 'current', v -> 'start', 'chain', jsonb_build_array(v -> 'start'),
      'turn', ra, 'hint', null, 'done', false, 'success', false, 'points', 0,
      '_secret', jsonb_build_object('bank', 'growth_levels', 'idx', e -> 'i',
        'solution', jsonb_build_object('path', v -> 'path', 'accepted', v -> 'accepted_words')));

  when 'cross_letters' then
    e := private.pick_entry(s.id, 'cross_levels'); v := e -> 'v';
    w := (v ->> 'horizontal') || substr(v ->> 'vertical', 1, 2) || substr(v ->> 'vertical', 4, 2);
    ids := private.shuffle_int(9);
    select jsonb_agg(jsonb_build_object('id', ids[o], 'l', l) order by ids[o]) into arr
      from unnest(private.letters(w)) with ordinality t(l, o);
    return jsonb_build_object('mech', m, 'a', ra, 'b', 3 - ra, 'tiles', arr, 'props', '{}'::jsonb,
      'ok', jsonb_build_object('1', false, '2', false), 'done', false, 'success', false, 'points', 0,
      '_secret', jsonb_build_object('bank', 'cross_levels', 'idx', e -> 'i',
        'solution', jsonb_build_object('horizontal', v -> 'horizontal', 'vertical', v -> 'vertical', 'center', v -> 'center')));

  when 'rebus' then
    e := private.pick_entry(s.id, 'rebus_levels'); v := e -> 'v';
    return jsonb_build_object('mech', m,
      'icons', (select jsonb_agg(jsonb_build_object('name', x, 'src', '/assets/jeux/elements/' || x || '.svg') order by o)
                from jsonb_array_elements_text(v -> 'icons') with ordinality t(x, o)),
      'readings', null, 'tries', '[]'::jsonb, 'max', 3, 'done', false, 'success', false, 'points', 0,
      '_secret', jsonb_build_object('bank', 'rebus_levels', 'idx', e -> 'i',
        'solution', jsonb_build_object('answer', v -> 'display_answer', 'explanation', v -> 'explanation',
          'readings', v -> 'readings', 'accepted', v -> 'accepted')));
  else
    raise exception 'unknown_mechanic';
  end case;
end $$;

-- ===========================================================================
-- Règles des coups
-- ===========================================================================
create or replace function private.board_apply(m text, c jsonb, sec jsonb, seat int, typ text, p jsonb, p_session uuid) returns jsonb
language plpgsql volatile security definer set search_path = '' as $$
declare
  me text := seat::text;
  oth text := (3 - seat)::text;
  t text;
  n text;
  w text;
  x text;
  i int;
  k int;
  ok boolean;
  arr jsonb;
  ids int[];
  sol jsonb := coalesce(sec -> 'solution', '{}');
  lex text[];
  cur text;
  st text;
  role text;
begin
  -- Abandon possible partout : la manche se termine et la solution s'affiche.
  if typ = 'giveup' then
    return private.res(c || '{"done": true, "gave_up": true}', sec);
  end if;

  case m
  -- -------------------------------------------------------------------------
  when 'taboo' then
    if typ = 'clue' then
      if seat <> (c ->> 'giver')::int or c ->> 'phase' <> 'clue' then perform private.mv('not_your_turn'); end if;
      t := private.txt(p, 'text', 80);
      for x in select y from regexp_split_to_table(t, '[[:space:][:punct:]’«»]+') y loop
        n := private.nrm_lower(x);
        continue when n = '';
        for w in select private.nrm_lower(z) from jsonb_array_elements_text(jsonb_build_array(sol ->> 'target') || (sol -> 'forbidden')) z loop
          if left(n, length(private.stem(w))) = private.stem(w) then perform private.mv('forbidden_word'); end if;
        end loop;
      end loop;
      c := c || jsonb_build_object('clues', private.push(c -> 'clues', jsonb_build_object('text', t)), 'phase', 'guess', 'turn', c -> 'guesser');
      return private.res(c, sec);
    elsif typ = 'guess' then
      if seat <> (c ->> 'guesser')::int or c ->> 'phase' <> 'guess' then perform private.mv('not_your_turn'); end if;
      t := private.txt(p, 'text', 40);
      n := private.nrm_lower(t); w := private.nrm_lower(sol ->> 'target');
      ok := n in (w, w || 's', w || 'x') or regexp_replace(n, '[sx]$', '') = w;
      c := c || jsonb_build_object('guesses', private.push(c -> 'guesses', jsonb_build_object('text', t, 'ok', ok)));
      if ok then
        c := c || '{"done": true, "success": true, "points": 1}';
      elsif jsonb_array_length(c -> 'guesses') >= 3 then
        c := c || '{"done": true}';
      elsif jsonb_array_length(c -> 'clues') < 3 then
        c := c || jsonb_build_object('phase', 'clue', 'turn', c -> 'giver');
      end if;
      return private.res(c, sec);
    elsif typ = 'flag' then
      if seat <> (c ->> 'guesser')::int then perform private.mv('not_your_turn'); end if;
      i := private.int_in(p, 'i', jsonb_array_length(c -> 'clues'));
      return private.res(jsonb_set(c, array['clues', i::text, 'flagged'], 'true'), sec);
    end if;

  -- -------------------------------------------------------------------------
  when 'anagram' then
    if typ = 'propose' then
      t := private.txt(p, 'word', 20);
      n := private.nrm_lower(t);
      if length(n) <> (c ->> 'len')::int then perform private.mv('wrong_length'); end if;
      if private.sortl(n) <> private.sortl(lower(array_to_string(array(select jsonb_array_elements_text(c -> 'letters')), ''))) then
        perform private.mv('wrong_letters');
      end if;
      ok := sol -> 'accepted' ? upper(n);
      c := c || jsonb_build_object('attempts', private.push(c -> 'attempts', jsonb_build_object('seat', seat, 'word', upper(n), 'ok', ok)));
      if ok then c := c || '{"done": true, "success": true, "points": 1}'; end if;
      return private.res(c, sec, jsonb_build_object('hit', ok));
    end if;

  -- -------------------------------------------------------------------------
  when 'categories' then
    if typ = 'submit' then
      if c ->> 'phase' <> 'write' or c -> 'submitted' ? me then perform private.mv('already_submitted'); end if;
      if jsonb_typeof(p -> 'words') <> 'array' or jsonb_array_length(p -> 'words') <> jsonb_array_length(c -> 'categories') then
        perform private.mv('invalid_move');
      end if;
      select jsonb_agg(coalesce(private.txt(jsonb_build_object('t', y), 't', 30, false), '') order by o) into arr
        from jsonb_array_elements(p -> 'words') with ordinality q(y, o);
      sec := jsonb_set(sec, array['seats', me], jsonb_build_object('words', arr));
      c := jsonb_set(c, array['submitted', me], 'true');
      if c -> 'submitted' ? oth then
        -- Les deux grilles sont prêtes : contrôle automatique, puis arbitrage mutuel des mots hors exemples.
        select jsonb_object_agg(sx, (select jsonb_agg(jsonb_build_object('text', wt, 'status',
                   case when private.nrm_lower(wt) = '' then 'empty'
                        when left(private.nrm_lower(wt), 1) <> lower(c ->> 'letter') then 'refused'
                        when private.nrm_lower(wt) = private.nrm_lower(sol -> 'examples' ->> (o - 1)::int) then 'auto'
                        else 'pending' end) order by o)
                 from jsonb_array_elements_text(sec -> 'seats' -> sx -> 'words') with ordinality q(wt, o)))
          into arr from unnest(array['1', '2']) sx;
        c := c || jsonb_build_object('words', arr);
        if not exists (select 1 from jsonb_each(arr) q, jsonb_array_elements(q.value) y where y ->> 'status' = 'pending') then
          c := c || jsonb_build_object('phase', 'done', 'done', true,
            'scores', (select jsonb_object_agg(q.key, (select count(*) from jsonb_array_elements(q.value) y where y ->> 'status' in ('auto', 'accepted')))
                       from jsonb_each(arr) q));
        else
          c := c || '{"phase": "judge"}';
        end if;
      end if;
      return private.res(c, sec);
    elsif typ = 'judge' then
      if c ->> 'phase' <> 'judge' or c -> 'judged' ? me then perform private.mv('not_your_turn'); end if;
      if jsonb_typeof(p -> 'verdicts') <> 'array' then perform private.mv('invalid_move'); end if;
      arr := c -> 'words' -> oth;
      for i in 0 .. jsonb_array_length(arr) - 1 loop
        if arr -> i ->> 'status' = 'pending' then
          arr := jsonb_set(arr, array[i::text, 'status'],
                           to_jsonb(case when coalesce((p -> 'verdicts' ->> i)::boolean, false) then 'accepted' else 'refused' end));
        end if;
      end loop;
      c := jsonb_set(jsonb_set(c, array['words', oth], arr), array['judged', me], 'true');
      if not exists (select 1 from jsonb_each(c -> 'words') q, jsonb_array_elements(q.value) y where y ->> 'status' = 'pending') then
        c := c || jsonb_build_object('phase', 'done', 'done', true,
          'scores', (select jsonb_object_agg(q.key, (select count(*) from jsonb_array_elements(q.value) y where y ->> 'status' in ('auto', 'accepted')))
                     from jsonb_each(c -> 'words') q));
      end if;
      return private.res(c, sec);
    end if;

  -- -------------------------------------------------------------------------
  when 'word_chain' then
    perform private.need_turn(c, seat);
    if typ = 'word' then
      n := private.nrm_lower(private.txt(p, 'text', 30));
      select y into w from jsonb_array_elements_text(c -> 'reserve') y where private.nrm_lower(y) = n limit 1;
      if w is null then perform private.mv('not_in_reserve'); end if;
      if exists (select 1 from jsonb_array_elements(c -> 'chain') y where private.nrm_lower(y ->> 'w') = n) then
        perform private.mv('already_used');
      end if;
      cur := private.nrm_lower(c -> 'chain' -> -1 ->> 'w');
      if left(n, 1) <> right(cur, 1) then perform private.mv('wrong_letter'); end if;
      c := c || jsonb_build_object('chain', private.push(c -> 'chain', jsonb_build_object('w', w, 'seat', seat)),
        'added', (c ->> 'added')::int + 1, 'points', (c ->> 'added')::int + 1, 'passes', 0, 'turn', 3 - seat);
      if (c ->> 'added')::int >= (c ->> 'target')::int then c := c || '{"done": true, "success": true}'; end if;
      return private.res(c, sec);
    elsif typ = 'pass' then
      c := c || jsonb_build_object('passes', (c ->> 'passes')::int + 1, 'turn', 3 - seat);
      if (c ->> 'passes')::int >= 2 then c := c || jsonb_build_object('done', true, 'success', (c ->> 'added')::int > 0); end if;
      return private.res(c, sec);
    elsif typ = 'restart' then
      -- Impasse : nouveau départ tiré dans la réserve, la chaîne continue de compter.
      select y into w from jsonb_array_elements_text(c -> 'reserve') y
        where not exists (select 1 from jsonb_array_elements(c -> 'chain') z where private.nrm_lower(z ->> 'w') = private.nrm_lower(y))
        order by random() limit 1;
      if w is null then return private.res(c || jsonb_build_object('done', true, 'success', (c ->> 'added')::int > 0), sec); end if;
      c := c || jsonb_build_object('chain', private.push(c -> 'chain', jsonb_build_object('w', w, 'seat', 0, 'restart', true)), 'passes', 0);
      return private.res(c, sec);
    end if;

  -- -------------------------------------------------------------------------
  when 'convergence' then
    if typ = 'submit' then
      if c -> 'submitted' ? me then perform private.mv('already_submitted'); end if;
      t := private.txt(p, 'word', 30);
      sec := jsonb_set(sec, array['seats', me], jsonb_build_object('draft', t));
      c := jsonb_set(c, array['submitted', me], 'true');
      if c -> 'submitted' ? oth then
        ok := private.nrm_lower(sec #>> '{seats,1,draft}') = private.nrm_lower(sec #>> '{seats,2,draft}');
        c := c || jsonb_build_object('history', private.push(c -> 'history', jsonb_build_object('tour', c -> 'tour',
                 'words', jsonb_build_object('1', sec #> '{seats,1,draft}', '2', sec #> '{seats,2,draft}'), 'match', ok)),
               'submitted', '{}'::jsonb);
        if ok then
          c := c || '{"done": true, "success": true, "points": 1}';
        elsif (c ->> 'tour')::int >= (c ->> 'max')::int then
          c := c || '{"done": true}';
        else
          c := c || jsonb_build_object('pair', jsonb_build_array(sec #> '{seats,1,draft}', sec #> '{seats,2,draft}'),
                                       'tour', (c ->> 'tour')::int + 1);
        end if;
        sec := sec || '{"seats": {}}';
      end if;
      return private.res(c, sec);
    end if;

  -- -------------------------------------------------------------------------
  when 'word_ladder' then
    cur := lower(c ->> 'current');
    if typ = 'hint' then
      select upper(y) into w from jsonb_array_elements_text(sol -> 'path') with ordinality q(y, o)
        where o > coalesce((select o2 from jsonb_array_elements_text(sol -> 'path') with ordinality q2(y2, o2) where lower(y2) = cur), 0)
        order by o limit 1;
      if w is null then perform private.mv('no_hint'); end if;
      return private.res(c || jsonb_build_object('hint', w), sec);
    end if;
    perform private.need_turn(c, seat);
    if typ = 'step' then
      n := private.nrm_lower(private.txt(p, 'word', 12));
      if length(n) <> length(cur) then perform private.mv('wrong_length'); end if;
      select count(*) into k from generate_series(1, length(n)) g where substr(n, g, 1) <> substr(cur, g, 1);
      if k <> 1 then perform private.mv('one_letter'); end if;
      lex := private.lexicon();
      if not (n = any(lex)) and not (sol -> 'path' ? upper(n)) then perform private.mv('unknown_word'); end if;
      if c -> 'chain' ? upper(n) then perform private.mv('already_used'); end if;
      c := c || jsonb_build_object('chain', private.push(c -> 'chain', to_jsonb(upper(n))), 'current', upper(n), 'hint', null,
                                   'turn', 3 - seat);
      if upper(n) = c ->> 'end' then
        c := c || jsonb_build_object('done', true, 'success', true, 'points', 1, 'steps', jsonb_array_length(c -> 'chain') - 1);
      end if;
      return private.res(c, sec);
    elsif typ = 'back' then
      if jsonb_array_length(c -> 'chain') < 2 then perform private.mv('invalid_move'); end if;
      c := c || jsonb_build_object('chain', (c -> 'chain') - (-1), 'turn', 3 - seat);
      c := c || jsonb_build_object('current', c -> 'chain' -> -1);
      return private.res(c, sec);
    end if;

  -- -------------------------------------------------------------------------
  when 'word_search' then
    if typ = 'select' then
      declare
        r1 int := private.int_in(p, 'r1', 6); c1 int := private.int_in(p, 'c1', 6);
        r2 int := private.int_in(p, 'r2', 6); c2 int := private.int_in(p, 'c2', 6);
      begin
        if (r1 <> r2 and c1 <> c2) or (r1 = r2 and c1 = c2) then perform private.mv('straight_line'); end if;
        select string_agg(substr(c -> 'grid' ->> rr, cc + 1, 1), '' order by rr, cc) into t
          from generate_series(least(r1, r2), greatest(r1, r2)) rr, generate_series(least(c1, c2), greatest(c1, c2)) cc;
        select y into w from jsonb_array_elements_text(c -> 'words') y
          where (y = t or y = reverse(t))
            and not exists (select 1 from jsonb_array_elements(c -> 'found') f where f ->> 'w' = y)
          limit 1;
        if w is null then
          return private.res(c || jsonb_build_object('misses', (c ->> 'misses')::int + 1), sec, '{"hit": false}');
        end if;
        c := c || jsonb_build_object('found', private.push(c -> 'found',
               jsonb_build_object('w', w, 'r1', r1, 'c1', c1, 'r2', r2, 'c2', c2, 'seat', seat)));
        c := c || jsonb_build_object('points', jsonb_array_length(c -> 'found'));
        if jsonb_array_length(c -> 'found') >= jsonb_array_length(c -> 'words') then c := c || '{"done": true, "success": true}'; end if;
        return private.res(c, sec, '{"hit": true}');
      end;
    end if;

  -- -------------------------------------------------------------------------
  when 'masked_word' then
    w := sol ->> 'letters';
    if typ = 'hint' then
      if (c ->> 'hint_used')::boolean then perform private.mv('no_hint'); end if;
      select substr(w, g, 1) into x from generate_series(1, length(w)) g where c -> 'mask' ->> (g - 1) is null order by random() limit 1;
      if x is null then perform private.mv('no_hint'); end if;
      for k in 1 .. length(w) loop
        if substr(w, k, 1) = x then c := jsonb_set(c, array['mask', (k - 1)::text], to_jsonb(x)); end if;
      end loop;
      c := c || jsonb_build_object('hint_used', true, 'tried', private.push(c -> 'tried', to_jsonb(x)));
    else
      perform private.need_turn(c, seat);
      if typ = 'letter' then
        x := upper(private.nrm_lower(private.txt(p, 'letter', 2)));
        if length(x) <> 1 then perform private.mv('invalid_move'); end if;
        if c -> 'tried' ? x then perform private.mv('already_tried'); end if;
        c := c || jsonb_build_object('tried', private.push(c -> 'tried', to_jsonb(x)), 'turn', 3 - seat);
        if position(x in w) > 0 then
          for k in 1 .. length(w) loop
            if substr(w, k, 1) = x then c := jsonb_set(c, array['mask', (k - 1)::text], to_jsonb(x)); end if;
          end loop;
        else
          c := c || jsonb_build_object('errors', (c ->> 'errors')::int + 1);
        end if;
      elsif typ = 'word' then
        n := upper(private.nrm_lower(private.txt(p, 'word', 20)));
        c := c || jsonb_build_object('turn', 3 - seat);
        if n = w then
          c := c || jsonb_build_object('mask', to_jsonb(private.letters(w)));
        else
          c := c || jsonb_build_object('errors', (c ->> 'errors')::int + 1, 'wrong_words', private.push(c -> 'wrong_words', to_jsonb(n)));
        end if;
      else
        perform private.mv('invalid_move');
      end if;
    end if;
    if not exists (select 1 from jsonb_array_elements(c -> 'mask') y where y = 'null'::jsonb) then
      c := c || '{"done": true, "success": true, "points": 1}';
    elsif (c ->> 'errors')::int >= (c ->> 'max')::int then
      c := c || '{"done": true}';
    end if;
    return private.res(c, sec);

  -- -------------------------------------------------------------------------
  when 'syllables' then
    if typ = 'submit' then
      if jsonb_typeof(p -> 'order') <> 'array' or jsonb_array_length(p -> 'order') < 1 then perform private.mv('invalid_move'); end if;
      select array_agg((y::text)::int order by o) into ids from jsonb_array_elements(p -> 'order') with ordinality q(y, o);
      if cardinality(ids) <> (select count(distinct z) from unnest(ids) z)
         or exists (select 1 from unnest(ids) z where not exists (select 1 from jsonb_array_elements(c -> 'tiles') tl where (tl ->> 'id')::int = z)) then
        perform private.mv('invalid_move');
      end if;
      ok := to_jsonb(ids) = sol -> 'order';
      c := c || jsonb_build_object('attempts', (c ->> 'attempts')::int + 1, 'last', to_jsonb(ids));
      if ok then c := c || '{"done": true, "success": true, "points": 1}'; end if;
      return private.res(c, sec, jsonb_build_object('hit', ok));
    end if;

  -- -------------------------------------------------------------------------
  when 'letter_market' then
    if c ->> 'phase' = 'buy' then
      perform private.need_turn(c, seat);
      if typ = 'buy' then
        i := private.int_in(p, 'id', jsonb_array_length(c -> 'market'));
        if c -> 'market' -> i -> 'owner' <> 'null'::jsonb then perform private.mv('already_bought'); end if;
        if (c -> 'market' -> i ->> 'cost')::int > (c -> 'tokens' ->> me)::int then perform private.mv('not_enough_tokens'); end if;
        if (c -> 'buys' ->> me)::int >= 3 then perform private.mv('max_buys'); end if;
        c := jsonb_set(c, array['market', i::text, 'owner'], to_jsonb(seat));
        c := jsonb_set(c, array['tokens', me], to_jsonb((c -> 'tokens' ->> me)::int - (c -> 'market' -> i ->> 'cost')::int));
        c := jsonb_set(c, array['buys', me], to_jsonb((c -> 'buys' ->> me)::int + 1));
        if (c -> 'buys' ->> me)::int >= 3 then c := jsonb_set(c, array['stopped', me], 'true'); end if;
      elsif typ = 'stop' then
        c := jsonb_set(c, array['stopped', me], 'true');
      else
        perform private.mv('invalid_move');
      end if;
      if not (c -> 'stopped' ->> oth)::boolean then
        c := c || jsonb_build_object('turn', 3 - seat);
      elsif (c -> 'stopped' ->> me)::boolean then
        c := c || jsonb_build_object('phase', 'compose', 'turn', null);
      end if;
      return private.res(c, sec);
    end if;
    if c ->> 'phase' = 'compose' and typ = 'submit' then
      if c -> 'submitted' ? me then perform private.mv('already_submitted'); end if;
      n := upper(private.nrm_lower(coalesce(private.txt(p, 'word', 20, false), '')));
      if n <> '' then
        if private.ms_minus(array(select jsonb_array_elements_text(c -> 'base')) ||
                            array(select y ->> 'l' from jsonb_array_elements(c -> 'market') y where (y ->> 'owner')::int = seat),
                            private.letters(n)) is null then
          perform private.mv('missing_letters');
        end if;
        if not (lower(n) = any(private.lexicon())) then perform private.mv('unknown_word'); end if;
      end if;
      sec := jsonb_set(sec, array['seats', me], jsonb_build_object('word', n));
      c := jsonb_set(c, array['submitted', me], 'true');
      if c -> 'submitted' ? oth then
        c := c || jsonb_build_object('words', jsonb_build_object('1', sec #> '{seats,1,word}', '2', sec #> '{seats,2,word}'),
          'scores', jsonb_build_object('1', length(sec #>> '{seats,1,word}'), '2', length(sec #>> '{seats,2,word}')),
          'done', true, 'phase', 'done');
      end if;
      return private.res(c, sec);
    end if;

  -- -------------------------------------------------------------------------
  when 'semantic_intruder' then
    if typ = 'pick' then
      if c -> 'submitted' ? me then perform private.mv('already_submitted'); end if;
      i := private.int_in(p, 'i', jsonb_array_length(c -> 'items'));
      sec := jsonb_set(sec, array['seats', me], jsonb_build_object('pick', i));
      c := jsonb_set(c, array['submitted', me], 'true');
      if c -> 'submitted' ? oth then
        c := c || jsonb_build_object('picks', jsonb_build_object('1', sec #> '{seats,1,pick}', '2', sec #> '{seats,2,pick}'),
          'scores', jsonb_build_object(
            '1', case when (sec #>> '{seats,1,pick}')::int = (sol ->> 'index')::int then 1 else 0 end,
            '2', case when (sec #>> '{seats,2,pick}')::int = (sol ->> 'index')::int then 1 else 0 end),
          'done', true);
      end if;
      return private.res(c, sec);
    end if;

  -- -------------------------------------------------------------------------
  when 'telegram' then
    perform private.need_turn(c, seat);
    if typ = 'telegram' and c ->> 'phase' = 'write' then
      t := private.txt(p, 'text', 120);
      arr := (select coalesce(jsonb_agg(y), '[]') from regexp_split_to_table(btrim(t), '\s+') y where y <> '');
      if jsonb_array_length(arr) <> 5 then perform private.mv('five_words'); end if;
      if exists (select 1 from jsonb_array_elements_text(arr) y where char_length(y) > 24) then perform private.mv('invalid_text'); end if;
      if exists (select 1 from jsonb_array_elements_text(arr) y,
                   regexp_split_to_table(sol ->> 'scene', '[[:space:][:punct:]’]+') z
                 where length(private.nrm_lower(z)) >= 4 and private.nrm_lower(y) = private.nrm_lower(z)) then
        perform private.mv('scene_word');
      end if;
      c := c || jsonb_build_object('telegram', arr, 'phase', 'guess', 'turn', c -> 'receiver');
    elsif typ = 'guess' and c ->> 'phase' = 'guess' then
      c := c || jsonb_build_object('guess', private.txt(p, 'text', 60), 'phase', 'judge', 'turn', c -> 'sender', 'scene', sol -> 'scene');
    elsif typ = 'judge' and c ->> 'phase' = 'judge' then
      if jsonb_typeof(p -> 'ok') <> 'boolean' then perform private.mv('invalid_move'); end if;
      c := c || jsonb_build_object('verdict', p -> 'ok', 'done', true, 'success', (p ->> 'ok')::boolean,
                                   'points', case when (p ->> 'ok')::boolean then 1 else 0 end);
    else
      perform private.mv('invalid_move');
    end if;
    return private.res(c, sec);

  -- -------------------------------------------------------------------------
  when 'rhymes' then
    if typ = 'hint' then
      select y into w from jsonb_array_elements_text(sol -> 'words') y
        where not exists (select 1 from jsonb_array_elements(c -> 'found') f where private.nrm_lower(f ->> 'w') = private.nrm_lower(y))
        limit 1;
      if w is null then perform private.mv('no_hint'); end if;
      return private.res(c || jsonb_build_object('hint', jsonb_build_object('start', left(w, 2), 'len', char_length(w))), sec);
    end if;
    perform private.need_turn(c, seat);
    if typ = 'word' then
      n := private.nrm_lower(private.txt(p, 'text', 30));
      select y into w from jsonb_array_elements_text(sol -> 'words') y where private.nrm_lower(y) = n limit 1;
      if w is null then perform private.mv('not_in_list'); end if;
      if exists (select 1 from jsonb_array_elements(c -> 'found') f where private.nrm_lower(f ->> 'w') = n) then
        perform private.mv('already_used');
      end if;
      c := c || jsonb_build_object('found', private.push(c -> 'found', jsonb_strip_nulls(jsonb_build_object('w', w, 'seat', seat,
               'phrase', private.txt(p, 'phrase', 80, false)))), 'passes', 0, 'turn', 3 - seat, 'hint', null);
      c := c || jsonb_build_object('points', jsonb_array_length(c -> 'found'));
      if jsonb_array_length(c -> 'found') >= (c ->> 'count')::int then c := c || '{"done": true, "success": true}'; end if;
      return private.res(c, sec);
    elsif typ = 'pass' then
      c := c || jsonb_build_object('passes', (c ->> 'passes')::int + 1, 'turn', 3 - seat);
      if (c ->> 'passes')::int >= 2 then c := c || jsonb_build_object('done', true, 'success', jsonb_array_length(c -> 'found') > 0); end if;
      return private.res(c, sec);
    end if;

  -- -------------------------------------------------------------------------
  when 'clue_grid' then
    perform private.need_turn(c, seat);
    if typ = 'clue' and c ->> 'phase' = 'clue' then
      t := private.txt(p, 'word', 24);
      if t ~ '\s' then perform private.mv('one_word'); end if;
      n := private.nrm_lower(t);
      if n = '' then perform private.mv('invalid_text'); end if;
      if exists (select 1 from jsonb_array_elements_text(c -> 'words') y
                 where left(n, length(private.stem(private.nrm_lower(y)))) = private.stem(private.nrm_lower(y))) then
        perform private.mv('board_word');
      end if;
      c := c || jsonb_build_object('clues', private.push(c -> 'clues', jsonb_build_object('tour', c -> 'tour', 'word', t)),
        'phase', 'guess', 'picks_left', 3, 'turn', c -> 'guesser');
      return private.res(c, sec);
    elsif c ->> 'phase' = 'guess' and typ in ('pick', 'stop') then
      ok := typ = 'stop';
      if typ = 'pick' then
        i := private.int_in(p, 'i', 12);
        if c -> 'revealed' ? i::text then perform private.mv('already_revealed'); end if;
        role := sol -> 'roles' ->> i;
        c := jsonb_set(c, array['revealed', i::text], to_jsonb(role));
        if role = 'target' then
          c := c || jsonb_build_object('found', (c ->> 'found')::int + 1, 'picks_left', (c ->> 'picks_left')::int - 1);
          c := c || jsonb_build_object('points', c -> 'found');
          if (c ->> 'found')::int >= 3 then return private.res(c || '{"done": true, "success": true}', sec); end if;
          ok := (c ->> 'picks_left')::int <= 0;
        elsif role = 'trap' then
          return private.res(c || '{"done": true, "trap": true}', sec);
        else
          ok := true;
        end if;
      end if;
      if ok then
        if (c ->> 'tour')::int >= (c ->> 'max_tours')::int then
          c := c || '{"done": true}';
        else
          c := c || jsonb_build_object('tour', (c ->> 'tour')::int + 1, 'phase', 'clue', 'turn', c -> 'giver', 'picks_left', 0);
        end if;
      end if;
      return private.res(c, sec);
    end if;

  -- -------------------------------------------------------------------------
  when 'sentence_order' then
    if typ = 'agree' then
      c := jsonb_set(c, array['agree', me], c -> 'moves');
      if c -> 'agree' -> oth = c -> 'agree' -> me then c := c || '{"done": true, "success": true, "points": 1, "alternative": true}'; end if;
      return private.res(c, sec);
    end if;
    perform private.need_turn(c, seat);
    if typ = 'move' then
      i := private.int_in(p, 'from', jsonb_array_length(c -> 'order'));
      k := private.int_in(p, 'to', jsonb_array_length(c -> 'order'));
      if i = k then perform private.mv('invalid_move'); end if;
      select array_agg((y::text)::int order by o) into ids from jsonb_array_elements(c -> 'order') with ordinality q(y, o);
      x := ids[i + 1]::text;
      ids := ids[1:i] || ids[i + 2:];
      ids := ids[1:k] || x::int || ids[k + 1:];
      c := c || jsonb_build_object('order', to_jsonb(ids), 'moves', (c ->> 'moves')::int + 1, 'agree', '{}'::jsonb, 'turn', 3 - seat);
      if to_jsonb(ids) = sol -> 'order' then
        c := c || '{"done": true, "success": true, "points": 1}';
      elsif (c ->> 'moves')::int >= (c ->> 'max')::int then
        c := c || '{"done": true}';
      end if;
      return private.res(c, sec);
    end if;

  -- -------------------------------------------------------------------------
  when 'word_growth' then
    cur := c ->> 'current';
    if typ = 'hint' then
      select x2 into w from jsonb_array_elements_text(sol -> 'accepted') a(y),
             lateral unnest(private.ms_minus(private.letters(y), private.letters(cur))) x2
        where length(y) = length(cur) + 1 and private.ms_minus(private.letters(y), private.letters(cur)) is not null
        limit 1;
      if w is null then perform private.mv('no_hint'); end if;
      return private.res(c || jsonb_build_object('hint', w), sec);
    end if;
    perform private.need_turn(c, seat);
    if typ = 'grow' then
      n := upper(private.nrm_lower(private.txt(p, 'word', 20)));
      if length(n) <> length(cur) + 1 then perform private.mv('one_more_letter'); end if;
      if private.ms_minus(private.letters(n), private.letters(cur)) is null then perform private.mv('keep_letters'); end if;
      if not (sol -> 'accepted' ? n) then perform private.mv('unknown_word'); end if;
      if c -> 'chain' ? n then perform private.mv('already_used'); end if;
      c := c || jsonb_build_object('chain', private.push(c -> 'chain', to_jsonb(n)), 'current', n, 'hint', null, 'turn', 3 - seat,
                                   'points', jsonb_array_length(c -> 'chain'));
      if not exists (select 1 from jsonb_array_elements_text(sol -> 'accepted') y
                     where length(y) = length(n) + 1 and private.ms_minus(private.letters(y), private.letters(n)) is not null) then
        c := c || '{"done": true, "success": true}';
      end if;
      return private.res(c, sec);
    end if;

  -- -------------------------------------------------------------------------
  when 'cross_letters' then
    if typ = 'propose' then
      if jsonb_typeof(p -> 'ids') <> 'array' or jsonb_array_length(p -> 'ids') <> 5 then perform private.mv('invalid_move'); end if;
      select array_agg((y::text)::int order by o) into ids from jsonb_array_elements(p -> 'ids') with ordinality q(y, o);
      if (select count(distinct z) from unnest(ids) z) <> 5
         or exists (select 1 from unnest(ids) z where z < 0 or z > 8) then
        perform private.mv('invalid_move');
      end if;
      select string_agg(t2.l, '' order by o) into w
        from unnest(ids) with ordinality u(z, o) join lateral (
          select tl ->> 'l' l from jsonb_array_elements(c -> 'tiles') tl where (tl ->> 'id')::int = u.z) t2 on true;
      ok := w = case when seat = (c ->> 'a')::int then sol ->> 'horizontal' else sol ->> 'vertical' end;
      c := jsonb_set(jsonb_set(c, array['props', me], to_jsonb(ids)), array['ok', me], to_jsonb(ok));
      -- Les deux mots lisibles, une seule tuile commune : celle du centre.
      if (c -> 'ok' ->> '1')::boolean and (c -> 'ok' ->> '2')::boolean
         and c -> 'props' -> '1' -> 2 = c -> 'props' -> '2' -> 2
         and (select count(*) from jsonb_array_elements(c -> 'props' -> '1') a1, jsonb_array_elements(c -> 'props' -> '2') a2 where a1 = a2) = 1 then
        c := c || '{"done": true, "success": true, "points": 1}';
      end if;
      return private.res(c, sec, jsonb_build_object('hit', ok));
    end if;

  -- -------------------------------------------------------------------------
  when 'rebus' then
    if typ = 'hint' then
      return private.res(c || jsonb_build_object('readings', sol -> 'readings'), sec);
    elsif typ = 'propose' then
      t := private.txt(p, 'text', 30);
      ok := exists (select 1 from jsonb_array_elements_text(sol -> 'accepted') y where private.nrm_lower(y) = private.nrm_lower(t));
      c := c || jsonb_build_object('tries', private.push(c -> 'tries', jsonb_build_object('seat', seat, 'text', t, 'ok', ok)));
      if ok then
        c := c || '{"done": true, "success": true, "points": 1}';
      elsif jsonb_array_length(c -> 'tries') >= (c ->> 'max')::int then
        c := c || '{"done": true}';
      end if;
      return private.res(c, sec, jsonb_build_object('hit', ok));
    end if;
  else
    raise exception 'unknown_mechanic';
  end case;
  perform private.mv('invalid_move');
  return null;
end $$;
