import { defineConfig, globalIgnores } from "eslint/config";
import nextVitals from "eslint-config-next/core-web-vitals";
import nextTs from "eslint-config-next/typescript";

// NOTE: this deliberately does NOT use the FlatCompat bridge
// (`@eslint/eslintrc` + `compat.extends("next/core-web-vitals", ...)`).
// That legacy-config bridge throws
// `TypeError: Converting circular structure to JSON` with current
// ESLint 9.x + eslint-plugin-react versions (confirmed against a real
// Vercel build log). eslint-config-next now ships native flat config
// exports (`eslint-config-next/core-web-vitals`,
// `eslint-config-next/typescript`), which avoid the bridge entirely -
// this is the officially documented setup as of the current Next.js docs.
const eslintConfig = defineConfig([
    ...nextVitals,
    ...nextTs,
    globalIgnores([".next/**", "out/**", "build/**", "next-env.d.ts"]),
  ]);

export default eslintConfig;
