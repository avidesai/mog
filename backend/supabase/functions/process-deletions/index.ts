// process-deletions — scheduled (hourly). Service role. Completes "Delete everything":
//   1. for every deletion_queue row requested ≥ 24 h ago and not processed: delete the auth user
//      (cascades the tombstoned profile row and any remaining FK children), mark processed
//   2. purge consent rows whose user was deleted more than 3 years ago (the retention promise)
// The 24 h delay exists only so a support request to undo an accidental tap can be honoured;
// the policy promises completion within 30 days and this runs every hour.
//
// Schedule with: select cron.schedule('process-deletions', '0 * * * *', $$ select net.http_post(...) $$);
// or the Supabase dashboard's function scheduler.

import { createClient } from "jsr:@supabase/supabase-js@2";

Deno.serve(async (req) => {
  const secret = Deno.env.get("CRON_SECRET");
  if (secret && req.headers.get("authorization") !== `Bearer ${secret}`) return new Response("forbidden", { status: 403 });

  const admin = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!, { auth: { persistSession: false } });
  const cutoff = new Date(Date.now() - 24 * 3600 * 1000).toISOString();

  const { data: queue, error } = await admin.from("deletion_queue").select("user_id, requested_at").is("processed_at", null).lte("requested_at", cutoff).limit(200);
  if (error) return new Response(error.message, { status: 500 });

  let done = 0, failed = 0;
  for (const row of queue ?? []) {
    const { error: delErr } = await admin.auth.admin.deleteUser(row.user_id);
    if (delErr && !/not found/i.test(delErr.message)) { failed++; continue; }
    await admin.from("deletion_queue").update({ processed_at: new Date().toISOString() }).eq("user_id", row.user_id);
    done++;
  }

  // consent purge: rows for users deleted > 3 years ago. public.users rows are gone (cascade), so
  // the consent's user_id no longer resolves; keep by revoked_at age instead.
  const threeYears = new Date(Date.now() - 3 * 365 * 24 * 3600 * 1000).toISOString();
  const { count } = await admin.from("consents").delete({ count: "exact" }).lte("revoked_at", threeYears).select("id");

  return new Response(JSON.stringify({ deleted_users: done, failed, purged_consents: count ?? 0 }), { headers: { "content-type": "application/json" } });
});
