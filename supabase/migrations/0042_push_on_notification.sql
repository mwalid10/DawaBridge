-- Real push notifications for messages and deal events.
--
-- THE GAP
--
-- `notify_new_message()` (0007) and `respond_to_deal()` (0035) insert into
-- `notifications`, which lights up the in-app bell over Realtime. That's
-- all they ever did. The only code anywhere that actually sent an FCM
-- message was the admin broadcast edge function — so with the app
-- backgrounded or closed, a pharmacy was told nothing.
--
-- That was tolerable when a buyer's request reserved the listing outright:
-- the seller found out whenever they next opened the app, and the listing
-- was held for them regardless. It stopped being tolerable with 0035's
-- accept/decline step, which gives the seller a 48-hour window to respond
-- (enforced by the sweep job in 0038). A seller who doesn't open the app
-- loses the sale, and the buyer waits two days to find that out.
--
-- HOW IT WORKS
--
-- An AFTER INSERT trigger on `notifications` posts the row to the
-- `send-push` edge function through pg_net, which is asynchronous — it
-- queues the request and returns immediately, so a slow or dead FCM never
-- delays (or fails) the insert that triggered it. Sending a chat message
-- must not be able to fail because a push couldn't go out.
--
-- CONFIGURATION (both required, see the DO block at the bottom for status)
--
--   1. Vault secrets, so the trigger knows where to post and how to prove
--      it's us:
--        select vault.create_secret('https://<ref>.supabase.co', 'project_url');
--        select vault.create_secret('<random string>', 'push_hook_secret');
--
--   2. The same secret on the function, so it accepts the call:
--        supabase secrets set PUSH_HOOK_SECRET='<the same random string>'
--
--   And, for anything to actually be delivered, FCM_SERVICE_ACCOUNT_JSON
--   must also be set on the functions (a Firebase-console step that was
--   already outstanding for the broadcast function).
--
-- Until those exist the trigger no-ops quietly: the in-app notification is
-- still created, nothing errors, and no push is attempted.

create extension if not exists pg_net with schema extensions;

create or replace function public.push_notification_to_device()
returns trigger
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_url text;
  v_secret text;
begin
  -- Admin broadcasts are pushed by the broadcast function itself, which
  -- writes these same rows. Pushing here too would double every one.
  if new.kind = 'admin_broadcast' then
    return new;
  end if;

  begin
    select decrypted_secret into v_url
      from vault.decrypted_secrets where name = 'project_url';
    select decrypted_secret into v_secret
      from vault.decrypted_secrets where name = 'push_hook_secret';
  exception when others then
    -- Vault unavailable or secrets absent. Not fatal: the in-app
    -- notification has already been written and is what the bell reads.
    return new;
  end;

  if v_url is null or v_secret is null then
    return new;
  end if;

  -- Fire-and-forget. pg_net queues this on a background worker; it does not
  -- block the transaction and its failure cannot roll back the insert.
  perform net.http_post(
    url := v_url || '/functions/v1/send-push',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'x-push-secret', v_secret
    ),
    body := jsonb_build_object(
      'id', new.id,
      'pharmacy_id', new.pharmacy_id,
      'kind', new.kind,
      'title', new.title,
      'body', new.body,
      'deal_id', new.deal_id,
      'listing_id', new.listing_id
    ),
    timeout_milliseconds := 5000
  );

  return new;
end;
$$;

revoke execute on function public.push_notification_to_device() from public, anon, authenticated;

-- INSERT only, deliberately.
--
-- 0035 changed notify_new_message() to collapse consecutive unread messages
-- in one thread into a single notification row: the first one INSERTs, the
-- rest UPDATE its preview text. Hanging the push off INSERT therefore gives
-- one push per conversation until the recipient reads it, instead of one
-- per message — which is the behaviour you want on a thread where someone
-- sends six lines in a row. Deal events each write their own row with a
-- distinct `kind`, so every one of those still pushes.
create trigger trg_push_notification_to_device
  after insert on notifications
  for each row execute function push_notification_to_device();

-- Report configuration status in the query output rather than failing —
-- this migration is valid and complete without the secrets, it just can't
-- deliver anything yet.
do $$
declare
  v_has_url boolean := false;
  v_has_secret boolean := false;
begin
  begin
    select exists(select 1 from vault.decrypted_secrets where name = 'project_url') into v_has_url;
    select exists(select 1 from vault.decrypted_secrets where name = 'push_hook_secret') into v_has_secret;
  exception when others then
    null;
  end;

  if v_has_url and v_has_secret then
    raise notice 'Push hook configured. Also confirm PUSH_HOOK_SECRET and FCM_SERVICE_ACCOUNT_JSON are set on the edge functions.';
  else
    raise notice 'Push hook INACTIVE — missing vault secret(s): project_url=%, push_hook_secret=%. See the header comment in this migration.',
      v_has_url, v_has_secret;
  end if;
end $$;
