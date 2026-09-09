import { isSupabaseConfigured } from "@/lib/env";
import { createSupabaseServerClient } from "@/lib/supabase/server-client";

export type AdminAccess =
  | { status: "not_configured" }
  | { status: "unauthenticated" }
  | { status: "forbidden" }
  | { status: "ok"; userId: string };

/**
 * Phase 1 placeholder guard for /admin.
 *
 * It deliberately does NOT grant access yet, even to a signed-in user:
 * role checks depend on the `profiles` table, which is created in the
 * Phase 2 migrations (see architecture doc, migration 0001). Until then
 * this always resolves to "not_configured" or "forbidden" rather than
 * faking an authorization decision.
 *
 * This function performs an authentication + (future) authorization check
 * only — it does not contain business logic, per the Server Action rules
 * in the security spec.
 */
export async function checkAdminAccess(): Promise<AdminAccess> {
  if (!isSupabaseConfigured()) {
    return { status: "not_configured" };
  }

  const supabase = await createSupabaseServerClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  if (!user) {
    return { status: "unauthenticated" };
  }

  // TODO(Phase 2): once `profiles` exists, replace this with a real
  // `profiles.role === 'admin'` check via the RLS-aware server client.
  return { status: "forbidden" };
}
