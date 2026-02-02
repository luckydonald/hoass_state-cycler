import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

import vue from '@vitejs/plugin-vue';
import { defineConfig } from 'vite';

const __dirname = dirname(fileURLToPath(import.meta.url));

export default defineConfig({
  plugins: [
    vue({
      template: {
        compilerOptions: {
          // Treat ha-* tags as custom elements (Home Assistant components)
          isCustomElement: (tag: string) => tag.startsWith('ha-'),
        },
      },
    }),
  ],
  define: {
    'process.env': {},
  },
  resolve: {
    alias: {
      '@': resolve(__dirname, 'src'),
    },
  },
  build: {
    lib: {
      entry: resolve(__dirname, 'src/main.ts'),
      name: 'StateCyclerCard',
      fileName: () => 'state-cycler-card.js',
      formats: [
        'iife',
      ],
    },
    outDir: '../custom_components/state_cycler/www',
    emptyOutDir: false,
    rollupOptions: {
      output: {
        inlineDynamicImports: true,
        globals: {},
      },
    },
  },
});
