-- Petit bac : normalisation Unicode et explication de l'arbitrage.
-- Les banques et versions antérieures restent inchangées. Seules les nouvelles
-- parties utilisent v2 ; aucun résultat/brouillon historique n'est recalculé.
-- Aucun lexique externe ajouté : copie versionnée des 866 entrées déjà présentes.

create or replace function private.pb_norm_v2(t text) returns text
language sql immutable set search_path = '' as $$
  select btrim(regexp_replace(private.nd_norm(
    translate(
      regexp_replace(pg_catalog.normalize(coalesce(t, ''), 'NFD'), U&'[\0300-\036f]', '', 'g'),
      U&'\00a0\1680\2000\2001\2002\2003\2004\2005\2006\2007\2008\2009\200a\2028\2029\202f\205f\3000',
      repeat(' ', 18))), '\s+', ' ', 'g'))
$$;
revoke all on function private.pb_norm_v2(text) from public, anon, authenticated;

insert into public.content_banks (bank, idx, value, content_version)
select 'petit_bac_huit_unicode', cb.idx,
  jsonb_set(cb.value, '{aliases}', (
    select jsonb_agg(private.pb_norm_v2(a.alias) order by a.ord)
    from jsonb_array_elements_text(cb.value -> 'aliases') with ordinality a(alias, ord))),
  'pb8-2026-10-29-v2'
from public.content_banks cb where cb.bank = 'petit_bac_huit'
on conflict (bank, idx) do nothing;

-- Le contrôle précédent parcourait content_banks, y compris les autres jeux.
-- Index limité à cette banque immuable ; la requête v2 emploie le même prédicat.
create index if not exists content_banks_pb8_v2_aliases_idx
  on public.content_banks using gin ((value -> 'aliases'))
  where bank = 'petit_bac_huit_unicode';

create or replace function private.pb_classify(p_bank text, p_cat text, p_letter text, p_text text) returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare
  n text;
  acc text;
  answer jsonb;
begin
  if p_bank = 'petit_bac_huit_unicode' then
    n := private.pb_norm_v2(p_text);
    answer := jsonb_build_object('text', btrim(coalesce(p_text, '')), 'norm', n,
      'index_version', 'pb8-2026-10-29-v2');
    if n = '' then
      return answer || jsonb_build_object('text', '', 'status', 'empty', 'reason', 'empty_answer');
    end if;
    if left(n, 1) <> private.pb_norm_v2(p_letter) then
      return answer || jsonb_build_object('status', 'invalid', 'reason', 'wrong_initial');
    end if;
    select value ->> 'acc' into acc from public.content_banks
      where bank = 'petit_bac_huit_unicode' and value ->> 'cat' = p_cat and value -> 'aliases' ? n
      order by idx limit 1;
    if acc is not null then
      return answer || jsonb_build_object('status', 'valid', 'acc', acc, 'reason', 'indexed_match');
    end if;
    -- L'index est limité : une absence, même dans une autre rubrique, n'est pas
    -- une preuve de fausseté. Les deux joueurs conservent leur arbitrage habituel.
    return answer || jsonb_build_object('status', 'unknown', 'reason', 'not_in_index');
  end if;

  -- Comportement historique inchangé pour les parties des versions précédentes.
  n := private.nd_norm(p_text);
  if n = '' then return jsonb_build_object('text', '', 'status', 'empty'); end if;
  if left(n, 1) <> p_letter then return jsonb_build_object('text', btrim(p_text), 'status', 'invalid', 'norm', n); end if;
  select value ->> 'acc' into acc from public.content_banks
    where bank = p_bank and value ->> 'cat' = p_cat and value -> 'aliases' ? n limit 1;
  if acc is not null then
    return jsonb_build_object('text', btrim(p_text), 'status', 'valid', 'acc', acc, 'norm', n);
  end if;
  return jsonb_build_object('text', btrim(p_text), 'status', 'unknown', 'norm', n);
end $$;

with v as (
  select * from public.game_versions
  where game_id = 'N2-018'
    and version = (select current_version from public.games where id = 'N2-018')
)
insert into public.game_versions (game_id, version, rules, config, published_at)
select 'N2-018', v.version + 1,
  v.rules || jsonb_build_object('details', (v.rules -> 'details') || jsonb_build_array(
    'Normalisation v2 : accents Unicode composés ou décomposés, casse et ligatures ignorés ; espaces de début et de fin retirés, espaces répétés ou insécables ramenés à un seul. Les traits d''union et l''article restent significatifs.',
    'L''index reste limité à 866 entrées : une absence signifie « à vérifier ensemble », jamais « faux » par défaut. Les deux joueurs peuvent contester une réponse reconnue. Le barème et le délai d''arbitrage restent inchangés.')),
  v.config || jsonb_build_object('bank', 'petit_bac_huit_unicode', 'bank_version', 'pb8-2026-10-29-v2',
    'version', 'noodeu-m16-2.1.0', 'normalization_version', 2),
  now()
from v where v.config ->> 'bank' = 'petit_bac_huit'
  and not exists (select 1 from public.game_versions gv where gv.game_id = 'N2-018' and gv.config ->> 'bank' = 'petit_bac_huit_unicode');

update public.games g set current_version = v.version, updated_at = now()
from public.game_versions v
where g.id = 'N2-018' and v.game_id = g.id and v.config ->> 'bank' = 'petit_bac_huit_unicode'
  and g.current_version < v.version;
