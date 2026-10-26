-- Tu préfères : 30 situations ajoutées, deux propositions chacune, +18, sans doublon. Transaction annulée.
begin;
do $$
declare n int;
begin
  select count(*) into n from public.content_banks where bank = 'conv_dilemma' and value ->> 'id' like 'TPS-%';
  if n <> 30 then raise exception 'ÉCHEC : % situations au lieu de 30', n; end if;
  if exists (select 1 from public.content_banks where bank = 'conv_dilemma' and value ->> 'id' like 'TPS-%'
             and (jsonb_array_length(value -> 'options') <> 2 or not (value ->> 'adult')::boolean
                  or coalesce(value #>> '{options,0,text}', '') = '' or coalesce(value #>> '{options,1,text}', '') = '')) then
    raise exception 'ÉCHEC : situation mal formée';
  end if;
  if (select count(*) from public.content_meta where bank = 'conv_dilemma' and item_id like 'TPS-%' and intensity = 'hot') <> 30 then
    raise exception 'ÉCHEC : métadonnées';
  end if;
  if (select count(distinct idx) from public.content_banks where bank = 'conv_dilemma') <> (select count(*) from public.content_banks where bank = 'conv_dilemma') then
    raise exception 'ÉCHEC : index en double';
  end if;
end $$;
select 'TOUS LES TESTS TU PRÉFÈRES SITUATIONS SONT PASSÉS';
rollback;
