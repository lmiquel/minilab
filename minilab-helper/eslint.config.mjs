import js from "@eslint/js";
import tseslint from "typescript-eslint";
import importPlugin from "eslint-plugin-import";

export default tseslint.config(
  {
    ignores: ["dist/**", "node_modules/**"],
  },
  js.configs.recommended,
  ...tseslint.configs.recommended,
  {
    files: ["**/*.ts"],
    plugins: { import: importPlugin },
    languageOptions: {
      parserOptions: {
        project: "./tsconfig.json",
        tsconfigRootDir: import.meta.dirname,
      },
    },
    settings: {
      "import/resolver": {
        typescript: { project: "./tsconfig.json" },
      },
    },
    rules: {
      "@typescript-eslint/consistent-type-imports": ["error", { prefer: "type-imports" }],
      "@typescript-eslint/no-unused-vars": ["warn", { argsIgnorePattern: "^_" }],
      "@typescript-eslint/no-explicit-any": "off",

      // Un dictionnaire (src/dictionaries/**) ne doit jamais dépendre de la
      // logique d'un manager (src/managers/**) : les managers consomment les
      // dictionnaires, jamais l'inverse (voir command-dictionary vs
      // commands-manager/internals/command-handlers.ts).
      "import/no-restricted-paths": [
        "error",
        {
          zones: [
            {
              target: "./src/dictionaries",
              from: "./src/managers",
              message: "Un dictionnaire ne doit pas importer la logique d'un manager — cette dépendance doit toujours aller dans l'autre sens.",
            },
          ],
        },
      ],
    },
  }
);
