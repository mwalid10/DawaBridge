// Adds a dashboard admin. Super-admin only (0044_admin_roles.sql).
//
// Admins need their own auth.users row, and only the service role can
// create one — which is why this is an edge function and `admins` has no
// client INSERT policy. Role changes and removal don't need the service
// role, so the dashboard does those directly under RLS.
//
// The account is created with a password the super admin chooses and hands
// over, already email-confirmed: the confirmation/invite emails send a link,
// not a code, and a link is useless for signing in to the desktop app.
//
// An email that already has an account is re-admitted rather than rejected
// (typically an admin who was removed and is being added back) — its
// password is reset to the one given. Pharmacy accounts are refused: one
// account can't be both, same rule as complete_my_registration().
import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { corsHeaders, json, serviceClient } from "../_shared/fcm.ts";

const ROLES = ["super_admin", "moderator", "viewer"];

interface CreateAdminBody {
  email: string;
  password: string;
  name: string;
  role: string;
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

    const { data: caller } = await supabase.from("admins").select("role").eq("id", userData.user.id).maybeSingle();
    if (caller?.role !== "super_admin") {
      return json({ error: "Not authorized" }, 403);
    }

    const body: CreateAdminBody = await req.json();
    const email = body.email?.trim().toLowerCase();
    const name = body.name?.trim();
    const password = body.password ?? "";
    if (!email || !email.includes("@") || !name) {
      return json({ error: "email and name are required", code: "INVALID_INPUT" }, 400);
    }
    if (password.length < 8) {
      return json({ error: "password must be at least 8 characters", code: "WEAK_PASSWORD" }, 400);
    }
    if (!ROLES.includes(body.role)) {
      return json({ error: "invalid role", code: "INVALID_INPUT" }, 400);
    }

    let userId: string;
    const { data: existingId, error: lookupError } = await supabase.rpc("admin_user_id_by_email", { p_email: email });
    if (lookupError) return json({ error: lookupError.message }, 500);

    if (existingId) {
      userId = existingId as string;

      const { data: pharmacy } = await supabase.from("pharmacies").select("id").eq("id", userId).maybeSingle();
      if (pharmacy) {
        return json({ error: "This email belongs to a pharmacy account", code: "IS_PHARMACY" }, 409);
      }
      const { data: admin } = await supabase.from("admins").select("id").eq("id", userId).maybeSingle();
      if (admin) {
        return json({ error: "Already an admin", code: "ALREADY_ADMIN" }, 409);
      }

      const { error: updateError } = await supabase.auth.admin.updateUserById(userId, {
        password,
        email_confirm: true,
      });
      if (updateError) return json({ error: updateError.message }, 500);
    } else {
      const { data: created, error: createError } = await supabase.auth.admin.createUser({
        email,
        password,
        email_confirm: true,
        user_metadata: { name },
      });
      if (createError || !created.user) {
        return json({ error: createError?.message ?? "Couldn't create user" }, 500);
      }
      userId = created.user.id;
    }

    const { error: insertError } = await supabase.from("admins").insert({ id: userId, name, role: body.role });
    if (insertError) return json({ error: insertError.message }, 500);

    return json({ id: userId, email, name, role: body.role });
  } catch (error) {
    return json({ error: (error as Error).message }, 500);
  }
});
