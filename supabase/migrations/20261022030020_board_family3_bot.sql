-- Partenaire automatique de test (temporaire) pour la famille 3 : un coup valide, ou null s'il doit attendre.
create or replace function private.bot_scribble(n int default 6, half boolean default false) returns jsonb
language sql volatile set search_path = '' as $$
  select jsonb_build_object('c', private.rnd(6), 'w', 1, 'p', jsonb_agg(jsonb_build_array(
    round((random() * case when half then 0.45 else 0.9 end + 0.05)::numeric, 3), round((random() * 0.9 + 0.05)::numeric, 3))))
  from generate_series(1, n)
$$;

create or replace function private.board_bot3(m text, c jsonb, sec jsonb, seat int) returns jsonb
language plpgsql volatile security definer set search_path = '' as $$
declare
  me text := seat::text;
  oth text := (3 - seat)::text;
  sol jsonb := coalesce(sec -> 'solution', '{}');
  my_turn boolean := (c ->> 'turn')::int is not distinct from seat;
  human_last boolean := (c #>> '{last,seat}')::int is distinct from seat and c ? 'last';
  i int;
  k int;
  e jsonb;
  t text;
begin
  if coalesce((c ->> 'done')::boolean, false) then return null; end if;
  case m
  when 'draw_guess', 'stroke_budget' then
    if seat = (c ->> 'drawer')::int then
      if jsonb_array_length(c -> 'strokes') >= 3 then return null; end if;
      return jsonb_build_object('type', 'stroke', 'payload', jsonb_build_object('s', private.bot_scribble()));
    end if;
    if jsonb_array_length(c -> 'strokes') = 0 or not human_last then return null; end if;
    return jsonb_build_object('type', 'guess', 'payload', jsonb_build_object('text',
      case when jsonb_array_length(c -> 'guesses') >= 1 then sec #>> '{solution,target}' else 'essai' end));

  when 'complete_doodle', 'mirror_draw' then
    if c ->> 'phase' = 'draw' then
      if not my_turn then return null; end if;
      return jsonb_build_object('type', 'stroke', 'payload', jsonb_build_object('s', private.bot_scribble(5, m = 'mirror_draw')));
    end if;
    t := case when m = 'mirror_draw' then 'names' else 'titles' end;
    if c -> t ? me then return null; end if;
    return jsonb_build_object('type', 'name', 'payload', '{"text": "Notre création de test"}'::jsonb);

  when 'draw_dictation' then
    if seat = (c ->> 'guide')::int then
      k := (select count(*) from jsonb_array_elements(c -> 'messages') q where (q ->> 'seat')::int = seat);
      if k >= jsonb_array_length(sol -> 'model') or (k > 0 and not human_last) then return null; end if;
      e := sol -> 'model' -> k;
      return jsonb_build_object('type', 'say', 'payload', jsonb_build_object('text',
        format('Un %s en colonne %s, ligne %s, tourné de %s°.', e ->> 'shape', (e ->> 'x')::int + 1, (e ->> 'y')::int + 1, e ->> 'rotation')));
    end if;
    if jsonb_array_length(c -> 'messages') = 0 then return null; end if;
    if c -> 'placed' <> sol -> 'model' then
      return jsonb_build_object('type', 'place', 'payload', jsonb_build_object('shapes', sol -> 'model'));
    end if;
    return jsonb_build_object('type', 'validate');

  when 'exquisite_drawing' then
    if c ->> 'phase' = 'draw' then
      select o - 1 into i from jsonb_array_elements(c -> 'owners') with ordinality u(q, o)
        where (q::text)::int = seat and not (c -> 'done_bands') ? (o - 1)::text order by o limit 1;
      if i is null then return null; end if;
      return jsonb_build_object('type', 'band', 'payload', jsonb_build_object('band', i,
        'strokes', jsonb_build_array(private.bot_scribble(), private.bot_scribble(4))));
    end if;
    if c -> 'names' ? me then return null; end if;
    return jsonb_build_object('type', 'name', 'payload', '{"text": "Bidule de test"}'::jsonb);

  when 'pixel_art' then
    if jsonb_array_length(c -> 'pending') > 0 and (c -> 'pending' -> 0 ->> 'by')::int <> seat then
      return jsonb_build_object('type', 'accept', 'payload', '{"k": 0}'::jsonb);
    end if;
    if not human_last then return null; end if;
    select g into i from generate_series(0, 63) g
      where g / 8 between 1 and 5 and g % 8 between 1 and 5
        and substr(c -> 'model' -> 'rows' ->> (g / 8 - 1), g % 8, 1) = '1' and c -> 'cells' ->> g is null
      order by g limit 1;
    if i is not null then
      return jsonb_build_object('type', 'paint', 'payload', jsonb_build_object('i', i, 'c', c -> 'colors' -> me -> 0));
    end if;
    if c -> 'validated' ? oth and not c -> 'validated' ? me then return jsonb_build_object('type', 'validate'); end if;
    return null;

  when 'tangram' then
    if not human_last then return null; end if;
    for e in select * from jsonb_array_elements(c -> 'pieces') loop
      k := (select min((q ->> 0)::int) from jsonb_array_elements(e -> 'base') q);
      i := (select min((q ->> 1)::int) from jsonb_array_elements(e -> 'base') q);
      if (e ->> 'x')::int <> 1 + k or (e ->> 'y')::int <> 1 + i or (e ->> 'rot')::int <> 0 or (e ->> 'flip')::boolean then
        return jsonb_build_object('type', 'place', 'payload', jsonb_build_object('id', e -> 'id', 'x', 1 + k, 'y', 1 + i, 'rot', 0, 'flip', false));
      end if;
    end loop;
    return null;

  when 'jigsaw' then
    if not human_last then return null; end if;
    select o - 1 into i from jsonb_array_elements(c -> 'order') with ordinality u(q, o) where (q::text)::int <> o - 1 order by o limit 1;
    if i is null then return null; end if;
    select o - 1 into k from jsonb_array_elements(c -> 'order') with ordinality u(q, o) where (q::text)::int = i;
    return jsonb_build_object('type', 'swap', 'payload', jsonb_build_object('a', i, 'b', k));

  when 'sticker_portrait' then
    if c -> 'submitted' ? me then return null; end if;
    return jsonb_build_object('type', 'submit', 'payload', jsonb_build_object('items', (
      select jsonb_agg(jsonb_build_object('s', g, 'x', round((0.2 + random() * 0.6)::numeric, 2), 'y', round((0.2 + random() * 0.6)::numeric, 2), 'r', 0))
      from unnest(array[0, 3, 6, 11, 17]) g)));

  when 'emblem' then
    if my_turn then
      return jsonb_build_object('type', 'symbol', 'payload', jsonb_build_object('o', private.rnd(jsonb_array_length(c -> 'symbols')), 'c', private.rnd(6)));
    end if;
    if not (c -> 'slots' ? '1' and c -> 'slots' ? '2') then return null; end if;
    if c -> 'support' = 'null'::jsonb then return jsonb_build_object('type', 'support', 'payload', '{"k": 0}'::jsonb); end if;
    if c -> 'name' = 'null'::jsonb then return jsonb_build_object('type', 'name', 'payload', '{"text": "Emblème de test"}'::jsonb); end if;
    if c -> 'validated' ? oth and not c -> 'validated' ? me then return jsonb_build_object('type', 'validate'); end if;
    return null;

  when 'palette' then
    if c ->> 'phase' = 'pick' then
      if c -> 'submitted' ? me then return null; end if;
      return jsonb_build_object('type', 'pick', 'payload', jsonb_build_object('ids', to_jsonb(private.bot_sample(jsonb_array_length(c -> 'colors'), 3))));
    end if;
    if not my_turn then return null; end if;
    if c -> 'proposal' <> 'null'::jsonb then return jsonb_build_object('type', 'answer', 'payload', '{"ok": true}'::jsonb); end if;
    select g into i from generate_series(0, jsonb_array_length(c -> 'colors') - 1) g where not (c -> 'final') @> to_jsonb(g) order by random() limit 1;
    return jsonb_build_object('type', 'propose', 'payload', jsonb_build_object('id', i));

  when 'poster' then
    if not my_turn then return null; end if;
    return case c ->> 'phase'
      when 'title' then jsonb_build_object('type', 'title', 'payload', '{"text": "Grand festival du test"}'::jsonb)
      when 'visual' then jsonb_build_object('type', 'visual', 'payload', '{"items": [{"s": 7, "x": 0.3, "y": 0.4, "r": 0}, {"s": 18, "x": 0.7, "y": 0.3, "r": 15}]}'::jsonb)
      when 'subtitle' then jsonb_build_object('type', 'subtitle', 'payload', '{"text": "Entrée libre, chaussettes dépareillées conseillées"}'::jsonb)
      else jsonb_build_object('type', 'detail', 'payload', '{"text": "Le 32 du mois prochain (date imaginaire)"}'::jsonb) end;

  when 'silent_comic' then
    if c ->> 'phase' = 'draw' then
      if not my_turn then return null; end if;
      return jsonb_build_object('type', 'frame', 'payload', jsonb_build_object('strokes', jsonb_build_array(private.bot_scribble()),
        'stickers', '[{"s": 3, "x": 0.5, "y": 0.5, "r": 0}]'::jsonb));
    end if;
    if c -> 'submitted' ? me then return null; end if;
    return jsonb_build_object('type', 'title', 'payload', '{"text": "Le titre de test"}'::jsonb);

  when 'tile_scene' then
    if not my_turn then return null; end if;
    select h.o - 1, g into k, i
      from jsonb_array_elements_text(c -> 'hands' -> me) with ordinality h(t, o), generate_series(0, 24) g
      where private.tile_legal(c -> 'grid', h.t, g)
      order by (h.t = 'maison') desc, private.is_path(h.t) desc, random() limit 1;
    if k is null then return jsonb_build_object('type', 'swap'); end if;
    return jsonb_build_object('type', 'place', 'payload', jsonb_build_object('h', k, 'i', i));

  when 'constellation' then
    if c ->> 'phase' = 'compose' then
      if not my_turn then return null; end if;
      return jsonb_build_object('type', 'note', 'payload', jsonb_build_object('k', private.rnd(jsonb_array_length(c -> 'stars'))));
    end if;
    if c -> 'names' ? me then return null; end if;
    return jsonb_build_object('type', 'name', 'payload', '{"text": "Petite musique de test"}'::jsonb);

  when 'flipbook' then
    select o - 1 into i from jsonb_array_elements(c -> 'owners') with ordinality u(q, o)
      where (q::text)::int = seat and c -> 'frames' -> (o - 1)::int = 'null'::jsonb order by o limit 1;
    if i is not null then
      return jsonb_build_object('type', 'frame', 'payload', jsonb_build_object('i', i,
        'objs', jsonb_build_array(jsonb_build_object('s', 0, 'x', 0.15 + i * 0.1, 'y', 0.5, 'r', i * 15),
                                  jsonb_build_object('s', 1, 'x', 0.8, 'y', 0.2 + i * 0.05, 'r', 0))));
    end if;
    if c -> 'validated' ? oth and not c -> 'validated' ? me
       and not exists (select 1 from jsonb_array_elements(c -> 'frames') q where q = 'null'::jsonb) then
      return jsonb_build_object('type', 'validate');
    end if;
    return null;

  when 'weaving' then
    if seat = (c ->> 'b')::int then
      select o - 1 into i from jsonb_array_elements(c -> 'hcolors') with ordinality u(q, o) where q = 'null'::jsonb order by o limit 1;
      if i is not null then
        return jsonb_build_object('type', 'hcolor', 'payload', jsonb_build_object('k', i, 'c',
          coalesce((select o2 - 1 from jsonb_array_elements(c -> 'palette') with ordinality u2(q2, o2) where q2 ->> 'name' = c -> 'model' -> 'horizontal' ->> i), 0)));
      end if;
    else
      select o - 1 into i from jsonb_array_elements(c -> 'vcolors') with ordinality u(q, o) where q = 'null'::jsonb order by o limit 1;
      if i is not null then
        return jsonb_build_object('type', 'vcolor', 'payload', jsonb_build_object('k', i, 'c',
          coalesce((select o2 - 1 from jsonb_array_elements(c -> 'palette') with ordinality u2(q2, o2) where q2 ->> 'name' = c -> 'model' -> 'vertical' ->> i), 0)));
      end if;
    end if;
    if human_last then
      select g into i from generate_series(0, 35) g
        where ((seat = (c ->> 'a')::int) = (g % 6 < 3)) and c -> 'mask' -> g <> c -> 'model' -> 'mask' -> g order by g limit 1;
      if i is not null then return jsonb_build_object('type', 'toggle', 'payload', jsonb_build_object('i', i)); end if;
    end if;
    if c -> 'title' = 'null'::jsonb then return jsonb_build_object('type', 'title', 'payload', '{"text": "Tissage de test"}'::jsonb); end if;
    if c -> 'validated' ? oth and not c -> 'validated' ? me then return jsonb_build_object('type', 'validate'); end if;
    return null;
  else
    return null;
  end case;
end $$;
