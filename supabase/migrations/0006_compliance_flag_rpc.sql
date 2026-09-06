-- compliance_flags was never included in 0001_init.sql's "enable row level
-- security" block and has zero policies — meaning it's currently wide open
-- to any authenticated client. Lock it down: RLS on, no client-facing
-- policies at all, and a security-definer RPC as the sole write path so a
-- pharmacy can never spoof pharmacy_id or read other pharmacies' flags.
alter table compliance_flags enable row level security;

create or replace function public.log_compliance_flag(p_drug_id uuid, p_kind text)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into compliance_flags (pharmacy_id, drug_id, kind)
  values (auth.uid(), p_drug_id, p_kind);
end;
$$;

grant execute on function public.log_compliance_flag(uuid, text) to authenticated;
