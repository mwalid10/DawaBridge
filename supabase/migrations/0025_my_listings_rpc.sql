-- get_my_listings() — a pharmacy's own listings across every state, not
-- just 'available'. search_listings (0011) always filters to
-- state = 'available' (it's the public browse feed), and the RLS policy
-- on `listings` already lets an owner read all their own rows regardless
-- of state, but nothing in the client surfaced that: there was no "my
-- listings" screen. Same column shape as search_listings/get_listing_detail
-- so the client can reuse ListingSummary/ListingCard as-is —
-- distance_km is always null here since sorting by distance from yourself
-- isn't meaningful.
create or replace function public.get_my_listings(p_state listing_state default null)
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
set search_path = public
stable
as $$
  select
    l.id, l.drug_id, d.trade_name, d.active_ingredient, d.concentration, d.is_controlled,
    l.type, l.quantity, l.price, l.discount_price, l.expiry_date, l.state, l.accepted_alternatives, l.photo_url, l.created_at,
    l.pharmacy_id, p.name, p.governorate, p.area, p.lat, p.lng,
    null::double precision as distance_km
  from listings l
  join drugs d on d.id = l.drug_id
  join pharmacies p on p.id = l.pharmacy_id
  where l.pharmacy_id = auth.uid()
    and (p_state is null or l.state = p_state)
  order by l.created_at desc;
$$;

grant execute on function public.get_my_listings(listing_state) to authenticated;
