-- Deux vérités et un mensonge, version 2 (demande du propriétaire, 25/10/2026) : écriture simultanée de trois
-- affirmations et d'un mensonge, « OK, je suis prêt », puis chacun devine le mensonge de l'autre en même temps.
-- 1 point par mensonge trouvé ; score affiché X/N tours. Tours 4, 6 ou 10, 6 par défaut.
-- Les séances déjà commencées gardent la version 1 (tours alternés) : la règle suit la version de la séance.

CREATE OR REPLACE FUNCTION private.board_setup7(s game_sessions, cfg jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  m text := cfg ->> 'mechanic';
  first int := private.first_seat(s);
  item jsonb;
  base jsonb;
begin
  base := jsonb_build_object('mech', m, 'first', first, 'locked', '{}'::jsonb, 'continue', '{}'::jsonb, 'done', false,
                             '_secret', '{"seats": {}}'::jsonb);
  if m = 'nd_truth_dare' then
    return base || jsonb_build_object('active', first, 'phase', 'choice');
  elsif m = 'nd_two_truths' and cfg ->> 'mode' = 'simultaneous' then
    -- Version 2 : les deux écrivent en même temps, puis chacun devine le mensonge de l'autre.
    return base || jsonb_build_object('mode', 'simultaneous', 'phase', 'write', 'ready', '{}'::jsonb, 'guessed', '{}'::jsonb);
  elsif m = 'nd_two_truths' then
    return base || jsonb_build_object('author', first, 'guesser', 3 - first, 'phase', 'write');
  end if;
  item := private.conv_draw(s.id, cfg ->> 'bank');
  if item is null then raise exception 'not_enough_cards'; end if;
  base := base || private.conv_card(item);
  if m = 'nd_predict' then
    base := base || jsonb_build_object('subject', first, 'predictor', 3 - first);
  end if;
  return base;
end $function$;

CREATE OR REPLACE FUNCTION private.board_apply7(m text, c jsonb, sec jsonb, seat integer, typ text, p jsonb, p_session uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  me text := seat::text;
  oth int := 3 - seat;
  cfg jsonb;
  item jsonb;
  t text;
  st jsonb;
  ids text[];
  lie text;
  guess text;
begin
  select private.version_config(g) into cfg from public.game_sessions g where g.id = p_session;

  -- Passer : la manche se clôt sans pénalité et sans révéler aucune réponse scellée.
  if typ = 'skip_round' then
    return private.res(c || jsonb_build_object('done', true, 'skipped', true, 'skipped_by', seat, 'locked', '{}'::jsonb),
                       '{"seats": {}}'::jsonb);
  end if;

  if m = 'nd_truth_dare' then
    if (c ->> 'active')::int <> seat then perform private.mv('not_your_turn'); end if;
    if typ = 'choose_kind' then
      if c ->> 'phase' <> 'choice' then perform private.mv('phase'); end if;
      if coalesce(p ->> 'kind', '') not in ('truth', 'dare') then perform private.mv('invalid_move'); end if;
      item := private.conv_draw(p_session, cfg ->> 'bank', p ->> 'kind');
      if item is null then perform private.mv('no_cards'); end if;
      return private.res(c || private.conv_card(item) || jsonb_build_object('phase', 'respond'), sec);
    elsif typ = 'replace_card' then
      if c ->> 'phase' <> 'respond' then perform private.mv('phase'); end if;
      item := private.conv_draw(p_session, cfg ->> 'bank', c ->> 'kind', array[c ->> 'card_id']);
      if item is null then perform private.mv('no_cards'); end if;
      c := c || jsonb_build_object('seen', coalesce(c -> 'seen', '[]') || to_jsonb(c ->> 'card_id'));
      return private.res(c - 'prompt' || private.conv_card(item), sec);
    elsif typ = 'submit_text' then
      if c ->> 'phase' <> 'respond' or c ->> 'kind' <> 'truth' then perform private.mv('phase'); end if;
      t := btrim(coalesce(p ->> 'text', ''));
      if t = '' or char_length(t) > 1000 then perform private.mv('invalid_text'); end if;
      return private.res(c || jsonb_build_object('done', true, 'phase', 'reveal', 'response', jsonb_build_object('text', t)), sec);
    elsif typ = 'submit_action' then
      if c ->> 'phase' <> 'respond' or c ->> 'kind' <> 'dare' then perform private.mv('phase'); end if;
      t := nullif(btrim(coalesce(p ->> 'text', '')), '');
      if t is not null and char_length(t) > 1000 then perform private.mv('invalid_text'); end if;
      -- Action marquée faite, sans preuve ; un texte n'est partagé que si la personne le choisit.
      return private.res(c || jsonb_build_object('done', true, 'phase', 'reveal',
        'response', jsonb_strip_nulls(jsonb_build_object('status', 'done', 'text', t))), sec);
    end if;
    perform private.mv('invalid_move');

  elsif m = 'nd_two_truths' and c ->> 'mode' = 'simultaneous' then
    -- Écriture simultanée : trois affirmations et un mensonge par personne, scellés côté serveur. Rien n'est
    -- transmis à l'autre avant que les deux soient prêts ; les devinettes restent scellées jusqu'à la seconde.
    if typ = 'publish_three' then
      if c ->> 'phase' <> 'write' then perform private.mv('phase'); end if;
      if c -> 'ready' ? me then perform private.mv('locked'); end if;
      if coalesce((p ->> 'confirmed_truths')::boolean, false) is not true then perform private.mv('invalid_move'); end if;
      if jsonb_typeof(p -> 'statements') <> 'array' or jsonb_array_length(p -> 'statements') <> 3 then perform private.mv('invalid_move'); end if;
      select array_agg(x ->> 'id' order by x ->> 'id') into ids from jsonb_array_elements(p -> 'statements') x;
      if ids is distinct from array['s1', 's2', 's3'] then perform private.mv('invalid_move'); end if;
      if exists (select 1 from jsonb_array_elements(p -> 'statements') x
                 where btrim(coalesce(x ->> 'text', '')) = '' or char_length(btrim(x ->> 'text')) > 240) then
        perform private.mv('invalid_text');
      end if;
      if (select count(distinct lower(btrim(x ->> 'text'))) from jsonb_array_elements(p -> 'statements') x) <> 3 then
        perform private.mv('duplicate_text');
      end if;
      lie := p ->> 'lie_statement_id';
      if lie is null or lie not in ('s1', 's2', 's3') then perform private.mv('invalid_move'); end if;
      sec := jsonb_set(sec, '{seats}', coalesce(sec -> 'seats', '{}') || jsonb_build_object(me, jsonb_build_object('lie', lie,
        'statements', (select jsonb_agg(jsonb_build_object('id', x ->> 'id', 'text', btrim(x ->> 'text')) order by x ->> 'id')
                       from jsonb_array_elements(p -> 'statements') x))));
      c := jsonb_set(c, array['ready', me], 'true');
      if c -> 'ready' ? oth::text then
        -- Les deux sont prêts : chacun reçoit les trois textes de l'autre, jamais l'indice du mensonge.
        c := c || jsonb_build_object('phase', 'guess', 'statements', jsonb_build_object(
          '1', sec #> '{seats,1,statements}', '2', sec #> '{seats,2,statements}'));
      end if;
      return private.res(c, sec);
    elsif typ = 'unready' then
      -- Reprendre ses affirmations tant que l'autre n'est pas prêt (rien n'a été montré).
      if c ->> 'phase' <> 'write' or not (c -> 'ready' ? me) then perform private.mv('phase'); end if;
      sec := jsonb_set(sec, '{seats}', coalesce(sec -> 'seats', '{}') - me);
      return private.res(jsonb_set(c, '{ready}', (c -> 'ready') - me), sec);
    elsif typ = 'lock_guess' then
      if c ->> 'phase' <> 'guess' then perform private.mv('phase'); end if;
      if c -> 'guessed' ? me then perform private.mv('locked'); end if;
      guess := p ->> 'statement_id';
      if guess is null or guess not in ('s1', 's2', 's3') then perform private.mv('invalid_move'); end if;
      sec := jsonb_set(sec, array['seats', me, 'guess'], to_jsonb(guess));
      c := jsonb_set(c, array['guessed', me], 'true');
      if c -> 'guessed' ? oth::text then
        c := c || jsonb_build_object('done', true, 'phase', 'reveal',
          'lies', jsonb_build_object('1', sec #>> '{seats,1,lie}', '2', sec #>> '{seats,2,lie}'),
          'guesses', jsonb_build_object('1', sec #>> '{seats,1,guess}', '2', sec #>> '{seats,2,guess}'),
          'found', jsonb_build_object('1', sec #>> '{seats,1,guess}' = sec #>> '{seats,2,lie}',
                                      '2', sec #>> '{seats,2,guess}' = sec #>> '{seats,1,lie}'),
          'scores', jsonb_build_object('1', case when sec #>> '{seats,1,guess}' = sec #>> '{seats,2,lie}' then 1 else 0 end,
                                       '2', case when sec #>> '{seats,2,guess}' = sec #>> '{seats,1,lie}' then 1 else 0 end));
      end if;
      return private.res(c, sec);
    end if;
    perform private.mv('invalid_move');

  elsif m = 'nd_two_truths' then
    if typ = 'publish_three' then
      if c ->> 'phase' <> 'write' then perform private.mv('phase'); end if;
      if (c ->> 'author')::int <> seat then perform private.mv('not_your_turn'); end if;
      if coalesce((p ->> 'confirmed_truths')::boolean, false) is not true then perform private.mv('invalid_move'); end if;
      if jsonb_typeof(p -> 'statements') <> 'array' or jsonb_array_length(p -> 'statements') <> 3 then perform private.mv('invalid_move'); end if;
      select array_agg(x ->> 'id' order by x ->> 'id') into ids from jsonb_array_elements(p -> 'statements') x;
      if ids is distinct from array['s1', 's2', 's3'] then perform private.mv('invalid_move'); end if;
      if exists (select 1 from jsonb_array_elements(p -> 'statements') x
                 where btrim(coalesce(x ->> 'text', '')) = '' or char_length(btrim(x ->> 'text')) > 240) then
        perform private.mv('invalid_text');
      end if;
      if (select count(distinct lower(btrim(x ->> 'text'))) from jsonb_array_elements(p -> 'statements') x) <> 3 then
        perform private.mv('duplicate_text');
      end if;
      lie := p ->> 'lie_statement_id';
      if lie is null or lie not in ('s1', 's2', 's3') then perform private.mv('invalid_move'); end if;
      sec := jsonb_set(sec, '{seats}', coalesce(sec -> 'seats', '{}') || jsonb_build_object(me, jsonb_build_object('lie', lie)));
      return private.res(c || jsonb_build_object('phase', 'guess', 'statements',
        (select jsonb_agg(jsonb_build_object('id', x ->> 'id', 'text', btrim(x ->> 'text')) order by x ->> 'id')
         from jsonb_array_elements(p -> 'statements') x)), sec);
    elsif typ = 'lock_guess' then
      if c ->> 'phase' <> 'guess' then perform private.mv('phase'); end if;
      if (c ->> 'guesser')::int <> seat then perform private.mv('not_your_turn'); end if;
      guess := p ->> 'statement_id';
      if guess is null or guess not in ('s1', 's2', 's3') then perform private.mv('invalid_move'); end if;
      lie := sec #>> array['seats', c ->> 'author', 'lie'];
      return private.res(c || jsonb_build_object('done', true, 'phase', 'reveal', 'guess', guess, 'lie', lie, 'found', guess = lie,
        'scores', jsonb_build_object(me, case when guess = lie then 1 else 0 end, c ->> 'author', case when guess = lie then 0 else 1 end)),
        sec);
    end if;
    perform private.mv('invalid_move');
  end if;

  -- Cartes simultanées : chacun scelle sa réponse ; la seconde révèle les deux dans la même transaction.
  if typ <> 'lock' then perform private.mv('invalid_move'); end if;
  if c -> 'locked' ? me then perform private.mv('locked'); end if;
  st := private.conv_answer(m, c, p);
  sec := jsonb_set(sec, '{seats}', coalesce(sec -> 'seats', '{}') || jsonb_build_object(me, st));
  c := jsonb_set(c, array['locked', me], 'true');
  if c -> 'locked' ? oth::text then
    c := c || jsonb_build_object('done', true, 'answers', jsonb_build_object(me, st, oth::text, sec #> array['seats', oth::text]));
  end if;
  return private.res(c, sec);
end $function$;

CREATE OR REPLACE FUNCTION private.board_bot7(m text, c jsonb, sec jsonb, seat integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare me text := seat::text;
begin
  if coalesce((c ->> 'done')::boolean, false) then return null; end if;
  if m = 'nd_truth_dare' then
    if (c ->> 'active')::int <> seat then return null; end if;
    if c ->> 'phase' = 'choice' then return '{"type": "choose_kind", "payload": {"kind": "truth"}}'; end if;
    if c ->> 'kind' = 'truth' then return '{"type": "submit_text", "payload": {"text": "Réponse du partenaire automatique de test."}}'; end if;
    return '{"type": "submit_action", "payload": {"status": "done"}}';
  elsif m = 'nd_two_truths' and c ->> 'mode' = 'simultaneous' then
    if c ->> 'phase' = 'write' and not (c -> 'ready' ? me) then
      return jsonb_build_object('type', 'publish_three', 'payload', jsonb_build_object('confirmed_truths', true,
        'lie_statement_id', 's' || (1 + private.rnd(3)), 'statements', '[{"id": "s1", "text": "Affirmation de test numéro un."},
          {"id": "s2", "text": "Affirmation de test numéro deux."}, {"id": "s3", "text": "Affirmation de test numéro trois."}]'::jsonb));
    elsif c ->> 'phase' = 'guess' and not (c -> 'guessed' ? me) then
      return jsonb_build_object('type', 'lock_guess', 'payload', jsonb_build_object('statement_id', 's' || (1 + private.rnd(3))));
    end if;
    return null;
  elsif m = 'nd_two_truths' then
    if c ->> 'phase' = 'write' and (c ->> 'author')::int = seat then
      return jsonb_build_object('type', 'publish_three', 'payload', jsonb_build_object('confirmed_truths', true,
        'lie_statement_id', 's' || (1 + private.rnd(3)), 'statements', '[{"id": "s1", "text": "Affirmation de test numéro un."},
          {"id": "s2", "text": "Affirmation de test numéro deux."}, {"id": "s3", "text": "Affirmation de test numéro trois."}]'::jsonb));
    elsif c ->> 'phase' = 'guess' and (c ->> 'guesser')::int = seat then
      return jsonb_build_object('type', 'lock_guess', 'payload', jsonb_build_object('statement_id', 's' || (1 + private.rnd(3))));
    end if;
    return null;
  end if;
  if c -> 'locked' ? me then return null; end if;
  if m in ('nd_never', 'nd_opinion', 'nd_dilemma') then
    return jsonb_build_object('type', 'lock', 'payload', jsonb_build_object('choice', c -> 'options' -> private.rnd(2) ->> 'id'));
  elsif m = 'nd_duo_target' then
    return jsonb_build_object('type', 'lock', 'payload', jsonb_build_object('seat', 1 + private.rnd(2)));
  end if;
  return '{"type": "lock", "payload": {"text": "Réponse du partenaire automatique de test."}}';
end $function$;

-- Nouvelle version des règles, publiée et rendue courante.
with v as (select * from public.game_versions where game_id = 'nd-deux-verites-mensonge'
           and version = (select current_version from public.games where id = 'nd-deux-verites-mensonge'))
insert into public.game_versions (game_id, version, rules, config, published_at)
select 'nd-deux-verites-mensonge', v.version + 1,
  jsonb_build_object(
    'objective', 'Chacun écrit trois affirmations sur soi, dont un mensonge ; chacun devine ensuite le mensonge de l''autre.',
    'how_to', jsonb_build_array(
      'Vous écrivez en même temps, chacun de votre côté : trois affirmations (240 caractères au plus), dont une fausse que tu désignes en secret.',
      'Appuie sur « OK, je suis prêt » : tes affirmations sont scellées. Tant que l''autre écrit, tu peux les reprendre.',
      'Quand vous êtes prêts tous les deux, chacun voit les trois affirmations de l''autre et choisit celle qu''il croit fausse.',
      'Les deux choix se révèlent ensemble : 1 point par mensonge trouvé. Une manche passée ne compte pas.'),
    'details', jsonb_build_array(
      'Score : 1 point par mensonge trouvé, sur le nombre de tours (par exemple 4/6).',
      'Adaptation Noodeu : écriture simultanée pour éviter d''attendre pendant que l''autre écrit.',
      'Adaptation Noodeu : écriture personnelle obligatoire ; aucune biographie tirée du générateur.',
      'Référence de mécanique : Deux vérités et un mensonge — PsyCat Games (https://psycatgames.com/fr/app/2-truths-1-lie/).'),
    'privacy', 'Rien n''est montré à l''autre avant que vous soyez prêts tous les deux ; ton mensonge reste secret jusqu''à la révélation.',
    'step_texts', '{}'::jsonb),
  v.config || jsonb_build_object('mode', 'simultaneous', 'turn', 'simultaneous', 'version', 'noodeu-g08-2.0.0'),
  now()
from v where coalesce(v.config ->> 'mode', '') <> 'simultaneous';
update public.games set current_version = (select max(version) from public.game_versions where game_id = 'nd-deux-verites-mensonge'),
  updated_at = now() where id = 'nd-deux-verites-mensonge';
