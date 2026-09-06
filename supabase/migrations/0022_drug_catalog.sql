-- Drug reference catalog — trade name / concentration / manufacturer /
-- pharmaceutical form, imported from Egypt's public drug registry export
-- (~23,600 rows, see supabase/seed_data/drug_catalog.csv). Deliberately a
-- SEPARATE table from `drugs`: `drugs` is the small, organically-grown
-- table of products actually listed on the platform — DrugsController
-- fetches it in full once per app session ("drugs rarely change"), which
-- would be a multi-MB payload on every cold start if this whole catalog
-- lived there. This table only ever gets searched server-side (ILIKE on
-- display_name), never fetched wholesale.
create extension if not exists pg_trgm;

create table drug_catalog (
  id uuid primary key default gen_random_uuid(),
  trade_name text not null,
  concentration text,
  company text,
  pharmaceutical_form text,
  display_name text not null,
  created_at timestamptz not null default now()
);

create index idx_drug_catalog_display_name_trgm on drug_catalog using gin (display_name gin_trgm_ops);

alter table drug_catalog enable row level security;

create policy "drug_catalog: public read" on drug_catalog for select using (true);

create policy "drug_catalog: admin write" on drug_catalog for all using (is_admin()) with check (is_admin());

-- drugs: the Add Medicine picker can now resolve a catalog pick (or a
-- fully custom typed name) into a real `drugs` row, so it needs
-- manufacturer/form alongside the concentration column 0010 already
-- added. The catalog has no generic/active-ingredient name, so
-- active_ingredient can no longer be required — same relax-a-not-null-
-- constraint pattern 0017 used for pharmacies.phone.
alter table drugs alter column active_ingredient drop not null;
alter table drugs add column company text;
alter table drugs add column pharmaceutical_form text;

-- find_or_create_drug() — the self-service write path a pharmacy needs
-- when the medicine they're listing isn't already a `drugs` row, whether
-- picked from drug_catalog or typed freehand. Security-definer since
-- 0021's "drugs: admin write" policy intentionally keeps plain INSERT off
-- limits to non-admins; this is the one narrow, validated exception.
-- Matches existing rows by trade_name + concentration (case-insensitive)
-- so repeated picks of the same product across different pharmacies
-- converge on one drugs row instead of spawning duplicates — which
-- matters because drug_id identity is what the alternatives/search/
-- notify-me matching across pharmacies relies on.
create or replace function public.find_or_create_drug(
  p_trade_name text,
  p_concentration text default null,
  p_company text default null,
  p_pharmaceutical_form text default null
)
returns table (
  id uuid,
  trade_name text,
  active_ingredient text,
  concentration text,
  company text,
  pharmaceutical_form text,
  is_controlled boolean
)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_id uuid;
begin
  if trim(p_trade_name) = '' then
    raise exception 'Medicine name is required';
  end if;

  select d.id into v_id
  from drugs d
  where lower(d.trade_name) = lower(trim(p_trade_name))
    and coalesce(lower(d.concentration), '') = coalesce(lower(trim(p_concentration)), '')
  limit 1;

  if v_id is null then
    insert into drugs (trade_name, concentration, company, pharmaceutical_form, is_controlled)
    values (
      trim(p_trade_name),
      nullif(trim(coalesce(p_concentration, '')), ''),
      nullif(trim(coalesce(p_company, '')), ''),
      nullif(trim(coalesce(p_pharmaceutical_form, '')), ''),
      false
    )
    returning drugs.id into v_id;
  else
    -- Backfill manufacturer/form on an existing row if it's missing them
    -- (e.g. it was created earlier via free text and this pick came from
    -- the catalog) — never overwrites data that's already there.
    update drugs
    set company = coalesce(drugs.company, nullif(trim(coalesce(p_company, '')), '')),
        pharmaceutical_form = coalesce(drugs.pharmaceutical_form, nullif(trim(coalesce(p_pharmaceutical_form, '')), ''))
    where drugs.id = v_id;
  end if;

  return query
  select d.id, d.trade_name, d.active_ingredient, d.concentration, d.company, d.pharmaceutical_form, d.is_controlled
  from drugs d where d.id = v_id;
end;
$$;

grant execute on function public.find_or_create_drug(text, text, text, text) to authenticated;
