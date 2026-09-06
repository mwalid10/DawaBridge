-- Pharmacists can list a medicine that isn't in the curated `drugs` table
-- yet, via find_or_create_drug (0022) — but that self-service row landed
-- in `drugs` indistinguishable from an admin-curated one, silently
-- expanding what the admin Products page shows with zero review. This
-- flags anything created that way as pending so the Products page can
-- default to hiding it from the main list until an admin reviews and
-- approves it.
--
-- The listing itself still works immediately either way — is_pending is
-- purely an admin-curation concern, not a marketplace-visibility gate:
-- other pharmacies can already see/search/buy a listing on a pending
-- drug, since none of the public-facing RPCs (search_listings,
-- get_listing_detail, get_listings_feed) filter on it. No RLS changes
-- needed here either — "drugs: public read" (0001) and "drugs: admin
-- write" (0021) already cover reading and moderating this column.
alter table drugs add column is_pending boolean not null default false;

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
    insert into drugs (trade_name, concentration, company, pharmaceutical_form, is_controlled, is_pending)
    values (
      trim(p_trade_name),
      nullif(trim(coalesce(p_concentration, '')), ''),
      nullif(trim(coalesce(p_company, '')), ''),
      nullif(trim(coalesce(p_pharmaceutical_form, '')), ''),
      false,
      true
    )
    returning drugs.id into v_id;
  else
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
