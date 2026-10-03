// The lint rules for every TypeScript and JavaScript source in the repository.
// They live in web/ because that is where ESLint and its plugins are installed;
// eslint.config.mjs at the repository root re-exports them, so paths here are
// relative to the root.
import js from "@eslint/js";
import globals from "globals";
import tseslint from "typescript-eslint";

export default tseslint.config(
  {
    // Compiled, vendored, generated or not ours.
    ignores: [
      "web/public/**",
      "web/node_modules/**",
      "addons/**",
      "art/**",
      "assets/**",
      "local/**",
      "builds/**",
      "test-results/**",
      ".godot/**",
    ],
  },
  js.configs.recommended,
  ...tseslint.configs.recommended,
  {
    files: ["web/src/**/*.ts"],
    languageOptions: { globals: globals.browser },
  },
  {
    files: ["*.mjs", "tools/**/*.mjs", "web/*.{mjs,ts}", "web/{tests,scripts,e2e}/**/*.{mjs,ts}"],
    languageOptions: { globals: globals.node },
  },
  {
    // A test page loads this module in a browser.
    files: ["web/tests/fixtures/platform_controller_review.mjs"],
    languageOptions: { globals: globals.browser },
  },
);
