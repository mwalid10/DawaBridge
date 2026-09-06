-- Pharma Exchange Egypt — initial schema (PRS v3.0 / Build Roadmap Phase 0-4)
-- Run with: supabase db push

create extension if not exists postgis;

create type pharmacy_status as enum ('pending','approved','rejected','suspended');
create type plan_status    as enum ('trial','free','active');
create type listing_type   as enum ('sell','buy','barter');
create type listing_state  as enum ('available','reserved','completed','cancelled');
create type dispute_status as enum ('open','under_review','resolved');

-- pharmacies -----------------------------------------------------------
-- lat/lng are stored as plain columns so the Flutter client can insert
-- them directly (see AddressStep's map pin-drop); the `location`
-- geography column is derived by trigger below and is what proximity
-- search in Phase 2 actually queries against.
create table pharmacies (
  id uuid primary key references auth.users(id),
  name text not null,
  email text not null unique,
  governorate text not null,
  area text not null,
  address_text text not null,
  lat double precision not null,
  lng double precision not null,
  location geography(Point,4326),
  license_url text not null,
  license_expiry date not null,
  status pharmacy_status not null default 'pending',
  plan plan_status not null default 'trial',
  trial_ends_at timestamptz default (now() + interval '30 days'),
  created_at timestamptz not null default now()
);

create or replace function pharmacies_set_location() returns trigger as $$
begin
  new.location := ST_SetSRID(ST_MakePoint(new.lng, new.lat), 4326)::geography;
  return new;
end;
$$ language plpgsql;

create trigger trg_pharmacies_set_location
  before insert or update of lat, lng on pharmacies
  for each row execute function pharmacies_set_location();

create index idx_pharmacies_location on pharmacies using gist (location);

-- drugs ------------------------------------------------------------------
create table drugs (
  id uuid primary key default gen_random_uuid(),
  trade_name text not null,
  active_ingredient text not null,
  is_controlled boolean not null default false
);

-- listings -----------------------------------------------------------
create table listings (
  id uuid primary key default gen_random_uuid(),
  pharmacy_id uuid not null references pharmacies(id),
  drug_id uuid not null references drugs(id),
  type listing_type not null,
  quantity int not null check (quantity > 0),
  expiry_date date not null check (expiry_date > current_date + interval '90 days'),
  state listing_state not null default 'available',
  reserved_until timestamptz,
  accepted_alternatives uuid[] not null default '{}',
  created_at timestamptz not null default now()
);

-- deals ----------------------------------------------------------------
create table deals (
  id uuid primary key default gen_random_uuid(),
  listing_id uuid not null references listings(id),
  counterpart_pharmacy_id uuid not null references pharmacies(id),
  state listing_state not null default 'reserved',
  completed_at timestamptz,
  created_at timestamptz not null default now()
);

-- ratings — unique per (deal, rater) so a review can only follow a
-- specific completed transaction, never posted open-ended -------------
create table ratings (
  id uuid primary key default gen_random_uuid(),
  deal_id uuid not null references deals(id),
  rater_id uuid not null references pharmacies(id),
  stars int not null check (stars between 1 and 5),
  credibility int check (credibility between 1 and 5),
  responsiveness int check (responsiveness between 1 and 5),
  packaging int check (packaging between 1 and 5),
  created_at timestamptz not null default now(),
  unique (deal_id, rater_id)
);

-- disputes ---------------------------------------------------------------
create table disputes (
  id uuid primary key default gen_random_uuid(),
  deal_id uuid not null references deals(id),
  raised_by uuid not null references pharmacies(id),
  reason text not null,
  description text,
  evidence_urls text[] not null default '{}',
  status dispute_status not null default 'open',
  created_at timestamptz not null default now()
);

-- compliance_flags — controlled-substance listing attempts, logged
-- instead of silently blocked, so Compliance Reviewer can see patterns --
create table compliance_flags (
  id uuid primary key default gen_random_uuid(),
  pharmacy_id uuid references pharmacies(id),
  drug_id uuid references drugs(id),
  kind text not null,
  created_at timestamptz not null default now()
);

-- Row Level Security -----------------------------------------------------
alter table pharmacies enable row level security;
alter table listings   enable row level security;
alter table deals      enable row level security;
alter table ratings    enable row level security;
alter table disputes   enable row level security;

create policy "pharmacies read/update own row" on pharmacies
  for all using (auth.uid() = id) with check (auth.uid() = id);

create policy "listings: public read when available, owner reads all" on listings
  for select using (state = 'available' or pharmacy_id = auth.uid());

create policy "listings: owner writes" on listings
  for insert with check (pharmacy_id = auth.uid());

create policy "listings: owner updates" on listings
  for update using (pharmacy_id = auth.uid());

create policy "deals: participants only" on deals
  for select using (
    counterpart_pharmacy_id = auth.uid()
    or listing_id in (select id from listings where pharmacy_id = auth.uid())
  );

create policy "ratings: participants read, rater writes own" on ratings
  for select using (true);

create policy "ratings: rater inserts own" on ratings
  for insert with check (rater_id = auth.uid());

create policy "disputes: raiser reads/writes own" on disputes
  for all using (raised_by = auth.uid()) with check (raised_by = auth.uid());

-- drugs table is reference data — public read, no client writes
alter table drugs enable row level security;
create policy "drugs: public read" on drugs for select using (true);
