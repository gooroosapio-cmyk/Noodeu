-- Partenaire automatique de test (temporaire) : un coup valide pour le plateau, ou null s'il doit attendre.
-- Dans les jeux à tour, il joue à son tour ; dans les jeux libres, il laisse d'abord l'autre chercher.
create or replace function private.board_bot(m text, c jsonb, sec jsonb, seat int) returns jsonb
language plpgsql volatile security definer set search_path = '' as $$
declare
  me text := seat::text;
  oth text := (3 - seat)::text;
  sol jsonb := coalesce(sec -> 'solution', '{}');
  my_turn boolean := (c ->> 'turn')::int is not distinct from seat;
  human_last boolean := (c #>> '{last,seat}')::int is distinct from seat and c ? 'last';
  w text;
  i int;
  ids jsonb;
  cur text;
  lex text[];
begin
  if coalesce((c ->> 'done')::boolean, false) then return null; end if;
  case m
  when 'taboo' then
    if not my_turn then return null; end if;
    if seat = (c ->> 'giver')::int then
      return jsonb_build_object('type', 'clue', 'payload', jsonb_build_object('text', 'Indice numéro ' || (jsonb_array_length(c -> 'clues') + 1)));
    end if;
    return jsonb_build_object('type', 'guess', 'payload', jsonb_build_object('text',
      case when jsonb_array_length(c -> 'guesses') >= 1 then sol ->> 'target' else 'essai' end));

  when 'anagram' then
    if (select count(*) from jsonb_array_elements(c -> 'attempts') a where (a ->> 'seat')::int <> seat) < 2 or not human_last then return null; end if;
    return jsonb_build_object('type', 'propose', 'payload', jsonb_build_object('word', sol -> 'accepted' ->> 0));

  when 'categories' then
    if c ->> 'phase' = 'write' and not c -> 'submitted' ? me then
      return jsonb_build_object('type', 'submit', 'payload', jsonb_build_object('words', sol -> 'examples'));
    elsif c ->> 'phase' = 'judge' and not c -> 'judged' ? me
          and exists (select 1 from jsonb_array_elements(c -> 'words' -> oth) y where y ->> 'status' = 'pending') then
      return jsonb_build_object('type', 'judge', 'payload', jsonb_build_object('verdicts',
        (select jsonb_agg(true) from jsonb_array_elements(c -> 'words' -> oth))));
    end if;
    return null;

  when 'word_chain' then
    if not my_turn then return null; end if;
    cur := private.nrm_lower(c -> 'chain' -> -1 ->> 'w');
    select y into w from jsonb_array_elements_text(c -> 'reserve') y
      where left(private.nrm_lower(y), 1) = right(cur, 1)
        and not exists (select 1 from jsonb_array_elements(c -> 'chain') z where private.nrm_lower(z ->> 'w') = private.nrm_lower(y))
      order by random() limit 1;
    if w is not null then return jsonb_build_object('type', 'word', 'payload', jsonb_build_object('text', w)); end if;
    return jsonb_build_object('type', 'restart');

  when 'convergence' then
    -- Il attend le mot de l'autre ; à partir du deuxième tour, il le rejoint.
    if c -> 'submitted' ? me or not (c -> 'submitted' ? oth) then return null; end if;
    return jsonb_build_object('type', 'submit', 'payload', jsonb_build_object('word',
      case when (c ->> 'tour')::int >= 2 then sec #>> array['seats', oth, 'draft'] else 'lien' end));

  when 'word_ladder' then
    if not my_turn then return null; end if;
    cur := upper(c ->> 'current');
    select upper(y) into w from jsonb_array_elements_text(sol -> 'path') with ordinality q(y, o)
      where o > coalesce((select o2 from jsonb_array_elements_text(sol -> 'path') with ordinality q2(y2, o2) where upper(y2) = cur), 0)
      order by o limit 1;
    if w is null or (select count(*) from generate_series(1, length(w)) g where substr(w, g, 1) <> substr(cur, g, 1)) <> 1 then
      return jsonb_build_object('type', 'back');
    end if;
    return jsonb_build_object('type', 'step', 'payload', jsonb_build_object('word', w));

  when 'word_search' then
    if not human_last then return null; end if;
    select y into ids from jsonb_array_elements(sol -> 'placements') y
      where not exists (select 1 from jsonb_array_elements(c -> 'found') f where f ->> 'w' = y ->> 'w') limit 1;
    if ids is null then return null; end if;
    return jsonb_build_object('type', 'select', 'payload', ids - 'w');

  when 'masked_word' then
    if not my_turn then return null; end if;
    select substr(sol ->> 'letters', g, 1) into w from generate_series(1, length(sol ->> 'letters')) g
      where not (c -> 'tried') ? substr(sol ->> 'letters', g, 1) order by random() limit 1;
    if w is null then return jsonb_build_object('type', 'word', 'payload', jsonb_build_object('word', sol ->> 'letters')); end if;
    return jsonb_build_object('type', 'letter', 'payload', jsonb_build_object('letter', w));

  when 'syllables' then
    if (c ->> 'attempts')::int < 2 or not human_last then return null; end if;
    return jsonb_build_object('type', 'submit', 'payload', jsonb_build_object('order', sol -> 'order'));

  when 'letter_market' then
    if c ->> 'phase' = 'buy' then
      if not my_turn then return null; end if;
      if (c -> 'buys' ->> me)::int >= 2 then return jsonb_build_object('type', 'stop'); end if;
      select (y ->> 'id')::int into i from jsonb_array_elements(c -> 'market') y
        where y -> 'owner' = 'null'::jsonb and (y ->> 'cost')::int <= (c -> 'tokens' ->> me)::int
        order by (y ->> 'cost')::int, random() limit 1;
      if i is null then return jsonb_build_object('type', 'stop'); end if;
      return jsonb_build_object('type', 'buy', 'payload', jsonb_build_object('id', i));
    end if;
    if c ->> 'phase' = 'compose' and not c -> 'submitted' ? me then
      lex := private.lexicon();
      select upper(x) into w from unnest(lex) x
        where private.ms_minus(array(select jsonb_array_elements_text(c -> 'base')) ||
                               array(select y ->> 'l' from jsonb_array_elements(c -> 'market') y where (y ->> 'owner')::int = seat),
                               private.letters(upper(x))) is not null
        order by length(x) desc limit 1;
      return jsonb_build_object('type', 'submit', 'payload', jsonb_build_object('word', coalesce(w, '')));
    end if;
    return null;

  when 'semantic_intruder' then
    if c -> 'submitted' ? me then return null; end if;
    return jsonb_build_object('type', 'pick', 'payload', jsonb_build_object('i', private.rnd(jsonb_array_length(c -> 'items'))));

  when 'telegram' then
    if not my_turn then return null; end if;
    if c ->> 'phase' = 'write' then
      return jsonb_build_object('type', 'telegram', 'payload', jsonb_build_object('text', 'petit message envoyé pour essai'));
    elsif c ->> 'phase' = 'guess' then
      return jsonb_build_object('type', 'guess', 'payload', jsonb_build_object('text', 'Une scène de test, je crois.'));
    end if;
    return jsonb_build_object('type', 'judge', 'payload', jsonb_build_object('ok', true));

  when 'rhymes' then
    if not my_turn then return null; end if;
    select y into w from jsonb_array_elements_text(sol -> 'words') y
      where not exists (select 1 from jsonb_array_elements(c -> 'found') f where private.nrm_lower(f ->> 'w') = private.nrm_lower(y))
      order by random() limit 1;
    if w is null then return jsonb_build_object('type', 'pass'); end if;
    return jsonb_build_object('type', 'word', 'payload', jsonb_build_object('text', w));

  when 'clue_grid' then
    if not my_turn then return null; end if;
    if c ->> 'phase' = 'clue' then
      return jsonb_build_object('type', 'clue', 'payload', jsonb_build_object('word', 'Kaléidoscope'));
    end if;
    select o - 1 into i from jsonb_array_elements_text(sol -> 'roles') with ordinality q(y, o)
      where y = 'target' and not (c -> 'revealed') ? (o - 1)::text limit 1;
    if i is null then return jsonb_build_object('type', 'stop'); end if;
    return jsonb_build_object('type', 'pick', 'payload', jsonb_build_object('i', i));

  when 'sentence_order' then
    if (c -> 'agree' ? oth) and not (c -> 'agree' ? me) then return jsonb_build_object('type', 'agree'); end if;
    if not my_turn then return null; end if;
    select o - 1 into i from jsonb_array_elements(c -> 'order') with ordinality q(y, o)
      where y <> sol -> 'order' -> (o - 1)::int order by o limit 1;
    if i is null then return null; end if;
    return jsonb_build_object('type', 'move', 'payload', jsonb_build_object('from',
      (select o - 1 from jsonb_array_elements(c -> 'order') with ordinality q(y, o) where y = sol -> 'order' -> i), 'to', i));

  when 'word_growth' then
    if not my_turn then return null; end if;
    select y into w from jsonb_array_elements_text(sol -> 'accepted') y
      where length(y) = length(c ->> 'current') + 1 and private.ms_minus(private.letters(y), private.letters(c ->> 'current')) is not null
        and not (c -> 'chain') ? y
      limit 1;
    if w is null then return jsonb_build_object('type', 'giveup'); end if;
    return jsonb_build_object('type', 'grow', 'payload', jsonb_build_object('word', w));

  when 'cross_letters' then
    if coalesce((c -> 'ok' ->> me)::boolean, false) and (not (c -> 'props' ? oth) or c -> 'props' -> oth -> 2 = c -> 'props' -> me -> 2) then
      return null;
    end if;
    if not human_last and c ? 'last' then return null; end if;
    declare
      word text := case when seat = (c ->> 'a')::int then sol ->> 'horizontal' else sol ->> 'vertical' end;
      used int[] := '{}';
      center int;
      g int;
      tid int;
    begin
      center := case when c -> 'props' ? oth then (c -> 'props' -> oth ->> 2)::int end;
      if center is null or (select tl ->> 'l' from jsonb_array_elements(c -> 'tiles') tl where (tl ->> 'id')::int = center) <> substr(word, 3, 1) then
        select (tl ->> 'id')::int into center from jsonb_array_elements(c -> 'tiles') tl where tl ->> 'l' = substr(word, 3, 1) limit 1;
      end if;
      used := array[center];
      ids := '[]';
      for g in 1 .. 5 loop
        if g = 3 then ids := ids || to_jsonb(center); continue; end if;
        select (tl ->> 'id')::int into tid from jsonb_array_elements(c -> 'tiles') tl
          where tl ->> 'l' = substr(word, g, 1) and not ((tl ->> 'id')::int = any(used))
            and not (c -> 'props' ? oth and (c -> 'props' -> oth) @> to_jsonb((tl ->> 'id')::int))
          limit 1;
        if tid is null then return null; end if;
        used := used || tid;
        ids := ids || to_jsonb(tid);
      end loop;
      return jsonb_build_object('type', 'propose', 'payload', jsonb_build_object('ids', ids));
    end;

  when 'rebus' then
    if jsonb_array_length(c -> 'tries') < 2 or not human_last then return null; end if;
    return jsonb_build_object('type', 'propose', 'payload', jsonb_build_object('text', sol ->> 'answer'));
  else
    return null;
  end case;
end $$;
