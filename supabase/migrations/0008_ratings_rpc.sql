-- Phase 4: Profile (plan/trial, ratings).
--
-- 0001_init.sql's "ratings: rater inserts own" policy only checks
-- rater_id = auth.uid() — it never verifies the caller was actually a
-- participant in deal_id, nor that the deal is completed. Since ratings
-- has no explicit "ratee" column (the rated party is inferred structurally
-- from the deal's other participant), a rater could otherwise post a
-- rating against a deal they were never part of. Same class of gap as
-- compliance_flags in 0006: drop the loose insert policy, move writes
-- behind a security-definer RPC that does the real check.
drop policy "ratings: rater inserts own" on ratings;

create or replace function public.submit_rating(
  p_deal_id uuid,
  p_stars int,
  p_credibility int default null,
  p_responsiveness int default null,
  p_packaging int default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_deal deals%rowtype;
  v_listing listings%rowtype;
  v_ratee uuid;
begin
  select * into v_deal from deals where id = p_deal_id;
  if v_deal.id is null then
    raise exception 'Deal not found';
  end if;

  select * into v_listing from listings where id = v_deal.listing_id;

  if not (v_listing.pharmacy_id = auth.uid() or v_deal.counterpart_pharmacy_id = auth.uid()) then
    raise exception 'Not a participant in this deal';
  end if;
  if v_deal.state <> 'completed' then
    raise exception 'Deal must be completed before it can be rated';
  end if;

  v_ratee := case when v_listing.pharmacy_id = auth.uid() then v_deal.counterpart_pharmacy_id else v_listing.pharmacy_id end;

  insert into ratings (deal_id, rater_id, stars, credibility, responsiveness, packaging)
  values (p_deal_id, auth.uid(), p_stars, p_credibility, p_responsiveness, p_packaging);

  insert into notifications (pharmacy_id, kind, title, body, deal_id)
  values (v_ratee, 'new_rating', 'New rating received', p_stars || ' star rating received', p_deal_id);
end;
$$;

grant execute on function public.submit_rating(uuid, int, int, int, int) to authenticated;

-- get_my_rating_summary() — the client can already read individual rating
-- rows directly (ratings' select policy is public), but resolving "which
-- ratings were about me" requires the same deals+listings join
-- get_my_deals() already needed, so this stays a security-definer RPC for
-- consistency rather than something computed row-by-row on the client.
create or replace function public.get_my_rating_summary()
returns table (
  avg_stars numeric,
  rating_count int,
  avg_credibility numeric,
  avg_responsiveness numeric,
  avg_packaging numeric
)
language sql
security definer
set search_path = public
stable
as $$
  select
    avg(r.stars),
    count(*)::int,
    avg(r.credibility),
    avg(r.responsiveness),
    avg(r.packaging)
  from ratings r
  join deals d on d.id = r.deal_id
  join listings l on l.id = d.listing_id
  where (case when l.pharmacy_id = r.rater_id then d.counterpart_pharmacy_id else l.pharmacy_id end) = auth.uid();
$$;

grant execute on function public.get_my_rating_summary() to authenticated;
