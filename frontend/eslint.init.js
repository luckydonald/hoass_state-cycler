import path from 'node:path';
import { fileURLToPath } from 'node:url';
import tsParser from '@typescript-eslint/parser';
import vueParser from 'vue-eslint-parser';

// Resolve __dirname for this ESM module
const __dirname = path.dirname(fileURLToPath(import.meta.url));

// Base parser options without `project` (safe for SFCs)
const tsParserOptionsBase = {
  tsconfigRootDir: path.resolve(__dirname),
};

// Parser options that include the `project` (used only for .ts/.tsx)
const tsParserOptionsWithProject = {
  ...tsParserOptionsBase,
  project: [path.resolve(__dirname, 'tsconfig.eslint.json')],
};

export default [
  // For plain JS config and script files (including eslint.config.js), use espree
  {
    files: [
      'eslint.config.js',
      'eslint.*.js',
      '*.config.js',
      '**/*.config.js',
      '**/*.js',
      '**/*.cjs',
      '**/*.mjs'
    ],
    languageOptions: {
      parser: 'espree',
      parserOptions: {
        ecmaVersion: 2020,
        sourceType: 'module'
      }
    },
    // Disable the specific typed rule on JS files where type information is not available
    rules: {
      '@typescript-eslint/await-thenable': 'off'
    }
  },
  // Ensure TypeScript files are parsed with type information
  {
    files: ['**/*.ts', '**/*.tsx'],
    languageOptions: {
      parser: tsParser,
      parserOptions: tsParserOptionsWithProject,
    },
  },
  // Ensure Vue SFC script blocks are parsed by the TypeScript parser
  // but do NOT pass the `project` to the SFC parser options to avoid
  // "file not included in tsconfig" diagnostics from TypeScript when
  // eslint inspects the virtual SFC script file.
  {
    files: ['**/*.vue'],
    languageOptions: {
      parser: vueParser,
      parserOptions: {
        parser: tsParser,
        ...tsParserOptionsBase,
      },
    },
  },
];
