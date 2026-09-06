-- Device FCM tokens, one row per installed app instance. `token` is unique
-- across all pharmacies since a device can only be logged into one pharmacy
-- account at a time — a re-login from a new pharmacy on the same device
-- should move the row, not duplicate it (see the app-side upsert with
-- onConflict: 'token').
--
-- No admin/select-all policy: the broadcast-notification edge function
-- reads this with the service-role key, which bypasses RLS entirely, so
-- admins never need direct client access to other pharmacies' tokens.
create table device_push_tokens (
  id uuid primary key default gen_random_uuid(),
  pharmacy_id uuid not null references pharmacies(id),
  token text not null unique,
  platform text not null,
  updated_at timestamptz not null default now()
);

create index idx_device_push_tokens_pharmacy_id on device_push_tokens (pharmacy_id);

alter table device_push_tokens enable row level security;

create policy "device_push_tokens: owner manage" on device_push_tokens
  for all using (pharmacy_id = auth.uid()) with check (pharmacy_id = auth.uid());
