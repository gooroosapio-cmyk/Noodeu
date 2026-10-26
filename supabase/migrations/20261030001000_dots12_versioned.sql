-- M04 : préparer 12 × 12 POINTS, soit 121 cases et 264 segments.
-- GATE FRONTEND : cette migration n'active PAS la nouvelle version. Elle reste
-- non publiée et games.current_version reste inchangé. Publication + changement
-- du pointeur nécessiteront une migration distincte après UI 12 points, revue des
-- planches, tests de navigation/cibles 44 px et accord de mise en service.
-- Les anciennes parties/cards sans dimensions passent toujours par le moteur
-- historique 5 × 5 ; ni leurs versions, cartes, scores ni données ne sont modifiés.
-- Dépendances : aiguillage lot4 20261025000300, setup 20261028000500 et moteur008.

-- Surcharges explicites : les signatures historiques restent intactes.
create or replace function private.db_edge_ok(e text, dot_rows int, dot_columns int) returns boolean
language plpgsql immutable set search_path = '' as $$
declare k text; r int; c int;
begin
  if dot_rows is null or dot_columns is null or dot_rows not between 2 and 12 or dot_columns not between 2 and 12
     or not coalesce(e ~ '^[hv]:(0|[1-9][0-9]?):(0|[1-9][0-9]?)$', false) then return false; end if;
  k := split_part(e, ':', 1); r := split_part(e, ':', 2)::int; c := split_part(e, ':', 3)::int;
  return case when k = 'h' then r < dot_rows and c < dot_columns - 1
              else r < dot_rows - 1 and c < dot_columns end;
end $$;

create or replace function private.db_boxes(e text, dot_rows int, dot_columns int) returns int[]
language plpgsql immutable set search_path = '' as $$
declare k text; r int; c int; out int[] := '{}'; width int := dot_columns - 1;
begin
  if not private.db_edge_ok(e, dot_rows, dot_columns) then perform private.mv('invalid_move'); end if;
  k := split_part(e, ':', 1); r := split_part(e, ':', 2)::int; c := split_part(e, ':', 3)::int;
  if k = 'h' then
    if r > 0 then out := out || ((r - 1) * width + c); end if;
    if r < dot_rows - 1 then out := out || (r * width + c); end if;
  else
    if c > 0 then out := out || (r * width + c - 1); end if;
    if c < dot_columns - 1 then out := out || (r * width + c); end if;
  end if;
  return out;
end $$;

create or replace function private.db_count(edges jsonb, box int, dot_rows int, dot_columns int) returns int
language plpgsql immutable set search_path = '' as $$
begin
  if dot_rows is null or dot_columns is null or dot_rows not between 2 and 12 or dot_columns not between 2 and 12
     or box is null or box not between 0 and (dot_rows - 1) * (dot_columns - 1) - 1 then
    perform private.mv('invalid_move');
  end if;
  return (select count(*)::int from unnest(private.db_sides(box / (dot_columns - 1), box % (dot_columns - 1))) side
    where edges ? side);
end $$;

create or replace function private.db_setup12(s public.game_sessions) returns jsonb
language plpgsql volatile security definer set search_path = '' as $$
declare first int := private.first_seat(s);
begin
  return jsonb_build_object('mech', 'dots_boxes', 'dot_rows', 12, 'dot_columns', 12,
    'box_rows', 11, 'box_columns', 11, 'total_boxes', 121, 'total_edges', 264,
    'edges', '{}'::jsonb, 'owner', (select jsonb_agg(0) from generate_series(1, 121)),
    'tally', '{"1":0,"2":0}'::jsonb, 'first', first, 'turn', first, 'done', false,
    '_secret', '{"seats":{}}'::jsonb);
end $$;

create or replace function private.db_apply(c jsonb, sec jsonb, seat int, typ text, p jsonb) returns jsonb
language plpgsql immutable set search_path = '' as $$
declare
  dot_rows int := coalesce((c ->> 'dot_rows')::int, 5);
  dot_columns int := coalesce((c ->> 'dot_columns')::int, 5);
  me text := seat::text; e text; box int; gained int := 0;
begin
  if typ is distinct from 'draw_edge' then perform private.mv('invalid_move'); end if;
  perform private.need_turn(c, seat);
  e := p ->> 'edge_id';
  if not private.db_edge_ok(e, dot_rows, dot_columns) then perform private.mv('invalid_move'); end if;
  if jsonb_array_length(c -> 'owner') is distinct from (dot_rows - 1) * (dot_columns - 1) then perform private.mv('invalid_move'); end if;
  if c -> 'edges' ? e then perform private.mv('edge_taken'); end if;
  c := jsonb_set(c, array['edges', e], to_jsonb(seat));
  foreach box in array private.db_boxes(e, dot_rows, dot_columns) loop
    if (c #>> array['owner', box::text])::int = 0 and private.db_count(c -> 'edges', box, dot_rows, dot_columns) = 4 then
      c := jsonb_set(c, array['owner', box::text], to_jsonb(seat));
      gained := gained + 1;
    end if;
  end loop;
  c := jsonb_set(c, array['tally', me], to_jsonb((c #>> array['tally', me])::int + gained));
  if not exists (select 1 from jsonb_array_elements(c -> 'owner') x where x::int = 0) then
    c := c || jsonb_build_object('done', true, 'scores', c -> 'tally',
      'winner', case when (c #>> '{tally,1}')::int > (c #>> '{tally,2}')::int then 1
                     when (c #>> '{tally,2}')::int > (c #>> '{tally,1}')::int then 2 else 0 end);
  elsif gained = 0 then
    c := jsonb_set(c, '{turn}', to_jsonb(3 - seat));
  end if;
  return private.res(c, sec, jsonb_build_object('gained', gained));
end $$;

create or replace function private.db_bot(c jsonb, seat int) returns jsonb
language plpgsql volatile set search_path = '' as $$
declare
  dot_rows int := coalesce((c ->> 'dot_rows')::int, 5);
  dot_columns int := coalesce((c ->> 'dot_columns')::int, 5);
  cand text[]; safe text[] := '{}'; e text; box int; ok boolean;
begin
  if coalesce((c ->> 'done')::boolean, false) or (c ->> 'turn')::int <> seat then return null; end if;
  select array_agg(t.eid order by t.eid) into cand from (
    select 'h:' || r || ':' || col eid from generate_series(0, dot_rows - 1) r, generate_series(0, dot_columns - 2) col
    union all select 'v:' || r || ':' || col from generate_series(0, dot_rows - 2) r, generate_series(0, dot_columns - 1) col) t
    where not (c -> 'edges' ? t.eid);
  if coalesce(cardinality(cand), 0) = 0 then return null; end if;
  foreach e in array cand loop
    ok := true;
    foreach box in array private.db_boxes(e, dot_rows, dot_columns) loop
      if private.db_count(c -> 'edges', box, dot_rows, dot_columns) = 3 then
        return jsonb_build_object('type', 'draw_edge', 'payload', jsonb_build_object('edge_id', e));
      end if;
      if private.db_count(c -> 'edges', box, dot_rows, dot_columns) = 2 then ok := false; end if;
    end loop;
    if ok then safe := safe || e; end if;
  end loop;
  if cardinality(safe) > 0 then cand := safe; end if;
  return jsonb_build_object('type', 'draw_edge', 'payload',
    jsonb_build_object('edge_id', cand[1 + private.rnd(cardinality(cand))]));
end $$;

-- Un seul cas ajouté aux aiguillages : les familles et fonctions historiques
-- (y compris G08 simultané, le dé à30 et la validation navale008) restent intacts.
create or replace function private.board_setup_any(s public.game_sessions, cfg jsonb) returns jsonb
language plpgsql volatile security definer set search_path = '' as $$
begin
  if cfg ->> 'mechanic' = 'dots_boxes' and cfg #>> '{parameters,dot_rows}' = '12'
     and cfg #>> '{parameters,dot_columns}' = '12' then return private.db_setup12(s); end if;
  if cfg ->> 'mechanic' = any(private.board_route8()) then return private.board_setup8(s, cfg); end if;
  if cfg ->> 'mechanic' = any(private.board_route7()) then return private.board_setup7(s, cfg); end if;
  if cfg ->> 'mechanic' = any(private.board_route6()) then return private.board_setup6(s, cfg); end if;
  if cfg ->> 'mechanic' = any(private.board_route5()) then return private.board_setup5(s, cfg); end if;
  if cfg ->> 'mechanic' = any(private.board_route4()) then return private.board_setup4(s, cfg); end if;
  if cfg ->> 'mechanic' = any(private.board_route3()) then return private.board_setup3(s, cfg); end if;
  return private.board_setup(s, cfg);
end $$;

create or replace function private.board_apply_any(m text, c jsonb, sec jsonb, seat int, typ text, p jsonb, p_session uuid) returns jsonb
language plpgsql volatile security definer set search_path = '' as $$
begin
  if m = 'dots_boxes' and c ->> 'dot_rows' = '12' and c ->> 'dot_columns' = '12' then
    return private.db_apply(c, sec, seat, typ, p);
  end if;
  if m = any(private.board_route8()) then return private.board_apply8(m, c, sec, seat, typ, p, p_session); end if;
  if m = any(private.board_route7()) then return private.board_apply7(m, c, sec, seat, typ, p, p_session); end if;
  if m = any(private.board_route6()) then return private.board_apply6(m, c, sec, seat, typ, p, p_session); end if;
  if m = any(private.board_route5()) then return private.board_apply5(m, c, sec, seat, typ, p, p_session); end if;
  if m = any(private.board_route3()) or m = any(private.board_route4()) then
    if typ = 'giveup' then return private.res(c || '{"done": true, "gave_up": true}', sec); end if;
    if m = any(private.board_route4()) then return private.board_apply4(m, c, sec, seat, typ, p, p_session); end if;
    return private.board_apply3(m, c, sec, seat, typ, p, p_session);
  end if;
  return private.board_apply(m, c, sec, seat, typ, p, p_session);
end $$;

create or replace function private.board_bot_any(m text, c jsonb, sec jsonb, seat int) returns jsonb
language plpgsql volatile security definer set search_path = '' as $$
begin
  if m = 'dots_boxes' and c ->> 'dot_rows' = '12' and c ->> 'dot_columns' = '12' then return private.db_bot(c, seat); end if;
  if m = any(private.board_route8()) then return private.board_bot8(m, c, sec, seat); end if;
  if m = any(private.board_route7()) then return private.board_bot7(m, c, sec, seat); end if;
  if m = any(private.board_route6()) then return private.board_bot6(m, c, sec, seat); end if;
  if m = any(private.board_route5()) then return private.board_bot5(m, c, sec, seat); end if;
  if m = any(private.board_route4()) then return private.board_bot4(m, c, sec, seat); end if;
  if m = any(private.board_route3()) then return private.board_bot3(m, c, sec, seat); end if;
  return private.board_bot(m, c, sec, seat);
end $$;

-- Une chaîne de plus de40 captures est possible sur121cases. Le plafond du robot
-- de test augmente uniquement pour une card12×12 ; les autres jeux restent à40.
create or replace function private.autoplay(p_session uuid) returns void
language plpgsql security definer set search_path = '' as $$
declare
  me uuid := auth.uid(); bot record; old_claims text; old_sub text; guard int; budget int := 40;
begin
  if me is null or exists (select 1 from private.test_autoplayers where user_id = me) then return; end if;
  if exists (select 1 from public.session_rounds r join public.game_sessions s on s.id = r.session_id and s.current_round = r.round_no
             where s.id = p_session and r.card ->> 'mech' = 'dots_boxes'
               and r.card ->> 'dot_rows' = '12' and r.card ->> 'dot_columns' = '12') then budget := 264; end if;
  for bot in select sp.user_id, sp.seat from public.session_players sp
             join private.test_autoplayers t on t.user_id = sp.user_id where sp.session_id = p_session loop
    old_claims := current_setting('request.jwt.claims', true);
    old_sub := current_setting('request.jwt.claim.sub', true);
    begin
      perform set_config('request.jwt.claims', jsonb_build_object('sub', bot.user_id, 'role', 'authenticated')::text, true);
      perform set_config('request.jwt.claim.sub', bot.user_id::text, true);
      guard := 0;
      while guard < budget and private.bot_step(p_session, bot.seat) loop guard := guard + 1; end loop;
    exception when others then
      null; -- comportement historique : le robot ne bloque jamais le coup humain
    end;
    perform set_config('request.jwt.claims', coalesce(old_claims, ''), true);
    perform set_config('request.jwt.claim.sub', coalesce(old_sub, ''), true);
  end loop;
end $$;

revoke all on function private.db_edge_ok(text,int,int), private.db_boxes(text,int,int),
  private.db_count(jsonb,int,int,int), private.db_setup12(public.game_sessions),
  private.db_apply(jsonb,jsonb,int,text,jsonb), private.db_bot(jsonb,int) from public, anon, authenticated;

-- Version PRÉPARÉE, non publiée et non courante. Pas d'UPDATE de games.
with current_v as (
  select v.* from public.games g join public.game_versions v on v.game_id = g.id and v.version = g.current_version
  where g.id = 'N2-079'
)
insert into public.game_versions(game_id, version, rules, config, published_at)
select v.game_id, (select max(version) + 1 from public.game_versions where game_id = v.game_id),
  v.rules || jsonb_build_object(
    'how_to', jsonb_build_array(
      'Une grille de 12 × 12 points forme 121 cases. Le premier joueur est tiré au sort par le serveur.',
      'À ton tour, trace un segment horizontal ou vertical entre deux points voisins ; aucun segment diagonal ou déjà tracé.',
      'Fermer le quatrième côté d''une case te donne 1 point. Un segment qui ferme deux cases te donne 2 points.',
      'Tu rejoues après chaque fermeture ; sans case fermée, la main passe.',
      'Quand les 121 cases sont fermées, le plus grand nombre de cases gagne. Le total de 121 étant impair, une partie complète n''a pas d''égalité.'),
    'details', (select jsonb_agg(x order by ord) from jsonb_array_elements(v.rules -> 'details') with ordinality d(x,ord)
      where x #>> '{}' not like 'Score : %' and x #>> '{}' not like 'Adaptation Noodeu : Taille mobile%') || jsonb_build_array(
      'Score : 1 point par case, 2 pour une double fermeture ; total de 121 points.',
      'Adaptation Noodeu : 12 × 12 points, 11 × 11 cases et 264 segments.')),
  v.config || jsonb_build_object('version', 'noodeu-m04-2.0.0', 'frontend_contract', 'dots12-v1',
    'parameters', (v.config -> 'parameters') || '{"dot_rows":12,"dot_columns":12,"boxes":121,"edges":264}'::jsonb),
  null
from current_v v where not exists (
  select 1 from public.game_versions where game_id = v.game_id and config ->> 'version' = 'noodeu-m04-2.0.0');
