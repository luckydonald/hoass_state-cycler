/**
 * eslint.base.js → JS + generic rules
 * eslint.ts.js → TypeScript (type-checked) rules
 * eslint.vue.js → Vue-specific rules
 **/
import path from 'node:path';
import { fileURLToPath } from 'node:url';

import tseslint from 'typescript-eslint';
import tsParser from '@typescript-eslint/parser';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

export default [
  // TypeScript base recommended + stylistic (non-type-checked)
  ...tseslint.configs.recommended,
  ...tseslint.configs.stylistic,

  {
    files: ['**/*.ts', '**/*.tsx'],
    ignores: ['vite.config.ts', 'vitest.config.ts'],
    languageOptions: {
      parser: tsParser,
      parserOptions: {
        project: [path.resolve(__dirname, 'tsconfig.eslint.json')],
        tsconfigRootDir: __dirname,
      },
    },

    rules: {
      // Disable stylistic max-len (we prefer no enforced line length limits)
      '@stylistic/max-len': 'off',

      '@typescript-eslint/naming-convention': [
        'error',
        // Allow CSS custom properties ("--kebab-case") and Home Assistant element names ("ha-kebab")
        // for property/typeProperty/objectLiteralProperty selectors.
        { selector: 'property', format: null, filter: { regex: '^(--[a-z0-9-]+|ha-[a-z0-9-]+)$', match: true } },
        { selector: 'typeProperty', format: null, filter: { regex: '^(--[a-z0-9-]+|ha-[a-z0-9-]+)$', match: true } },
        { selector: 'objectLiteralProperty', format: null, filter: { regex: '^(--[a-z0-9-]+|ha-[a-z0-9-]+)$', match: true } },
        { selector: 'default', format: ['camelCase', 'PascalCase', 'UPPER_CASE'], leadingUnderscore: 'forbid' },
        { selector: 'property', format: ['camelCase', 'snake_case', 'PascalCase', 'UPPER_CASE'], leadingUnderscore: 'allow' },
        { selector: 'typeProperty', format: ['camelCase', 'snake_case', 'PascalCase', 'UPPER_CASE'], leadingUnderscore: 'allow' },
        // Keep existing objectLiteralProperty entry (allows --* already covered above)
        { selector: 'objectLiteralProperty', format: null, filter: { regex: '^--[a-z0-9-]+$', match: true } },
        { selector: 'method', format: ['camelCase', 'PascalCase'], leadingUnderscore: 'allow' },
        { selector: 'function', format: ['camelCase', 'PascalCase'], leadingUnderscore: 'allow' },
      ],

      '@typescript-eslint/no-use-before-define': ['error', { functions: false, classes: true, variables: true }],
      '@typescript-eslint/no-unused-vars': ['error', { argsIgnorePattern: '^_', varsIgnorePattern: '^_' }],
    },
  },

  // TS config files (vite / vitest – no type info)
  {
    files: ['vite.config.ts', 'vitest.config.ts'],
    languageOptions: {
      parser: tsParser,
      ecmaVersion: 2020,
      sourceType: 'module',
    },
    rules: {
      '@typescript-eslint/no-unused-vars': 'off',
      '@typescript-eslint/naming-convention': 'off',
      'no-multiple-empty-lines': 'off',
    },
  },
];
