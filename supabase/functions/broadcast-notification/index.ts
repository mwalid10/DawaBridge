// Admin broadcast, phase 2: does the in-app insert (same effect as
// admin_broadcast_notification() in 0032_admin_broadcast.sql) *and* the
// real FCM push in one call, so the dashboard only has to invoke one thing.
//
// Uses the service-role key throughout, so it bypasses RLS entirely — the
// admin check below is the only gate, mirroring is_admin() from
// 0019_admin_dashboard.sql but re-implemented here since Deno can't call
// into Postgres's security-definer functions directly.
import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";
import admin from "npm:firebase-admin@^12";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

// Lazy + fault-tolerant on purpose: until FCM_SERVICE_ACCOUNT_JSON is set
// (a manual Firebase-console step), this must still succeed at the in-app
// notifications insert below — only the push-sending loop should degrade.
function getMessaging(): admin.messaging.Messaging | null {
  try {
    if (admin.apps.length === 0) {
      const raw = Deno.env.get("FCM_SERVICE_ACCOUNT_JSON");
      if (!raw) return null;
      admin.initializeApp({ credential: admin.credential.cert(JSON.parse(raw)) });
    }
    return admin.messaging();
  } catch {
    return null;
  }
}

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

    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const supabase = createClient(supabaseUrl, serviceRoleKey);

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
    if (!body.title?.trim() || !body.body?.trim()) {
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

    const { error: insertError } = await supabase.from("notifications").insert(
      pharmacyIds.map((id: string) => ({
        pharmacy_id: id,
        kind: "admin_broadcast",
        title: body.title.trim(),
        body: body.body.trim(),
      })),
    );
    if (insertError) return json({ error: insertError.message }, 500);

    const { data: tokenRows, error: tokensError } = await supabase
      .from("device_push_tokens")
      .select("id, token")
      .in("pharmacy_id", pharmacyIds);
    if (tokensError) return json({ error: tokensError.message }, 500);

    const tokens = tokenRows ?? [];
    let pushed = 0;
    let failed = 0;
    const staleTokenIds: string[] = [];
    const messaging = tokens.length > 0 ? getMessaging() : null;

    if (tokens.length > 0 && !messaging) {
      failed = tokens.length;
    } else if (messaging) {
      for (let i = 0; i < tokens.length; i += 500) {
        const chunk = tokens.slice(i, i + 500);
        const response = await messaging.sendEachForMulticast({
          tokens: chunk.map((t: { token: string }) => t.token),
          notification: { title: body.title.trim(), body: body.body.trim() },
        });
        response.responses.forEach((r, idx) => {
          if (r.success) {
            pushed++;
          } else {
            failed++;
            if (r.error?.code === "messaging/registration-token-not-registered") {
              staleTokenIds.push(chunk[idx].id);
            }
          }
        });
      }
    }

    if (staleTokenIds.length > 0) {
      await supabase.from("device_push_tokens").delete().in("id", staleTokenIds);
    }

    return json({ recipients: pharmacyIds.length, pushed, failed });
  } catch (error) {
    return json({ error: (error as Error).message }, 500);
  }
});

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}
