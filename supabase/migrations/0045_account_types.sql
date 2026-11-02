-- 0045 — a second customer type: warehouses.
--
-- The product launched pharmacy-only, so `pharmacies` is both "the account
-- table" and "the pharmacy table": listings.pharmacy_id,
-- deals.counterpart_pharmacy_id, ratings.rater_id, disputes.raised_by,
-- favorites, notifications and messages all reference it, and every RLS
-- policy keys on it. A warehouse is a different *kind* of account, not a
-- different kind of entity — it registers the same way, is approved the
-- same way, lists, deals, chats and is rated the same way. So this adds a
-- discriminator column rather than a parallel table: a second table would
-- have meant a nullable FK pair (or a polymorphic id) on nine tables and a
-- rewrite of every policy, to express something that is one column.
--
-- The table keeps its name. Renaming it would touch all 44 migrations
-- before this one plus every RPC return shape the client parses, for no
-- behavioural gain; the column comment below records the widened meaning.
-- ---------------------------------------------------------------------------

create type account_type as enum ('pharmacy', 'warehouse');

alter table pharmacies
  add column account_type account_type not null default 'pharmacy';

comment on table pharmacies is
  'Marketplace accounts. Named for the original pharmacy-only product; '
  'account_type discriminates pharmacies from warehouses (migration 0045).';
comment on column pharmacies.account_type is
  'What kind of business this account is. Set once at registration and '
  'only changeable by an admin editor — see trg_pharmacies_guard_account_type.';

-- Search filters on it, and the admin dashboard segments the KYC queue by
-- it. Low cardinality, but both queries also filter on status, so the
-- composite is what actually gets used.
create index idx_pharmacies_account_type on pharmacies (account_type, status);

-- ---------------------------------------------------------------------------
-- Account type is not self-service.
--
-- "pharmacies read/update own row" (0001_init.sql) is `for all`, so without
-- this an approved pharmacy could PATCH itself into a warehouse after KYC —
-- the licence on file would then be the wrong kind of licence for what the
-- account claims to be. Same shape as trg_pharmacies_guard_plan_changes
-- from 0044: RLS can't separate columns, a column-aware trigger can, and
-- service-role/cron (auth.uid() null) keeps the access it had.
-- ---------------------------------------------------------------------------

create or replace function public.pharmacies_guard_account_type()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.account_type is distinct from old.account_type
     and auth.uid() is not null
     and not is_admin_editor() then
    raise exception 'ACCOUNT_TYPE_LOCKED';
  end if;
  return new;
end;
$$;

revoke execute on function public.pharmacies_guard_account_type() from public, anon, authenticated;

create trigger trg_pharmacies_guard_account_type
  before update of account_type on pharmacies
  for each row execute function pharmacies_guard_account_type();

-- ---------------------------------------------------------------------------
-- get_my_status() — the client's router guard. `role` deliberately stays
-- 'pharmacy' for both kinds: it answers "does this session have a
-- marketplace account" and every routing rule built on it is unchanged.
-- The new column is what the app needs to word its own screens.
-- ---------------------------------------------------------------------------

drop function if exists public.get_my_status();

create function public.get_my_status()
returns table (
  role text,
  status pharmacy_status,
  account_type account_type
)
language sql
security definer
set search_path = public
stable
as $$
  select
    case
      when exists (select 1 from admins where id = auth.uid()) then 'admin'
      when exists (select 1 from pharmacies where id = auth.uid()) then 'pharmacy'
      when auth.uid() is null then 'anonymous'
      else 'none'
    end,
    (select status from pharmacies where id = auth.uid()),
    (select p.account_type from pharmacies p where p.id = auth.uid());
$$;

grant execute on function public.get_my_status() to authenticated;

-- ---------------------------------------------------------------------------
-- complete_my_registration() — now takes the type the applicant picked in
-- the wizard's first step. Defaulted, so the recovery path and any caller
-- that hasn't been updated still lands a pharmacy (the pre-0045
-- behaviour). Still idempotent: an existing row's type is never rewritten
-- by a retry, which is also what keeps the guard trigger above honest.
-- ---------------------------------------------------------------------------

drop function if exists public.complete_my_registration(
  text, text, text, text, double precision, double precision, text, date
);

create function public.complete_my_registration(
  p_name text,
  p_governorate text,
  p_area text,
  p_address_text text,
  p_lat double precision,
  p_lng double precision,
  p_license_url text,
  p_license_expiry date default date '2099-12-31',
  p_account_type account_type default 'pharmacy'
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
    lat, lng, license_url, license_expiry, status, account_type
  ) values (
    v_uid, trim(p_name), v_email, trim(p_governorate), trim(coalesce(p_area, '')),
    trim(coalesce(p_address_text, '')), p_lat, p_lng, trim(p_license_url),
    coalesce(p_license_expiry, date '2099-12-31'),
    'pending',
    coalesce(p_account_type, 'pharmacy')
  );

  return 'pending'::pharmacy_status;
end;
$$;

grant execute on function public.complete_my_registration(
  text, text, text, text, double precision, double precision, text, date, account_type
) to authenticated;

-- ---------------------------------------------------------------------------
-- Read paths.
--
-- Every RPC that already hands the client a counterpart's safe columns now
-- also hands over its account type, so a listing card, a listing detail, a
-- chat header and a deal row can all say who they are talking to without a
-- second round trip. `create or replace` can't widen a RETURNS TABLE, so
-- each one is dropped and rebuilt — bodies are otherwise unchanged from the
-- migration named above each.
-- ---------------------------------------------------------------------------

-- search_listings — from 0036_listing_integrity.sql, plus a p_account_type
-- filter so pharmacies can browse warehouse supply specifically.
drop function if exists public.search_listings(
  text, text, text, listing_type, text, date, double precision, double precision, uuid, int, int, double precision
);

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
  p_offset int default 0,
  p_max_distance_km double precision default null,
  p_account_type account_type default null
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
  account_type account_type,
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
    l.pharmacy_id, p.name, p.account_type, p.governorate, p.area, p.lat, p.lng,
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
    and (p_account_type is null or p.account_type = p_account_type)
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
  text, text, text, listing_type, text, date, double precision, double precision, uuid, int, int, double precision, account_type
) to authenticated;

-- get_listing_detail — from 0028_listing_description.sql.
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
  description text,
  expiry_date date,
  listing_state listing_state,
  accepted_alternatives uuid[],
  photo_url text,
  created_at timestamptz,
  pharmacy_id uuid,
  pharmacy_name text,
  account_type account_type,
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
    l.type, l.quantity, l.price, l.discount_price, l.description, l.expiry_date, l.state, l.accepted_alternatives, l.photo_url, l.created_at,
    l.pharmacy_id, p.name, p.account_type, p.governorate, p.area, p.lat, p.lng
  from listings l
  join drugs d on d.id = l.drug_id
  join pharmacies p on p.id = l.pharmacy_id
  where l.id = p_listing_id
    and (l.state = 'available' or l.pharmacy_id = auth.uid());
$$;

grant execute on function public.get_listing_detail(uuid) to authenticated;

-- get_my_favorites — from 0026_favorites.sql.
drop function if exists public.get_my_favorites();

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
  account_type account_type,
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
    l.pharmacy_id, p.name, p.account_type, p.governorate, p.area, p.lat, p.lng,
    null::double precision as distance_km
  from favorites f
  join listings l on l.id = f.listing_id
  join drugs d on d.id = l.drug_id
  join pharmacies p on p.id = l.pharmacy_id
  where f.pharmacy_id = auth.uid()
  order by f.created_at desc;
$$;

grant execute on function public.get_my_favorites() to authenticated;

-- get_my_deals / get_deal_detail — from 0035_deal_lifecycle_v2.sql. The
-- counterpart's type is what lets the chat list and thread header show who
-- the other side is, which matters more here than anywhere else: a
-- pharmacy answering a supply offer wants to know it came from a warehouse.
drop function if exists public.get_my_deals();

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
  counterpart_account_type account_type,
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
    cp.account_type,
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

grant execute on function public.get_my_deals() to authenticated;

drop function if exists public.get_deal_detail(uuid);

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
  counterpart_account_type account_type,
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
    cp.account_type,
    d.expires_at,
    d.created_at
  from deals d
  join listings l on l.id = d.listing_id
  join drugs dr on dr.id = l.drug_id
  join pharmacies cp on cp.id = (case when l.pharmacy_id = auth.uid() then d.counterpart_pharmacy_id else l.pharmacy_id end)
  where d.id = p_deal_id
    and (l.pharmacy_id = auth.uid() or d.counterpart_pharmacy_id = auth.uid());
$$;

grant execute on function public.get_deal_detail(uuid) to authenticated;

-- get_my_listings — from 0025_my_listings_rpc.sql. These are the caller's
-- own listings, so the type is never news to them; it's here because
-- ListingSummary on the client is filled from this RPC as well as from
-- search_listings and get_my_favorites, and a model field that is present
-- from two of its three sources is a trap for whoever reads it next.
drop function if exists public.get_my_listings(listing_state);

create function public.get_my_listings(p_state listing_state default null)
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
  account_type account_type,
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
    l.pharmacy_id, p.name, p.account_type, p.governorate, p.area, p.lat, p.lng,
    null::double precision as distance_km
  from listings l
  join drugs d on d.id = l.drug_id
  join pharmacies p on p.id = l.pharmacy_id
  where l.pharmacy_id = auth.uid()
    and (p_state is null or l.state = p_state)
  order by l.created_at desc;
$$;

grant execute on function public.get_my_listings(listing_state) to authenticated;
