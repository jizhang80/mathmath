import js from "@eslint/js";
import reactHooks from "eslint-plugin-react-hooks";
import globals from "globals";
import tseslint from "typescript-eslint";

export default tseslint.config(
  { ignores: ["**/dist/**", "**/node_modules/**", "web/core/src/generated/**", "web/app/test-results/**"] },
  {
    files: ["web/**/*.{ts,tsx}", "*.ts"],
    extends: [js.configs.recommended, ...tseslint.configs.strictTypeChecked],
    languageOptions: {
      parserOptions: {
        project: [
          "./tsconfig.json",
          "./web/core/tsconfig.json",
          "./web/core/tsconfig.node.json",
          "./web/app/tsconfig.json",
          "./web/app/tsconfig.node.json",
        ],
        tsconfigRootDir: import.meta.dirname,
      },
    },
    rules: {
      "no-console": "error",
      "@typescript-eslint/restrict-template-expressions": ["error", { allowNumber: false }],
    },
  },
  {
    files: ["web/app/src/**/*.tsx"],
    plugins: { "react-hooks": reactHooks },
    rules: reactHooks.configs.recommended.rules,
    languageOptions: { globals: globals.browser },
  },
  {
    // Node entry points may write to the console.
    files: ["web/core/src/cli.ts", "web/core/scripts/**/*.ts"],
    rules: { "no-console": "off" },
  },
);
