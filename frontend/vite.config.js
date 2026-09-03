import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';

const api = 'http://localhost:3000';

export default defineConfig({
  plugins: [react()],
  // /health is proxied too, otherwise the footer's probe would get index.html
  // back from the dev server instead of the API response.
  server: { port: 5173, proxy: { '/api': api, '/health': api } },
});
