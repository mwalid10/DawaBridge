-- Post-0040 grant cleanup. Applied directly to the project on 2026-09-18,
-- recorded here so a fresh database ends up in the same state.
--
-- 0040's bulk revoke loop only took EXECUTE away from PUBLIC and `anon`.
-- That wasn't enough, because Supabase ships a default-privileges rule
--
--   alter default privileges in schema public
--     grant all on functions to anon, authenticated, service_role;
--
-- so every new function gets a *direct* grant to `authenticated` at creation
-- time, independent of the PUBLIC grant. Anything meant to be off-limits to
-- clients has to be revoked from `authenticated` by name as well.

-- release_expired_deals() is the cron sweep, not a client API. 0040
-- deliberately left it out of the re-grant list, but the default-privileges
-- grant had already given it to `authenticated` anyway.
revoke execute on function public.release_expired_deals() from authenticated;

-- Trigger functions. Postgres refuses a direct call ("trigger functions can
-- only be called as triggers"), so these were never exploitable — but they
-- were still enumerable on /rest/v1/rpc/ and flagged by the linter, and
-- there's no reason for them to be on the REST surface at all.
revoke execute on function public.listings_block_controlled() from public, anon, authenticated;
revoke execute on function public.match_listing_alerts() from public, anon, authenticated;
revoke execute on function public.notify_new_message() from public, anon, authenticated;
revoke execute on function public.record_listing_price_history() from public, anon, authenticated;
revoke execute on function public.touch_updated_at() from public, anon, authenticated;
revoke execute on function public.listings_guard_updates() from public, anon, authenticated;
revoke execute on function public.listings_check_expiry_on_insert() from public, anon, authenticated;

-- Advisor: function_search_path_mutable. These two are immutable constants
-- so the risk is theoretical, but a pinned search_path costs nothing.
alter function public.deal_offer_window() set search_path = public;
alter function public.deal_reservation_window() set search_path = public;

-- Remaining advisor findings after this migration, all accepted:
--
--   * spatial_ref_sys RLS disabled, postgis/pg_trgm in public schema —
--     PostGIS-owned, not ours to move.
--   * st_estimatedextent anon-executable — PostGIS built-in.
--   * listing_price_history RLS enabled with no policies — intentional, see
--     the table comment added in 0040.
--   * ~38 "authenticated can execute SECURITY DEFINER" — that *is* the app's
--     API surface. Each one is guarded internally on auth.uid() / is_admin()
--     / is_approved_pharmacy(). Expected, not a finding.
--   * Leaked password protection disabled — a dashboard toggle
--     (Authentication -> Policies), not something SQL can set.
