-- Admin-initiated broadcast notifications (phase 1 of push notifications:
-- in-app only, delivered via the existing `notifications` table/Realtime
-- bell — see 0007_deals_chat_notifications.sql). Targeting mirrors the
-- filters already exposed on the pharmacies admin screen: governorate,
-- status, plan, or a single pharmacy; any combination left null broadens
-- the match, so no filters at all means "everyone".
--
-- Two security-definer functions, same is_admin() guard as 0019's other
-- admin write paths: one that performs the insert (returns the recipient
-- count), one read-only twin for the dashboard's live count preview before
-- the admin commits to sending.

create or replace function public.admin_broadcast_notification(
  p_title text,
  p_body text,
  p_governorate text default null,
  p_status pharmacy_status default null,
  p_plan plan_status default null,
  p_pharmacy_id uuid default null
) returns int
language plpgsql
security definer
set search_path = public
as $$
declare
  v_count int;
begin
  if not is_admin() then
    raise exception 'Not authorized';
  end if;

  insert into notifications (pharmacy_id, kind, title, body)
  select id, 'admin_broadcast', p_title, p_body
  from pharmacies
  where (p_pharmacy_id is null or id = p_pharmacy_id)
    and (p_governorate is null or governorate = p_governorate)
    and (p_status is null or status = p_status)
    and (p_plan is null or plan = p_plan);

  get diagnostics v_count = row_count;
  return v_count;
end;
$$;

grant execute on function public.admin_broadcast_notification(text, text, text, pharmacy_status, plan_status, uuid) to authenticated;

create or replace function public.admin_count_broadcast_targets(
  p_governorate text default null,
  p_status pharmacy_status default null,
  p_plan plan_status default null,
  p_pharmacy_id uuid default null
) returns int
language sql
security definer
set search_path = public
stable
as $$
  select case when is_admin() then (
    select count(*)::int from pharmacies
    where (p_pharmacy_id is null or id = p_pharmacy_id)
      and (p_governorate is null or governorate = p_governorate)
      and (p_status is null or status = p_status)
      and (p_plan is null or plan = p_plan)
  ) else 0 end;
$$;

grant execute on function public.admin_count_broadcast_targets(text, pharmacy_status, plan_status, uuid) to authenticated;
