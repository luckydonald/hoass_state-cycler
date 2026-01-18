import { defineConfig } from 'vite';
import vue from '@vitejs/plugin-vue';
import { resolve, dirname } from 'path';
import { fileURLToPath } from 'url';

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
      name: 'PluginTemplateCard',
      fileName: () => 'plugin-template-card.js',
      formats: ['iife'],
    },
    outDir: '../custom_components/plugin_template/www',
    emptyOutDir: false,
    rollupOptions: {
      output: {
        inlineDynamicImports: true,
        globals: {},
      },
    },
  },
});

