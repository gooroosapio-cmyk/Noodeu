-- Mesure locale, sans seuil dépendant de la machine. Aucune donnée modifiée.
-- Exécuter après 20261030000700 sur le Docker jetable uniquement.
begin;
do $$ begin
  if current_database() not in ('noodeu_lot6_clean_2154', 'noodeu') and not (
    current_database() ~ '^noodeu_server_[a-zA-Z0-9_]+$' and coalesce((
      select shobj_description(oid, 'pg_database') from pg_database where datname = current_database()
    ), '') = 'noodeu:disposable-local-sql-test'
  ) then
    raise exception 'Mesure réservée aux bases Docker jetables explicitement autorisées';
  end if;
end $$;
explain (analyze, buffers)
select value->>'acc' from public.content_banks
where bank='petit_bac_huit_unicode' and value->>'cat'='animal' and value->'aliases' ? 'CHAT'
order by idx limit 1;
do $$
declare t timestamptz; i int; v jsonb; c jsonb; sec jsonb; times float8[]; k text; st text; bank text;
begin
  c:='{"letter":"C","categories":["animal","ville","metier","objet","pays","prenom","fruit-legume","celebrite"]}';
  sec:='{"seats":{"1":{"drafts":{}},"2":{"drafts":{}}}}';
  foreach st in array array['1','2'] loop
    for k in select jsonb_array_elements_text(c->'categories') loop
      sec:=jsonb_set(sec,array['seats',st,'drafts',k],'{"text":"Czzz inconnu"}');
    end loop;
  end loop;
  foreach bank in array array['petit_bac_huit','petit_bac_huit_unicode'] loop
    times:='{}';
    for i in 1..2000 loop
      t:=clock_timestamp(); v:=private.pb_classify(bank,'animal','C','chat');
      times:=array_append(times,extract(epoch from clock_timestamp()-t)*1000);
    end loop;
    raise notice '% indexed_hit n=2000 mean_ms=% p95_ms=%',bank,
      (select avg(x) from unnest(times)x),(select percentile_cont(0.95)within group(order by x)from unnest(times)x);
    times:='{}';
    for i in 1..2000 loop
      t:=clock_timestamp(); v:=private.pb_classify(bank,'animal','C','Czzz inconnu');
      times:=array_append(times,extract(epoch from clock_timestamp()-t)*1000);
    end loop;
    raise notice '% unknown n=2000 mean_ms=% p95_ms=%',bank,
      (select avg(x) from unnest(times)x),(select percentile_cont(0.95)within group(order by x)from unnest(times)x);
    times:='{}';
    for i in 1..1000 loop
      t:=clock_timestamp(); v:=private.pb_freeze(c,sec,bank,1);
      times:=array_append(times,extract(epoch from clock_timestamp()-t)*1000);
    end loop;
    raise notice '% freeze16 n=1000 mean_ms=% p95_ms=%',bank,
      (select avg(x) from unnest(times)x),(select percentile_cont(0.95)within group(order by x)from unnest(times)x);
  end loop;
end $$;
rollback;
