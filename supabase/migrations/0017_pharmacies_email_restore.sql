-- Fix schema drift: the live pharmacies table lost its `email` column at
-- some point (a `phone` column was added directly in Studio in its place,
-- bypassing migrations). This broke both new-pharmacy signup (the KYC
-- flow's insert in otp_verification_screen.dart writes `email`) and the
-- profile screen (PharmacyProfile.fromJson reads `email`, got null, threw
-- -> "Couldn't load profile"). Restore `email`, backfill it from
-- auth.users for any rows that only have `phone`, and relax `phone` to
-- nullable since new signups never populate it.

alter table pharmacies add column if not exists email text;

update pharmacies p
set email = u.email
from auth.users u
where u.id = p.id and p.email is null;

alter table pharmacies alter column phone drop not null;

do $$
begin
  if not exists (select 1 from pg_constraint where conname = 'pharmacies_email_key') then
    alter table pharmacies add constraint pharmacies_email_key unique (email);
  end if;
end $$;

alter table pharmacies alter column email set not null;
