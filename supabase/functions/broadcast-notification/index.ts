// Admin broadcast: does the in-app insert (same effect as
// admin_broadcast_notification() in 0032_admin_broadcast.sql) *and* the
// real FCM push in one call, so the dashboard only has to invoke one thing.
//
// Uses the service-role key throughout, so it bypasses RLS entirely — the
// admin check below is the only gate, mirroring is_admin() from
// 0019_admin_dashboard.sql but re-implemented here since Deno can't call
// into Postgres's security-definer functions directly.
//
// The FCM mechanics (chunking, stale-token pruning) moved to
// `_shared/fcm.ts` when `send-push` became a second sender — there's one
// implementation now instead of two that could drift.
import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { corsHeaders, json, sendPush, serviceClient } from "../_shared/fcm.ts";

interface BroadcastBody {
  title: string;
  body: string;
  governorate?: string | null;
  status?: string | null;
  plan?: string | null;
  pharmacyId?: string | null;
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return json({ error: "Missing Authorization header" }, 401);
    }

    const supabase = serviceClient();

    const jwt = authHeader.replace("Bearer ", "");
    const { data: userData, error: userError } = await supabase.auth.getUser(jwt);
    if (userError || !userData.user) {
      return json({ error: "Invalid session" }, 401);
    }

    const { data: adminRow } = await supabase.from("admins").select("id").eq("id", userData.user.id).maybeSingle();
    if (!adminRow) {
      return json({ error: "Not authorized" }, 403);
    }

    const body: BroadcastBody = await req.json();
    const title = body.title?.trim();
    const message = body.body?.trim();
    if (!title || !message) {
      return json({ error: "title and body are required" }, 400);
    }

    let targets = supabase.from("pharmacies").select("id");
    if (body.pharmacyId) targets = targets.eq("id", body.pharmacyId);
    if (body.governorate) targets = targets.eq("governorate", body.governorate);
    if (body.status) targets = targets.eq("status", body.status);
    if (body.plan) targets = targets.eq("plan", body.plan);

    const { data: pharmacies, error: targetsError } = await targets;
    if (targetsError) return json({ error: targetsError.message }, 500);

    const pharmacyIds = (pharmacies ?? []).map((p: { id: string }) => p.id);
    if (pharmacyIds.length === 0) {
      return json({ recipients: 0, pushed: 0, failed: 0 });
    }

    // kind 'admin_broadcast' is what stops the notifications trigger
    // (migration 0042) pushing these a second time — see send-push.
    const { error: insertError } = await supabase.from("notifications").insert(
      pharmacyIds.map((id: string) => ({
        pharmacy_id: id,
        kind: "admin_broadcast",
        title,
        body: message,
      })),
    );
    if (insertError) return json({ error: insertError.message }, 500);

    const result = await sendPush(supabase, pharmacyIds, title, message, {
      kind: "admin_broadcast",
    });

    return json({ recipients: pharmacyIds.length, ...result });
  } catch (error) {
    return json({ error: (error as Error).message }, 500);
  }
});
