// Shared FCM sending, used by both `broadcast-notification` (admin-initiated)
// and `send-push` (database-triggered, for messages and deal events).
//
// Extracted because there are now two senders and exactly one correct way to
// do the fiddly parts: chunking at 500 tokens, and pruning registration
// tokens that FCM reports as dead so `device_push_tokens` doesn't accumulate
// garbage from reinstalled apps.
import { createClient, type SupabaseClient } from "jsr:@supabase/supabase-js@2";
import admin from "npm:firebase-admin@^12";

export interface PushResult {
  pushed: number;
  failed: number;
  /** Tokens FCM said are dead; already deleted by `sendPush`. */
  pruned: number;
  /**
   * Why nothing was sent, when nothing was sent.
   *
   * Added because the first live test of this pipeline returned
   * `{pushed:0, failed:1}` with a 200 and no log line, which is the same
   * shape whether the credentials are missing, malformed, or FCM simply
   * rejected the token. Three very different fixes, one indistinguishable
   * result — so the reason is reported explicitly now.
   */
  reason?:
    | "no_tokens"
    | "fcm_env_missing"
    | "fcm_env_malformed"
    | "fcm_init_failed"
    | "fcm_rejected";
}

let _messagingError: PushResult["reason"];

/// Lazy + fault-tolerant on purpose: until FCM_SERVICE_ACCOUNT_JSON is set
/// (a manual Firebase-console step) the caller must still be able to do its
/// in-app work — only the push-sending half should degrade.
///
/// Records *why* it failed in `_messagingError` rather than swallowing it,
/// so the caller can say something more useful than "failed".
export function getMessaging(): admin.messaging.Messaging | null {
  _messagingError = undefined;
  try {
    if (admin.apps.length === 0) {
      const raw = Deno.env.get("FCM_SERVICE_ACCOUNT_JSON");
      if (!raw) {
        _messagingError = "fcm_env_missing";
        console.error("FCM_SERVICE_ACCOUNT_JSON is not set on this function.");
        return null;
      }

      let parsed: Record<string, unknown>;
      try {
        parsed = JSON.parse(raw);
      } catch (error) {
        // Overwhelmingly the common cause: the service-account JSON was
        // pasted into the dashboard with its newlines mangled, so the
        // private_key field no longer parses.
        _messagingError = "fcm_env_malformed";
        console.error(`FCM_SERVICE_ACCOUNT_JSON is not valid JSON: ${(error as Error).message}`);
        return null;
      }

      for (const field of ["project_id", "client_email", "private_key"]) {
        if (!parsed[field]) {
          _messagingError = "fcm_env_malformed";
          console.error(`FCM_SERVICE_ACCOUNT_JSON is missing "${field}".`);
          return null;
        }
      }

      admin.initializeApp({ credential: admin.credential.cert(parsed as admin.ServiceAccount) });
    }
    return admin.messaging();
  } catch (error) {
    _messagingError = "fcm_init_failed";
    console.error(`Firebase admin init failed: ${(error as Error).message}`);
    return null;
  }
}

export function serviceClient(): SupabaseClient {
  return createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );
}

/// Sends one notification to every device registered to [pharmacyIds].
///
/// `data` is delivered alongside the visible notification so the app can
/// deep-link on tap (see `_handleNotificationTap` in the Flutter app's
/// main.dart). FCM requires every data value to be a string.
export async function sendPush(
  supabase: SupabaseClient,
  pharmacyIds: string[],
  title: string,
  body: string,
  data: Record<string, string> = {},
): Promise<PushResult> {
  if (pharmacyIds.length === 0) return { pushed: 0, failed: 0, pruned: 0 };

  const { data: tokenRows, error } = await supabase
    .from("device_push_tokens")
    .select("id, token")
    .in("pharmacy_id", pharmacyIds);
  if (error) throw new Error(error.message);

  const tokens = tokenRows ?? [];
  if (tokens.length === 0) return { pushed: 0, failed: 0, pruned: 0, reason: "no_tokens" };

  const messaging = getMessaging();
  if (!messaging) {
    // No usable FCM credentials — the in-app notification still exists, the
    // device just won't be woken. `reason` says which of the three it is.
    return {
      pushed: 0,
      failed: tokens.length,
      pruned: 0,
      reason: _messagingError ?? "fcm_init_failed",
    };
  }

  let pushed = 0;
  let failed = 0;
  const staleTokenIds: string[] = [];

  for (let i = 0; i < tokens.length; i += 500) {
    const chunk = tokens.slice(i, i + 500);
    const response = await messaging.sendEachForMulticast({
      tokens: chunk.map((t: { token: string }) => t.token),
      notification: { title, body },
      data,
      android: { priority: "high" },
      apns: {
        payload: { aps: { sound: "default", badge: 1 } },
      },
    });
    response.responses.forEach((r, idx) => {
      if (r.success) {
        pushed++;
      } else {
        failed++;
        console.error(`FCM rejected a token: ${r.error?.code ?? 'unknown'} — ${r.error?.message ?? ''}`);
        if (
          r.error?.code === "messaging/registration-token-not-registered" ||
          r.error?.code === "messaging/invalid-registration-token"
        ) {
          staleTokenIds.push(chunk[idx].id);
        }
      }
    });
  }

  if (staleTokenIds.length > 0) {
    await supabase.from("device_push_tokens").delete().in("id", staleTokenIds);
  }

  return {
    pushed,
    failed,
    pruned: staleTokenIds.length,
    reason: pushed === 0 && failed > 0 ? "fcm_rejected" : undefined,
  };
}

/// Constant-time string compare, so the shared-secret check on `send-push`
/// doesn't leak the secret a byte at a time through response timing.
export function secretsMatch(a: string | null, b: string | undefined): boolean {
  if (!a || !b || a.length !== b.length) return false;
  let diff = 0;
  for (let i = 0; i < a.length; i++) diff |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return diff === 0;
}

export const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type, x-push-secret",
};

export function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}
