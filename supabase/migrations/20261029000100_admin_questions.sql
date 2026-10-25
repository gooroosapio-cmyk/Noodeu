-- Administration des questions (demande du propriétaire, 25/10/2026) : lister, modifier, ajouter, supprimer,
-- marquer +18. Réservé aux comptes de public.app_admins, vérifié côté serveur à chaque appel.
-- Les cartes déjà tirées sont copiées dans les parties : une modification vaut pour les prochains tirages.
-- Les questionnaires notés (tests) gardent leurs items : texte et +18 modifiables, ni ajout ni suppression.

create table if not exists private.question_trash (
  id bigserial primary key,
  bank text not null,
  idx int not null,
  value jsonb not null,
  deleted_by uuid,
  deleted_at timestamptz not null default now()
);
create table if not exists private.question_log (
  id bigserial primary key,
  at timestamptz not null default now(),
  by_user uuid,
  action text not null check (action in ('update', 'add', 'delete', 'adult')),
  bank text not null,
  item_id text not null,
  before jsonb,
  after jsonb
);
revoke all on private.question_trash, private.question_log from public, anon, authenticated;

create or replace function public.is_app_admin() returns boolean
language sql stable security definer set search_path = '' as $$ select private.is_admin() $$;
revoke execute on function public.is_app_admin() from public, anon;
grant execute on function public.is_app_admin() to authenticated;

-- Banque → activité (catégorie affichée, type, mécanique). Les questionnaires aléatoires n'ont pas de banque propre.
create or replace function private.admin_bank_map()
returns table (bank text, game_id text, activity text, category text, kind text, mechanic text, status text, sort_cat int, sort_game int)
language sql stable security definer set search_path = '' as $$
  select distinct on (b.bank) b.bank, g.id, g.title,
    case when g.content_level = 'intime' then 'À huis clos' else coalesce(c.title, 'Sans catégorie') end,
    case g.mechanic when 'test_form' then 'test' when 'pack_conversation' then 'pack' else 'game' end,
    g.mechanic, g.status,
    case when g.content_level = 'intime' then 2 when c.id in ('nd-se-decouvrir', 'nd-mieux-se-comprendre') then 1
         when c.id = 'nd-conversation-decouverte' then 3 else 4 end,
    coalesce(g.sort, 0)
  from public.games g
  join public.game_versions v on v.game_id = g.id and v.version = g.current_version
  left join public.game_categories c on c.id = g.category_id
  cross join lateral (select coalesce(v.config ->> 'bank', v.config #>> '{test,bank}',
    case when g.mechanic = 'nd_two_truths' then 'conv_two_truths_ideas' end) as bank) b
  where b.bank is not null and b.bank not in ('hangman_words', 'petit_bac', 'petit_bac_huit')
  order by b.bank, (g.status = 'published') desc, g.id
$$;

create or replace function private.admin_guard() returns void
language plpgsql stable security definer set search_path = '' as $$
begin
  if auth.uid() is null or not private.is_admin() then raise exception 'forbidden'; end if;
end $$;

create or replace function public.admin_list_questions() returns jsonb
language plpgsql stable security definer set search_path = '' as $$
begin
  perform private.admin_guard();
  return jsonb_build_object('ok', true, 'questions', coalesce((
    select jsonb_agg(jsonb_strip_nulls(jsonb_build_object(
      'bank', cb.bank, 'idx', cb.idx, 'id', cb.value ->> 'id',
      'text', coalesce(cb.value ->> 'text_fr', cb.value ->> 'text'),
      'options', case when cb.value ? 'options' then cb.value -> 'options' end,
      'kind', case when m.mechanic = 'nd_truth_dare' then cb.value ->> 'kind' end,
      'theme', cb.value ->> 'theme',
      'adult', coalesce((cb.value ->> 'adult')::boolean, false),
      'category', m.category, 'activity', m.activity, 'type', m.kind, 'mechanic', m.mechanic,
      'archived', m.status <> 'published', 'admin', cb.value ->> 'source' = 'Ajout administrateur'))
      order by m.sort_cat, m.kind, m.sort_game, m.activity, cb.idx)
    from public.content_banks cb join private.admin_bank_map() m on m.bank = cb.bank), '[]'::jsonb));
end $$;

-- Options d'un « Tu préfères » : deux textes non vides, identifiants stables.
create or replace function private.admin_dilemma_options(p_id text, p_old jsonb, p_new jsonb) returns jsonb
language plpgsql immutable set search_path = '' as $$
declare a text := btrim(p_new ->> 0); b text := btrim(p_new ->> 1);
begin
  if jsonb_typeof(p_new) <> 'array' or jsonb_array_length(p_new) <> 2 or coalesce(a, '') = '' or coalesce(b, '') = ''
     or length(a) > 200 or length(b) > 200 then raise exception 'invalid_options'; end if;
  return jsonb_build_array(
    jsonb_build_object('id', coalesce(p_old -> 0 ->> 'id', p_id || '-A'), 'text', a),
    jsonb_build_object('id', coalesce(p_old -> 1 ->> 'id', p_id || '-B'), 'text', b));
end $$;

create or replace function private.admin_clean_text(p text) returns text
language plpgsql immutable set search_path = '' as $$
declare x text := btrim(regexp_replace(coalesce(p, ''), '\s+', ' ', 'g'));
begin
  if x = '' or length(x) > 600 then raise exception 'invalid_text'; end if;
  return x;
end $$;

create or replace function public.admin_update_question(p_bank text, p_id text, p_text text, p_options jsonb default null,
  p_kind text default null, p_adult boolean default null) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  m record;
  rw public.content_banks;
  v jsonb;
  txt text;
begin
  perform private.admin_guard();
  select * into m from private.admin_bank_map() where bank = p_bank;
  if m.bank is null then return jsonb_build_object('ok', false, 'error', 'not_found'); end if;
  select * into rw from public.content_banks where bank = p_bank and value ->> 'id' = p_id for update;
  if rw.bank is null then return jsonb_build_object('ok', false, 'error', 'not_found'); end if;
  txt := private.admin_clean_text(p_text);
  v := rw.value;
  v := case when v ? 'text_fr' then jsonb_set(v, '{text_fr}', to_jsonb(txt)) else jsonb_set(v, '{text}', to_jsonb(txt), true) end;
  if m.mechanic = 'nd_sentence' then
    v := jsonb_set(v, '{prefix}', to_jsonb(btrim(regexp_replace(txt, '\s*(…|\.\.\.)\s*$', ''))));
  end if;
  if m.mechanic = 'nd_dilemma' and p_options is not null then
    v := jsonb_set(v, '{options}', private.admin_dilemma_options(p_id, v -> 'options', p_options));
  end if;
  if m.mechanic = 'nd_truth_dare' and p_kind is not null then
    if p_kind not in ('truth', 'dare') then return jsonb_build_object('ok', false, 'error', 'invalid_kind'); end if;
    v := jsonb_set(v, '{kind}', to_jsonb(p_kind));
  end if;
  if p_adult is not null then v := jsonb_set(v, '{adult}', to_jsonb(p_adult)); end if;
  update public.content_banks set value = v, updated_at = now() where bank = p_bank and idx = rw.idx;
  insert into private.question_log (by_user, action, bank, item_id, before, after) values (auth.uid(), 'update', p_bank, p_id, rw.value, v);
  return jsonb_build_object('ok', true);
exception when raise_exception then
  return jsonb_build_object('ok', false, 'error', sqlerrm);
end $$;

create or replace function public.admin_set_question_adult(p_bank text, p_id text, p_adult boolean) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare rw public.content_banks;
begin
  perform private.admin_guard();
  if not exists (select 1 from private.admin_bank_map() where bank = p_bank) then return jsonb_build_object('ok', false, 'error', 'not_found'); end if;
  select * into rw from public.content_banks where bank = p_bank and value ->> 'id' = p_id for update;
  if rw.bank is null then return jsonb_build_object('ok', false, 'error', 'not_found'); end if;
  update public.content_banks set value = jsonb_set(value, '{adult}', to_jsonb(coalesce(p_adult, false))), updated_at = now()
    where bank = p_bank and idx = rw.idx;
  insert into private.question_log (by_user, action, bank, item_id, before, after)
    values (auth.uid(), 'adult', p_bank, p_id, jsonb_build_object('adult', rw.value -> 'adult'), jsonb_build_object('adult', p_adult));
  return jsonb_build_object('ok', true);
end $$;

create or replace function public.admin_add_question(p_bank text, p_text text, p_adult boolean default false,
  p_options jsonb default null, p_kind text default null, p_theme text default null) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  m record;
  tpl jsonb;
  nid text;
  nidx int;
  txt text;
  v jsonb;
begin
  perform private.admin_guard();
  select * into m from private.admin_bank_map() where bank = p_bank;
  if m.bank is null then return jsonb_build_object('ok', false, 'error', 'not_found'); end if;
  if m.kind = 'test' then return jsonb_build_object('ok', false, 'error', 'locked_test'); end if;
  perform pg_advisory_xact_lock(hashtext('admin_bank:' || p_bank));
  txt := private.admin_clean_text(p_text);
  select value into tpl from public.content_banks where bank = p_bank order by idx limit 1;
  select coalesce(max(idx), -1) + 1 into nidx from public.content_banks where bank = p_bank;
  nid := 'ADM-' || upper(substr(md5(random()::text || clock_timestamp()::text), 1, 10));
  if m.kind = 'pack' then
    v := jsonb_build_object('id', nid, 'kind', 'question', 'adult', coalesce(p_adult, false), 'text_fr', txt,
      'source', 'Ajout administrateur', 'source_position', nidx + 1,
      'theme', coalesce(nullif(btrim(p_theme), ''), tpl ->> 'theme'));
    -- Vrai / Faux : même échelle que le reste du pack ; sinon réponse libre.
    if tpl ->> 'response_type' = 'true_false' then
      v := v || jsonb_build_object('kind', tpl ->> 'kind', 'response_type', 'true_false', 'scale_id', tpl ->> 'scale_id',
        'options_ordered', tpl -> 'options_ordered');
    else
      v := v || jsonb_build_object('response_type', 'open');
    end if;
  else
    v := jsonb_build_object('id', nid, 'text', txt, 'adult', coalesce(p_adult, false), 'source', 'Ajout administrateur');
    if m.mechanic in ('nd_never', 'nd_opinion') then v := v || jsonb_build_object('options', tpl -> 'options'); end if;
    if m.mechanic = 'nd_dilemma' then
      v := v || jsonb_build_object('prompt', coalesce(tpl ->> 'prompt', 'Tu préfères…'),
        'options', private.admin_dilemma_options(nid, null, p_options));
    end if;
    if m.mechanic = 'nd_truth_dare' then
      if coalesce(p_kind, '') not in ('truth', 'dare') then return jsonb_build_object('ok', false, 'error', 'invalid_kind'); end if;
      v := v || jsonb_build_object('kind', p_kind);
    end if;
    if m.mechanic = 'nd_sentence' then
      v := v || jsonb_build_object('prefix', btrim(regexp_replace(txt, '\s*(…|\.\.\.)\s*$', '')));
    end if;
  end if;
  insert into public.content_banks (bank, idx, value, content_version) values (p_bank, nidx, jsonb_strip_nulls(v), 'admin');
  insert into private.question_log (by_user, action, bank, item_id, after) values (auth.uid(), 'add', p_bank, nid, v);
  return jsonb_build_object('ok', true, 'id', nid, 'idx', nidx);
exception when raise_exception then
  return jsonb_build_object('ok', false, 'error', sqlerrm);
end $$;

create or replace function public.admin_delete_question(p_bank text, p_id text) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  m record;
  rw public.content_banks;
begin
  perform private.admin_guard();
  select * into m from private.admin_bank_map() where bank = p_bank;
  if m.bank is null then return jsonb_build_object('ok', false, 'error', 'not_found'); end if;
  if m.kind = 'test' then return jsonb_build_object('ok', false, 'error', 'locked_test'); end if;
  select * into rw from public.content_banks where bank = p_bank and value ->> 'id' = p_id for update;
  if rw.bank is null then return jsonb_build_object('ok', false, 'error', 'not_found'); end if;
  if (select count(*) from public.content_banks where bank = p_bank) <= 1 then
    return jsonb_build_object('ok', false, 'error', 'last_question');
  end if;
  -- Conservée dans la corbeille (restaurable par l'équipe), puis retirée des tirages.
  insert into private.question_trash (bank, idx, value, deleted_by) values (rw.bank, rw.idx, rw.value, auth.uid());
  delete from public.content_banks where bank = p_bank and idx = rw.idx;
  insert into private.question_log (by_user, action, bank, item_id, before) values (auth.uid(), 'delete', p_bank, p_id, rw.value);
  return jsonb_build_object('ok', true);
end $$;

revoke execute on function public.admin_list_questions(), public.admin_update_question(text, text, text, jsonb, text, boolean),
  public.admin_set_question_adult(text, text, boolean), public.admin_add_question(text, text, boolean, jsonb, text, text),
  public.admin_delete_question(text, text) from public, anon;
grant execute on function public.admin_list_questions(), public.admin_update_question(text, text, text, jsonb, text, boolean),
  public.admin_set_question_adult(text, text, boolean), public.admin_add_question(text, text, boolean, jsonb, text, text),
  public.admin_delete_question(text, text) to authenticated;
revoke execute on function private.admin_bank_map(), private.admin_guard(), private.admin_dilemma_options(text, jsonb, jsonb),
  private.admin_clean_text(text) from public, anon, authenticated;

create or replace function private.board_setup5(s public.game_sessions, cfg jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
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
      -- Une question supprimée par l'administration après le tirage est sautée.
      loop
        exit when ci >= jsonb_array_length(queue);
        select value into it from public.content_banks where bank = queue -> ci ->> 0 and content_banks.idx = (queue -> ci ->> 1)::int;
        exit when it is not null;
        ci := ci + 1;
      end loop;
      if it is null then raise exception 'bank_missing'; end if;
      return jsonb_build_object('mech', m, 'index', ci, 'count', jsonb_array_length(queue), 'queue', queue, 'random', true,
        'set_no', null, 'set_size', null, 'first', 1 + ci % 2, 'response', 'open', 'scales', '{}'::jsonb,
        'item', jsonb_build_object('id', it ->> 'id', 'text', it ->> 'text_fr', 'kind', it ->> 'kind', 'bank', queue -> ci ->> 0,
                                   'response', it ->> 'response_type', 'position', it -> 'source_position',
                                   'options', it -> 'options_ordered', 'adult', coalesce((it ->> 'adult')::boolean, false)),
        'status', '{}'::jsonb, 'answers', null, 'done', false,
        '_secret', jsonb_build_object('seats', '{}'::jsonb));
    end if;
    -- Taille réelle du pack (questions ajoutées ou supprimées par l'administration comprises).
    n := coalesce((select max(cb.idx) + 1 from public.content_banks cb where cb.bank = cfg ->> 'bank'), 0);
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
end $function$;
