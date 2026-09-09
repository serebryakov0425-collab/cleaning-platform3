/**
 * Central, typed access to environment variables.
 *
 * SECURITY: SUPABASE_SERVICE_ROLE_KEY is deliberately NOT exposed here in a
 * way that could be imported from client code. It is only read inside
 * lib/supabase/service-role-client.ts, which is marked `server-only`.
 * Never rename it to NEXT_PUBLIC_SUPABASE_SERVICE_ROLE_KEY or similar.
 */

export const publicEnv = {
  NEXT_PUBLIC_SUPABASE_URL: process.env.NEXT_PUBLIC_SUPABASE_URL,
  NEXT_PUBLIC_SUPABASE_ANON_KEY: process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY,
  NEXT_PUBLIC_SITE_URL:
    process.env.NEXT_PUBLIC_SITE_URL ?? "http://localhost:3000",
};

/** True once the minimum client-facing Supabase config is present. */
export function isSupabaseConfigured(): boolean {
  return Boolean(
    publicEnv.NEXT_PUBLIC_SUPABASE_URL &&
      publicEnv.NEXT_PUBLIC_SUPABASE_ANON_KEY
  );
}
