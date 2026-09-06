-- get_listing_detail(): adds company/pharmaceutical_form to the output so
-- the listing detail screen can show Manufacturer/Form rows — drugs already
-- carries both columns (0022_drug_catalog.sql), they just weren't exposed
-- here yet. Postgres won't let `create or replace function` change a
-- table-returning function's output columns, so it's dropped and recreated,
-- same as 0011 had to do for the same reason. search_listings/
-- get_my_listings/get_my_favorites are untouched — the mobile client only
-- needs this on the detail screen for now, and ListingSummary's new fields
-- are nullable so those other RPCs' rows keep parsing fine without it.

drop function if exists public.get_listing_detail(uuid);

create function public.get_listing_detail(p_listing_id uuid)
returns table (
  listing_id uuid,
  drug_id uuid,
  trade_name text,
  active_ingredient text,
  concentration text,
  company text,
  pharmaceutical_form text,
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
    l.id, l.drug_id, d.trade_name, d.active_ingredient, d.concentration, d.company, d.pharmaceutical_form, d.is_controlled,
    l.type, l.quantity, l.price, l.discount_price, l.expiry_date, l.state, l.accepted_alternatives, l.photo_url, l.created_at,
    l.pharmacy_id, p.name, p.governorate, p.area, p.lat, p.lng
  from listings l
  join drugs d on d.id = l.drug_id
  join pharmacies p on p.id = l.pharmacy_id
  where l.id = p_listing_id
    and (l.state = 'available' or l.pharmacy_id = auth.uid());
$$;

grant execute on function public.get_listing_detail(uuid) to authenticated;
