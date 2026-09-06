-- Follow-up to 0019: the admin Disputes screen needs to join dispute ->
-- deal -> listing -> drug for context (which drug, which pharmacies), but
-- deals/listings only had owner/participant-scoped read policies. Same
-- additive pattern as 0019 — admin read-all, no changes to existing
-- policies.

create policy "deals: admin read all" on deals
  for select using (is_admin());

create policy "listings: admin read all" on listings
  for select using (is_admin());
