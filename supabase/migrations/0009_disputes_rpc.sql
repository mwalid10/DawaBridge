-- Disputes (trust phase): raise-a-dispute + status view.
--
-- 0001_init.sql's "disputes: raiser reads/writes own" policy uses
-- `for all using (raised_by = auth.uid())` — two problems: (1) it never
-- checks the caller was actually a participant in deal_id, same class of
-- gap fixed for ratings in 0008; (2) `for all` + owner-only `using` means
-- the *other* deal participant — the party the dispute is about — can
-- never see it, which defeats the point of a dispute. Replace with a
-- participant-scoped select and a security-definer RPC for the write path.
drop policy "disputes: raiser reads/writes own" on disputes;

create policy "disputes: participants read" on disputes
  for select using (is_deal_participant(deal_id));

-- No insert/update policy: raising a dispute goes through raise_dispute()
-- below; status transitions (open -> under_review -> resolved) are an
-- admin action done via Supabase Studio for now, same manual pattern as
-- pharmacies.status approval — the client only ever reads status, live via
-- the realtime publication add at the bottom of this file.

create or replace function public.raise_dispute(
  p_deal_id uuid,
  p_reason text,
  p_description text default null,
  p_evidence_urls text[] default '{}'
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_deal deals%rowtype;
  v_listing listings%rowtype;
  v_other_party uuid;
  v_dispute_id uuid;
begin
  select * into v_deal from deals where id = p_deal_id;
  if v_deal.id is null then
    raise exception 'Deal not found';
  end if;

  select * into v_listing from listings where id = v_deal.listing_id;

  if not (v_listing.pharmacy_id = auth.uid() or v_deal.counterpart_pharmacy_id = auth.uid()) then
    raise exception 'Not a participant in this deal';
  end if;

  v_other_party := case when v_listing.pharmacy_id = auth.uid() then v_deal.counterpart_pharmacy_id else v_listing.pharmacy_id end;

  insert into disputes (deal_id, raised_by, reason, description, evidence_urls)
  values (p_deal_id, auth.uid(), p_reason, p_description, p_evidence_urls)
  returning id into v_dispute_id;

  insert into notifications (pharmacy_id, kind, title, body, deal_id)
  values (v_other_party, 'dispute_raised', 'A dispute was raised', p_reason, p_deal_id);

  return v_dispute_id;
end;
$$;

grant execute on function public.raise_dispute(uuid, text, text, text[]) to authenticated;

-- get_my_disputes() — same safe-join pattern as get_my_deals(): the client
-- can't otherwise resolve the counterpart's name (owner-only RLS on
-- pharmacies), so this stays a security-definer RPC.
create or replace function public.get_my_disputes()
returns table (
  dispute_id uuid,
  deal_id uuid,
  drug_trade_name text,
  reason text,
  dispute_status dispute_status,
  raised_by_me boolean,
  counterpart_name text,
  created_at timestamptz
)
language sql
security definer
set search_path = public
stable
as $$
  select
    dp.id,
    dp.deal_id,
    dr.trade_name,
    dp.reason,
    dp.status,
    (dp.raised_by = auth.uid()),
    cp.name,
    dp.created_at
  from disputes dp
  join deals d on d.id = dp.deal_id
  join listings l on l.id = d.listing_id
  join drugs dr on dr.id = l.drug_id
  join pharmacies cp on cp.id = (case when l.pharmacy_id = auth.uid() then d.counterpart_pharmacy_id else l.pharmacy_id end)
  where l.pharmacy_id = auth.uid() or d.counterpart_pharmacy_id = auth.uid()
  order by dp.created_at desc;
$$;

grant execute on function public.get_my_disputes() to authenticated;

-- Same duplicate_object guard as 0007's realtime publication adds — see
-- that migration's comment for why this is wrapped rather than a bare
-- ALTER PUBLICATION.
do $$ begin
  alter publication supabase_realtime add table disputes;
exception when duplicate_object then null;
end $$;
