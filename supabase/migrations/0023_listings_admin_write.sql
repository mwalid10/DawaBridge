-- Bugfix: the admin Listings page's cancel/reinstate/delete actions
-- (ListingsController.setState/delete in pharma_exchange_admin) have been
-- silent no-ops. 0020 only ever gave admins SELECT on `listings` ("admin
-- read all", added so the Disputes page could join listing->drug context)
-- — there was never an admin UPDATE or DELETE policy. With RLS blocking
-- every row, PostgREST's update()/delete() calls match zero rows and
-- return success with no error, so the client saw the dialog close but
-- nothing actually changed in the database. Same additive pattern as
-- 0019/0020: admin gets its own permissive policy, existing owner-scoped
-- policies are untouched.
--
-- Delete was previously blocked for *everyone*, not just admins — 0001
-- never added a delete policy on listings at all. The admin delete
-- confirmation dialog's warning ("It will fail if a deal already
-- references it") already anticipates the real remaining guard here: the
-- foreign-key reference from `deals.listing_id`, which still applies and
-- will raise a normal constraint-violation error for that case.
create policy "listings: admin update" on listings
  for update using (is_admin()) with check (is_admin());

create policy "listings: admin delete" on listings
  for delete using (is_admin());
