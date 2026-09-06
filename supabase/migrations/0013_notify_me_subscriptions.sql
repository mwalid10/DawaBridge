-- "Notify me when available" — a pharmacy subscribes to a
-- trade_name/active_ingredient (+ optional governorate) combination when a
-- search comes back empty. Client reads/writes its own rows directly
-- (mirrors the messages-insert convention, no RPC needed since the RLS
-- check is a simple ownership match); matching against new listings is
-- server-side via a trigger so it can't be bypassed or spoofed.
create table listing_alerts (
  id uuid primary key default gen_random_uuid(),
  pharmacy_id uuid not null references pharmacies(id),
  trade_name text not null,
  active_ingredient text,
  governorate text,
  created_at timestamptz not null default now(),
  fulfilled_at timestamptz
);

create index idx_listing_alerts_pharmacy_id on listing_alerts (pharmacy_id, created_at desc);
create index idx_listing_alerts_unfulfilled on listing_alerts (trade_name) where fulfilled_at is null;

alter table listing_alerts enable row level security;

create policy "listing_alerts: owner manages own" on listing_alerts
  for all using (pharmacy_id = auth.uid()) with check (pharmacy_id = auth.uid());

-- match_listing_alerts() — fires whenever a listing becomes available
-- (either on creation, or when it flips back to available after a
-- cancelled deal), and notifies every unfulfilled alert whose
-- trade_name/active_ingredient/governorate matches. One-shot: fulfilled_at
-- is stamped on match so it never fires twice for the same alert.
create or replace function public.match_listing_alerts()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_drug drugs%rowtype;
  v_pharmacy_governorate text;
  v_alert record;
begin
  select * into v_drug from drugs where id = new.drug_id;
  select governorate into v_pharmacy_governorate from pharmacies where id = new.pharmacy_id;

  for v_alert in
    select * from listing_alerts
    where fulfilled_at is null
      and v_drug.trade_name ilike '%' || trade_name || '%'
      and (active_ingredient is null or v_drug.active_ingredient ilike '%' || active_ingredient || '%')
      and (governorate is null or governorate = v_pharmacy_governorate)
  loop
    insert into notifications (pharmacy_id, kind, title, body, listing_id)
    values (v_alert.pharmacy_id, 'listing_alert', 'Now available: ' || v_drug.trade_name,
            'A listing matching your alert just became available.', new.id);

    update listing_alerts set fulfilled_at = now() where id = v_alert.id;
  end loop;

  return new;
end;
$$;

create trigger trg_match_listing_alerts
  after insert or update of state on listings
  for each row
  when (new.state = 'available')
  execute function match_listing_alerts();
