-- Storage buckets — licenses and chat attachments are private; only the
-- owning pharmacy (matched by the first path segment being their user id,
-- e.g. licenses/<uid>/license.jpg) can read or write their own files.

insert into storage.buckets (id, name, public)
values
  ('licenses', 'licenses', false),
  ('medicine-photos', 'medicine-photos', true),
  ('chat-attachments', 'chat-attachments', false)
on conflict (id) do nothing;

create policy "licenses: owner read/write"
  on storage.objects for all
  using (bucket_id = 'licenses' and (storage.foldername(name))[1] = auth.uid()::text)
  with check (bucket_id = 'licenses' and (storage.foldername(name))[1] = auth.uid()::text);

create policy "medicine-photos: public read, owner write"
  on storage.objects for select
  using (bucket_id = 'medicine-photos');

create policy "medicine-photos: owner write"
  on storage.objects for insert
  with check (bucket_id = 'medicine-photos' and (storage.foldername(name))[1] = auth.uid()::text);

create policy "chat-attachments: owner read/write"
  on storage.objects for all
  using (bucket_id = 'chat-attachments' and (storage.foldername(name))[1] = auth.uid()::text)
  with check (bucket_id = 'chat-attachments' and (storage.foldername(name))[1] = auth.uid()::text);
