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
