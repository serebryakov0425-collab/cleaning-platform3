import createMiddleware from "next-intl/middleware";
import { routing } from "./i18n/routing";

export default createMiddleware(routing);

export const config = {
  // Run on every path except: /admin, /api, Next.js internals and files
  // with an extension (static assets). /admin is intentionally excluded —
  // it is not locale-prefixed and has its own auth guard (see
  // lib/auth/require-admin.ts and app/(admin)/admin/*).
  matcher: ["/((?!api|admin|_next|_vercel|.*\\..*).*)"],
};
