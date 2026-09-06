-- Admin dashboard support. Admin staff are NOT pharmacy accounts — they
-- get their own auth.users row plus a row in this new `admins` table
-- (membership only, no pharmacy data). is_admin() is security-definer so
-- RLS policies on other tables can check membership without recursive-
-- policy issues. New policies below are strictly additive (Postgres ORs
-- permissive policies together), so none of the existing owner-scoped
-- policies need to change.
--
-- This finally gives a real path for the things several earlier
-- migrations' comments flagged as "done via Supabase Studio for now":
-- pharmacy KYC approval (0001), dispute status transitions (0009), and
-- global_price_alerts / news_articles content (0018, 0012).

create table admins (
  id uuid primary key references auth.users(id),
  name text not null,
  created_at timestamptz not null default now()
);

alter table admins enable row level security;

create policy "admins: read own row" on admins
  for select using (auth.uid() = id);

create or replace function public.is_admin()
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select exists(select 1 from admins where id = auth.uid());
$$;

-- pharmacies: admin read-all + status/approval updates
create policy "pharmacies: admin read all" on pharmacies
  for select using (is_admin());

create policy "pharmacies: admin update" on pharmacies
  for update using (is_admin()) with check (is_admin());

-- disputes: admin read-all + resolution. resolution_note records why/how
-- an admin closed it out, shown back to both deal participants.
alter table disputes add column resolution_note text;

create policy "disputes: admin read all" on disputes
  for select using (is_admin());

create policy "disputes: admin update" on disputes
  for update using (is_admin()) with check (is_admin());

-- global_price_alerts: replaces the "service-role/Studio only" write path
-- from 0018 with real admin RLS access.
create policy "global_price_alerts: admin write" on global_price_alerts
  for all using (is_admin()) with check (is_admin());

-- news_articles: had zero write policies at all (0012) — admin managed.
create policy "news_articles: admin write" on news_articles
  for all using (is_admin()) with check (is_admin());

-- compliance_flags: had zero read policies at all (0006) — admin can
-- review controlled-substance listing-attempt patterns.
create policy "compliance_flags: admin read" on compliance_flags
  for select using (is_admin());

-- licenses bucket: admins need to view uploaded KYC license files to
-- approve/reject a pharmacy; currently owner-only read (0002).
create policy "licenses: admin read"
  on storage.objects for select
  using (bucket_id = 'licenses' and is_admin());
