-- Account deletion, and a way out of a half-finished registration.

-- ---------------------------------------------------------------------
-- 1. Orphaned registrations.
--
-- otp_verification_screen.dart does three things in sequence with no
-- transaction and no rollback: verify the OTP (at which point the
-- auth.users row exists and is signed in), upload the licence to Storage,
-- then insert the pharmacies row. If either of the last two fails — a
-- dropped connection on a slow mobile link is enough — the user is left
-- with a confirmed auth account and no pharmacy.
--
-- There was no way back. Registering again fails on "User already
-- registered", the upload wasn't an upsert so retrying 409s on the
-- existing object, and splash routes any session to /home where every
-- pharmacy-keyed query throws. One such account (walidmadany@hotmail.com)
-- was already sitting in the live database.
--
-- complete_my_registration() is the recovery path: it's idempotent, so
-- the app can safely call it on every attempt, and it's the same function
-- the normal first-time flow now uses.
-- ---------------------------------------------------------------------
create or replace function public.complete_my_registration(
  p_name text,
  p_governorate text,
  p_area text,
  p_address_text text,
  p_lat double precision,
  p_lng double precision,
  p_license_url text,
  -- pharmacies.license_expiry is NOT NULL from 0001_init.sql and nothing in
  -- the product reads it, so this is optional: the KYC wizard passes the
  -- date it already collects (behaviour unchanged), and the recovery flow —
  -- which has no wizard state to draw on — falls back to the placeholder.
  p_license_expiry date default date '2099-12-31'
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
    lat, lng, license_url, license_expiry, status
  ) values (
    v_uid, trim(p_name), v_email, trim(p_governorate), trim(coalesce(p_area, '')),
    trim(coalesce(p_address_text, '')), p_lat, p_lng, trim(p_license_url),
    coalesce(p_license_expiry, date '2099-12-31'),
    'pending'
  );

  return 'pending'::pharmacy_status;
end;
$$;

grant execute on function public.complete_my_registration(text, text, text, text, double precision, double precision, text, date) to authenticated;

-- ---------------------------------------------------------------------
-- 2. Account deletion.
--
-- There was no way to delete an account from inside the app at all. That
-- is a hard App Store rejection (Guideline 5.1.1(v), mandatory since 2022)
-- and a Play Store requirement, so the app could not have shipped.
--
-- Deal, rating and dispute history is referenced by the other party, so a
-- hard row delete would either fail on the foreign keys or erase the
-- counterparty's own transaction record. The pharmacy row is anonymised
-- instead — every piece of personal/business identifying data is cleared —
-- and the auth user is deleted so the account genuinely can't be used
-- again. That satisfies the stores' requirement (account gone, personal
-- data removed) without rewriting someone else's history.
-- ---------------------------------------------------------------------
create or replace function public.delete_my_account()
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null then
    raise exception 'AUTH_REQUIRED';
  end if;

  if exists (
    select 1 from deals d
    join listings l on l.id = d.listing_id
    where d.state in ('pending','accepted')
      and (l.pharmacy_id = v_uid or d.counterpart_pharmacy_id = v_uid)
  ) then
    raise exception 'ACCOUNT_HAS_ACTIVE_DEALS';
  end if;

  if exists (select 1 from disputes dp
             join deals d on d.id = dp.deal_id
             join listings l on l.id = d.listing_id
             where dp.status <> 'resolved'
               and (l.pharmacy_id = v_uid or d.counterpart_pharmacy_id = v_uid)) then
    raise exception 'ACCOUNT_HAS_OPEN_DISPUTES';
  end if;

  -- Take everything of theirs off the marketplace first.
  update listings set state = 'cancelled', reserved_until = null
  where pharmacy_id = v_uid and state in ('available','reserved');

  delete from device_push_tokens where pharmacy_id = v_uid;
  delete from favorites where pharmacy_id = v_uid;
  delete from listing_alerts where pharmacy_id = v_uid;
  delete from notifications where pharmacy_id = v_uid;

  -- Private KYC documents.
  delete from storage.objects
  where bucket_id = 'licenses' and (storage.foldername(name))[1] = v_uid::text;

  update pharmacies set
    name = 'Deleted pharmacy',
    email = 'deleted+' || v_uid::text || '@pharmaexchange.invalid',
    governorate = '',
    area = '',
    address_text = '',
    lat = 0,
    lng = 0,
    license_url = '',
    status = 'suspended',
    plan = 'free'
  where id = v_uid;

  delete from auth.users where id = v_uid;
end;
$$;

grant execute on function public.delete_my_account() to authenticated;

-- The anonymised row carries lat/lng 0,0, which is in the Gulf of Guinea —
-- it must never show up in a proximity search. Status is 'suspended' and
-- 0036 already filters search_listings on status = 'approved', so this is
-- belt-and-braces: their listings are cancelled above too.
