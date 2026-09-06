-- Feed/search RPC: joins listings + drugs + a safe subset of pharmacies
-- columns (never email/address_text/lat/lng/license_url), so the client
-- never needs direct cross-pharmacy table reads. Bypasses pharmacies' RLS
-- deliberately, but only exposes what's already meant to be public here.
--
-- NOTE: verify which schema PostGIS actually lives in on the real project
-- (`select extnamespace::regnamespace from pg_extension where extname='postgis';`)
-- and adjust `set search_path` below if it isn't `extensions`.
create or replace function public.search_listings(
  p_search text default null,
  p_type listing_type default null,
  p_governorate text default null,
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
  is_controlled boolean,
  listing_type listing_type,
  quantity int,
  expiry_date date,
  listing_state listing_state,
  accepted_alternatives uuid[],
  photo_url text,
  created_at timestamptz,
  pharmacy_id uuid,
  pharmacy_name text,
  governorate text,
  area text,
  distance_km double precision
)
language sql
security definer
set search_path = public, extensions
stable
as $$
  select
    l.id, l.drug_id, d.trade_name, d.active_ingredient, d.is_controlled,
    l.type, l.quantity, l.expiry_date, l.state, l.accepted_alternatives, l.photo_url, l.created_at,
    l.pharmacy_id, p.name, p.governorate, p.area,
    case when p_lat is not null and p_lng is not null
      then ST_Distance(p.location, ST_SetSRID(ST_MakePoint(p_lng, p_lat), 4326)::geography) / 1000.0
      else null end as distance_km
  from listings l
  join drugs d on d.id = l.drug_id
  join pharmacies p on p.id = l.pharmacy_id
  where l.state = 'available'
    and (p_exclude_pharmacy_id is null or l.pharmacy_id <> p_exclude_pharmacy_id)
    and (p_search is null or d.trade_name ilike '%' || p_search || '%' or d.active_ingredient ilike '%' || p_search || '%')
    and (p_type is null or l.type = p_type)
    and (p_governorate is null or p.governorate = p_governorate)
  order by
    case when p_lat is not null and p_lng is not null
      then ST_Distance(p.location, ST_SetSRID(ST_MakePoint(p_lng, p_lat), 4326)::geography) end asc nulls last,
    l.created_at desc
  limit p_limit offset p_offset;
$$;

grant execute on function public.search_listings(
  text, listing_type, text, double precision, double precision, uuid, int, int
) to authenticated;

-- Single-listing detail: same safe-column contract, and manually replicates
-- the listings RLS visibility rule (available OR owned by caller) since a
-- security-definer function bypasses RLS.
create or replace function public.get_listing_detail(p_listing_id uuid)
returns table (
  listing_id uuid,
  drug_id uuid,
  trade_name text,
  active_ingredient text,
  is_controlled boolean,
  listing_type listing_type,
  quantity int,
  expiry_date date,
  listing_state listing_state,
  accepted_alternatives uuid[],
  photo_url text,
  created_at timestamptz,
  pharmacy_id uuid,
  pharmacy_name text,
  governorate text,
  area text
)
language sql
security definer
set search_path = public, extensions
stable
as $$
  select
    l.id, l.drug_id, d.trade_name, d.active_ingredient, d.is_controlled,
    l.type, l.quantity, l.expiry_date, l.state, l.accepted_alternatives, l.photo_url, l.created_at,
    l.pharmacy_id, p.name, p.governorate, p.area
  from listings l
  join drugs d on d.id = l.drug_id
  join pharmacies p on p.id = l.pharmacy_id
  where l.id = p_listing_id
    and (l.state = 'available' or l.pharmacy_id = auth.uid());
$$;

grant execute on function public.get_listing_detail(uuid) to authenticated;
