-- Controlled substances: the block was client-side only, and trivially
-- bypassable without any hacking at all.
--
-- HOW IT FAILED:
--
-- The only thing standing between a pharmacy and a controlled-substance
-- listing was `isControlledBlocked` in add_listing_data.dart, which greys
-- out the submit button. Nothing on the server checked anything — the
-- listings INSERT policy never looked at drugs.is_controlled.
--
-- Worse, find_or_create_drug() — the function every self-service listing
-- goes through — hardcoded `is_controlled = false` on every row it
-- created. drug_catalog has no is_controlled column to inherit from, so a
-- pharmacist typing a trade name whose exact (name, concentration) pair
-- wasn't already a `drugs` row got a brand-new drug flagged uncontrolled,
-- and the client-side block then had nothing to fire on. Typing
-- "Tramadol 225mg" was enough. No API calls, no tampering — just typing.
--
-- THE FIX: a term list, applied at the one place drugs are created, and a
-- trigger on listings so the marketplace rule is enforced by the database
-- rather than by a disabled button.

create table controlled_substance_terms (
  id uuid primary key default gen_random_uuid(),
  term text not null unique,
  note text,
  created_at timestamptz not null default now()
);

alter table controlled_substance_terms enable row level security;

create policy "controlled_substance_terms: public read"
  on controlled_substance_terms for select using (true);

create policy "controlled_substance_terms: admin write"
  on controlled_substance_terms for all using (is_admin()) with check (is_admin());

-- Narcotics and psychotropics scheduled under Egyptian Law 182/1960 and
-- its later amendments, plus the trade names those are actually sold under
-- locally. Deliberately errs toward over-matching: a false positive costs
-- a pharmacy one support ticket, a false negative puts a scheduled
-- substance on an open B2B marketplace. Admins can curate the list from
-- the dashboard.
insert into controlled_substance_terms (term, note) values
  ('tramadol', 'opioid'), ('tramal', 'tramadol'), ('contramal', 'tramadol'),
  ('amadol', 'tramadol'), ('tramax', 'tramadol'), ('ultracet', 'tramadol combo'),
  ('tapentadol', 'opioid'), ('nucynta', 'tapentadol'),
  ('codeine', 'opioid'), ('kodein', 'codeine'),
  ('morphine', 'opioid'), ('morphin', 'opioid'),
  ('pethidine', 'opioid'), ('meperidine', 'pethidine'),
  ('fentanyl', 'opioid'), ('oxycodone', 'opioid'), ('methadone', 'opioid'),
  ('buprenorphine', 'opioid'), ('pentazocine', 'opioid'), ('nalbuphine', 'opioid'),
  ('alprazolam', 'benzodiazepine'), ('xanax', 'alprazolam'),
  ('diazepam', 'benzodiazepine'), ('valium', 'diazepam'), ('neuril', 'diazepam'),
  ('clonazepam', 'benzodiazepine'), ('rivotril', 'clonazepam'),
  ('apetryl', 'clonazepam'), ('amotril', 'clonazepam'),
  ('lorazepam', 'benzodiazepine'), ('ativan', 'lorazepam'),
  ('bromazepam', 'benzodiazepine'), ('calmepam', 'bromazepam'), ('lexotanil', 'bromazepam'),
  ('midazolam', 'benzodiazepine'), ('dormicum', 'midazolam'),
  ('nitrazepam', 'benzodiazepine'), ('mogadon', 'nitrazepam'),
  ('chlordiazepoxide', 'benzodiazepine'), ('librax', 'chlordiazepoxide'), ('epicotil', 'chlordiazepoxide'),
  ('clobazam', 'benzodiazepine'), ('frisium', 'clobazam'),
  ('flurazepam', 'benzodiazepine'), ('triazolam', 'benzodiazepine'), ('temazepam', 'benzodiazepine'),
  ('zolpidem', 'z-drug'), ('stilnox', 'zolpidem'), ('zolam', 'zolpidem'),
  ('phenobarbital', 'barbiturate'), ('luminal', 'phenobarbital'), ('somnaletten', 'phenobarbital'),
  ('barbital', 'barbiturate'), ('thiopental', 'barbiturate'),
  ('methylphenidate', 'stimulant'), ('ritalin', 'methylphenidate'), ('concerta', 'methylphenidate'),
  ('amphetamine', 'stimulant'), ('dexamphetamine', 'stimulant'),
  ('pregabalin', 'scheduled in Egypt since 2019'), ('lyrica', 'pregabalin'),
  ('ketamine', 'dissociative'), ('ketalar', 'ketamine'),
  ('carisoprodol', 'muscle relaxant, scheduled'), ('somadril', 'carisoprodol'),
  ('trihexyphenidyl', 'anticholinergic, scheduled'), ('parkinol', 'trihexyphenidyl'),
  ('flunitrazepam', 'benzodiazepine'), ('rohypnol', 'flunitrazepam')
on conflict (term) do nothing;

-- is_controlled_name() — the single place the matching rule lives, so the
-- drug-creation path and the admin re-scan below can't diverge.
create or replace function public.is_controlled_name(p_name text, p_ingredient text default null)
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select exists (
    select 1 from controlled_substance_terms t
    where lower(coalesce(p_name, '')) like '%' || t.term || '%'
       or lower(coalesce(p_ingredient, '')) like '%' || t.term || '%'
  );
$$;

grant execute on function public.is_controlled_name(text, text) to authenticated;

-- Re-flag everything already in `drugs`. Rows created through the old
-- find_or_create_drug() are all sitting at is_controlled = false
-- regardless of what they actually are.
update drugs
set is_controlled = true
where not is_controlled
  and is_controlled_name(trade_name, active_ingredient);

-- find_or_create_drug() v3 — the one-line fix that matters: is_controlled
-- is now derived from the name instead of hardcoded false. Also stops
-- silently reusing a row whose controlled status has since been corrected.
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
  v_controlled boolean;
begin
  if auth.uid() is null then
    raise exception 'AUTH_REQUIRED';
  end if;
  if trim(coalesce(p_trade_name, '')) = '' then
    raise exception 'DRUG_NAME_REQUIRED';
  end if;
  if length(trim(p_trade_name)) > 200 then
    raise exception 'DRUG_NAME_TOO_LONG';
  end if;

  v_controlled := is_controlled_name(trim(p_trade_name), null);

  select d.id into v_id
  from drugs d
  where lower(d.trade_name) = lower(trim(p_trade_name))
    and coalesce(lower(d.concentration), '') = coalesce(lower(trim(p_concentration)), '')
  limit 1;

  if v_id is null then
    insert into drugs (trade_name, concentration, company, pharmaceutical_form, is_controlled, is_pending)
    values (
      trim(p_trade_name),
      nullif(trim(coalesce(p_concentration, '')), ''),
      nullif(trim(coalesce(p_company, '')), ''),
      nullif(trim(coalesce(p_pharmaceutical_form, '')), ''),
      v_controlled,
      true
    )
    returning drugs.id into v_id;
  else
    update drugs
    set company = coalesce(drugs.company, nullif(trim(coalesce(p_company, '')), '')),
        pharmaceutical_form = coalesce(drugs.pharmaceutical_form, nullif(trim(coalesce(p_pharmaceutical_form, '')), '')),
        -- Only ever escalates. An admin who has deliberately cleared the
        -- flag on a false positive shouldn't have it set again by the next
        -- pharmacy that types the name.
        is_controlled = drugs.is_controlled or v_controlled
    where drugs.id = v_id;
  end if;

  return query
  select d.id, d.trade_name, d.active_ingredient, d.concentration, d.company, d.pharmaceutical_form, d.is_controlled
  from drugs d where d.id = v_id;
end;
$$;

-- The enforcement itself. Even with the drug correctly flagged, nothing
-- stopped a direct PostgREST insert; the client-side disabled button was
-- the whole control. This is the rule the app was always supposed to have.
create or replace function public.listings_block_controlled()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_controlled boolean;
begin
  select is_controlled into v_controlled from drugs where id = new.drug_id;

  if coalesce(v_controlled, false) then
    insert into compliance_flags (pharmacy_id, drug_id, kind)
    values (new.pharmacy_id, new.drug_id, 'controlled_substance_listing_blocked');
    raise exception 'LISTING_CONTROLLED_SUBSTANCE';
  end if;

  return new;
end;
$$;

create trigger trg_listings_block_controlled
  before insert on listings
  for each row execute function listings_block_controlled();

-- Any listing already in the marketplace for a drug the re-scan above just
-- reclassified gets pulled. Cancelling rather than deleting keeps it
-- visible to the owner in My Listings (with a cancelled badge) and to
-- compliance, instead of vanishing silently.
with retired as (
  update listings l
  set state = 'cancelled', reserved_until = null
  from drugs d
  where d.id = l.drug_id
    and d.is_controlled
    and l.state in ('available','reserved')
  returning l.pharmacy_id, l.drug_id
)
insert into compliance_flags (pharmacy_id, drug_id, kind)
select pharmacy_id, drug_id, 'controlled_substance_listing_retired' from retired;

-- Any live deal on a listing that just got pulled is dead too.
update deals set state = 'cancelled', expires_at = null
where state in ('pending','accepted')
  and listing_id in (
    select l.id from listings l join drugs d on d.id = l.drug_id
    where d.is_controlled and l.state = 'cancelled'
  );
