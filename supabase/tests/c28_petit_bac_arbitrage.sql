-- PostgreSQL jetable uniquement. Tous les joueurs et coups sont annulés à la fin.
begin;
do $$ begin
  if current_database() not in ('noodeu_lot6_clean_2154', 'noodeu') and not (
    current_database() ~ '^noodeu_server_[a-zA-Z0-9_]+$' and coalesce((
      select shobj_description(oid, 'pg_database') from pg_database where datname = current_database()
    ), '') = 'noodeu:disposable-local-sql-test'
  ) then
    raise exception 'Test réservé aux bases Docker jetables explicitement autorisées';
  end if;
end $$;
create schema t28;
create function t28.ok(cond boolean, msg text) returns void language plpgsql as $$
begin if cond is distinct from true then raise exception 'ÉCHEC : %', msg; end if; end $$;
create function t28.as_user(p uuid) returns void language plpgsql as $$
begin perform set_config('request.jwt.claims', json_build_object('sub', p, 'role', 'authenticated')::text, true); end $$;
create function t28.uid(s uuid, seat int) returns uuid language sql as $$
  select user_id from public.session_players where session_id = s and seat = $2 $$;
create function t28.card(s uuid) returns jsonb language sql as $$
  select card from public.session_rounds r join public.game_sessions g on g.id = r.session_id and r.round_no = g.current_round where g.id = s $$;
create function t28.mv(s uuid, seat int, typ text, p jsonb default '{}', action uuid default gen_random_uuid()) returns jsonb language plpgsql as $$
begin
  perform t28.as_user(t28.uid(s, seat));
  return public.play_move(s, (select current_round from public.game_sessions where id = s), action, typ, p);
end $$;
create function t28.start() returns uuid language plpgsql as $$
declare s uuid;
begin
  perform t28.as_user('00000000-0000-4000-a000-000000000a28');
  s := (public.create_session('N2-018') ->> 'session_id')::uuid;
  perform public.set_ready(s, true);
  perform t28.as_user('00000000-0000-4000-a000-000000000b28');
  perform public.set_ready(s, true);
  return s;
end $$;

-- Les anciennes banques et leurs réponses conservent leur comportement exact.
do $$ declare e record; r jsonb; n int := 0;
begin
  perform t28.ok((select count(*) from public.content_banks where bank='petit_bac') = 134, '134 entrées historiques');
  perform t28.ok((select count(*) from public.content_banks where bank='petit_bac_huit') = 866, '866 entrées v1');
  perform t28.ok((select count(*) from public.content_banks where bank='petit_bac_huit_unicode') = 866, '866 entrées v2, aucun mot ajouté');
  perform t28.ok(not exists (
    select 1 from public.content_banks old full join public.content_banks new
      on new.bank='petit_bac_huit_unicode' and old.idx=new.idx
    where old.bank='petit_bac_huit' and old.value is distinct from new.value), 'copie identique de l''index existant');
  perform t28.ok(private.pb_letters('petit_bac_huit_unicode',8) = private.pb_letters('petit_bac_huit',8), '16 initiales conservées');
  perform t28.ok(private.pb_classify('petit_bac_huit','animal','E',U&'e\0301le\0301phant')->>'status'='unknown', 'normalisation v1 inchangée');
  perform t28.ok(private.pb_classify('petit_bac_huit','animal','C',E'\tchat\t')->>'status'='invalid', 'parties v1 inchangées');
  perform t28.ok((select config->>'bank' from public.game_versions where game_id='N2-018' and version=1)='petit_bac', 'version 1 conservée');
  perform t28.ok((select config->>'bank' from public.game_versions where game_id='N2-018' and version=2)='petit_bac_huit', 'version 2 conservée');
  for e in select value->>'cat' cat, value->>'acc' acc, a.alias
    from public.content_banks cb cross join lateral jsonb_array_elements_text(value->'aliases') a(alias)
    where bank='petit_bac_huit_unicode' loop
    r := private.pb_classify('petit_bac_huit_unicode',e.cat,left(e.alias,1),lower(e.alias));
    perform t28.ok(r->>'status'='valid' and r->>'acc'=e.acc and r->>'reason'='indexed_match', 'chaque alias réel reconnu dans sa rubrique');
    n := n+1;
  end loop;
  raise notice '% alias réels vérifiés',n;
  perform t28.ok(private.pb_classify('petit_bac_huit_unicode','animal','E',U&'e\0301le\0301phant')->>'status'='valid', 'accents décomposés reconnus');
  perform t28.ok(private.pb_classify('petit_bac_huit_unicode','animal','E',' ÉLÉPHANT ')->>'status'='valid', 'accent composé et casse');
  perform t28.ok(private.pb_classify('petit_bac_huit_unicode','animal','C',E'\tchat\n')->>'status'='valid', 'tabulations et retours périphériques');
  perform t28.ok(private.pb_classify('petit_bac_huit_unicode','animal','C',U&'\00a0chat\202f')->>'status'='valid', 'espaces insécables');
  perform t28.ok(private.pb_classify('petit_bac_huit_unicode','pays','C',U&'Côte\00a0d\2019Ivoire')->>'status'='valid', 'apostrophe courbe et espace insécable');
  perform t28.ok(private.pb_classify('petit_bac_huit_unicode','ville','L',E' Le\t\t Caire ')->>'status'='valid', 'espaces répétés et article conservé');
  perform t28.ok(private.pb_classify('petit_bac_huit_unicode','ville','C','Le Caire')->>'reason'='wrong_initial', 'article compte pour initiale');
  perform t28.ok(private.pb_norm_v2('ŒUF Æsop')='OEUF AESOP', 'ligatures');
  perform t28.ok(private.pb_classify('petit_bac_huit_unicode','animal','C',U&'\202f\00a0')->>'status'='empty', 'espaces seuls = vide');
  perform t28.ok(private.pb_classify('petit_bac_huit_unicode','animal','B','chat')->>'reason'='wrong_initial', 'mauvaise initiale explicite');
  perform t28.ok(private.pb_classify('petit_bac_huit_unicode','ville','C','chat')->>'status'='unknown', 'rubrique obligatoire, pas validation lexicale globale');
  perform t28.ok(private.pb_classify('petit_bac_huit_unicode','animal','C','chevaux')->>'status'='unknown', 'variante absente à arbitrer, pas de faux rejet');
  perform t28.ok(private.pb_classify('petit_bac_huit_unicode','ville','C','Cherbourg')->>'reason'='not_in_index', 'ville réelle absente reste à vérifier');
  perform t28.ok(private.pb_classify('petit_bac_huit_unicode','celebrite','C','Céline Dion')->>'acc' =
                 private.pb_classify('petit_bac_huit_unicode','celebrite','D','Dion')->>'acc', 'nom complet et alias partagent identité');
end $$;

insert into auth.users (id, email, raw_user_meta_data) values
  ('00000000-0000-4000-a000-000000000a28', 'joueur-a28@noodeu.invalid', '{"display_name":"A"}'),
  ('00000000-0000-4000-a000-000000000b28', 'joueur-b28@noodeu.invalid', '{"display_name":"B"}');
do $$ declare r jsonb;
begin
  perform t28.as_user('00000000-0000-4000-a000-000000000a28'); r:=public.create_invitation();
  perform t28.as_user('00000000-0000-4000-a000-000000000b28'); perform public.claim_invitation(r->>'code');
  perform t28.as_user('00000000-0000-4000-a000-000000000a28'); perform public.respond_to_claim((r->>'id')::uuid,true);
end $$;

-- Parcours réel : secrets, gel atomique, même identifiant rejoué et deuxième clic,
-- réponse absente, contestation d'une réponse reconnue, scores inchangés.
do $$
declare s uuid; c jsonb; before jsonb; r jsonb; action uuid:=gen_random_uuid(); cat text;
  drafts jsonb:='{}'; words jsonb:='{"animal":"chat","ville":"Copenhague","metier":"chauffeur","objet":"chaise","pays":"Chili","prenom":"Camille","fruit-legume":"carotte","celebrite":"Céline Dion"}';
begin
  s:=t28.start();
  perform t28.ok((select private.version_config(g)->>'bank' from public.game_sessions g where id=s)='petit_bac_huit_unicode', 'nouvelles parties v2');
  perform t28.ok(not (t28.card(s)?'letter'), 'lettre secrète au chargement');
  perform t28.mv(s,1,'round_loaded'); perform t28.mv(s,2,'round_loaded');
  update public.session_rounds set card=card||jsonb_build_object('letter','C','stop_after',now()-interval '1 second') where session_id=s;
  perform t28.mv(s,2,'save_field','{"category_id":"animal","text":"CHAT","draft_revision":1}');
  perform t28.mv(s,2,'save_field','{"category_id":"metier","text":"coiffeur","draft_revision":1}');
  perform t28.mv(s,2,'save_field','{"category_id":"ville","text":"Cherbourg","draft_revision":1}');
  perform t28.mv(s,2,'save_field','{"category_id":"objet","text":"Catamaran inconnu","draft_revision":1}');
  perform t28.as_user(t28.uid(s,1));
  perform t28.ok(position('Cherbourg' in public.get_session_state(s)::text)=0, 'brouillons adverses jamais transmis avant gel');
  for cat in select jsonb_object_keys(words) loop
    drafts:=drafts||jsonb_build_object(cat,jsonb_build_object('text',words->>cat,'draft_revision',1));
  end loop;
  r:=t28.mv(s,1,'stop',jsonb_build_object('drafts',drafts),action);
  perform t28.ok((r->>'ok')::boolean and t28.card(s)->>'phase'='validation', 'gel de seize réponses');
  before:=t28.card(s);
  r:=t28.mv(s,1,'stop',jsonb_build_object('drafts',drafts),action);
  perform t28.ok((r->>'repeated')::boolean and t28.card(s)=before, 'réessai même action sans second effet');
  perform t28.ok(t28.mv(s,1,'stop',jsonb_build_object('drafts',drafts))->>'error'='phase' and t28.card(s)=before, 'double clic nouvel identifiant sans second gel');
  perform t28.ok(before#>>'{answers,2,ville,status}'='unknown' and before#>>'{answers,2,ville,reason}'='not_in_index', 'absence expliquée');
  -- Inconnu accepté par les deux et identifié comme différent : 10 chacun.
  perform t28.mv(s,1,'judge_entry','{"seat":2,"category_id":"objet","verdict":"accept"}');
  perform t28.mv(s,2,'judge_entry','{"seat":2,"category_id":"objet","verdict":"accept"}');
  perform t28.mv(s,1,'judge_identity','{"category_id":"objet","same":false}');
  perform t28.mv(s,2,'judge_identity','{"category_id":"objet","same":false}');
  -- Une réponse reconnue peut toujours être contestée ; modifier un vote annule les confirmations.
  perform t28.mv(s,1,'confirm_validation');
  perform t28.mv(s,2,'judge_entry','{"seat":1,"category_id":"celebrite","verdict":"reject"}');
  perform t28.ok(t28.card(s)->'confirmed'='{}'::jsonb, 'confirmation remise à zéro après vote');
  perform t28.mv(s,1,'confirm_validation');
  action:=gen_random_uuid(); perform t28.mv(s,2,'confirm_validation','{}',action);
  c:=t28.card(s);
  perform t28.ok(c->>'phase'='result' and (c->>'done')::boolean, 'clôture serveur');
  perform t28.ok(c#>>'{answers,1,animal,points}'='5' and c#>>'{answers,2,animal,points}'='5', 'réponse identique : 5');
  perform t28.ok(c#>>'{answers,1,metier,points}'='10' and c#>>'{answers,2,metier,points}'='10', 'réponses reconnues différentes : 10');
  perform t28.ok(c#>>'{answers,1,pays,points}'='15', 'unique réponse valide : 15');
  perform t28.ok(c#>>'{answers,2,objet,final}'='accepted' and c#>>'{answers,2,objet,points}'='10', 'inconnu accepté sans changer barème');
  perform t28.ok(c#>>'{answers,2,ville,final}'='contested' and c#>>'{answers,2,ville,points}'='0', 'absence non tranchée reste contestée, pas fausse');
  perform t28.ok(c#>>'{answers,1,celebrite,final}'='contested' and c#>>'{answers,1,celebrite,points}'='0', 'reconnu contesté sans pénalité');
  perform t28.ok(c->'scores'='{"1":85,"2":25}'::jsonb, 'total 5/10/15 inchangé');
  perform t28.ok((t28.mv(s,2,'confirm_validation','{}',action)->>'repeated')::boolean and t28.card(s)=c, 'double confirmation sans second score');
end $$;

-- Une partie déjà liée à la version 2 continue avec son index et ses règles,
-- même lorsque le catalogue propose la version 3 aux nouvelles parties.
do $$ declare s uuid; current_v int; old_s uuid;
begin
  select session_id into old_s from public.session_players
    where user_id='00000000-0000-4000-a000-000000000a28';
  update public.game_sessions set status='abandoned' where id=old_s;
  select current_version into current_v from public.games where id='N2-018';
  update public.games set current_version=2 where id='N2-018';
  s:=t28.start();
  update public.games set current_version=current_v where id='N2-018';
  perform t28.ok((select private.version_config(g)->>'bank' from public.game_sessions g where id=s)='petit_bac_huit', 'partie historique garde banque v1');
  perform t28.mv(s,1,'round_loaded'); perform t28.mv(s,2,'round_loaded');
  update public.session_rounds set card=card||jsonb_build_object('letter','E','deadline_at',now()) where session_id=s;
  update private.round_secrets set secret=jsonb_set(secret,'{seats}',jsonb_build_object('1',jsonb_build_object('drafts',
    jsonb_build_object('animal',jsonb_build_object('text',U&'e\0301le\0301phant','rev',1))))) where session_id=s;
  perform t28.mv(s,1,'expire');
  perform t28.ok(t28.card(s)#>>'{answers,1,animal,status}'='unknown' and
    not (t28.card(s)#>'{answers,1,animal}'?'index_version'), 'ancienne partie conserve classification originale');
end $$;

select 'TOUS LES TESTS PETIT BAC NORMALISATION ET ARBITRAGE SONT PASSÉS';
rollback;
