-- Assorted hardening: advisor findings, the notification flood, storage
-- limits, and one stale function overload.

-- ---------------------------------------------------------------------
-- 1. Stale overload. 0030 added p_max_distance_km with CREATE OR REPLACE,
-- which for a function with a new defaulted parameter creates a *second*
-- overload rather than replacing the first. Both were live. PostgREST
-- picks by the named arguments it's given, so a client sending exactly the
-- old 11 would silently hit the pre-distance version.
-- ---------------------------------------------------------------------
drop function if exists public.search_listings(
  text, text, text, listing_type, text, date, double precision, double precision, uuid, int, int
);

-- ---------------------------------------------------------------------
-- 2. Advisor: function_search_path_mutable on pharmacies_set_location.
-- A trigger function without a pinned search_path can be hijacked by a
-- role-local schema shadowing ST_SetSRID/ST_MakePoint.
-- ---------------------------------------------------------------------
create or replace function public.pharmacies_set_location() returns trigger
language plpgsql
set search_path = public, extensions
as $$
begin
  new.location := ST_SetSRID(ST_MakePoint(new.lng, new.lat), 4326)::geography;
  return new;
end;
$$;

-- ---------------------------------------------------------------------
-- 3. Advisor: anon_security_definer_function_executable (27 findings).
--
-- Postgres grants EXECUTE on a new function to PUBLIC by default, and the
-- migrations only ever added an explicit grant to `authenticated` on top —
-- they never took the default away. So every one of these was reachable
-- unauthenticated via /rest/v1/rpc/... with nothing but the anon key,
-- which ships inside the app bundle.
--
-- Most were harmless because they key off auth.uid() and return nothing
-- for a null one, and the two admin_* functions have their own is_admin()
-- guard. find_or_create_drug was not harmless: it INSERTs into `drugs`
-- and had no auth check at all, so anyone with the anon key could inflate
-- the catalogue indefinitely. (0037 added an AUTH_REQUIRED guard to it;
-- this removes the reachability as well.)
-- ---------------------------------------------------------------------
do $$
declare
  fn record;
begin
  for fn in
    select p.oid::regprocedure as sig
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.prosecdef
      and p.proname in (
        'admin_broadcast_notification','admin_count_broadcast_targets',
        'complete_my_registration','deal_offer_window','deal_reservation_window',
        'delete_my_account','delete_my_listing','find_or_create_drug',
        'get_deal_detail','get_listing_detail','get_my_deals','get_my_disputes',
        'get_my_favorites','get_my_home_stats','get_my_listings',
        'get_my_rating_summary','get_my_status','get_notifications',
        'get_price_increased_listings','get_unread_notification_count',
        'is_admin','is_approved_pharmacy','is_controlled_name','is_deal_participant',
        'log_compliance_flag','mark_all_notifications_read','raise_dispute',
        'release_expired_deals','request_listing','respond_to_deal',
        'search_listings','submit_rating','update_my_listing'
      )
  loop
    execute format('revoke execute on function %s from public', fn.sig);
    execute format('revoke execute on function %s from anon', fn.sig);
  end loop;
end $$;

-- Re-grant to signed-in clients only. release_expired_deals is deliberately
-- absent: it's a maintenance job for cron and admins.
do $$
declare
  fn record;
begin
  for fn in
    select p.oid::regprocedure as sig
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.prosecdef
      and p.proname in (
        'admin_broadcast_notification','admin_count_broadcast_targets',
        'complete_my_registration','delete_my_account','delete_my_listing',
        'find_or_create_drug','get_deal_detail','get_listing_detail',
        'get_my_deals','get_my_disputes','get_my_favorites','get_my_home_stats',
        'get_my_listings','get_my_rating_summary','get_my_status',
        'get_notifications','get_price_increased_listings',
        'get_unread_notification_count','is_admin','is_approved_pharmacy',
        'is_controlled_name','is_deal_participant','log_compliance_flag',
        'mark_all_notifications_read','raise_dispute','request_listing',
        'respond_to_deal','search_listings','submit_rating','update_my_listing'
      )
  loop
    execute format('grant execute on function %s to authenticated', fn.sig);
  end loop;
end $$;

-- log_compliance_flag was also anon-reachable and inserted a row with
-- pharmacy_id = auth.uid(), which is NULL for anon — and compliance_flags
-- .pharmacy_id is nullable, so the insert succeeded. Unauthenticated table
-- stuffing. Guarded now as well as ungranted.
create or replace function public.log_compliance_flag(p_drug_id uuid, p_kind text)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception 'AUTH_REQUIRED';
  end if;
  insert into compliance_flags (pharmacy_id, drug_id, kind)
  values (auth.uid(), p_drug_id, p_kind);
end;
$$;

grant execute on function public.log_compliance_flag(uuid, text) to authenticated;

-- ---------------------------------------------------------------------
-- 4. Notifications: paging, a real unread count, and mark-all-read.
--
-- notifications_controller.dart fetched the entire table for the user with
-- no limit on every app open, and unreadNotificationsCountProvider then
-- computed the badge by counting that list in Dart. Combined with the old
-- notify_new_message() (one row per chat message, fixed in 0035), an
-- active pharmacy would be downloading thousands of rows on every cold
-- start to render a number.
-- ---------------------------------------------------------------------
create index if not exists idx_notifications_unread
  on notifications (pharmacy_id) where not read;

create or replace function public.get_unread_notification_count()
returns int
language sql
security definer
set search_path = public
stable
as $$
  select count(*)::int from notifications
  where pharmacy_id = auth.uid() and not read;
$$;

create or replace function public.get_notifications(p_limit int default 30, p_before timestamptz default null)
returns setof notifications
language sql
security definer
set search_path = public
stable
as $$
  select * from notifications
  where pharmacy_id = auth.uid()
    and (p_before is null or created_at < p_before)
  order by created_at desc
  limit least(greatest(coalesce(p_limit, 30), 1), 100);
$$;

create or replace function public.mark_all_notifications_read()
returns int
language plpgsql
security definer
set search_path = public
as $$
declare v_count int;
begin
  update notifications set read = true
  where pharmacy_id = auth.uid() and not read;
  get diagnostics v_count = row_count;
  return v_count;
end;
$$;

-- These are created after the bulk revoke loop above, so they still carry
-- Postgres's default grant to PUBLIC — take it away explicitly.
revoke execute on function public.get_unread_notification_count() from public, anon;
revoke execute on function public.get_notifications(int, timestamptz) from public, anon;
revoke execute on function public.mark_all_notifications_read() from public, anon;

grant execute on function public.get_unread_notification_count() to authenticated;
grant execute on function public.get_notifications(int, timestamptz) to authenticated;
grant execute on function public.mark_all_notifications_read() to authenticated;

-- ---------------------------------------------------------------------
-- 5. Messages paging. messages_controller.dart also fetched every message
-- in a thread with no limit.
-- ---------------------------------------------------------------------
create or replace function public.get_messages(
  p_deal_id uuid,
  p_limit int default 50,
  p_before timestamptz default null
)
returns setof messages
language sql
security definer
set search_path = public
stable
as $$
  select * from messages
  where deal_id = p_deal_id
    and is_deal_participant(p_deal_id)
    and (p_before is null or created_at < p_before)
  order by created_at desc
  limit least(greatest(coalesce(p_limit, 50), 1), 100);
$$;

revoke execute on function public.get_messages(uuid, int, timestamptz) from public, anon;
grant execute on function public.get_messages(uuid, int, timestamptz) to authenticated;

-- ---------------------------------------------------------------------
-- 6. Storage. No bucket had a size limit or a MIME allowlist, so a single
-- user could push a 500MB "photo". medicine-photos also had no DELETE or
-- UPDATE policy, so the app could never clean up an orphaned upload — and
-- the upload happens *before* the listing insert, so a failed insert
-- stranded the file permanently.
-- ---------------------------------------------------------------------
update storage.buckets
set file_size_limit = 5242880,  -- 5 MB
    allowed_mime_types = array['image/jpeg','image/png','image/webp','image/heic']
where id = 'medicine-photos';

update storage.buckets
set file_size_limit = 10485760,  -- 10 MB
    allowed_mime_types = array['image/jpeg','image/png','image/webp','image/heic','application/pdf']
where id = 'licenses';

update storage.buckets
set file_size_limit = 15728640,  -- 15 MB
    allowed_mime_types = array['image/jpeg','image/png','image/webp','image/heic','application/pdf']
where id = 'chat-attachments';

create policy "medicine-photos: owner delete"
  on storage.objects for delete
  using (bucket_id = 'medicine-photos' and (storage.foldername(name))[1] = auth.uid()::text);

create policy "medicine-photos: owner update"
  on storage.objects for update
  using (bucket_id = 'medicine-photos' and (storage.foldername(name))[1] = auth.uid()::text)
  with check (bucket_id = 'medicine-photos' and (storage.foldername(name))[1] = auth.uid()::text);

-- ---------------------------------------------------------------------
-- 7. Disputes: one open dispute per deal per party. raise_dispute() had no
-- limit, so the button could be tapped repeatedly and each tap filed a new
-- dispute and notified the other side.
-- ---------------------------------------------------------------------
create unique index if not exists idx_disputes_one_open_per_party
  on disputes (deal_id, raised_by) where status <> 'resolved';

create or replace function public.raise_dispute(
  p_deal_id uuid,
  p_reason text,
  p_description text default null,
  p_evidence_urls text[] default '{}'
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_deal deals%rowtype;
  v_listing listings%rowtype;
  v_other_party uuid;
  v_dispute_id uuid;
begin
  if auth.uid() is null then
    raise exception 'AUTH_REQUIRED';
  end if;
  if trim(coalesce(p_reason, '')) = '' then
    raise exception 'DISPUTE_REASON_REQUIRED';
  end if;

  select * into v_deal from deals where id = p_deal_id;
  if v_deal.id is null then
    raise exception 'DEAL_NOT_FOUND';
  end if;

  select * into v_listing from listings where id = v_deal.listing_id;

  if not (v_listing.pharmacy_id = auth.uid() or v_deal.counterpart_pharmacy_id = auth.uid()) then
    raise exception 'DEAL_NOT_PARTICIPANT';
  end if;

  if exists (select 1 from disputes where deal_id = p_deal_id and raised_by = auth.uid() and status <> 'resolved') then
    raise exception 'DISPUTE_ALREADY_OPEN';
  end if;

  v_other_party := case when v_listing.pharmacy_id = auth.uid() then v_deal.counterpart_pharmacy_id else v_listing.pharmacy_id end;

  insert into disputes (deal_id, raised_by, reason, description, evidence_urls)
  values (p_deal_id, auth.uid(), trim(p_reason), p_description, p_evidence_urls)
  returning id into v_dispute_id;

  insert into notifications (pharmacy_id, kind, title, body, deal_id)
  values (v_other_party, 'dispute_raised', 'A dispute was raised', trim(p_reason), p_deal_id);

  return v_dispute_id;
end;
$$;

revoke execute on function public.raise_dispute(uuid, text, text, text[]) from public, anon;
grant execute on function public.raise_dispute(uuid, text, text, text[]) to authenticated;

-- ---------------------------------------------------------------------
-- 8. Advisor: listing_price_history has RLS on with zero policies. That's
-- intentional (write-only via trigger, read only through the
-- security-definer RPC) but the linter can't tell intent from oversight,
-- so it's recorded here explicitly.
-- ---------------------------------------------------------------------
comment on table listing_price_history is
  'Write-only via trg_record_listing_price_history. RLS enabled with no policies by design: readable only through get_price_increased_listings() (security definer). Do not add a client-facing policy.';

comment on table compliance_flags is
  'Write-only via log_compliance_flag() and trg_listings_block_controlled. Admin-readable only.';
