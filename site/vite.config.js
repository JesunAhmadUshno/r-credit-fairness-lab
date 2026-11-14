import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';
// The site is generated from ../results/ at build time (src/make-data.mjs writes src/data.json
// from the committed CSV and JSON artifacts), so every number on the page comes from the record.
export default defineConfig({
  base: '/r-credit-fairness-lab/',
  plugins: [react()],
  server: { fs: { allow: ['..'] } },
});
