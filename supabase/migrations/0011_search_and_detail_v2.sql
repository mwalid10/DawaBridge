-- search_listings/get_listing_detail v2: adds price, discount_price,
-- concentration, and pharmacy_lat/pharmacy_lng (for the map view) to the
-- safe-column contract, and splits the old single p_search text into
-- p_trade_name/p_active_ingredient/p_concentration so the client can filter
-- each field independently; adds p_expiry_before. Postgres won't let
-- `create or replace function` change a table-returning function's output
-- columns, so both are dropped and recreated here rather than replaced.
--
-- Exposing pharmacy lat/lng here is a deliberate reversal of 0005's
-- comment ("never exposes... lat/lng"): a map/list toggle in search needs
-- per-listing coordinates, and pharmacies are businesses being marketed
-- for B2B discovery, not individuals, so approximate business location is
-- reasonable to surface alongside the governorate/area that's already public.

drop function if exists public.search_listings(text, listing_type, text, double precision, double precision, uuid, int, int);
drop function if exists public.get_listing_detail(uuid);

create function public.search_listings(
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
  p_offset int default 0
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
    and (p_exclude_pharmacy_id is null or l.pharmacy_id <> p_exclude_pharmacy_id)
    and (p_trade_name is null or d.trade_name ilike '%' || p_trade_name || '%')
    and (p_active_ingredient is null or d.active_ingredient ilike '%' || p_active_ingredient || '%')
    and (p_concentration is null or d.concentration ilike '%' || p_concentration || '%')
    and (p_type is null or l.type = p_type)
    and (p_governorate is null or p.governorate = p_governorate)
    and (p_expiry_before is null or l.expiry_date <= p_expiry_before)
  order by
    case when p_lat is not null and p_lng is not null
      then ST_Distance(p.location, ST_SetSRID(ST_MakePoint(p_lng, p_lat), 4326)::geography) end asc nulls last,
    l.created_at desc
  limit p_limit offset p_offset;
$$;

grant execute on function public.search_listings(
  text, text, text, listing_type, text, date, double precision, double precision, uuid, int, int
) to authenticated;

create function public.get_listing_detail(p_listing_id uuid)
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
  pharmacy_lng double precision
)
language sql
security definer
set search_path = public, extensions
stable
as $$
  select
    l.id, l.drug_id, d.trade_name, d.active_ingredient, d.concentration, d.is_controlled,
    l.type, l.quantity, l.price, l.discount_price, l.expiry_date, l.state, l.accepted_alternatives, l.photo_url, l.created_at,
    l.pharmacy_id, p.name, p.governorate, p.area, p.lat, p.lng
  from listings l
  join drugs d on d.id = l.drug_id
  join pharmacies p on p.id = l.pharmacy_id
  where l.id = p_listing_id
    and (l.state = 'available' or l.pharmacy_id = auth.uid());
$$;

grant execute on function public.get_listing_detail(uuid) to authenticated;

-- get_price_increased_listings() — for each available listing with at
-- least two recorded prices, compares the two most recent
-- listing_price_history rows and surfaces the ones whose price went up,
-- ranked by percentage increase. Powers the Home screen's "Price
-- Increased Items" row.
create function public.get_price_increased_listings(
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
    and latest.price > previous.price
    and (p_exclude_pharmacy_id is null or l.pharmacy_id <> p_exclude_pharmacy_id)
  order by pct_increase desc
  limit p_limit;
$$;

grant execute on function public.get_price_increased_listings(int, uuid) to authenticated;
