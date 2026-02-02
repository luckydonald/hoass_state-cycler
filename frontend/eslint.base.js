/**
 * eslint.base.js → JS + generic rules
 * eslint.ts.js → TypeScript (type-checked) rules
 * eslint.vue.js → Vue-specific rules
 **/
import js from '@eslint/js';
import globals from 'globals';

export default [
  // Base JS recommended
  js.configs.recommended,

  {
    languageOptions: {
      ecmaVersion: 2020,
      sourceType: 'module',
      globals: {
        ...globals.browser,
        ...globals.node,
      },
    },

    rules: {
      // Arrays
      'array-bracket-newline': ['error', { multiline: true, minItems: 1 }],
      'array-element-newline': ['error', 'always'],

      // Objects
      'object-curly-newline': ['error', { multiline: true, consistent: true }],
      'object-property-newline': ['error', { allowAllPropertiesOnSameLine: true }],

      // Functions
      'function-call-argument-newline': ['error', 'consistent'],
      'function-paren-newline': ['error', 'multiline'],

      // Imports / misc
      'comma-dangle': ['error', 'always-multiline'],
      'max-len': 'off',

      // Project conventions
      'no-underscore-dangle': 'off',
      'max-classes-per-file': ['error', 3],
      'class-methods-use-this': 'off',
      'no-console': 'warn',
      'no-restricted-globals': ['error', { name: 'event', message: 'Do not use global event' }],
      'default-case': 'off',
    },
  },

  // JS config files (no type checking)
  {
    files: ['**/*.js', '**/*.cjs', '**/*.mjs'],
    languageOptions: {
      // Use parser name 'espree' for compatibility with various @eslint/js versions
      parser: 'espree',
      ecmaVersion: 2020,
      sourceType: 'module',
    },
    rules: {
      'array-bracket-newline': 'off',
      'array-element-newline': 'off',
    },
  },
];
