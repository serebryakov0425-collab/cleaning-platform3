import { createServerClient } from "@supabase/ssr";
import { cookies } from "next/headers";
import { publicEnv, isSupabaseConfigured } from "@/lib/env";

/**
 * RLS-aware server client bound to the current user's session (via cookies).
 *
 * This is the DEFAULT client for Server Actions and Server Components.
 * It respects Row Level Security — a request can only see/change what the
 * signed-in user's role is allowed to via the RLS policies defined in the
 * database (see architecture doc, section 3 "RLS-стратегия").
 *
 * Do NOT use this file for operations that must bypass RLS — see
 * ./service-role-client.ts for that narrow, explicitly-justified case.
 */
export async function createSupabaseServerClient() {
  if (!isSupabaseConfigured()) {
    throw new Error(
      "Supabase is not configured. Set NEXT_PUBLIC_SUPABASE_URL and NEXT_PUBLIC_SUPABASE_ANON_KEY."
    );
  }

  const cookieStore = await cookies();

  return createServerClient(
    publicEnv.NEXT_PUBLIC_SUPABASE_URL!,
    publicEnv.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
    {
      cookies: {
        getAll() {
          return cookieStore.getAll();
        },
        setAll(cookiesToSet) {
          try {
            cookiesToSet.forEach(({ name, value, options }) =>
              cookieStore.set(name, value, options)
            );
          } catch {
            // `setAll` can be invoked from a Server Component render, where
            // cookies cannot be mutated. Safe to ignore as long as the
            // session is refreshed by middleware elsewhere in the request
            // lifecycle (wired up when auth flows are implemented).
          }
        },
      },
    }
  );
}
