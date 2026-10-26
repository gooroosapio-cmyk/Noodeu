-- Complète la phrase et D'accord ou pas d'accord quittent « À huis clos » pour « Se découvrir » (demande du
-- propriétaire, 26/10/2026). Le salon garde la mention « Ce contenu contient des questions relatives au sexe »
-- (adult_available). PDF « D'accord ou pas d'accord ? + Complète la phrase » : 56 des 60 textes étaient déjà présents ;
-- 4 affirmations reprennent la formulation du PDF, une amorce nouvelle est ajoutée.
update public.games set category_id = 'nd-se-decouvrir', content_level = 'standard', adult_available = true,
  sort = case id when 'nd-complete-phrase' then 60 else 61 end, updated_at = now()
where id in ('nd-complete-phrase', 'nd-accord-desaccord');

update public.content_banks set value = jsonb_set(value, '{text}', to_jsonb(x.txt)), updated_at = now()
from (values
  ('PK-G10-003', 'Dire non après avoir dit oui, c’est complètement normal.'),
  ('PK-G10-004', 'Les sextoys peuvent vraiment améliorer la vie sexuelle d’un couple.'),
  ('PK-G10-006', 'La masturbation en couple, ça peut être un sujet cool à discuter.'),
  ('PK-G10-016', 'Faire l’amour ailleurs que dans une chambre, ça peut être très fun.')) x(id, txt)
where bank = 'conv_opinion' and value ->> 'id' = x.id;

insert into public.content_banks (bank, idx, value, content_version)
select 'conv_sentence', (select coalesce(max(idx), -1) + 1 from public.content_banks where bank = 'conv_sentence'),
  jsonb_build_object('id', 'ACS-S-030', 'text', 'Le fantasme que je garde encore pour moi c’est…',
    'prefix', 'Le fantasme que je garde encore pour moi c’est', 'adult', true,
    'source', 'PDF « D’accord ou pas d’accord ? + Complète la phrase » (26/10/2026)'), 'acs-2026-10-26'
where not exists (select 1 from public.content_banks where bank = 'conv_sentence' and value ->> 'id' = 'ACS-S-030');

insert into public.content_meta (bank, item_id, intensity, adult, duration_kind, minutes_min, minutes_max, formats, standalone, review, review_note, source)
values ('conv_sentence', 'ACS-S-030', 'hot', true, 'rapide', 1, 3, array['duo', 'jeu'], true, true,
  'importé du PDF du 26/10/2026, à relire', 'pdf-accord-phrase-2026-10-26')
on conflict (bank, item_id) do nothing;
