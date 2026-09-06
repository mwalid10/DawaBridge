-- Chat attachments. messages gains an optional attachment_path (storage
-- object path, not a public URL — the bucket stays private and the client
-- resolves it to a signed URL on demand).
--
-- The chat-attachments bucket's RLS policy today is uploader-uid-scoped
-- (storage/<uid>/...), which only ever let the uploader read their own
-- files back — fine for disputes' one-way evidence upload, but useless for
-- a two-party chat where the other participant also needs read access.
-- This migration re-scopes the bucket to deal-scoped paths
-- (storage/<deal_id>/...) gated by the existing is_deal_participant()
-- helper from 0007, so both sides of a deal can read/write.
--
-- BREAKING: any object already uploaded under the old <uid>/... path
-- convention (dispute evidence photos raised before this migration) will
-- no longer match this policy and becomes unreadable — RLS can't rename
-- existing storage objects. disputes_controller.dart's upload path is
-- updated to the new <deal_id>/... convention in the same app release
-- this migration ships with; any pre-existing evidence under the old path
-- is not migrated here.

alter table messages add column attachment_path text;

drop policy if exists "chat-attachments: owner read/write" on storage.objects;

create policy "chat-attachments: participants read"
  on storage.objects for select
  using (bucket_id = 'chat-attachments' and is_deal_participant(((storage.foldername(name))[1])::uuid));

create policy "chat-attachments: participants write"
  on storage.objects for insert
  with check (bucket_id = 'chat-attachments' and is_deal_participant(((storage.foldername(name))[1])::uuid));

create policy "chat-attachments: participants delete"
  on storage.objects for delete
  using (bucket_id = 'chat-attachments' and is_deal_participant(((storage.foldername(name))[1])::uuid));
