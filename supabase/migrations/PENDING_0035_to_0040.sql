-- ============================================================
-- Pharma Exchange Egypt — pending migrations 0035..0040
--
-- 0034_pharmacy_status_enforcement.sql is ALREADY APPLIED to the
-- live project. These six are not. Paste this whole file into the
-- Supabase Studio SQL editor and run it once, top to bottom — the
-- order matters (0035 creates the deal_status type the rest use).
--
-- IMPORTANT: the mobile app code in this repo already expects this
-- schema. Until this runs, the Chat tab, deal actions and listing
-- edit/delete will error against the old schema.
-- ============================================================


-- ============================================================
-- 0035_deal_lifecycle_v2.sql
-- ============================================================

-- Deal lifecycle v2 — the seller now has to accept.
--
-- WHAT WAS BROKEN (both confirmed against live data):
--
-- 1. request_listing() flipped the listing straight to 'reserved' with no
--    seller involvement, so any buyer could unilaterally lock any listing
--    just by tapping Request. One bad actor could freeze a whole
--    governorate's inventory.
-- 2. reserved_until was set to now() + 48h and then never read by
--    anything — no cron, no lazy sweep, nothing. Every one of the 8
--    reserved listings in the database was 8-9 days past its
--    reserved_until and invisible to search, permanently.
--
-- THE NEW MODEL:
--
--   buyer requests  -> deal 'pending', listing STAYS 'available'
--   seller accepts  -> deal 'accepted', listing -> 'reserved',
--                      every other pending deal on that listing
--                      auto-declines
--   seller declines -> deal 'declined', listing untouched
--   seller completes-> deal 'completed', listing -> 'completed'
--   either cancels  -> deal 'cancelled', listing -> back to 'available'
--
-- Because a pending request no longer locks anything, several buyers can
-- queue on the same listing and the seller picks. That removes the
-- griefing vector entirely and makes the 48h window a soft deadline on
-- the seller rather than a hard lock on the asset.
--
-- deals.state also stops borrowing the listing_state enum, which allowed
-- the nonsensical deal state 'available'. It gets its own deal_status.

-- System messages first. respond_to_deal() used to post its "Deal
-- cancelled." / "Deal marked complete." lines with sender_id = auth.uid(),
-- so the chat rendered them as an ordinary bubble *from whoever clicked* —
-- the other party saw "Deal cancelled." as if the person had typed it.
-- They get sender_id = null + is_system = true instead, and the thread
-- renders them as neutral centred system lines.
alter table messages alter column sender_id drop not null;
alter table messages add column is_system boolean not null default false;

-- Backfill: every historical message whose body exactly matches one of the
-- two strings respond_to_deal() used to write is a system line.
update messages
set is_system = true, sender_id = null
where body in ('Deal marked complete.', 'Deal cancelled.');

create type deal_status as enum ('pending','accepted','declined','completed','cancelled');

-- Existing rows: 'reserved' was the old "live deal" state -> 'accepted'.
-- (0001_init.sql's default was 'reserved' and nothing ever wrote
-- 'available', but the else branch keeps the cast total either way.)
alter table deals alter column state drop default;

alter table deals
  alter column state type deal_status
  using (
    case state::text
      when 'reserved'  then 'accepted'::deal_status
      when 'completed' then 'completed'::deal_status
      when 'cancelled' then 'cancelled'::deal_status
      else 'cancelled'::deal_status
    end
  );

alter table deals alter column state set default 'pending'::deal_status;

-- expires_at drives the sweep in 0037. For a pending deal it's the
-- seller's response deadline; for an accepted one it's the reservation
-- deadline. Null once the deal reaches a terminal state.
alter table deals add column expires_at timestamptz;
alter table deals add column responded_at timestamptz;

update deals set expires_at = null where state in ('completed','cancelled','declined');

create index idx_deals_listing_state on deals (listing_id, state);
create index idx_deals_expires_at on deals (expires_at) where expires_at is not null;

-- Deal-window constants live in one place so the sweep job (0037) and the
-- RPCs below can't drift apart.
create or replace function public.deal_offer_window() returns interval
language sql immutable as $$ select interval '48 hours' $$;

create or replace function public.deal_reservation_window() returns interval
language sql immutable as $$ select interval '7 days' $$;

-- request_listing() v2 — creates a *pending offer*. Critically it no
-- longer touches the listing's state, so the listing stays visible and
-- requestable by others until the seller actually picks someone.
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
  if v_listing.state <> 'available' then
    raise exception 'LISTING_UNAVAILABLE';
  end if;
  if v_listing.expiry_date <= current_date then
    raise exception 'LISTING_EXPIRED';
  end if;

  -- One live offer per buyer per listing. Without this the buyer can spam
  -- the seller's inbox by tapping Request repeatedly.
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

-- respond_to_deal() v2 — 'accept'/'decline' are new and seller-only;
-- 'complete' stays seller-only; 'cancel' stays either-side.
--
-- System messages are now written with sender_id = null (see 0034's
-- messages change below) so the chat can render them as neutral system
-- lines instead of attributing "Deal cancelled." to whoever clicked.
create or replace function public.respond_to_deal(p_deal_id uuid, p_action text)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_deal deals%rowtype;
  v_listing listings%rowtype;
  v_is_seller boolean;
  v_system_message text;
  v_notify uuid;
  v_notify_title text;
begin
  if auth.uid() is null then
    raise exception 'AUTH_REQUIRED';
  end if;

  select * into v_deal from deals where id = p_deal_id for update;
  if v_deal.id is null then
    raise exception 'DEAL_NOT_FOUND';
  end if;

  select * into v_listing from listings where id = v_deal.listing_id for update;

  v_is_seller := v_listing.pharmacy_id = auth.uid();
  if not (v_is_seller or v_deal.counterpart_pharmacy_id = auth.uid()) then
    raise exception 'DEAL_NOT_PARTICIPANT';
  end if;

  v_notify := case when v_is_seller then v_deal.counterpart_pharmacy_id else v_listing.pharmacy_id end;

  if p_action = 'accept' then
    if not v_is_seller then raise exception 'DEAL_SELLER_ONLY'; end if;
    if v_deal.state <> 'pending' then raise exception 'DEAL_NOT_PENDING'; end if;
    if v_listing.state <> 'available' then raise exception 'LISTING_UNAVAILABLE'; end if;

    update deals
      set state = 'accepted',
          responded_at = now(),
          expires_at = now() + deal_reservation_window()
      where id = p_deal_id;

    update listings
      set state = 'reserved',
          reserved_until = now() + deal_reservation_window()
      where id = v_deal.listing_id;

    -- Everyone else queued on this listing is now out.
    update deals
      set state = 'declined', responded_at = now(), expires_at = null
      where listing_id = v_deal.listing_id
        and id <> p_deal_id
        and state = 'pending';

    insert into notifications (pharmacy_id, kind, title, body, deal_id)
    select counterpart_pharmacy_id, 'deal_declined', 'Request declined',
           'The seller accepted another request for this listing.', id
    from deals
    where listing_id = v_deal.listing_id and id <> p_deal_id
      and state = 'declined' and responded_at >= now() - interval '1 second';

    v_system_message := 'Request accepted — the listing is now reserved for you.';
    v_notify_title := 'Request accepted';

  elsif p_action = 'decline' then
    if not v_is_seller then raise exception 'DEAL_SELLER_ONLY'; end if;
    if v_deal.state <> 'pending' then raise exception 'DEAL_NOT_PENDING'; end if;

    update deals set state = 'declined', responded_at = now(), expires_at = null where id = p_deal_id;
    v_system_message := 'Request declined.';
    v_notify_title := 'Request declined';

  elsif p_action = 'complete' then
    if not v_is_seller then raise exception 'DEAL_SELLER_ONLY'; end if;
    if v_deal.state <> 'accepted' then raise exception 'DEAL_NOT_ACTIVE'; end if;

    update deals set state = 'completed', completed_at = now(), expires_at = null where id = p_deal_id;
    update listings set state = 'completed', reserved_until = null where id = v_deal.listing_id;
    v_system_message := 'Deal marked complete.';
    v_notify_title := 'Deal completed';

  elsif p_action = 'cancel' then
    if v_deal.state not in ('pending','accepted') then raise exception 'DEAL_NOT_ACTIVE'; end if;

    update deals set state = 'cancelled', expires_at = null where id = p_deal_id;
    -- Only an accepted deal ever reserved the listing, so only that one
    -- has anything to hand back.
    if v_deal.state = 'accepted' then
      update listings set state = 'available', reserved_until = null where id = v_deal.listing_id;
    end if;
    v_system_message := 'Deal cancelled.';
    v_notify_title := 'Deal cancelled';

  else
    raise exception 'DEAL_UNKNOWN_ACTION';
  end if;

  insert into messages (deal_id, sender_id, body, is_system)
  values (p_deal_id, null, v_system_message, true);

  insert into notifications (pharmacy_id, kind, title, body, deal_id)
  values (v_notify, 'deal_' || p_action, v_notify_title, v_system_message, p_deal_id);
end;
$$;

grant execute on function public.request_listing(uuid, text) to authenticated;
grant execute on function public.respond_to_deal(uuid, text) to authenticated;

-- get_my_deals / get_deal_detail: deal_state changes type, and both gain
-- expires_at so the client can show the countdown. Table-returning
-- functions can't change their output columns via CREATE OR REPLACE.
drop function if exists public.get_my_deals();
drop function if exists public.get_deal_detail(uuid);

create function public.get_my_deals()
returns table (
  deal_id uuid,
  listing_id uuid,
  drug_trade_name text,
  listing_type listing_type,
  deal_state deal_status,
  is_seller boolean,
  counterpart_id uuid,
  counterpart_name text,
  last_message text,
  last_message_at timestamptz,
  expires_at timestamptz,
  unread_count int,
  created_at timestamptz
)
language sql
security definer
set search_path = public
stable
as $$
  select
    d.id,
    d.listing_id,
    dr.trade_name,
    l.type,
    d.state,
    (l.pharmacy_id = auth.uid()),
    case when l.pharmacy_id = auth.uid() then d.counterpart_pharmacy_id else l.pharmacy_id end,
    cp.name,
    lm.body,
    lm.created_at,
    d.expires_at,
    coalesce(un.c, 0)::int,
    d.created_at
  from deals d
  join listings l on l.id = d.listing_id
  join drugs dr on dr.id = l.drug_id
  join pharmacies cp on cp.id = (case when l.pharmacy_id = auth.uid() then d.counterpart_pharmacy_id else l.pharmacy_id end)
  left join lateral (
    select body, created_at from messages m where m.deal_id = d.id order by m.created_at desc limit 1
  ) lm on true
  left join lateral (
    select count(*) as c from notifications n
    where n.deal_id = d.id and n.pharmacy_id = auth.uid() and not n.read
  ) un on true
  where l.pharmacy_id = auth.uid() or d.counterpart_pharmacy_id = auth.uid()
  order by coalesce(lm.created_at, d.created_at) desc;
$$;

create function public.get_deal_detail(p_deal_id uuid)
returns table (
  deal_id uuid,
  listing_id uuid,
  drug_trade_name text,
  listing_type listing_type,
  quantity int,
  deal_state deal_status,
  is_seller boolean,
  counterpart_id uuid,
  counterpart_name text,
  expires_at timestamptz,
  created_at timestamptz
)
language sql
security definer
set search_path = public
stable
as $$
  select
    d.id, d.listing_id, dr.trade_name, l.type, l.quantity, d.state,
    (l.pharmacy_id = auth.uid()),
    case when l.pharmacy_id = auth.uid() then d.counterpart_pharmacy_id else l.pharmacy_id end,
    cp.name,
    d.expires_at,
    d.created_at
  from deals d
  join listings l on l.id = d.listing_id
  join drugs dr on dr.id = l.drug_id
  join pharmacies cp on cp.id = (case when l.pharmacy_id = auth.uid() then d.counterpart_pharmacy_id else l.pharmacy_id end)
  where d.id = p_deal_id
    and (l.pharmacy_id = auth.uid() or d.counterpart_pharmacy_id = auth.uid());
$$;

grant execute on function public.get_my_deals() to authenticated;
grant execute on function public.get_deal_detail(uuid) to authenticated;

-- submit_rating / get_my_home_stats referenced the old enum value by
-- name; 'completed' survives the rename so only the comparison operand's
-- type changes, but both are recreated here so their plans are rebuilt
-- against deal_status rather than silently depending on a cast.
create or replace function public.submit_rating(
  p_deal_id uuid,
  p_stars int,
  p_credibility int default null,
  p_responsiveness int default null,
  p_packaging int default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_deal deals%rowtype;
  v_listing listings%rowtype;
  v_ratee uuid;
begin
  if p_stars is null or p_stars < 1 or p_stars > 5 then
    raise exception 'RATING_INVALID_STARS';
  end if;

  select * into v_deal from deals where id = p_deal_id;
  if v_deal.id is null then
    raise exception 'DEAL_NOT_FOUND';
  end if;

  select * into v_listing from listings where id = v_deal.listing_id;

  if not (v_listing.pharmacy_id = auth.uid() or v_deal.counterpart_pharmacy_id = auth.uid()) then
    raise exception 'DEAL_NOT_PARTICIPANT';
  end if;
  if v_deal.state <> 'completed' then
    raise exception 'RATING_DEAL_NOT_COMPLETED';
  end if;

  v_ratee := case when v_listing.pharmacy_id = auth.uid() then v_deal.counterpart_pharmacy_id else v_listing.pharmacy_id end;

  insert into ratings (deal_id, rater_id, stars, credibility, responsiveness, packaging)
  values (p_deal_id, auth.uid(), p_stars, p_credibility, p_responsiveness, p_packaging);

  insert into notifications (pharmacy_id, kind, title, body, deal_id)
  values (v_ratee, 'new_rating', 'New rating received', p_stars || ' star rating received', p_deal_id);
end;
$$;

grant execute on function public.submit_rating(uuid, int, int, int, int) to authenticated;

-- notify_new_message() v2. Two fixes:
--
-- 1. It now skips system messages. respond_to_deal() writes its own,
--    better-titled notification for every transition, and the system
--    message it also posts would otherwise trigger a second, duplicate
--    "New message" notification with sender_id = null resolving the
--    recipient to the wrong party.
-- 2. It collapses consecutive unread messages in the same thread into one
--    notification row. Previously every single chat message inserted a
--    row, so notifications grew 1:1 with chat volume forever — and the
--    unread badge is computed from that table. A thread where someone
--    sends 40 messages produced 40 rows and a badge reading "40" for one
--    conversation. Now the first unread message in a thread creates the
--    row and later ones just refresh its preview text and timestamp.
create or replace function public.notify_new_message()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_listing_owner uuid;
  v_counterpart uuid;
  v_recipient uuid;
  v_existing uuid;
begin
  if new.is_system then
    return new;
  end if;

  select l.pharmacy_id, d.counterpart_pharmacy_id
    into v_listing_owner, v_counterpart
  from deals d
  join listings l on l.id = d.listing_id
  where d.id = new.deal_id;

  v_recipient := case when new.sender_id = v_listing_owner then v_counterpart else v_listing_owner end;
  if v_recipient is null then
    return new;
  end if;

  select id into v_existing
  from notifications
  where pharmacy_id = v_recipient
    and deal_id = new.deal_id
    and kind = 'new_message'
    and not read
  limit 1;

  if v_existing is not null then
    update notifications
      set body = left(new.body, 120), created_at = now()
      where id = v_existing;
  else
    insert into notifications (pharmacy_id, kind, title, body, deal_id)
    values (v_recipient, 'new_message', 'New message', left(new.body, 120), new.deal_id);
  end if;

  return new;
end;
$$;

-- ============================================================
-- 0036_listing_integrity.sql
-- ============================================================

-- Listing integrity: the volatile CHECK time bomb, editing, deleting, and
-- expired stock still being on sale.

-- ---------------------------------------------------------------------
-- 1. The volatile CHECK constraint.
--
-- 0029 left listings with `check (expiry_date > current_date)`. A CHECK is
-- re-evaluated on every UPDATE of the row, not just on INSERT, and
-- current_date moves — so a listing that was perfectly valid when created
-- silently becomes a row that violates its own table constraint the day it
-- expires. From that moment *every* write to it fails: the seller can't
-- edit the price, request_listing() can't reserve it, respond_to_deal()
-- can't cancel it. The row is frozen with a raw Postgres error.
--
-- Two listings in the database were already in this state.
--
-- Replaced with a BEFORE INSERT trigger, which enforces exactly the rule
-- that was intended ("you can't list already-expired stock") without
-- re-litigating it on every subsequent write.
-- ---------------------------------------------------------------------
alter table listings drop constraint if exists listings_expiry_date_check;

create or replace function public.listings_check_expiry_on_insert()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  if new.expiry_date <= current_date then
    raise exception 'LISTING_EXPIRY_IN_PAST';
  end if;
  return new;
end;
$$;

create trigger trg_listings_check_expiry
  before insert on listings
  for each row execute function listings_check_expiry_on_insert();

-- ---------------------------------------------------------------------
-- 2. Value sanity. `price` had no constraint at all, so zero and negative
-- prices were insertable — and get_price_increased_listings() divides by
-- the previous price, so a single 0.00 in the history table was a
-- division-by-zero away from breaking the Home screen for everyone.
-- ---------------------------------------------------------------------
alter table listings add constraint listings_price_positive
  check (price is null or price > 0);

alter table listings add constraint listings_discount_price_positive
  check (discount_price is null or discount_price > 0);

alter table listings add constraint listings_quantity_sane
  check (quantity > 0 and quantity <= 1000000);

alter table listings add column updated_at timestamptz not null default now();

create or replace function public.touch_updated_at()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

create trigger trg_listings_touch_updated_at
  before update on listings
  for each row execute function touch_updated_at();

-- ---------------------------------------------------------------------
-- 3. Freezing a listing that's under negotiation.
--
-- Nothing stopped a seller updating price while state = 'reserved'. Agree
-- 1000 EGP in chat, then quietly change the listing — the buyer's detail
-- screen re-reads it and the number has moved. (It also wrote a new
-- listing_price_history row, which fed straight into the "price increased"
-- Home row.) Terminal-state listings are frozen outright.
-- ---------------------------------------------------------------------
create or replace function public.listings_guard_updates()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  -- State transitions themselves come from the security-definer deal RPCs
  -- and the sweep job; those are allowed through.
  if new.state is distinct from old.state then
    return new;
  end if;

  if old.state in ('completed','cancelled') then
    raise exception 'LISTING_FROZEN';
  end if;

  if old.state = 'reserved' and (
       new.price is distinct from old.price
    or new.discount_price is distinct from old.discount_price
    or new.quantity is distinct from old.quantity
    or new.expiry_date is distinct from old.expiry_date
    or new.drug_id is distinct from old.drug_id
    or new.type is distinct from old.type
  ) then
    raise exception 'LISTING_RESERVED_NO_EDIT';
  end if;

  return new;
end;
$$;

create trigger trg_listings_guard_updates
  before update on listings
  for each row execute function listings_guard_updates();

-- ---------------------------------------------------------------------
-- 4. Editing and deleting.
--
-- The app could only ever change price/discount_price, via a direct
-- PostgREST update from the listing detail screen. Quantity, expiry, type,
-- description and photo were immutable once created, and there was no
-- DELETE policy on listings at all — so a listing created with the wrong
-- quantity or a typo'd expiry was permanently wrong and permanently
-- public, with no way for the seller to take it down.
--
-- update_my_listing() covers the editable fields in one validated call.
-- delete_my_listing() hard-deletes when nothing references the listing and
-- otherwise cancels it (deals/favorites/price history hold FKs, so a real
-- DELETE would either fail or need cascades that would erase deal history).
-- ---------------------------------------------------------------------
create or replace function public.update_my_listing(
  p_listing_id uuid,
  p_quantity int default null,
  p_expiry_date date default null,
  p_price numeric default null,
  p_discount_price numeric default null,
  p_description text default null,
  p_photo_url text default null,
  p_clear_discount boolean default false,
  p_clear_photo boolean default false
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_listing listings%rowtype;
  v_new_price numeric;
  v_new_discount numeric;
begin
  select * into v_listing from listings where id = p_listing_id for update;
  if v_listing.id is null then
    raise exception 'LISTING_NOT_FOUND';
  end if;
  if v_listing.pharmacy_id <> auth.uid() then
    raise exception 'LISTING_NOT_OWNER';
  end if;
  if v_listing.state <> 'available' then
    raise exception 'LISTING_NOT_EDITABLE';
  end if;

  if p_expiry_date is not null and p_expiry_date <= current_date then
    raise exception 'LISTING_EXPIRY_IN_PAST';
  end if;
  if p_quantity is not null and (p_quantity <= 0 or p_quantity > 1000000) then
    raise exception 'LISTING_QUANTITY_INVALID';
  end if;

  v_new_price := coalesce(p_price, v_listing.price);
  v_new_discount := case when p_clear_discount then null else coalesce(p_discount_price, v_listing.discount_price) end;

  if v_new_price is not null and v_new_price <= 0 then
    raise exception 'LISTING_PRICE_INVALID';
  end if;
  if v_new_discount is not null and (v_new_price is null or v_new_discount > v_new_price) then
    raise exception 'LISTING_DISCOUNT_INVALID';
  end if;

  update listings set
    quantity = coalesce(p_quantity, quantity),
    expiry_date = coalesce(p_expiry_date, expiry_date),
    price = v_new_price,
    discount_price = v_new_discount,
    description = coalesce(p_description, description),
    photo_url = case when p_clear_photo then null else coalesce(p_photo_url, photo_url) end
  where id = p_listing_id;
end;
$$;

grant execute on function public.update_my_listing(uuid, int, date, numeric, numeric, text, text, boolean, boolean) to authenticated;

create or replace function public.delete_my_listing(p_listing_id uuid)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  v_listing listings%rowtype;
  v_has_deals boolean;
begin
  select * into v_listing from listings where id = p_listing_id for update;
  if v_listing.id is null then
    raise exception 'LISTING_NOT_FOUND';
  end if;
  if v_listing.pharmacy_id <> auth.uid() then
    raise exception 'LISTING_NOT_OWNER';
  end if;

  select exists (select 1 from deals where listing_id = p_listing_id and state in ('pending','accepted'))
    into v_has_deals;
  if v_has_deals then
    raise exception 'LISTING_HAS_ACTIVE_DEAL';
  end if;

  if exists (select 1 from deals where listing_id = p_listing_id) then
    -- Deal history references it; cancelling preserves that history while
    -- taking the listing out of the marketplace.
    update listings set state = 'cancelled', reserved_until = null where id = p_listing_id;
    return 'cancelled';
  end if;

  delete from favorites where listing_id = p_listing_id;
  delete from listing_price_history where listing_id = p_listing_id;
  delete from notifications where listing_id = p_listing_id;
  delete from listings where id = p_listing_id;
  return 'deleted';
end;
$$;

grant execute on function public.delete_my_listing(uuid) to authenticated;

-- ---------------------------------------------------------------------
-- 5. Expired stock was still on sale.
--
-- search_listings filtered on state = 'available' but never on
-- expiry_date, so a listing whose medicine expired yesterday stayed in the
-- feed indefinitely. Two such listings were live. Same fix on the
-- favourites RPC, which shows saved listings in any state.
--
-- Signature and output columns are unchanged, so CREATE OR REPLACE is
-- enough here; the stale pre-0030 overload is dropped in 0040.
-- ---------------------------------------------------------------------
create or replace function public.search_listings(
  p_trade_name text default null,
  p_active_ingredient text default null,
  p_concentration text default null,
  p_type listing_type default null,
  p_governorate text default null,
  p_expiry_before date default null,
  p_lat double precision default null,
  p_lng double precision default null,
  p_exclude_pharmacy_id uuid default null,
  p_limit int default 20,
  p_offset int default 0,
  p_max_distance_km double precision default null
)
returns table (
  listing_id uuid,
  drug_id uuid,
  trade_name text,
  active_ingredient text,
  concentration text,
  is_controlled boolean,
  listing_type listing_type,
  quantity int,
  price numeric,
  discount_price numeric,
  expiry_date date,
  listing_state listing_state,
  accepted_alternatives uuid[],
  photo_url text,
  created_at timestamptz,
  pharmacy_id uuid,
  pharmacy_name text,
  governorate text,
  area text,
  pharmacy_lat double precision,
  pharmacy_lng double precision,
  distance_km double precision
)
language sql
security definer
set search_path = public, extensions
stable
as $$
  select
    l.id, l.drug_id, d.trade_name, d.active_ingredient, d.concentration, d.is_controlled,
    l.type, l.quantity, l.price, l.discount_price, l.expiry_date, l.state, l.accepted_alternatives, l.photo_url, l.created_at,
    l.pharmacy_id, p.name, p.governorate, p.area, p.lat, p.lng,
    case when p_lat is not null and p_lng is not null
      then ST_Distance(p.location, ST_SetSRID(ST_MakePoint(p_lng, p_lat), 4326)::geography) / 1000.0
      else null end as distance_km
  from listings l
  join drugs d on d.id = l.drug_id
  join pharmacies p on p.id = l.pharmacy_id
  where l.state = 'available'
    and l.expiry_date > current_date
    and p.status = 'approved'
    and (p_exclude_pharmacy_id is null or l.pharmacy_id <> p_exclude_pharmacy_id)
    and (p_trade_name is null or d.trade_name ilike '%' || p_trade_name || '%')
    and (p_active_ingredient is null or d.active_ingredient ilike '%' || p_active_ingredient || '%')
    and (p_concentration is null or d.concentration ilike '%' || p_concentration || '%')
    and (p_type is null or l.type = p_type)
    and (p_governorate is null or p.governorate = p_governorate)
    and (p_expiry_before is null or l.expiry_date <= p_expiry_before)
    and (
      p_max_distance_km is null or p_lat is null or p_lng is null
      or ST_DWithin(p.location, ST_SetSRID(ST_MakePoint(p_lng, p_lat), 4326)::geography, p_max_distance_km * 1000.0)
    )
  order by
    case when p_lat is not null and p_lng is not null
      then ST_Distance(p.location, ST_SetSRID(ST_MakePoint(p_lng, p_lat), 4326)::geography) end asc nulls last,
    l.created_at desc
  limit p_limit offset p_offset;
$$;

grant execute on function public.search_listings(
  text, text, text, listing_type, text, date, double precision, double precision, uuid, int, int, double precision
) to authenticated;

-- get_price_increased_listings(): same expiry/approval filter, plus the
-- division-by-zero guard on previous.price.
create or replace function public.get_price_increased_listings(
  p_limit int default 10,
  p_exclude_pharmacy_id uuid default null
)
returns table (
  listing_id uuid,
  trade_name text,
  photo_url text,
  price numeric,
  previous_price numeric,
  pct_increase numeric,
  pharmacy_name text,
  governorate text
)
language sql
security definer
set search_path = public
stable
as $$
  with ranked as (
    select
      h.listing_id,
      h.price,
      h.recorded_at,
      row_number() over (partition by h.listing_id order by h.recorded_at desc) as rn
    from listing_price_history h
  ),
  latest as (select listing_id, price, recorded_at from ranked where rn = 1),
  previous as (select listing_id, price from ranked where rn = 2)
  select
    l.id, d.trade_name, l.photo_url, latest.price, previous.price,
    round(((latest.price - previous.price) / previous.price) * 100, 1) as pct_increase,
    p.name, p.governorate
  from latest
  join previous on previous.listing_id = latest.listing_id
  join listings l on l.id = latest.listing_id
  join drugs d on d.id = l.drug_id
  join pharmacies p on p.id = l.pharmacy_id
  where l.state = 'available'
    and l.expiry_date > current_date
    and p.status = 'approved'
    and previous.price > 0
    and latest.price > previous.price
    and (p_exclude_pharmacy_id is null or l.pharmacy_id <> p_exclude_pharmacy_id)
  order by pct_increase desc
  limit p_limit;
$$;

grant execute on function public.get_price_increased_listings(int, uuid) to authenticated;

-- ============================================================
-- 0037_controlled_substance_enforcement.sql
-- ============================================================

-- Controlled substances: the block was client-side only, and trivially
-- bypassable without any hacking at all.
--
-- HOW IT FAILED:
--
-- The only thing standing between a pharmacy and a controlled-substance
-- listing was `isControlledBlocked` in add_listing_data.dart, which greys
-- out the submit button. Nothing on the server checked anything — the
-- listings INSERT policy never looked at drugs.is_controlled.
--
-- Worse, find_or_create_drug() — the function every self-service listing
-- goes through — hardcoded `is_controlled = false` on every row it
-- created. drug_catalog has no is_controlled column to inherit from, so a
-- pharmacist typing a trade name whose exact (name, concentration) pair
-- wasn't already a `drugs` row got a brand-new drug flagged uncontrolled,
-- and the client-side block then had nothing to fire on. Typing
-- "Tramadol 225mg" was enough. No API calls, no tampering — just typing.
--
-- THE FIX: a term list, applied at the one place drugs are created, and a
-- trigger on listings so the marketplace rule is enforced by the database
-- rather than by a disabled button.

create table controlled_substance_terms (
  id uuid primary key default gen_random_uuid(),
  term text not null unique,
  note text,
  created_at timestamptz not null default now()
);

alter table controlled_substance_terms enable row level security;

create policy "controlled_substance_terms: public read"
  on controlled_substance_terms for select using (true);

create policy "controlled_substance_terms: admin write"
  on controlled_substance_terms for all using (is_admin()) with check (is_admin());

-- Narcotics and psychotropics scheduled under Egyptian Law 182/1960 and
-- its later amendments, plus the trade names those are actually sold under
-- locally. Deliberately errs toward over-matching: a false positive costs
-- a pharmacy one support ticket, a false negative puts a scheduled
-- substance on an open B2B marketplace. Admins can curate the list from
-- the dashboard.
insert into controlled_substance_terms (term, note) values
  ('tramadol', 'opioid'), ('tramal', 'tramadol'), ('contramal', 'tramadol'),
  ('amadol', 'tramadol'), ('tramax', 'tramadol'), ('ultracet', 'tramadol combo'),
  ('tapentadol', 'opioid'), ('nucynta', 'tapentadol'),
  ('codeine', 'opioid'), ('kodein', 'codeine'),
  ('morphine', 'opioid'), ('morphin', 'opioid'),
  ('pethidine', 'opioid'), ('meperidine', 'pethidine'),
  ('fentanyl', 'opioid'), ('oxycodone', 'opioid'), ('methadone', 'opioid'),
  ('buprenorphine', 'opioid'), ('pentazocine', 'opioid'), ('nalbuphine', 'opioid'),
  ('alprazolam', 'benzodiazepine'), ('xanax', 'alprazolam'),
  ('diazepam', 'benzodiazepine'), ('valium', 'diazepam'), ('neuril', 'diazepam'),
  ('clonazepam', 'benzodiazepine'), ('rivotril', 'clonazepam'),
  ('apetryl', 'clonazepam'), ('amotril', 'clonazepam'),
  ('lorazepam', 'benzodiazepine'), ('ativan', 'lorazepam'),
  ('bromazepam', 'benzodiazepine'), ('calmepam', 'bromazepam'), ('lexotanil', 'bromazepam'),
  ('midazolam', 'benzodiazepine'), ('dormicum', 'midazolam'),
  ('nitrazepam', 'benzodiazepine'), ('mogadon', 'nitrazepam'),
  ('chlordiazepoxide', 'benzodiazepine'), ('librax', 'chlordiazepoxide'), ('epicotil', 'chlordiazepoxide'),
  ('clobazam', 'benzodiazepine'), ('frisium', 'clobazam'),
  ('flurazepam', 'benzodiazepine'), ('triazolam', 'benzodiazepine'), ('temazepam', 'benzodiazepine'),
  ('zolpidem', 'z-drug'), ('stilnox', 'zolpidem'), ('zolam', 'zolpidem'),
  ('phenobarbital', 'barbiturate'), ('luminal', 'phenobarbital'), ('somnaletten', 'phenobarbital'),
  ('barbital', 'barbiturate'), ('thiopental', 'barbiturate'),
  ('methylphenidate', 'stimulant'), ('ritalin', 'methylphenidate'), ('concerta', 'methylphenidate'),
  ('amphetamine', 'stimulant'), ('dexamphetamine', 'stimulant'),
  ('pregabalin', 'scheduled in Egypt since 2019'), ('lyrica', 'pregabalin'),
  ('ketamine', 'dissociative'), ('ketalar', 'ketamine'),
  ('carisoprodol', 'muscle relaxant, scheduled'), ('somadril', 'carisoprodol'),
  ('trihexyphenidyl', 'anticholinergic, scheduled'), ('parkinol', 'trihexyphenidyl'),
  ('flunitrazepam', 'benzodiazepine'), ('rohypnol', 'flunitrazepam')
on conflict (term) do nothing;

-- is_controlled_name() — the single place the matching rule lives, so the
-- drug-creation path and the admin re-scan below can't diverge.
create or replace function public.is_controlled_name(p_name text, p_ingredient text default null)
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select exists (
    select 1 from controlled_substance_terms t
    where lower(coalesce(p_name, '')) like '%' || t.term || '%'
       or lower(coalesce(p_ingredient, '')) like '%' || t.term || '%'
  );
$$;

grant execute on function public.is_controlled_name(text, text) to authenticated;

-- Re-flag everything already in `drugs`. Rows created through the old
-- find_or_create_drug() are all sitting at is_controlled = false
-- regardless of what they actually are.
update drugs
set is_controlled = true
where not is_controlled
  and is_controlled_name(trade_name, active_ingredient);

-- find_or_create_drug() v3 — the one-line fix that matters: is_controlled
-- is now derived from the name instead of hardcoded false. Also stops
-- silently reusing a row whose controlled status has since been corrected.
create or replace function public.find_or_create_drug(
  p_trade_name text,
  p_concentration text default null,
  p_company text default null,
  p_pharmaceutical_form text default null
)
returns table (
  id uuid,
  trade_name text,
  active_ingredient text,
  concentration text,
  company text,
  pharmaceutical_form text,
  is_controlled boolean
)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_id uuid;
  v_controlled boolean;
begin
  if auth.uid() is null then
    raise exception 'AUTH_REQUIRED';
  end if;
  if trim(coalesce(p_trade_name, '')) = '' then
    raise exception 'DRUG_NAME_REQUIRED';
  end if;
  if length(trim(p_trade_name)) > 200 then
    raise exception 'DRUG_NAME_TOO_LONG';
  end if;

  v_controlled := is_controlled_name(trim(p_trade_name), null);

  select d.id into v_id
  from drugs d
  where lower(d.trade_name) = lower(trim(p_trade_name))
    and coalesce(lower(d.concentration), '') = coalesce(lower(trim(p_concentration)), '')
  limit 1;

  if v_id is null then
    insert into drugs (trade_name, concentration, company, pharmaceutical_form, is_controlled, is_pending)
    values (
      trim(p_trade_name),
      nullif(trim(coalesce(p_concentration, '')), ''),
      nullif(trim(coalesce(p_company, '')), ''),
      nullif(trim(coalesce(p_pharmaceutical_form, '')), ''),
      v_controlled,
      true
    )
    returning drugs.id into v_id;
  else
    update drugs
    set company = coalesce(drugs.company, nullif(trim(coalesce(p_company, '')), '')),
        pharmaceutical_form = coalesce(drugs.pharmaceutical_form, nullif(trim(coalesce(p_pharmaceutical_form, '')), '')),
        -- Only ever escalates. An admin who has deliberately cleared the
        -- flag on a false positive shouldn't have it set again by the next
        -- pharmacy that types the name.
        is_controlled = drugs.is_controlled or v_controlled
    where drugs.id = v_id;
  end if;

  return query
  select d.id, d.trade_name, d.active_ingredient, d.concentration, d.company, d.pharmaceutical_form, d.is_controlled
  from drugs d where d.id = v_id;
end;
$$;

-- The enforcement itself. Even with the drug correctly flagged, nothing
-- stopped a direct PostgREST insert; the client-side disabled button was
-- the whole control. This is the rule the app was always supposed to have.
create or replace function public.listings_block_controlled()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_controlled boolean;
begin
  select is_controlled into v_controlled from drugs where id = new.drug_id;

  if coalesce(v_controlled, false) then
    insert into compliance_flags (pharmacy_id, drug_id, kind)
    values (new.pharmacy_id, new.drug_id, 'controlled_substance_listing_blocked');
    raise exception 'LISTING_CONTROLLED_SUBSTANCE';
  end if;

  return new;
end;
$$;

create trigger trg_listings_block_controlled
  before insert on listings
  for each row execute function listings_block_controlled();

-- Any listing already in the marketplace for a drug the re-scan above just
-- reclassified gets pulled. Cancelling rather than deleting keeps it
-- visible to the owner in My Listings (with a cancelled badge) and to
-- compliance, instead of vanishing silently.
with retired as (
  update listings l
  set state = 'cancelled', reserved_until = null
  from drugs d
  where d.id = l.drug_id
    and d.is_controlled
    and l.state in ('available','reserved')
  returning l.pharmacy_id, l.drug_id
)
insert into compliance_flags (pharmacy_id, drug_id, kind)
select pharmacy_id, drug_id, 'controlled_substance_listing_retired' from retired;

-- Any live deal on a listing that just got pulled is dead too.
update deals set state = 'cancelled', expires_at = null
where state in ('pending','accepted')
  and listing_id in (
    select l.id from listings l join drugs d on d.id = l.drug_id
    where d.is_controlled and l.state = 'cancelled'
  );

-- ============================================================
-- 0038_deal_expiry_sweep.sql
-- ============================================================

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

-- ============================================================
-- 0039_account_deletion_and_recovery.sql
-- ============================================================

-- Account deletion, and a way out of a half-finished registration.

-- ---------------------------------------------------------------------
-- 1. Orphaned registrations.
--
-- otp_verification_screen.dart does three things in sequence with no
-- transaction and no rollback: verify the OTP (at which point the
-- auth.users row exists and is signed in), upload the licence to Storage,
-- then insert the pharmacies row. If either of the last two fails — a
-- dropped connection on a slow mobile link is enough — the user is left
-- with a confirmed auth account and no pharmacy.
--
-- There was no way back. Registering again fails on "User already
-- registered", the upload wasn't an upsert so retrying 409s on the
-- existing object, and splash routes any session to /home where every
-- pharmacy-keyed query throws. One such account (walidmadany@hotmail.com)
-- was already sitting in the live database.
--
-- complete_my_registration() is the recovery path: it's idempotent, so
-- the app can safely call it on every attempt, and it's the same function
-- the normal first-time flow now uses.
-- ---------------------------------------------------------------------
create or replace function public.complete_my_registration(
  p_name text,
  p_governorate text,
  p_area text,
  p_address_text text,
  p_lat double precision,
  p_lng double precision,
  p_license_url text,
  -- pharmacies.license_expiry is NOT NULL from 0001_init.sql and nothing in
  -- the product reads it, so this is optional: the KYC wizard passes the
  -- date it already collects (behaviour unchanged), and the recovery flow —
  -- which has no wizard state to draw on — falls back to the placeholder.
  p_license_expiry date default date '2099-12-31'
)
returns pharmacy_status
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_email text;
  v_status pharmacy_status;
begin
  if v_uid is null then
    raise exception 'AUTH_REQUIRED';
  end if;

  select status into v_status from pharmacies where id = v_uid;
  if v_status is not null then
    -- Already registered. Idempotent by design: a retry after a network
    -- timeout that actually succeeded server-side must not error.
    return v_status;
  end if;

  if exists (select 1 from admins where id = v_uid) then
    raise exception 'ACCOUNT_IS_ADMIN';
  end if;

  if trim(coalesce(p_name, '')) = '' then raise exception 'PHARMACY_NAME_REQUIRED'; end if;
  if trim(coalesce(p_governorate, '')) = '' then raise exception 'GOVERNORATE_REQUIRED'; end if;
  if p_lat is null or p_lng is null then raise exception 'LOCATION_REQUIRED'; end if;
  if p_lat < 21 or p_lat > 32 or p_lng < 24 or p_lng > 37 then
    raise exception 'LOCATION_OUT_OF_BOUNDS';
  end if;
  if trim(coalesce(p_license_url, '')) = '' then raise exception 'LICENSE_REQUIRED'; end if;

  select email into v_email from auth.users where id = v_uid;
  if v_email is null then
    raise exception 'AUTH_REQUIRED';
  end if;

  insert into pharmacies (
    id, name, email, governorate, area, address_text,
    lat, lng, license_url, license_expiry, status
  ) values (
    v_uid, trim(p_name), v_email, trim(p_governorate), trim(coalesce(p_area, '')),
    trim(coalesce(p_address_text, '')), p_lat, p_lng, trim(p_license_url),
    coalesce(p_license_expiry, date '2099-12-31'),
    'pending'
  );

  return 'pending'::pharmacy_status;
end;
$$;

grant execute on function public.complete_my_registration(text, text, text, text, double precision, double precision, text, date) to authenticated;

-- ---------------------------------------------------------------------
-- 2. Account deletion.
--
-- There was no way to delete an account from inside the app at all. That
-- is a hard App Store rejection (Guideline 5.1.1(v), mandatory since 2022)
-- and a Play Store requirement, so the app could not have shipped.
--
-- Deal, rating and dispute history is referenced by the other party, so a
-- hard row delete would either fail on the foreign keys or erase the
-- counterparty's own transaction record. The pharmacy row is anonymised
-- instead — every piece of personal/business identifying data is cleared —
-- and the auth user is deleted so the account genuinely can't be used
-- again. That satisfies the stores' requirement (account gone, personal
-- data removed) without rewriting someone else's history.
-- ---------------------------------------------------------------------
create or replace function public.delete_my_account()
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null then
    raise exception 'AUTH_REQUIRED';
  end if;

  if exists (
    select 1 from deals d
    join listings l on l.id = d.listing_id
    where d.state in ('pending','accepted')
      and (l.pharmacy_id = v_uid or d.counterpart_pharmacy_id = v_uid)
  ) then
    raise exception 'ACCOUNT_HAS_ACTIVE_DEALS';
  end if;

  if exists (select 1 from disputes dp
             join deals d on d.id = dp.deal_id
             join listings l on l.id = d.listing_id
             where dp.status <> 'resolved'
               and (l.pharmacy_id = v_uid or d.counterpart_pharmacy_id = v_uid)) then
    raise exception 'ACCOUNT_HAS_OPEN_DISPUTES';
  end if;

  -- Take everything of theirs off the marketplace first.
  update listings set state = 'cancelled', reserved_until = null
  where pharmacy_id = v_uid and state in ('available','reserved');

  delete from device_push_tokens where pharmacy_id = v_uid;
  delete from favorites where pharmacy_id = v_uid;
  delete from listing_alerts where pharmacy_id = v_uid;
  delete from notifications where pharmacy_id = v_uid;

  -- Private KYC documents.
  delete from storage.objects
  where bucket_id = 'licenses' and (storage.foldername(name))[1] = v_uid::text;

  update pharmacies set
    name = 'Deleted pharmacy',
    email = 'deleted+' || v_uid::text || '@pharmaexchange.invalid',
    governorate = '',
    area = '',
    address_text = '',
    lat = 0,
    lng = 0,
    license_url = '',
    status = 'suspended',
    plan = 'free'
  where id = v_uid;

  delete from auth.users where id = v_uid;
end;
$$;

grant execute on function public.delete_my_account() to authenticated;

-- The anonymised row carries lat/lng 0,0, which is in the Gulf of Guinea —
-- it must never show up in a proximity search. Status is 'suspended' and
-- 0036 already filters search_listings on status = 'approved', so this is
-- belt-and-braces: their listings are cancelled above too.

-- ============================================================
-- 0040_hardening.sql
-- ============================================================

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
