-- Complète la phrase et D'accord ou pas d'accord dans « Se découvrir », mention conservée, contenus du PDF. Transaction annulée.
begin;
do $$
begin
  if exists (select 1 from public.games where id in ('nd-complete-phrase', 'nd-accord-desaccord')
             and (category_id <> 'nd-se-decouvrir' or content_level = 'intime' or not adult_available)) then
    raise exception 'ÉCHEC : déplacement';
  end if;
  if (select value ->> 'text' from public.content_banks where bank = 'conv_opinion' and value ->> 'id' = 'PK-G10-003') <> 'Dire non après avoir dit oui, c’est complètement normal.' then
    raise exception 'ÉCHEC : formulation du PDF';
  end if;
  if (select count(*) from public.content_banks where bank = 'conv_sentence' and value ->> 'id' = 'ACS-S-030' and value ->> 'prefix' = 'Le fantasme que je garde encore pour moi c’est') <> 1 then
    raise exception 'ÉCHEC : amorce ajoutée';
  end if;
  if (select count(*) from public.content_banks where bank = 'conv_sentence') <> 31 or (select count(*) from public.content_banks where bank = 'conv_opinion') <> 30 then
    raise exception 'ÉCHEC : nombre de cartes';
  end if;
end $$;
select 'TOUS LES TESTS ACCORD ET PHRASE SONT PASSÉS';
rollback;
