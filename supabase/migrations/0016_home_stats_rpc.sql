-- Home dashboard header stats (active listings + completed exchanges).
-- Mirrors get_my_rating_summary()'s pattern: a security-definer RPC rather
-- than raw client-side counts, since "completed exchanges" needs the same
-- listings/deals join get_my_deals() and get_my_rating_summary() already
-- do to resolve "deals I was a participant in".
create or replace function public.get_my_home_stats()
returns table (
  active_listings int,
  completed_exchanges int
)
language sql
security definer
set search_path = public
stable
as $$
  select
    (select count(*)::int from listings l where l.pharmacy_id = auth.uid() and l.state = 'available'),
    (
      select count(*)::int
      from deals d
      join listings l on l.id = d.listing_id
      where d.state = 'completed'
        and (l.pharmacy_id = auth.uid() or d.counterpart_pharmacy_id = auth.uid())
    );
$$;

grant execute on function public.get_my_home_stats() to authenticated;
