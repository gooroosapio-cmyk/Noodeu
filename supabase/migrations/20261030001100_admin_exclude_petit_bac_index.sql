-- Intégration Admin + normalisation Petit bac300007 : cet index est une banque
-- de validation, pas une liste de questions éditables. Ne change ni les données
-- ni admin_guard, RLS, ACL ou les moteurs. CREATE OR REPLACE conserve les ACL
-- de admin_bank_map définies par290001_admin_questions.
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
  where b.bank is not null and b.bank not in ('hangman_words', 'petit_bac', 'petit_bac_huit', 'petit_bac_huit_unicode')
  order by b.bank, (g.status = 'published') desc, g.id
$$;
