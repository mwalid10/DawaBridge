-- Let a pharmacy change what its exchange listing accepts in return.
--
-- `listings.accepted_alternatives` could only ever be set at insert time:
-- the add-medicine screen writes it directly, and update_my_listing (0036)
-- had no parameter for it. So a pharmacy that posted an exchange listing
-- without naming anything — five of the six exchange listings in this
-- database — had no way to add one afterwards short of deleting the listing
-- and posting it again, which loses its age and its favourites.
--
-- `create or replace` would not do here: adding a parameter changes the
-- signature, so it creates a second overload rather than replacing, and
-- PostgREST refuses a call it can resolve to two functions (PGRST203). The
-- old one is dropped by its exact argument list first.

drop function if exists public.update_my_listing(
  uuid, integer, date, numeric, numeric, text, text, boolean, boolean
);

create or replace function public.update_my_listing(
  p_listing_id uuid,
  p_quantity integer default null,
  p_expiry_date date default null,
  p_price numeric default null,
  p_discount_price numeric default null,
  p_description text default null,
  p_photo_url text default null,
  p_clear_discount boolean default false,
  p_clear_photo boolean default false,
  -- NULL leaves the list alone; an empty array clears it. Price and photo
  -- need a p_clear_* flag to tell those two cases apart, an array doesn't.
  p_accepted_alternatives uuid[] default null
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
  v_unknown_drugs integer;
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

  -- Checked only when the caller is actually setting the list. A listing
  -- that predates these rules stays editable in every other field instead
  -- of being frozen by them — 0036 is the record of what that costs.
  if p_accepted_alternatives is not null then
    if v_listing.type <> 'barter' and cardinality(p_accepted_alternatives) > 0 then
      raise exception 'LISTING_NOT_BARTER';
    end if;

    if cardinality(p_accepted_alternatives) > 20 then
      raise exception 'LISTING_ALTERNATIVES_TOO_MANY';
    end if;

    -- A uuid[] column carries no foreign key, so an id that matches no drug
    -- is storable — and it renders as nothing at all on the listing page,
    -- which looks like the pharmacy named fewer alternatives than it did.
    select count(*) into v_unknown_drugs
    from unnest(p_accepted_alternatives) as a(id)
    where not exists (select 1 from drugs d where d.id = a.id);

    if v_unknown_drugs > 0 then
      raise exception 'DRUG_NOT_FOUND';
    end if;
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
    photo_url = case when p_clear_photo then null else coalesce(p_photo_url, photo_url) end,
    accepted_alternatives = coalesce(p_accepted_alternatives, accepted_alternatives)
  where id = p_listing_id;
end;
$$;

-- 0040's revoke loop took EXECUTE from PUBLIC and `anon`; the direct grant
-- to `authenticated` is what actually lets the app call this, and dropping
-- the function above took the old one with it. See 0041.
grant execute on function public.update_my_listing(
  uuid, integer, date, numeric, numeric, text, text, boolean, boolean, uuid[]
) to authenticated;
