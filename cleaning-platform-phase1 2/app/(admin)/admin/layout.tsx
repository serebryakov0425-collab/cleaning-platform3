import type { Metadata } from "next";
import "@/app/globals.css";

export const metadata: Metadata = {
  title: "Admin",
  robots: { index: false, follow: false },
};

/**
 * Separate root layout for /admin (Next.js "multiple root layouts" pattern
 * via route groups — see app/(site)/[locale]/layout.tsx for the other one).
 * /admin is deliberately NOT under [locale]: it's an internal tool, not a
 * public/SEO surface, and is excluded from the i18n middleware matcher.
 */
export default function AdminRootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="cs">
      <body className="min-h-screen bg-background font-sans text-foreground antialiased">
        {children}
      </body>
    </html>
  );
}
