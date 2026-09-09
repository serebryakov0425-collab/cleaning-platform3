# Cleaning Platform — Phase 1 scaffold

Next.js 16 (App Router, TypeScript) scaffold for the Czech cleaning-services
marketplace platform. This is **Phase 1 only**: project setup, i18n routing,
design-system wiring, and a placeholder `/admin` guard. No calculator, CRM,
matching, or real database schema yet — see the architecture doc for the
full phase plan.

## Stack

Next.js 16 · TypeScript · Tailwind CSS v4 · shadcn/ui · next-intl ·
Supabase (Postgres, Auth, Storage) · Zod · Resend · Upstash Redis · Vercel

## ⚠️ Verification status of this scaffold

This project was generated in a sandboxed environment **with no outbound
network access** (`npm install` fails with `403 Forbidden` against the npm
registry). That means the following could **not** be executed here:

- `npm install`
- `npm run lint`
- `npm run typecheck`
- `npm run build`

All source files were written and reviewed by hand for correctness, but
**none of this has been mechanically verified with real dependencies
installed.** A manual audit was done in place of `npm install`: every host
that could plausibly serve packages (npmjs, unpkg, jsdelivr, GitHub,
yarnpkg, esm.sh) was tested and all returned `403 host_not_allowed` from
the sandbox's egress proxy — this is an environment restriction, not
something fixable from inside the project. As a substitute, a global
`tsc --noEmit` (no node_modules, syntax-only) was run and every resulting
error was manually categorized: 100% of them are "cannot find module/name"
errors caused by the absence of `node_modules`, not real code defects.
One real (non-install-related) issue was found and fixed during that audit:
`i18n/routing.ts` used next-intl's object form of `localePrefix`
(`{ mode, prefixes }`), which is meant for *custom* prefixes that differ
from the locale code — unnecessary and an unverifiable risk here since
`en -> /en` is exactly the default `"as-needed"` behavior. Simplified to
the plain string form `localePrefix: "as-needed"`.

Please run the steps below locally and report/fix anything that surfaces —
do not treat this as a working, tested build until you've done that.

## Local setup

```bash
# 1. Install dependencies
npm install

# 2. Copy env template and fill in what you have.
#    The app boots and the public site works with NO Supabase credentials —
#    it just skips anything that needs a database. /admin will explicitly
#    say "Supabase is not configured" instead of pretending to work.
cp .env.example .env.local

# 3. Run the dev server
npm run dev
```

Open:
- `http://localhost:3000/` — Czech homepage (default locale, no prefix)
- `http://localhost:3000/en` — English homepage
- `http://localhost:3000/admin` — admin placeholder (reports its real state)

## Verification commands (run these locally — see note above)

```bash
npm run lint
npm run typecheck
npm run build
```

If any of these fail, that's expected to be caught and fixed as part of
actually landing Phase 1 — they have not been run successfully yet in this
environment.

## Environment variables

See `.env.example` for the full list. Summary:

| Variable | Required for | Notes |
|---|---|---|
| `NEXT_PUBLIC_SUPABASE_URL` | Supabase client (public + admin) | Safe to expose — protected by RLS |
| `NEXT_PUBLIC_SUPABASE_ANON_KEY` | Supabase client (public + admin) | Safe to expose — protected by RLS |
| `SUPABASE_SERVICE_ROLE_KEY` | Narrow server-only bypass cases | **Secret.** Never `NEXT_PUBLIC_*`. Only read in `lib/supabase/service-role-client.ts` |
| `RESEND_API_KEY`, `RESEND_FROM_EMAIL` | Email notifications | Not wired up yet (later phase) |
| `UPSTASH_REDIS_REST_URL`, `UPSTASH_REDIS_REST_TOKEN` | Rate limiting | Not wired up yet (later phase) |
| `NEXT_PUBLIC_SITE_URL` | canonical/OG URLs | Defaults to `http://localhost:3000` |

None of these have real values checked in. The app is designed to run
without any of them and clearly report what's missing rather than fail
silently or fake data.

## Project structure

```
app/
  (site)/[locale]/     ← public, locale-routed pages (cs = no prefix, en = /en)
  (admin)/admin/        ← internal tool, separate root layout, no locale prefix
  api/                   ← reserved for webhooks (Telegram, etc.) — empty for now
i18n/                    ← next-intl routing + request config
messages/                ← UI strings (cs.json, en.json) — NOT SEO content
lib/
  supabase/              ← server / browser / service-role clients
  auth/                  ← admin access guard (placeholder, see below)
  env.ts, utils.ts
components/ui/            ← shadcn/ui primitives (Button so far)
```

## Fixes applied after a real Vercel build log (not guessed)

1. **`next`/`react`/`react-dom` bumped to patched versions.** The original
   `package.json` pinned `next@16.0.0` / `react@19.2.0`, which are affected
   by **CVE-2025-66478 / CVE-2025-55182** — a critical (CVSS 10.0)
   unauthenticated RCE in the App Router's React Server Components
   protocol. Fixed releases: `next@16.0.7`, `react@19.2.3`+. Bumped both,
   plus `eslint-config-next` to match. **If you pull an older copy of this
   project, check `package.json` before deploying anywhere public.**
2. **Vercel "Build Command" must NOT re-run `npm install`.** A real build
   log showed `npm install` running twice: once automatically (Vercel's
   own install step, installs `devDependencies` too), then again because
   `npm install && npm run lint && ...` was pasted into the *Build Command*
   field. On the second run, Vercel/Next tooling has `NODE_ENV=production`
   set, so npm silently drops `devDependencies` (eslint, typescript,
   tailwindcss...) — causing `eslint: command not found`. Fix: set Build
   Command to `npm run lint && npm run typecheck && npm run build` only,
   and leave Install Command as Vercel's default (`npm install`).

## Notable decisions made in Phase 1

- **Locale code `cs`, not `cz`.** The brief says "CZ" for Czech, but `CZ`
  is the ISO country code, not the language code — the correct BCP-47/
  ISO 639-1 language tag is `cs`. Routing/URLs behave exactly as specified
  (no prefix for Czech, `/en` for English); only the internal locale
  identifier differs from the literal word used in the brief.
- **RU/UK are not yet registered in `i18n/routing.ts`.** Per the product
  decision ("architecturally supported, no MVP content"), the routing
  config supports adding them later by adding one locale code + one
  `messages/<locale>.json` file — nothing else changes. Registering them
  now with empty/stub content risked exactly the kind of placeholder
  content the instructions said to avoid.
- **`/admin` uses two independent root layouts** (Next.js "multiple root
  layouts" pattern via `(site)` and `(admin)` route groups), because it is
  intentionally outside the `[locale]` tree and the i18n middleware
  matcher.
- **Admin guard always resolves to `not_configured` or `forbidden`**, never
  `ok`, until Supabase credentials exist *and* the `profiles` table exists
  (Phase 2 migration). This is deliberate — no fake/placeholder "logged in
  as admin" state.
- **No `pricing_rules`/`service_options`/seed data** — none of it exists
  yet; nothing in this phase invents prices, services, partners, or
  reviews.
