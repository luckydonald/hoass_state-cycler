import path from 'node:path';
import { fileURLToPath } from 'node:url';

import vue from 'eslint-plugin-vue';
import vueParser from 'vue-eslint-parser';
import tsParser from '@typescript-eslint/parser';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

export default [
  ...vue.configs['flat/recommended'],
  {
    files: ['**/*.vue'],
    languageOptions: {
      parser: vueParser,
      parserOptions: {
        parser: tsParser,
        // Do not enable project for SFCs here — some environments cannot
        // resolve SFC virtual files into the tsconfig `include` set. Keep
        // tsconfigRootDir for fallback, and allow .vue extensions.
        tsconfigRootDir: __dirname,
        extraFileExtensions: ['.vue'],
      },
    },

    rules: {
      'vue/max-attributes-per-line': ['error', { singleline: 1, multiline: { max: 1 } }],
      'vue/html-closing-bracket-newline': ['error', { singleline: 'never', multiline: 'always' }],
      'vue/multiline-html-element-content-newline': [
        'error',
        { ignoreWhenEmpty: true, allowEmptyLines: false },
      ],
      'vue/html-indent': ['error', 2],
      'vue/html-self-closing': [
        'error',
        {
          html: { void: 'always', normal: 'always', component: 'always' },
          svg: 'always',
          math: 'always',
        },
      ],
      'vue/no-deprecated-slot-attribute': [
        'error',
        {
          ignoreParents: [
            'ha-expansion-panel',
            'ha-button',
            'ha-fab',
            'ha-dialog',
          ],
        },
      ],
      'vue/v-slot-style': 'off',
      'vue/array-bracket-newline': ['error', 'consistent'],
      'vue/v-bind-style': ['error', 'shorthand', { sameNameShorthand: 'always' }],
    },
  },
];
