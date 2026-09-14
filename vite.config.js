import { defineConfig } from 'vite';

export default defineConfig({
  root: 'web',
  server: {
    host: '0.0.0.0',
    port: 3000,
    allowedHosts: 'all',
  },
  preview: {
    host: '0.0.0.0',
    port: 3000,
  },
  build: {
    outDir: '../dist',
    emptyOutDir: true,
  },
});
