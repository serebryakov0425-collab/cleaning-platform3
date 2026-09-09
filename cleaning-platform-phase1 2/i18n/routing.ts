import { defineRouting } from "next-intl/routing";

/**
 * MVP locales: cs (default, no URL prefix) + en (/en).
 *
 * ru/uk are intentionally NOT registered here yet — the brief requires them
 * to be "architecturally supported" but without MVP content. Enabling them
 * later is a two-line change (add to `locales` + `prefixes`) plus a new
 * `messages/<locale>.json` file — no other code changes are required.
 *
 * NOTE: "cs" is the correct ISO 639-1 code for Czech (the brief/user used
 * "CZ", which is the country code, not the language code). Using "cs" here
 * is a deliberate correction, not a deviation from the requirement.
 */
export const routing = defineRouting({
  locales: ["cs", "en"],
  defaultLocale: "cs",
  // "as-needed": the default locale (cs) is never prefixed, every other
  // locale is prefixed with its own locale code — i.e. en -> /en. This is
  // exactly what's required; no custom `prefixes` mapping is needed since
  // the locale code and the desired URL segment are identical.
  localePrefix: "as-needed",
});

export type AppLocale = (typeof routing.locales)[number];
