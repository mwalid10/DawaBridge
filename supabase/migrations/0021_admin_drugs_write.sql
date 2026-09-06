-- Products page in the admin dashboard needs to create/edit/delete drug
-- catalog entries. `drugs` (0001) only ever had a public-read policy — same
-- additive admin-write pattern as 0019's global_price_alerts/news_articles.
create policy "drugs: admin write" on drugs
  for all using (is_admin()) with check (is_admin());
