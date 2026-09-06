-- Chat location sharing — messages gains optional lat/lng, populated only
-- for a "share my location" send (mutually exclusive with attachment_path
-- in practice, though nothing enforces that at the DB level since a
-- message is naturally one or the other from the client). No RLS change
-- needed: "messages: participants read/send" from 0007 already covers
-- every column on the table.
alter table messages add column location_lat double precision;
alter table messages add column location_lng double precision;
