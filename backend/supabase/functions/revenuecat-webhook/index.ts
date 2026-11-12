// revenuecat-webhook — mirrors entitlement state into public.entitlements (service role).
// RevenueCat → Project settings → Integrations → Webhooks: URL of this function, Authorization
// header "Bearer <REVENUECAT_WEBHOOK_SECRET>". The app itself reads entitlements from the
// RevenueCat SDK; this copy exists for support and aggregate analytics only.
//
// app_user_id is set in the app to the Supabase auth user id (uuid), so no lookup is needed.

import { createClient } from "jsr:@supabase/supabase-js@2";
import { mapEvent } from "./logic.ts";

Deno.serve(async (req) => {
  if (req.method !== "POST") return new Response(null, { status: 405 });
  const secret = Deno.env.get("REVENUECAT_WEBHOOK_SECRET") ?? "";
  if (!secret || req.headers.get("authorization") !== `Bearer ${secret}`) return new Response("forbidden", { status: 403 });

  let payload: any;
  try { payload = await req.json(); } catch { return new Response("bad json", { status: 400 }); }
  const row = mapEvent(payload?.event);
  if (!row) return new Response(JSON.stringify({ ignored: true }), { headers: { "content-type": "application/json" } });

  const admin = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!, { auth: { persistSession: false } });
  const { error } = await admin.from("entitlements").upsert({ ...row, updated_at: new Date().toISOString() }, { onConflict: "user_id,product" });
  if (error) return new Response(error.message, { status: 500 });
  return new Response(JSON.stringify({ ok: true }), { headers: { "content-type": "application/json" } });
});
