import { checkAdminAccess } from "@/lib/auth/require-admin";

/**
 * Phase 1: no CRM/CMS here yet (out of scope per instructions). This page
 * only proves the auth-guard skeleton works and reports its real state —
 * it never pretends access was granted.
 */
export default async function AdminHomePage() {
  const access = await checkAdminAccess();

  switch (access.status) {
    case "not_configured":
      return (
        <StatusMessage
          title="Supabase není nakonfigurováno"
          description="Nastavte NEXT_PUBLIC_SUPABASE_URL, NEXT_PUBLIC_SUPABASE_ANON_KEY a SUPABASE_SERVICE_ROLE_KEY v .env.local a restartujte aplikaci."
        />
      );
    case "unauthenticated":
      return (
        <StatusMessage
          title="Přihlášení je vyžadováno"
          description="Tato sekce je dostupná pouze přihlášeným administrátorům. Přihlašovací formulář bude implementován spolu s auth flow."
        />
      );
    case "forbidden":
      return (
        <StatusMessage
          title="Přístup zatím nelze ověřit"
          description="Kontrola role administrátora čeká na tabulku profiles (Phase 2). Přístup je do té doby ve výchozím stavu zamítnut."
        />
      );
    case "ok":
      return (
        <StatusMessage
          title="Admin panel"
          description={`Přihlášen jako uživatel ${access.userId}. Obsah CRM/CMS bude implementován v dalších fázích.`}
        />
      );
  }
}

function StatusMessage({
  title,
  description,
}: {
  title: string;
  description: string;
}) {
  return (
    <main className="mx-auto flex min-h-screen max-w-xl flex-col items-center justify-center gap-3 px-4 text-center">
      <h1 className="text-2xl font-semibold">{title}</h1>
      <p className="text-muted-foreground">{description}</p>
    </main>
  );
}
