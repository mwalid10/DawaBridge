-- Deal lifecycle v2 — the seller now has to accept.
--
-- WHAT WAS BROKEN (both confirmed against live data):
--
-- 1. request_listing() flipped the listing straight to 'reserved' with no
--    seller involvement, so any buyer could unilaterally lock any listing
--    just by tapping Request. One bad actor could freeze a whole
--    governorate's inventory.
-- 2. reserved_until was set to now() + 48h and then never read by
--    anything — no cron, no lazy sweep, nothing. Every one of the 8
--    reserved listings in the database was 8-9 days past its
--    reserved_until and invisible to search, permanently.
--
-- THE NEW MODEL:
--
--   buyer requests  -> deal 'pending', listing STAYS 'available'
--   seller accepts  -> deal 'accepted', listing -> 'reserved',
--                      every other pending deal on that listing
--                      auto-declines
--   seller declines -> deal 'declined', listing untouched
--   seller completes-> deal 'completed', listing -> 'completed'
--   either cancels  -> deal 'cancelled', listing -> back to 'available'
--
-- Because a pending request no longer locks anything, several buyers can
-- queue on the same listing and the seller picks. That removes the
-- griefing vector entirely and makes the 48h window a soft deadline on
-- the seller rather than a hard lock on the asset.
--
-- deals.state also stops borrowing the listing_state enum, which allowed
-- the nonsensical deal state 'available'. It gets its own deal_status.

-- System messages first. respond_to_deal() used to post its "Deal
-- cancelled." / "Deal marked complete." lines with sender_id = auth.uid(),
-- so the chat rendered them as an ordinary bubble *from whoever clicked* —
-- the other party saw "Deal cancelled." as if the person had typed it.
-- They get sender_id = null + is_system = true instead, and the thread
-- renders them as neutral centred system lines.
alter table messages alter column sender_id drop not null;
alter table messages add column is_system boolean not null default false;

-- Backfill: every historical message whose body exactly matches one of the
-- two strings respond_to_deal() used to write is a system line.
update messages
set is_system = true, sender_id = null
where body in ('Deal marked complete.', 'Deal cancelled.');

create type deal_status as enum ('pending','accepted','declined','completed','cancelled');

-- Existing rows: 'reserved' was the old "live deal" state -> 'accepted'.
-- (0001_init.sql's default was 'reserved' and nothing ever wrote
-- 'available', but the else branch keeps the cast total either way.)
alter table deals alter column state drop default;

alter table deals
  alter column state type deal_status
  using (
    case state::text
      when 'reserved'  then 'accepted'::deal_status
      when 'completed' then 'completed'::deal_status
      when 'cancelled' then 'cancelled'::deal_status
      else 'cancelled'::deal_status
    end
  );

alter table deals alter column state set default 'pending'::deal_status;

-- expires_at drives the sweep in 0037. For a pending deal it's the
-- seller's response deadline; for an accepted one it's the reservation
-- deadline. Null once the deal reaches a terminal state.
alter table deals add column expires_at timestamptz;
alter table deals add column responded_at timestamptz;

update deals set expires_at = null where state in ('completed','cancelled','declined');

create index idx_deals_listing_state on deals (listing_id, state);
create index idx_deals_expires_at on deals (expires_at) where expires_at is not null;

-- Deal-window constants live in one place so the sweep job (0037) and the
-- RPCs below can't drift apart.
create or replace function public.deal_offer_window() returns interval
language sql immutable as $$ select interval '48 hours' $$;

create or replace function public.deal_reservation_window() returns interval
language sql immutable as $$ select interval '7 days' $$;

-- request_listing() v2 — creates a *pending offer*. Critically it no
-- longer touches the listing's state, so the listing stays visible and
-- requestable by others until the seller actually picks someone.
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
  v_existing uuid;
begin
  if auth.uid() is null then
    raise exception 'AUTH_REQUIRED';
  end if;
  if not is_approved_pharmacy() then
    raise exception 'PHARMACY_NOT_APPROVED';
  end if;

  select * into v_listing from listings where id = p_listing_id for update;

  if v_listing.id is null then
    raise exception 'LISTING_NOT_FOUND';
  end if;
  if v_listing.pharmacy_id = auth.uid() then
    raise exception 'LISTING_OWN';
  end if;
  if v_listing.state <> 'available' then
    raise exception 'LISTING_UNAVAILABLE';
  end if;
  if v_listing.expiry_date <= current_date then
    raise exception 'LISTING_EXPIRED';
  end if;

  -- One live offer per buyer per listing. Without this the buyer can spam
  -- the seller's inbox by tapping Request repeatedly.
  select id into v_existing
  from deals
  where listing_id = p_listing_id
    and counterpart_pharmacy_id = auth.uid()
    and state in ('pending','accepted');

  if v_existing is not null then
    raise exception 'DEAL_ALREADY_OPEN';
  end if;

  insert into deals (listing_id, counterpart_pharmacy_id, state, expires_at)
  values (p_listing_id, auth.uid(), 'pending', now() + deal_offer_window())
  returning id into v_deal_id;

  v_body := coalesce(nullif(trim(p_message), ''), 'Hi, I''m interested in this listing.');
  insert into messages (deal_id, sender_id, body) values (v_deal_id, auth.uid(), v_body);

  return v_deal_id;
end;
$$;

-- respond_to_deal() v2 — 'accept'/'decline' are new and seller-only;
-- 'complete' stays seller-only; 'cancel' stays either-side.
--
-- System messages are now written with sender_id = null (see 0034's
-- messages change below) so the chat can render them as neutral system
-- lines instead of attributing "Deal cancelled." to whoever clicked.
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
  v_notify uuid;
  v_notify_title text;
begin
  if auth.uid() is null then
    raise exception 'AUTH_REQUIRED';
  end if;

  select * into v_deal from deals where id = p_deal_id for update;
  if v_deal.id is null then
    raise exception 'DEAL_NOT_FOUND';
  end if;

  select * into v_listing from listings where id = v_deal.listing_id for update;

  v_is_seller := v_listing.pharmacy_id = auth.uid();
  if not (v_is_seller or v_deal.counterpart_pharmacy_id = auth.uid()) then
    raise exception 'DEAL_NOT_PARTICIPANT';
  end if;

  v_notify := case when v_is_seller then v_deal.counterpart_pharmacy_id else v_listing.pharmacy_id end;

  if p_action = 'accept' then
    if not v_is_seller then raise exception 'DEAL_SELLER_ONLY'; end if;
    if v_deal.state <> 'pending' then raise exception 'DEAL_NOT_PENDING'; end if;
    if v_listing.state <> 'available' then raise exception 'LISTING_UNAVAILABLE'; end if;

    update deals
      set state = 'accepted',
          responded_at = now(),
          expires_at = now() + deal_reservation_window()
      where id = p_deal_id;

    update listings
      set state = 'reserved',
          reserved_until = now() + deal_reservation_window()
      where id = v_deal.listing_id;

    -- Everyone else queued on this listing is now out.
    update deals
      set state = 'declined', responded_at = now(), expires_at = null
      where listing_id = v_deal.listing_id
        and id <> p_deal_id
        and state = 'pending';

    insert into notifications (pharmacy_id, kind, title, body, deal_id)
    select counterpart_pharmacy_id, 'deal_declined', 'Request declined',
           'The seller accepted another request for this listing.', id
    from deals
    where listing_id = v_deal.listing_id and id <> p_deal_id
      and state = 'declined' and responded_at >= now() - interval '1 second';

    v_system_message := 'Request accepted — the listing is now reserved for you.';
    v_notify_title := 'Request accepted';

  elsif p_action = 'decline' then
    if not v_is_seller then raise exception 'DEAL_SELLER_ONLY'; end if;
    if v_deal.state <> 'pending' then raise exception 'DEAL_NOT_PENDING'; end if;

    update deals set state = 'declined', responded_at = now(), expires_at = null where id = p_deal_id;
    v_system_message := 'Request declined.';
    v_notify_title := 'Request declined';

  elsif p_action = 'complete' then
    if not v_is_seller then raise exception 'DEAL_SELLER_ONLY'; end if;
    if v_deal.state <> 'accepted' then raise exception 'DEAL_NOT_ACTIVE'; end if;

    update deals set state = 'completed', completed_at = now(), expires_at = null where id = p_deal_id;
    update listings set state = 'completed', reserved_until = null where id = v_deal.listing_id;
    v_system_message := 'Deal marked complete.';
    v_notify_title := 'Deal completed';

  elsif p_action = 'cancel' then
    if v_deal.state not in ('pending','accepted') then raise exception 'DEAL_NOT_ACTIVE'; end if;

    update deals set state = 'cancelled', expires_at = null where id = p_deal_id;
    -- Only an accepted deal ever reserved the listing, so only that one
    -- has anything to hand back.
    if v_deal.state = 'accepted' then
      update listings set state = 'available', reserved_until = null where id = v_deal.listing_id;
    end if;
    v_system_message := 'Deal cancelled.';
    v_notify_title := 'Deal cancelled';

  else
    raise exception 'DEAL_UNKNOWN_ACTION';
  end if;

  insert into messages (deal_id, sender_id, body, is_system)
  values (p_deal_id, null, v_system_message, true);

  insert into notifications (pharmacy_id, kind, title, body, deal_id)
  values (v_notify, 'deal_' || p_action, v_notify_title, v_system_message, p_deal_id);
end;
$$;

grant execute on function public.request_listing(uuid, text) to authenticated;
grant execute on function public.respond_to_deal(uuid, text) to authenticated;

-- get_my_deals / get_deal_detail: deal_state changes type, and both gain
-- expires_at so the client can show the countdown. Table-returning
-- functions can't change their output columns via CREATE OR REPLACE.
drop function if exists public.get_my_deals();
drop function if exists public.get_deal_detail(uuid);

create function public.get_my_deals()
returns table (
  deal_id uuid,
  listing_id uuid,
  drug_trade_name text,
  listing_type listing_type,
  deal_state deal_status,
  is_seller boolean,
  counterpart_id uuid,
  counterpart_name text,
  last_message text,
  last_message_at timestamptz,
  expires_at timestamptz,
  unread_count int,
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
    d.expires_at,
    coalesce(un.c, 0)::int,
    d.created_at
  from deals d
  join listings l on l.id = d.listing_id
  join drugs dr on dr.id = l.drug_id
  join pharmacies cp on cp.id = (case when l.pharmacy_id = auth.uid() then d.counterpart_pharmacy_id else l.pharmacy_id end)
  left join lateral (
    select body, created_at from messages m where m.deal_id = d.id order by m.created_at desc limit 1
  ) lm on true
  left join lateral (
    select count(*) as c from notifications n
    where n.deal_id = d.id and n.pharmacy_id = auth.uid() and not n.read
  ) un on true
  where l.pharmacy_id = auth.uid() or d.counterpart_pharmacy_id = auth.uid()
  order by coalesce(lm.created_at, d.created_at) desc;
$$;

create function public.get_deal_detail(p_deal_id uuid)
returns table (
  deal_id uuid,
  listing_id uuid,
  drug_trade_name text,
  listing_type listing_type,
  quantity int,
  deal_state deal_status,
  is_seller boolean,
  counterpart_id uuid,
  counterpart_name text,
  expires_at timestamptz,
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
    d.expires_at,
    d.created_at
  from deals d
  join listings l on l.id = d.listing_id
  join drugs dr on dr.id = l.drug_id
  join pharmacies cp on cp.id = (case when l.pharmacy_id = auth.uid() then d.counterpart_pharmacy_id else l.pharmacy_id end)
  where d.id = p_deal_id
    and (l.pharmacy_id = auth.uid() or d.counterpart_pharmacy_id = auth.uid());
$$;

grant execute on function public.get_my_deals() to authenticated;
grant execute on function public.get_deal_detail(uuid) to authenticated;

-- submit_rating / get_my_home_stats referenced the old enum value by
-- name; 'completed' survives the rename so only the comparison operand's
-- type changes, but both are recreated here so their plans are rebuilt
-- against deal_status rather than silently depending on a cast.
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
  if p_stars is null or p_stars < 1 or p_stars > 5 then
    raise exception 'RATING_INVALID_STARS';
  end if;

  select * into v_deal from deals where id = p_deal_id;
  if v_deal.id is null then
    raise exception 'DEAL_NOT_FOUND';
  end if;

  select * into v_listing from listings where id = v_deal.listing_id;

  if not (v_listing.pharmacy_id = auth.uid() or v_deal.counterpart_pharmacy_id = auth.uid()) then
    raise exception 'DEAL_NOT_PARTICIPANT';
  end if;
  if v_deal.state <> 'completed' then
    raise exception 'RATING_DEAL_NOT_COMPLETED';
  end if;

  v_ratee := case when v_listing.pharmacy_id = auth.uid() then v_deal.counterpart_pharmacy_id else v_listing.pharmacy_id end;

  insert into ratings (deal_id, rater_id, stars, credibility, responsiveness, packaging)
  values (p_deal_id, auth.uid(), p_stars, p_credibility, p_responsiveness, p_packaging);

  insert into notifications (pharmacy_id, kind, title, body, deal_id)
  values (v_ratee, 'new_rating', 'New rating received', p_stars || ' star rating received', p_deal_id);
end;
$$;

grant execute on function public.submit_rating(uuid, int, int, int, int) to authenticated;

-- notify_new_message() v2. Two fixes:
--
-- 1. It now skips system messages. respond_to_deal() writes its own,
--    better-titled notification for every transition, and the system
--    message it also posts would otherwise trigger a second, duplicate
--    "New message" notification with sender_id = null resolving the
--    recipient to the wrong party.
-- 2. It collapses consecutive unread messages in the same thread into one
--    notification row. Previously every single chat message inserted a
--    row, so notifications grew 1:1 with chat volume forever — and the
--    unread badge is computed from that table. A thread where someone
--    sends 40 messages produced 40 rows and a badge reading "40" for one
--    conversation. Now the first unread message in a thread creates the
--    row and later ones just refresh its preview text and timestamp.
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
  v_existing uuid;
begin
  if new.is_system then
    return new;
  end if;

  select l.pharmacy_id, d.counterpart_pharmacy_id
    into v_listing_owner, v_counterpart
  from deals d
  join listings l on l.id = d.listing_id
  where d.id = new.deal_id;

  v_recipient := case when new.sender_id = v_listing_owner then v_counterpart else v_listing_owner end;
  if v_recipient is null then
    return new;
  end if;

  select id into v_existing
  from notifications
  where pharmacy_id = v_recipient
    and deal_id = new.deal_id
    and kind = 'new_message'
    and not read
  limit 1;

  if v_existing is not null then
    update notifications
      set body = left(new.body, 120), created_at = now()
      where id = v_existing;
  else
    insert into notifications (pharmacy_id, kind, title, body, deal_id)
    values (v_recipient, 'new_message', 'New message', left(new.body, 120), new.deal_id);
  end if;

  return new;
end;
$$;
