-- favorites — a pharmacy's saved listings (the heart icon on the listing
-- detail screen). Composite primary key (pharmacy_id, listing_id) makes
-- toggling idempotent from the client: insert to favorite, delete to
-- unfavorite, no separate existence check needed before either.
create table favorites (
  pharmacy_id uuid not null references pharmacies(id),
  listing_id uuid not null references listings(id),
  created_at timestamptz not null default now(),
  primary key (pharmacy_id, listing_id)
);

alter table favorites enable row level security;

create policy "favorites: owner reads/writes own" on favorites
  for all using (pharmacy_id = auth.uid()) with check (pharmacy_id = auth.uid());

-- get_my_favorites() — same column shape as search_listings/get_my_listings
-- so the client reuses ListingSummary/ListingCard as-is. Favorited listings
-- are returned regardless of state (a listing can go reserved/completed/
-- cancelled after being favorited) — the favorites screen shows a state
-- badge the same way My Listings does. distance_km is always null, same
-- reasoning as get_my_listings.
create function public.get_my_favorites()
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
  from favorites f
  join listings l on l.id = f.listing_id
  join drugs d on d.id = l.drug_id
  join pharmacies p on p.id = l.pharmacy_id
  where f.pharmacy_id = auth.uid()
  order by f.created_at desc;
$$;

grant execute on function public.get_my_favorites() to authenticated;
