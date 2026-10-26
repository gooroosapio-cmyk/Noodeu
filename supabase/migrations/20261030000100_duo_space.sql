-- PRÉPARÉE SEULEMENT : notes partagées et couverture privée. Aucune donnée existante supprimée.
create table private.duo_spaces (
  couple_id uuid primary key references public.couples(id),
  cover_path text,
  version integer not null default 0
);
create table private.duo_notes (
  id uuid primary key,
  couple_id uuid not null references public.couples(id),
  author uuid not null,
  body text not null check (char_length(btrim(body)) between 1 and 600),
  due_on date,
  done boolean not null default false,
  version integer not null default 0,
  created_at timestamptz not null default now()
);
create index duo_notes_couple on private.duo_notes(couple_id, created_at desc);
alter table private.duo_spaces enable row level security;
alter table private.duo_notes enable row level security;

create function public.get_duo_space(p_couple uuid) returns jsonb
language plpgsql security definer set search_path = '' as $$
begin
  if not private.is_member(p_couple, true) then return jsonb_build_object('ok', false, 'error', 'not_found'); end if;
  return jsonb_build_object('ok', true,
    'cover_path', (select cover_path from private.duo_spaces where couple_id = p_couple),
    'version', coalesce((select version from private.duo_spaces where couple_id = p_couple), 0),
    'notes', coalesce((select jsonb_agg(to_jsonb(n) - 'couple_id' order by n.created_at desc) from
      (select * from private.duo_notes where couple_id = p_couple order by created_at desc limit 100) n), '[]'::jsonb));
end $$;

create function public.save_duo_note(p_couple uuid, p_id uuid, p_body text, p_due date default null,
  p_done boolean default false, p_version integer default 0) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare n private.duo_notes;
begin
  if not private.is_member(p_couple) then return jsonb_build_object('ok', false, 'error', 'not_found'); end if;
  if p_id is null or p_body is null or char_length(btrim(p_body)) not between 1 and 600 or p_done is null then
    return jsonb_build_object('ok', false, 'error', 'invalid_text'); end if;
  perform pg_advisory_xact_lock(hashtext('space:' || p_couple::text));
  perform pg_advisory_xact_lock(hashtext('note:' || p_id::text));
  select * into n from private.duo_notes where id = p_id for update;
  if n.id is not null then
    if n.couple_id <> p_couple then return jsonb_build_object('ok', false, 'error', 'not_found'); end if;
    -- Retransmission strictement identique : aucun effet supplémentaire.
    if n.body = btrim(p_body) and n.due_on is not distinct from p_due and n.done = p_done then
      return jsonb_build_object('ok', true, 'version', n.version); end if;
    if n.version is distinct from p_version then return jsonb_build_object('ok', false, 'error', 'conflict'); end if;
    update private.duo_notes set body = btrim(p_body), due_on = p_due, done = p_done, version = version + 1 where id = p_id;
  else
    if p_version is distinct from 0 then return jsonb_build_object('ok', false, 'error', 'conflict'); end if;
    if (select count(*) from private.duo_notes where couple_id = p_couple) >= 100 then
      return jsonb_build_object('ok', false, 'error', 'limit'); end if;
    insert into private.duo_notes(id, couple_id, author, body, due_on, done) values(p_id, p_couple, auth.uid(), btrim(p_body), p_due, p_done);
  end if;
  perform realtime.send('{}'::jsonb, 'duo', 'couple:' || p_couple::text, true);
  return jsonb_build_object('ok', true);
end $$;

-- Le service Storage vérifie MIME et taille. Aucun lien public ni ACL d'un autre bucket modifiés.
insert into storage.buckets(id, name, public, file_size_limit, allowed_mime_types)
values ('duo-covers', 'duo-covers', false, 2097152, array['image/webp', 'image/jpeg', 'image/png']);
create function private.cover_duo(p_name text) returns uuid language plpgsql immutable set search_path = '' as $$
begin
  if p_name !~ '^[0-9a-f-]{36}/[0-9a-f-]{36}\.webp$' then return null; end if;
  return split_part(p_name, '/', 1)::uuid;
exception when invalid_text_representation then return null;
end $$;
create policy duo_covers_read on storage.objects for select to authenticated
using(bucket_id = 'duo-covers' and private.is_member(private.cover_duo(name), true));
create policy duo_covers_insert on storage.objects for insert to authenticated
with check(bucket_id = 'duo-covers' and private.is_member(private.cover_duo(name)));
-- Objets immuables : pas d'écrasement ni suppression par navigateur.
create function public.set_duo_cover(p_couple uuid, p_path text, p_version integer) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare v integer;
begin
  if not private.is_member(p_couple) then return jsonb_build_object('ok', false, 'error', 'not_found'); end if;
  if private.cover_duo(p_path) is distinct from p_couple or not exists
    (select 1 from storage.objects where bucket_id = 'duo-covers' and name = p_path) then
    return jsonb_build_object('ok', false, 'error', 'invalid_file'); end if;
  insert into private.duo_spaces(couple_id) values(p_couple) on conflict do nothing;
  select version into v from private.duo_spaces where couple_id = p_couple for update;
  if (select cover_path from private.duo_spaces where couple_id = p_couple) = p_path then return jsonb_build_object('ok', true); end if;
  if v is distinct from p_version then return jsonb_build_object('ok', false, 'error', 'conflict'); end if;
  update private.duo_spaces set cover_path = p_path, version = version + 1 where couple_id = p_couple;
  perform realtime.send('{}'::jsonb, 'duo', 'couple:' || p_couple::text, true);
  return jsonb_build_object('ok', true);
end $$;
revoke all on function public.get_duo_space(uuid), public.save_duo_note(uuid,uuid,text,date,boolean,integer), public.set_duo_cover(uuid,text,integer) from public, anon;
grant execute on function public.get_duo_space(uuid), public.save_duo_note(uuid,uuid,text,date,boolean,integer), public.set_duo_cover(uuid,text,integer) to authenticated;
revoke all on function private.cover_duo(text) from public, anon;
grant execute on function private.cover_duo(text) to authenticated;
