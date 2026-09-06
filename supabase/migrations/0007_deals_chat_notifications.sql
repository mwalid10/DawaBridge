-- Phase 3: deal negotiation, chat, notifications.
--
-- deals.state reuses the listing_state enum (available/reserved/completed/
-- cancelled) that 0001_init.sql already defined for it. There is no
-- separate "pending acceptance" state — request_listing() moves a deal
-- straight to 'reserved' and the two pharmacies negotiate over chat; the
-- seller then marks it 'completed' or either side 'cancel's it back to
-- available. This avoids an ALTER TYPE ... ADD VALUE migration for a
-- distinction the roadmap doesn't actually require.

-- messages ---------------------------------------------------------------
create table messages (
  id uuid primary key default gen_random_uuid(),
  deal_id uuid not null references deals(id),
  sender_id uuid not null references pharmacies(id),
  body text not null,
  created_at timestamptz not null default now()
);

create index idx_messages_deal_id on messages (deal_id, created_at);

-- notifications ------------------------------------------------------------
create table notifications (
  id uuid primary key default gen_random_uuid(),
  pharmacy_id uuid not null references pharmacies(id),
  kind text not null,
  title text not null,
  body text,
  deal_id uuid references deals(id),
  listing_id uuid references listings(id),
  read boolean not null default false,
  created_at timestamptz not null default now()
);

create index idx_notifications_pharmacy_id on notifications (pharmacy_id, created_at desc);

-- is_deal_participant() — security-definer helper so messages RLS can
-- check deal membership without needing a client-readable policy on
-- deals/listings beyond what 0001_init.sql already grants.
create or replace function public.is_deal_participant(p_deal_id uuid)
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select exists (
    select 1 from deals d
    join listings l on l.id = d.listing_id
    where d.id = p_deal_id
      and (l.pharmacy_id = auth.uid() or d.counterpart_pharmacy_id = auth.uid())
  );
$$;

grant execute on function public.is_deal_participant(uuid) to authenticated;

-- Row Level Security -------------------------------------------------------
alter table messages      enable row level security;
alter table notifications enable row level security;

create policy "messages: participants read" on messages
  for select using (is_deal_participant(deal_id));

create policy "messages: participants send" on messages
  for insert with check (sender_id = auth.uid() and is_deal_participant(deal_id));

create policy "notifications: owner reads own" on notifications
  for select using (pharmacy_id = auth.uid());

create policy "notifications: owner marks read" on notifications
  for update using (pharmacy_id = auth.uid()) with check (pharmacy_id = auth.uid());

-- No insert/delete policy on notifications: rows are only ever created by
-- the security-definer functions below (request_listing, respond_to_deal's
-- system messages via the trigger, direct inserts here) — same
-- write-only-via-trusted-path pattern as compliance_flags in 0006.

-- notify_new_message() — fires on every message insert (including the
-- auto-generated first message from request_listing and the system
-- messages respond_to_deal posts) and notifies whichever participant
-- didn't send it.
create or replace function public.notify_new_message()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_listing_owner uuid;
  v_counterpart uuid;
  v_recipient uuid;
begin
  select l.pharmacy_id, d.counterpart_pharmacy_id
    into v_listing_owner, v_counterpart
  from deals d
  join listings l on l.id = d.listing_id
  where d.id = new.deal_id;

  v_recipient := case when new.sender_id = v_listing_owner then v_counterpart else v_listing_owner end;

  insert into notifications (pharmacy_id, kind, title, body, deal_id)
  values (v_recipient, 'new_message', 'New message', left(new.body, 120), new.deal_id);

  return new;
end;
$$;

create trigger trg_notify_new_message
  after insert on messages
  for each row execute function notify_new_message();

-- request_listing() — the only way a deal gets created. Locks the listing
-- row so two simultaneous requests can't both reserve it, flips the
-- listing to 'reserved', and always posts an opening message (default
-- text if the caller didn't write one) so the seller gets a notification
-- via the trigger above.
create or replace function public.request_listing(p_listing_id uuid, p_message text default null)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_listing listings%rowtype;
  v_deal_id uuid;
  v_body text;
begin
  select * into v_listing from listings where id = p_listing_id for update;

  if v_listing.id is null then
    raise exception 'Listing not found';
  end if;
  if v_listing.pharmacy_id = auth.uid() then
    raise exception 'Cannot request your own listing';
  end if;
  if v_listing.state <> 'available' then
    raise exception 'Listing is no longer available';
  end if;

  insert into deals (listing_id, counterpart_pharmacy_id, state)
  values (p_listing_id, auth.uid(), 'reserved')
  returning id into v_deal_id;

  update listings set state = 'reserved', reserved_until = now() + interval '48 hours'
  where id = p_listing_id;

  v_body := coalesce(nullif(trim(p_message), ''), 'Hi, I''m interested in this listing.');
  insert into messages (deal_id, sender_id, body) values (v_deal_id, auth.uid(), v_body);

  return v_deal_id;
end;
$$;

grant execute on function public.request_listing(uuid, text) to authenticated;

-- respond_to_deal() — 'complete' (seller only) or 'cancel' (either side),
-- both only while the deal is still 'reserved'. Posts a system message so
-- the outcome shows up in the thread and the other party gets notified.
create or replace function public.respond_to_deal(p_deal_id uuid, p_action text)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_deal deals%rowtype;
  v_listing listings%rowtype;
  v_is_seller boolean;
  v_system_message text;
begin
  select * into v_deal from deals where id = p_deal_id for update;
  if v_deal.id is null then
    raise exception 'Deal not found';
  end if;

  select * into v_listing from listings where id = v_deal.listing_id for update;

  v_is_seller := v_listing.pharmacy_id = auth.uid();
  if not (v_is_seller or v_deal.counterpart_pharmacy_id = auth.uid()) then
    raise exception 'Not a participant in this deal';
  end if;
  if v_deal.state <> 'reserved' then
    raise exception 'Deal is no longer active';
  end if;

  if p_action = 'complete' then
    if not v_is_seller then
      raise exception 'Only the seller can mark a deal complete';
    end if;
    update deals set state = 'completed', completed_at = now() where id = p_deal_id;
    update listings set state = 'completed', reserved_until = null where id = v_deal.listing_id;
    v_system_message := 'Deal marked complete.';
  elsif p_action = 'cancel' then
    update deals set state = 'cancelled' where id = p_deal_id;
    update listings set state = 'available', reserved_until = null where id = v_deal.listing_id;
    v_system_message := 'Deal cancelled.';
  else
    raise exception 'Unknown action %', p_action;
  end if;

  insert into messages (deal_id, sender_id, body) values (p_deal_id, auth.uid(), v_system_message);
end;
$$;

grant execute on function public.respond_to_deal(uuid, text) to authenticated;

-- get_my_deals() / get_deal_detail() — same safe-join pattern as
-- search_listings/get_listing_detail in 0005: the client can't read other
-- pharmacies' rows directly (owner-only RLS), so these security-definer
-- RPCs expose only the counterpart's name plus deal/listing fields.
create or replace function public.get_my_deals()
returns table (
  deal_id uuid,
  listing_id uuid,
  drug_trade_name text,
  listing_type listing_type,
  deal_state listing_state,
  is_seller boolean,
  counterpart_id uuid,
  counterpart_name text,
  last_message text,
  last_message_at timestamptz,
  created_at timestamptz
)
language sql
security definer
set search_path = public
stable
as $$
  select
    d.id,
    d.listing_id,
    dr.trade_name,
    l.type,
    d.state,
    (l.pharmacy_id = auth.uid()),
    case when l.pharmacy_id = auth.uid() then d.counterpart_pharmacy_id else l.pharmacy_id end,
    cp.name,
    lm.body,
    lm.created_at,
    d.created_at
  from deals d
  join listings l on l.id = d.listing_id
  join drugs dr on dr.id = l.drug_id
  join pharmacies cp on cp.id = (case when l.pharmacy_id = auth.uid() then d.counterpart_pharmacy_id else l.pharmacy_id end)
  left join lateral (
    select body, created_at from messages m where m.deal_id = d.id order by m.created_at desc limit 1
  ) lm on true
  where l.pharmacy_id = auth.uid() or d.counterpart_pharmacy_id = auth.uid()
  order by coalesce(lm.created_at, d.created_at) desc;
$$;

grant execute on function public.get_my_deals() to authenticated;

create or replace function public.get_deal_detail(p_deal_id uuid)
returns table (
  deal_id uuid,
  listing_id uuid,
  drug_trade_name text,
  listing_type listing_type,
  quantity int,
  deal_state listing_state,
  is_seller boolean,
  counterpart_id uuid,
  counterpart_name text,
  created_at timestamptz
)
language sql
security definer
set search_path = public
stable
as $$
  select
    d.id, d.listing_id, dr.trade_name, l.type, l.quantity, d.state,
    (l.pharmacy_id = auth.uid()),
    case when l.pharmacy_id = auth.uid() then d.counterpart_pharmacy_id else l.pharmacy_id end,
    cp.name,
    d.created_at
  from deals d
  join listings l on l.id = d.listing_id
  join drugs dr on dr.id = l.drug_id
  join pharmacies cp on cp.id = (case when l.pharmacy_id = auth.uid() then d.counterpart_pharmacy_id else l.pharmacy_id end)
  where d.id = p_deal_id
    and (l.pharmacy_id = auth.uid() or d.counterpart_pharmacy_id = auth.uid());
$$;

grant execute on function public.get_deal_detail(uuid) to authenticated;

-- Realtime — new tables must be added to the publication explicitly. Most
-- fresh Supabase projects start with an empty `supabase_realtime`
-- publication, but some project templates create it as FOR ALL TABLES,
-- where re-adding an already-included table raises "duplicate_object"
-- (SQLSTATE 42710) and would otherwise abort this whole migration. Each
-- table is added in its own exception-guarded block so that's a no-op
-- instead of a failure, and one already-present table can't block another
-- from being added. `pharmacies` is included here too:
-- pending_approval_screen.dart has relied on a realtime subscription to it
-- since Phase 0/1, but no migration ever added it to the publication — a
-- pre-existing gap, fixed here alongside the tables this phase needs.
do $$ begin
  alter publication supabase_realtime add table messages;
exception when duplicate_object then null;
end $$;

do $$ begin
  alter publication supabase_realtime add table notifications;
exception when duplicate_object then null;
end $$;

do $$ begin
  alter publication supabase_realtime add table pharmacies;
exception when duplicate_object then null;
end $$;
