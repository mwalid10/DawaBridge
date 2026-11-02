-- Admin roles: super_admin / moderator / viewer.
--
-- Until now every row in `admins` had full write access to everything the
-- dashboard can touch. This splits that into three tiers:
--
--   * viewer      — read-only. Every existing `is_admin()` SELECT path keeps
--                   working for them; nothing that writes does.
--   * moderator   — day-to-day moderation: pharmacy KYC and details,
--                   disputes, listings, products/catalog, news, price
--                   alerts, controlled-substance terms.
--   * super_admin — everything a moderator can do, plus the three things
--                   with outsized blast radius: broadcasts (push to every
--                   pharmacy), plans & trials (billing state), and managing
--                   the admin team itself.
--
-- is_admin() keeps its meaning ("any admin") so the read policies and the
-- mobile app's get_my_status() don't change. Writes move to two new checks,
-- is_admin_editor() and is_super_admin().

create type admin_role as enum ('super_admin', 'moderator', 'viewer');

alter table admins add column role admin_role not null default 'viewer';

-- Everyone who was an admin before roles existed had full access; keep it.
update admins set role = 'super_admin';

create or replace function public.is_admin_editor()
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select exists(select 1 from admins where id = auth.uid() and role in ('super_admin', 'moderator'));
$$;

create or replace function public.is_super_admin()
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select exists(select 1 from admins where id = auth.uid() and role = 'super_admin');
$$;

revoke execute on function public.is_admin_editor() from public, anon;
revoke execute on function public.is_super_admin() from public, anon;
grant execute on function public.is_admin_editor() to authenticated;
grant execute on function public.is_super_admin() to authenticated;

-- ---------------------------------------------------------------------------
-- Write policies: is_admin() -> is_admin_editor().
--
-- The "for all" policies also covered SELECT, so each is split into an
-- admin read (any role) plus an editor write. Postgres ORs permissive
-- policies, so the editor policy still covering SELECT is harmless.
-- ---------------------------------------------------------------------------

drop policy "drugs: admin write" on drugs;
create policy "drugs: admin read" on drugs for select using (is_admin());
create policy "drugs: admin write" on drugs
  for all using (is_admin_editor()) with check (is_admin_editor());

drop policy "drug_catalog: admin write" on drug_catalog;
create policy "drug_catalog: admin read" on drug_catalog for select using (is_admin());
create policy "drug_catalog: admin write" on drug_catalog
  for all using (is_admin_editor()) with check (is_admin_editor());

drop policy "global_price_alerts: admin write" on global_price_alerts;
create policy "global_price_alerts: admin read" on global_price_alerts for select using (is_admin());
create policy "global_price_alerts: admin write" on global_price_alerts
  for all using (is_admin_editor()) with check (is_admin_editor());

drop policy "news_articles: admin write" on news_articles;
create policy "news_articles: admin read" on news_articles for select using (is_admin());
create policy "news_articles: admin write" on news_articles
  for all using (is_admin_editor()) with check (is_admin_editor());

drop policy "controlled_substance_terms: admin write" on controlled_substance_terms;
create policy "controlled_substance_terms: admin read" on controlled_substance_terms for select using (is_admin());
create policy "controlled_substance_terms: admin write" on controlled_substance_terms
  for all using (is_admin_editor()) with check (is_admin_editor());

drop policy "pharmacies: admin update" on pharmacies;
create policy "pharmacies: admin update" on pharmacies
  for update using (is_admin_editor()) with check (is_admin_editor());

drop policy "disputes: admin update" on disputes;
create policy "disputes: admin update" on disputes
  for update using (is_admin_editor()) with check (is_admin_editor());

drop policy "listings: admin update" on listings;
create policy "listings: admin update" on listings
  for update using (is_admin_editor()) with check (is_admin_editor());

drop policy "listings: admin delete" on listings;
create policy "listings: admin delete" on listings
  for delete using (is_admin_editor());

-- ---------------------------------------------------------------------------
-- Plans & trials: super admin only.
--
-- These live on `pharmacies`, which moderators can update (KYC, details), so
-- RLS can't separate them — a column-aware trigger does. Only admin callers
-- are checked: pharmacy sessions and service-role/cron (auth.uid() null)
-- keep whatever access they had before.
-- ---------------------------------------------------------------------------

create or replace function public.pharmacies_guard_plan_changes()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if (new.plan is distinct from old.plan or new.trial_ends_at is distinct from old.trial_ends_at)
     and is_admin() and not is_super_admin() then
    raise exception 'SUPER_ADMIN_REQUIRED';
  end if;
  return new;
end;
$$;

revoke execute on function public.pharmacies_guard_plan_changes() from public, anon, authenticated;

create trigger trg_pharmacies_guard_plan_changes
  before update of plan, trial_ends_at on pharmacies
  for each row execute function pharmacies_guard_plan_changes();

-- ---------------------------------------------------------------------------
-- Broadcast: super admin only. The dashboard goes through the
-- broadcast-notification edge function (updated alongside this migration);
-- this keeps the SQL path from 0032 consistent with it. The target count is
-- read-only and stays open to any admin.
-- ---------------------------------------------------------------------------

create or replace function public.admin_broadcast_notification(
  p_title text,
  p_body text,
  p_governorate text default null,
  p_status pharmacy_status default null,
  p_plan plan_status default null,
  p_pharmacy_id uuid default null
)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_count int;
begin
  if not is_super_admin() then
    raise exception 'Not authorized';
  end if;

  insert into notifications (pharmacy_id, kind, title, body)
  select id, 'admin_broadcast', p_title, p_body
  from pharmacies
  where (p_pharmacy_id is null or id = p_pharmacy_id)
    and (p_governorate is null or governorate = p_governorate)
    and (p_status is null or status = p_status)
    and (p_plan is null or plan = p_plan);

  get diagnostics v_count = row_count;
  return v_count;
end;
$$;

-- ---------------------------------------------------------------------------
-- Team management.
--
-- Super admins can see every admin, change name/role, and remove admins.
-- Creating one needs a new auth.users row, which only the service role can
-- do — that goes through the create-admin edge function, so there is no
-- client INSERT policy.
-- ---------------------------------------------------------------------------

create policy "admins: super admin read all" on admins
  for select using (is_super_admin());

create policy "admins: super admin update" on admins
  for update using (is_super_admin()) with check (is_super_admin());

create policy "admins: super admin delete" on admins
  for delete using (is_super_admin());

-- Only name and role are editable from the client; id and created_at aren't.
revoke update on admins from authenticated;
grant update (name, role) on admins to authenticated;

-- There must always be at least one super admin, or nobody can manage the
-- team again without Studio access. Locking the other super-admin rows
-- serialises two super admins demoting each other at the same moment.
create or replace function public.admins_keep_a_super_admin()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if old.role = 'super_admin' and (tg_op = 'DELETE' or new.role <> 'super_admin') then
    perform 1 from admins where role = 'super_admin' and id <> old.id for update;
    if not found then
      raise exception 'LAST_SUPER_ADMIN';
    end if;
  end if;
  return case when tg_op = 'DELETE' then old else new end;
end;
$$;

revoke execute on function public.admins_keep_a_super_admin() from public, anon, authenticated;

create trigger trg_admins_keep_a_super_admin
  before update of role or delete on admins
  for each row execute function admins_keep_a_super_admin();

-- The team list needs emails, which live in auth.users.
create or replace function public.admin_list_team()
returns table (
  id uuid,
  name text,
  email text,
  role admin_role,
  created_at timestamptz
)
language sql
security definer
set search_path = public
stable
as $$
  select a.id, a.name, u.email::text, a.role, a.created_at
  from admins a
  join auth.users u on u.id = a.id
  where is_super_admin()
  order by a.created_at asc;
$$;

revoke execute on function public.admin_list_team() from public, anon;
grant execute on function public.admin_list_team() to authenticated;

-- Used only by the create-admin edge function, to re-admit an existing
-- account (e.g. an admin who was removed and is being added back) instead of
-- failing on "email already registered".
create or replace function public.admin_user_id_by_email(p_email text)
returns uuid
language sql
security definer
set search_path = public
stable
as $$
  select id from auth.users where lower(email) = lower(trim(p_email)) limit 1;
$$;

revoke execute on function public.admin_user_id_by_email(text) from public, anon, authenticated;
grant execute on function public.admin_user_id_by_email(text) to service_role;
