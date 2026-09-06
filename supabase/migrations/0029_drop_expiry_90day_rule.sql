-- Drops the "expiry must be more than 90 days out" rule from 0001_init.sql
-- (per user request). Replaced with just "must be a future date" — a
-- listing for medicine that's already expired isn't a meaningful listing,
-- but the 90-day buffer itself is gone.
alter table listings drop constraint if exists listings_expiry_date_check;
alter table listings add constraint listings_expiry_date_check check (expiry_date > current_date);
