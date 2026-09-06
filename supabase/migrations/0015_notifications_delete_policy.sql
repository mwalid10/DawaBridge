-- Swipe-to-delete notifications: the only piece missing was a delete
-- policy — read/update-own already existed from 0007.
create policy "notifications: owner deletes own" on notifications
  for delete using (pharmacy_id = auth.uid());
