-- Add Medicine's optional photo upload has no column to land in yet.
-- 0002_storage.sql's medicine-photos bucket exists for exactly this and was
-- otherwise unused.
alter table listings add column photo_url text;
