// Delivers a real push for the in-app notifications the database creates:
// new chat messages, deal accepted/declined/completed/cancelled, expiries,
// disputes and ratings.
//
// WHY THIS EXISTS
//
// Until now the ONLY thing that actually sent an FCM message was the
// admin broadcast function. `notify_new_message()` and `respond_to_deal()`
// inserted a row into `notifications` and stopped there — which lights up
// the in-app bell, but only if the pharmacy already has the app open. With
// the app backgrounded or closed, nothing reached the device at all.
//
// That was survivable when a buyer's request reserved a listing outright.
// It isn't now: migration 0035 added a seller accept/decline step with a
// 48-hour response window, so a seller who doesn't happen to open the app
// silently loses the sale and the buyer waits two days for nothing.
//
// HOW IT'S CALLED
//
// A trigger on `notifications` (migration 0042) posts the new row here via
// pg_net. It is NOT called by the mobile client.
//
// AUTH
//
// Deployed with verify_jwt disabled, because the caller is Postgres, not a
// signed-in user — there is no JWT to present. Access is gated on a shared
// secret instead: the trigger reads it from Supabase Vault and sends it as
// `x-push-secret`, and it's compared here against PUSH_HOOK_SECRET in
// constant time. Without the secret set in both places the endpoint
// refuses everything.
import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { corsHeaders, json, secretsMatch, sendPush, serviceClient } from "../_shared/fcm.ts";

interface NotificationRow {
  id: string;
  pharmacy_id: string;
  kind: string;
  title: string;
  body: string | null;
  deal_id: string | null;
  listing_id: string | null;
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  const expected = Deno.env.get("PUSH_HOOK_SECRET");
  if (!expected) {
    // Fail closed. An unset secret must not mean "let everyone in".
    return json({ error: "Push hook not configured" }, 503);
  }
  if (!secretsMatch(req.headers.get("x-push-secret"), expected)) {
    return json({ error: "Forbidden" }, 403);
  }

  try {
    const row = (await req.json()) as NotificationRow;
    if (!row?.pharmacy_id || !row?.title) {
      return json({ error: "pharmacy_id and title are required" }, 400);
    }

    // Admin broadcasts are pushed by `broadcast-notification` itself, which
    // inserts the same rows. Pushing here too would double every one.
    if (row.kind === "admin_broadcast") {
      return json({ skipped: "admin_broadcast" });
    }

    const supabase = serviceClient();

    // Values must be strings — FCM rejects a data payload with any other
    // type. These are what the app's tap handler routes on.
    const data: Record<string, string> = { kind: row.kind, notification_id: row.id };
    if (row.deal_id) data.deal_id = row.deal_id;
    if (row.listing_id) data.listing_id = row.listing_id;

    const result = await sendPush(
      supabase,
      [row.pharmacy_id],
      row.title,
      row.body ?? "",
      data,
    );

    return json(result);
  } catch (error) {
    // Never 500 loudly at the trigger: pg_net fires this asynchronously and
    // nothing retries, so a failure here must not look like success but also
    // can't be allowed to affect the originating transaction (it already
    // committed). The log line is the signal.
    console.error("send-push failed", error);
    return json({ error: (error as Error).message }, 500);
  }
});
