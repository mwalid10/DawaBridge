-- Pricing: listings gain an optional price + discount price, drugs gain an
-- optional concentration label, and every price a listing is ever given
-- gets recorded in listing_price_history so a later RPC (0011) can compute
-- "price increased" listings. price/discount_price are nullable — existing
-- listings created before this migration simply have no price yet.

alter table listings add column price numeric(10, 2);
alter table listings add column discount_price numeric(10, 2);

alter table listings add constraint listings_discount_price_check
  check (discount_price is null or (price is not null and discount_price <= price));

alter table drugs add column concentration text;

-- listing_price_history — write-only via trigger, same
-- write-only-via-trusted-path pattern as compliance_flags (0006):
-- RLS is on with zero client policies, so it's only ever readable through
-- the security-definer get_price_increased_listings() RPC added in 0011.
create table listing_price_history (
  id uuid primary key default gen_random_uuid(),
  listing_id uuid not null references listings(id),
  price numeric(10, 2) not null,
  recorded_at timestamptz not null default now()
);

create index idx_listing_price_history_listing_id on listing_price_history (listing_id, recorded_at desc);

alter table listing_price_history enable row level security;

create or replace function public.record_listing_price_history()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.price is not null and (tg_op = 'INSERT' or new.price is distinct from old.price) then
    insert into listing_price_history (listing_id, price) values (new.id, new.price);
  end if;
  return new;
end;
$$;

create trigger trg_record_listing_price_history
  after insert or update of price on listings
  for each row execute function record_listing_price_history();
