-- Je n'ai jamais : libellés exacts, identifiants inchangés.
do $$
begin
  if exists (select 1 from public.content_banks where bank = 'conv_never'
             and (value #>> '{options,0,text}' <> 'Je l’ai déjà fait' or value #>> '{options,1,text}' <> 'Je ne l’ai jamais fait'
                  or value #>> '{options,0,id}' <> 'experienced' or value #>> '{options,1,id}' <> 'never')) then
    raise exception 'libellés de Je n''ai jamais incorrects';
  end if;
  if not exists (select 1 from public.content_banks where bank = 'conv_never') then raise exception 'banque vide'; end if;
end $$;
select 'TOUS LES TESTS JE N''AI JAMAIS SONT PASSÉS';
