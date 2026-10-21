-- En attendant la fermeture de l'accès direct aux tables de manches (migration 150, soumise à accord),
-- le contenu d'une capsule n'est jamais lisible en direct par l'autre : seule get_session_state(),
-- qui masque les champs non partagés, le montre.
create or replace function private.can_read_answer(p_session uuid, p_round int, p_user uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select p_user = auth.uid()
    or (private.is_member(private.session_couple(p_session), true)
        and exists (select 1 from public.session_rounds r
                    where r.session_id = p_session and r.round_no = p_round and r.revealed_at <= now())
        and not exists (select 1 from public.game_sessions gs
                        join public.game_versions v on v.game_id = gs.game_id and v.version = gs.game_version
                        where gs.id = p_session and v.config ->> 'reveal' = 'capsule'))
$$;

-- Les entrées retirées d'une banque (édition plus récente plus courte) ne sont plus tirées.
create or replace function private.bank_sample(p_bank text, p_count int) returns jsonb
language sql volatile security definer set search_path = '' as $$
  select coalesce(jsonb_agg(jsonb_build_object('i', b.idx, 'v', b.value) order by b.r), '[]')
  from (select idx, value, random() as r from public.content_banks where bank = p_bank and content_version <> 'retire'
        order by case when p_count is null then idx::float else random() end
        limit coalesce(p_count, 10000)) b
$$;
