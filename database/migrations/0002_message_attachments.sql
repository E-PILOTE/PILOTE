-- 0002_message_attachments.sql
-- Pièces jointes de messagerie + politiques RLS manquantes + bucket de stockage.
-- Appliqué le 2026-06-07 via le pooler Supavisor (aws-1-eu-central-2, port 5432).

begin;

-- 1) Colonne pièces jointes : tableau jsonb [{url,name,mime,size,kind}]
alter table public.messages
  add column if not exists attachments jsonb not null default '[]'::jsonb;

-- 2) Politiques RLS manquantes. messages avait RLS activée mais SEULEMENT
--    msg_insert + msg_select → markRead/markUnread/archive/delete n'affectaient
--    0 ligne pour admin_groupe (silencieux). On ajoute UPDATE + DELETE.
drop policy if exists msg_update on public.messages;
create policy msg_update on public.messages
  for update using (
    is_super_admin() or (group_id = auth_group_id()
      and (sender_id = auth.uid() or recipient_id = auth.uid()))
  ) with check (
    is_super_admin() or (group_id = auth_group_id()
      and (sender_id = auth.uid() or recipient_id = auth.uid()))
  );

drop policy if exists msg_delete on public.messages;
create policy msg_delete on public.messages
  for delete using (
    is_super_admin() or (group_id = auth_group_id()
      and (sender_id = auth.uid() or recipient_id = auth.uid()))
  );

-- 3) Bucket de stockage (public, chemins uuid imprévisibles : {group_id}/{uuid}_{name})
insert into storage.buckets (id, name, public)
  values ('message-attachments', 'message-attachments', true)
  on conflict (id) do nothing;

drop policy if exists msg_attach_insert on storage.objects;
create policy msg_attach_insert on storage.objects
  for insert with check (bucket_id = 'message-attachments' and auth.role() = 'authenticated');

drop policy if exists msg_attach_update on storage.objects;
create policy msg_attach_update on storage.objects
  for update using (bucket_id = 'message-attachments' and auth.role() = 'authenticated');

drop policy if exists msg_attach_delete on storage.objects;
create policy msg_attach_delete on storage.objects
  for delete using (bucket_id = 'message-attachments' and auth.role() = 'authenticated');

commit;
