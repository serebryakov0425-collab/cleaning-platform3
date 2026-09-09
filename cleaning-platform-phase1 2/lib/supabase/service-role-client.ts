import "server-only";
import { createClient } from "@supabase/supabase-js";
import { publicEnv } from "@/lib/env";

/**
 * ⚠️ SERVICE ROLE CLIENT — BYPASSES ROW LEVEL SECURITY.
 *
 * CRITICAL RULE (per project security spec): this is NOT a general-purpose
 * database client. Allowed use cases only:
 *   - system-level writes with no authenticated user in context
 *     (e.g. a Vercel Cron job, a provider webhook handler)
 *   - a specific, reviewed admin operation where RLS genuinely cannot
 *     express the required rule
 *
 * Rules:
 *   - never call this from a Client Component (the `server-only` import
 *     above makes that a build-time error, not just a convention)
 *   - never read/expose SUPABASE_SERVICE_ROLE_KEY via NEXT_PUBLIC_*
 *   - default to createSupabaseServerClient() (server-client.ts) instead;
 *     if you're not sure you need this file, you don't.
 *
 * SUPABASE_SERVICE_ROLE_KEY is intentionally read directly from
 * process.env here (not re-exported via lib/env.ts) to keep it out of any
 * shared object that other modules import.
 */
export function createSupabaseServiceRoleClient() {
  const url = publicEnv.NEXT_PUBLIC_SUPABASE_URL;
  const serviceRoleKey = process.env.SUPABASE_SERVICE_ROLE_KEY;

  if (!url || !serviceRoleKey) {
    throw new Error(
      "Service role client is not configured. Set NEXT_PUBLIC_SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY."
    );
  }

  return createClient(url, serviceRoleKey, {
    auth: { autoRefreshToken: false, persistSession: false },
  });
}
