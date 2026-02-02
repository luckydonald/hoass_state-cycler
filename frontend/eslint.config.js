import airbnb from './eslint.airbnb.mjs';
import initConfig from './eslint.init.js';
import base from './eslint.base.js';
import html from './eslint.html.js';
import ts from './eslint.ts.js';
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'node:url';
import tsParser from '@typescript-eslint/parser';
import vueParser from 'vue-eslint-parser';
import importPlugin from 'eslint-plugin-import';

/** @type { string[] } */
const OPTIONAL_CONFIGS = [
  'vue',
];

const optionals = await Promise.allSettled(
  OPTIONAL_CONFIGS.map(
    async (configName) => {
      try {
        return await import((`./eslint.${configName}.js`)).then(m => m.default ?? []);
      } catch {
        return [];
      }
    }
  )
);

// Read the repository root .gitignore (frontend_vue is one level deeper)
const __dirname = path.dirname(fileURLToPath(import.meta.url));
const repoGitignore = path.resolve(__dirname, '..', '.gitignore');
let gitignoreEntries = [];
if (fs.existsSync(repoGitignore)) {
  gitignoreEntries = fs.readFileSync(repoGitignore, 'utf8')
    .split(/\r?\n/)
    .map(l => l.trim())
    .filter(Boolean)
    // Ignore comments and negations for the flat config; keep simple patterns
    .filter(l => !l.startsWith('#') && !l.startsWith('!'))
    // Remove leading slash which is repo-root relative, flat-config expects glob-like patterns
    .map(l => l.replace(/^\//, ''));
}

// Also ignore our own ESLint flat-config module files to avoid eslint trying to lint them
const localEslintConfigFiles = [
  'eslint.config.js',
  'eslint.init.js',
  'eslint.base.js',
  'eslint.ts.js',
  'eslint.vue.js',
  'eslint.airbnb.mjs',
  'eslint.*.js',
  'eslint.*.mjs',
];
for (const p of localEslintConfigFiles) {
  if (!gitignoreEntries.includes(p)) gitignoreEntries.push(p);
}

// TypeScript parser options: point parser to the package's tsconfig.eslint.json so
// rules that require type information (like @typescript-eslint/await-thenable) work.
const tsParserOptions = {
  tsconfigRootDir: path.resolve(__dirname),
  // Ensure we do not enable projectService here — that option conflicts with
  // parserOptions.project in some plugin combinations. Disable it explicitly.
  projectService: false,
};

// Explicit absolute project path for parsers that need it
tsParserOptions.project = [path.resolve(__dirname, 'tsconfig.eslint.json')];


export default [
  // Ensure init config with parser/parserOptions is applied first
  ...initConfig,
  // Provide an explicit `ignores` entry so ESLint won't try to use includeIgnoreFile
  {
    ignores: gitignoreEntries,
  },
  // Also ignore TS declaration files as they're not part of lint type-checking here
  { ignores: ['**/*.d.ts'] },
  // Local plugin to auto-mark embedded HTML template literals
  {
    plugins: { 'local-mark-html': await import('./eslint.local.mark-html.mjs').then(m => m.default ?? m) },
    files: ['**/*.{ts,tsx,js,jsx}'],
    rules: { 'local-mark-html/mark-html': 'warn' },
  },
  // JavaScript/TypeScript/Vue/HTML configs
  ...airbnb,
  ...base,
  ...html,
  // Ensure import plugin is available for rules like import/no-unresolved that
  // may be referenced by presets.
  { plugins: { import: importPlugin } },
  // Explicit TypeScript languageOptions override so the parserOptions are applied
  // 1) For TS/TSX files: use the TypeScript parser directly so type-aware rules can run
  {
    files: ['**/*.ts', '**/*.tsx'],
    languageOptions: {
      parser: tsParser,
      parserOptions: tsParserOptions,
    },
  },
  // 2) For Vue SFCs: use the vue-eslint-parser as the outer parser and configure
  //    its `parser` option to use the TypeScript parser (so script blocks get type info)
  {
    files: ['**/*.vue'],
    languageOptions: {
      parser: vueParser,
      parserOptions: {
        parser: tsParser,
        // Do not spread project into SFC parserOptions; vue processing can
        // cause the 'file not included' diagnostics. Keep tsconfigRootDir.
        tsconfigRootDir: tsParserOptions.tsconfigRootDir,
        extraFileExtensions: ['.vue'],
      },
    },
  },
  ...ts,
  ...optionals.flatMap(r => r.status === 'fulfilled' ? (r.value ?? []) : []),
  // Final safety override: ensure plain JS files are parsed with espree and
  // disable specific typed rules that require type information on JS files.
  {
    files: ['**/*.js', '**/*.cjs', '**/*.mjs'],
    languageOptions: {
      parser: 'espree',
      parserOptions: { ecmaVersion: 2020, sourceType: 'module' }
    },
    rules: {
      '@typescript-eslint/await-thenable': 'off'
    }
  }
];
