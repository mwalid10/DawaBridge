-- The missing half of the reservation system.
--
-- request_listing() has set reserved_until = now() + 48h since
-- 0007_deals_chat_notifications.sql. Nothing has ever read it back. There
-- was no pg_cron extension installed, no scheduled function, no lazy
-- sweep — the column was written and then ignored.
--
-- Effect on the live database at the time of this migration: all 8
-- reserved listings were 8-9 days past their reserved_until, which is 27%
-- of the entire marketplace sitting invisible and unsellable. Every
-- listing that ever got requested and then ghosted was gone for good.
--
-- Two mechanisms here, deliberately redundant, because this is the bug
-- that quietly eats the marketplace:
--
--   1. release_expired_deals(), on a 15-minute pg_cron schedule.
--   2. A lazy release inside request_listing(), so a stale reservation is
--      cleared the moment anyone tries to request that listing even if
--      cron is unavailable or disabled on the project.

create extension if not exists pg_cron;

create or replace function public.release_expired_deals()
returns table (expired_offers int, released_reservations int)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_offers int := 0;
  v_released int := 0;
begin
  -- Pending offers the seller never answered. The listing was never locked
  -- by these (that's the 0035 change), so there's nothing to hand back —
  -- the offer just lapses.
  with lapsed as (
    update deals
    set state = 'declined', responded_at = now(), expires_at = null
    where state = 'pending' and expires_at is not null and expires_at < now()
    returning id, counterpart_pharmacy_id, listing_id
  ),
  notified as (
    insert into notifications (pharmacy_id, kind, title, body, deal_id)
    select counterpart_pharmacy_id, 'deal_expired', 'Request expired',
           'The seller didn''t respond in time. The listing is still available — you can request it again.',
           id
    from lapsed
    returning 1
  )
  select count(*)::int into v_offers from lapsed;

  -- Accepted deals whose reservation window ran out: the listing goes back
  -- on the market and both sides are told.
  with stale as (
    update deals d
    set state = 'cancelled', expires_at = null
    where d.state = 'accepted' and d.expires_at is not null and d.expires_at < now()
    returning d.id, d.listing_id, d.counterpart_pharmacy_id
  ),
  freed as (
    update listings l
    set state = 'available', reserved_until = null
    from stale s
    where l.id = s.listing_id and l.state = 'reserved'
    returning l.id, l.pharmacy_id
  ),
  notified_buyer as (
    insert into notifications (pharmacy_id, kind, title, body, deal_id)
    select s.counterpart_pharmacy_id, 'deal_expired', 'Reservation expired',
           'This deal wasn''t completed in time and the listing has been released.', s.id
    from stale s
    returning 1
  ),
  notified_seller as (
    insert into notifications (pharmacy_id, kind, title, body, deal_id, listing_id)
    select f.pharmacy_id, 'deal_expired', 'Reservation expired',
           'A reserved listing wasn''t completed in time and is available again.', s.id, f.id
    from stale s join freed f on f.id = s.listing_id
    returning 1
  )
  select count(*)::int into v_released from stale;

  return query select v_offers, v_released;
end;
$$;

-- Not granted to authenticated: this is a maintenance job, run by cron and
-- callable by admins through the dashboard, not by pharmacy clients.
revoke execute on function public.release_expired_deals() from public;

-- ---------------------------------------------------------------------
-- Backfill: clear the reservations that are already stuck.
--
-- These predate the deal_status migration, so they're 'accepted' now with
-- a null expires_at (0035 only set expires_at on new deals). Anything
-- whose listing is still 'reserved' past reserved_until is released here.
-- ---------------------------------------------------------------------
with stuck as (
  select d.id as deal_id, l.id as listing_id, l.pharmacy_id, d.counterpart_pharmacy_id
  from deals d
  join listings l on l.id = d.listing_id
  where d.state = 'accepted'
    and l.state = 'reserved'
    and l.reserved_until is not null
    and l.reserved_until < now()
),
cancelled_deals as (
  update deals set state = 'cancelled', expires_at = null
  where id in (select deal_id from stuck) returning id
),
freed_listings as (
  update listings set state = 'available', reserved_until = null
  where id in (select listing_id from stuck) returning id
)
insert into notifications (pharmacy_id, kind, title, body, deal_id)
select pharmacy_id, 'deal_expired', 'Reservation released',
       'A long-expired reservation on your listing has been released and the listing is available again.',
       deal_id
from stuck;

-- Any surviving accepted deal gets a real deadline so the sweep can see it.
update deals
set expires_at = greatest(now() + interval '24 hours', created_at + deal_reservation_window())
where state = 'accepted' and expires_at is null;

update deals
set expires_at = created_at + deal_offer_window()
where state = 'pending' and expires_at is null;

-- ---------------------------------------------------------------------
-- The schedule. Guarded so re-running the migration doesn't stack jobs.
-- ---------------------------------------------------------------------
do $$
begin
  perform cron.unschedule('release-expired-deals');
exception when others then null;
end $$;

select cron.schedule('release-expired-deals', '*/15 * * * *', $$select public.release_expired_deals()$$);

-- ---------------------------------------------------------------------
-- Lazy fallback. If cron is ever disabled on the project, a stale
-- reservation still can't outlive the next person who tries to request
-- that listing.
-- ---------------------------------------------------------------------
create or replace function public.request_listing(p_listing_id uuid, p_message text default null)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_listing listings%rowtype;
  v_deal_id uuid;
  v_body text;
  v_existing uuid;
begin
  if auth.uid() is null then
    raise exception 'AUTH_REQUIRED';
  end if;
  if not is_approved_pharmacy() then
    raise exception 'PHARMACY_NOT_APPROVED';
  end if;

  select * into v_listing from listings where id = p_listing_id for update;

  if v_listing.id is null then
    raise exception 'LISTING_NOT_FOUND';
  end if;
  if v_listing.pharmacy_id = auth.uid() then
    raise exception 'LISTING_OWN';
  end if;

  -- Stale reservation: release it here rather than telling this buyer the
  -- listing is unavailable when in truth it's been abandoned for days.
  if v_listing.state = 'reserved'
     and v_listing.reserved_until is not null
     and v_listing.reserved_until < now() then
    update deals set state = 'cancelled', expires_at = null
    where listing_id = p_listing_id and state = 'accepted';

    update listings set state = 'available', reserved_until = null
    where id = p_listing_id;

    v_listing.state := 'available';
  end if;

  if v_listing.state <> 'available' then
    raise exception 'LISTING_UNAVAILABLE';
  end if;
  if v_listing.expiry_date <= current_date then
    raise exception 'LISTING_EXPIRED';
  end if;

  select id into v_existing
  from deals
  where listing_id = p_listing_id
    and counterpart_pharmacy_id = auth.uid()
    and state in ('pending','accepted');

  if v_existing is not null then
    raise exception 'DEAL_ALREADY_OPEN';
  end if;

  insert into deals (listing_id, counterpart_pharmacy_id, state, expires_at)
  values (p_listing_id, auth.uid(), 'pending', now() + deal_offer_window())
  returning id into v_deal_id;

  v_body := coalesce(nullif(trim(p_message), ''), 'Hi, I''m interested in this listing.');
  insert into messages (deal_id, sender_id, body) values (v_deal_id, auth.uid(), v_body);

  return v_deal_id;
end;
$$;

grant execute on function public.request_listing(uuid, text) to authenticated;
