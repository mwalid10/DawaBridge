-- KYC approval was never actually enforced anywhere.
--
-- The app has had a pharmacies.status ('pending'/'approved'/'rejected'/
-- 'suspended') since 0001_init.sql, a KYC wizard that uploads a licence,
-- and a pending-approval screen. But nothing ever *checked* the column:
--
--   * splash_screen.dart sends any authenticated session straight to
--     /home, and login_screen.dart does the same. The pending-approval
--     screen is only reachable as the last step of the registration flow,
--     so signing out and back in walks straight past it.
--   * No RLS policy and no RPC looked at status either. A 'pending' or
--     even 'suspended' pharmacy could list, request, chat and transact
--     exactly like an approved one.
--
-- So the licence-verification process gated nothing at all. This migration
-- puts the check where it can't be walked around — the database — and the
-- router guard in the app is the cosmetic half of the same fix.
--
-- Read access stays open to any signed-in pharmacy (browsing the
-- marketplace while you wait for approval is fine, and it's what the
-- pending screen is for). Everything that *writes* to the marketplace now
-- requires 'approved'.

create or replace function public.is_approved_pharmacy()
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select exists (
    select 1 from pharmacies
    where id = auth.uid() and status = 'approved'
  );
$$;

grant execute on function public.is_approved_pharmacy() to authenticated;

-- get_my_status() — lets the client's router guard resolve "where does
-- this session belong" in a single call, without needing a readable
-- pharmacies row (an account that never finished registration has none —
-- see 0039's orphan cleanup). Returns 'none' for a signed-in user with no
-- pharmacy and no admin row, which is exactly the orphaned-registration
-- case the app now has to recover from.
create or replace function public.get_my_status()
returns table (
  role text,
  status pharmacy_status
)
language sql
security definer
set search_path = public
stable
as $$
  select
    case
      when exists (select 1 from admins where id = auth.uid()) then 'admin'
      when exists (select 1 from pharmacies where id = auth.uid()) then 'pharmacy'
      when auth.uid() is null then 'anonymous'
      else 'none'
    end,
    (select status from pharmacies where id = auth.uid());
$$;

grant execute on function public.get_my_status() to authenticated;

-- listings: writing now requires an approved pharmacy. Postgres ANDs the
-- USING/WITH CHECK of a single policy, so these replace (not supplement)
-- the ownership-only versions from 0001_init.sql.
drop policy if exists "listings: owner writes" on listings;
drop policy if exists "listings: owner updates" on listings;

create policy "listings: approved owner writes" on listings
  for insert with check (pharmacy_id = auth.uid() and is_approved_pharmacy());

create policy "listings: approved owner updates" on listings
  for update using (pharmacy_id = auth.uid() and is_approved_pharmacy())
  with check (pharmacy_id = auth.uid() and is_approved_pharmacy());

-- messages: same gate on sending. is_deal_participant() already proves
-- membership; this adds "and you're still in good standing", so a
-- pharmacy suspended mid-deal can read the thread but not keep talking.
drop policy if exists "messages: participants send" on messages;

create policy "messages: participants send" on messages
  for insert with check (
    sender_id = auth.uid()
    and is_deal_participant(deal_id)
    and is_approved_pharmacy()
  );

-- favorites and listing_alerts are private per-pharmacy bookkeeping, not
-- marketplace writes, so they stay open to any signed-in pharmacy.
