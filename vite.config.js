import { defineConfig } from 'vite';

export default defineConfig({
  root: 'web',
  server: {
    host: '0.0.0.0',
    port: 3000,
    strictPort: true,
    hmr: false,
  },
  preview: {
    host: '0.0.0.0',
    port: 3000,
    strictPort: true,
  },
  build: {
    outDir: '../dist',
    emptyOutDir: true,
  },
});

