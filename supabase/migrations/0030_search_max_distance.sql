-- search_listings: adds p_max_distance_km (default null = no cap), used by
-- the Search tab's "Nearest" toggle to cap results at 60km — plain
-- CREATE OR REPLACE, not drop+recreate, since this only appends a new
-- defaulted input parameter and doesn't touch the output columns.
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
