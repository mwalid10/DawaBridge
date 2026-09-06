-- The Home screen's "Price increased" row was originally computed from
-- listing_price_history (0010/0011) — i.e. it only fired when a pharmacy
-- happened to raise a price on their own listing. Per product direction,
-- this section is meant to surface market-wide drug price increases
-- (e.g. "Panadol went up nationally"), curated manually by an admin, not
-- derived from in-app listing activity. There's no admin dashboard yet, so
-- for now these rows are entered directly (Studio / service-role SQL) —
-- same "reference data, no client writes" shape as `drugs`.

create table global_price_alerts (
  id uuid primary key default gen_random_uuid(),
  drug_id uuid not null references drugs(id),
  old_price numeric(10, 2) not null,
  new_price numeric(10, 2) not null check (new_price > old_price),
  effective_date date not null default current_date,
  note text,
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

create index idx_global_price_alerts_active on global_price_alerts (is_active, effective_date desc);

alter table global_price_alerts enable row level security;

-- Public read of active alerts only — no client-facing write policy at
-- all, so pharmacies can never insert/edit these; an admin populates them
-- with the project's service-role key, bypassing RLS entirely.
create policy "global_price_alerts: public read active" on global_price_alerts
  for select using (is_active);
