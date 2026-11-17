import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';

export default defineConfig({
  plugins: [react()],
  server: {
    // For `npm run dev` against the local compose stack (docker compose publishes none of these;
    // use the gateway on :8088 instead, or run the APIs yourself on these ports).
    proxy: {
      '/api/menu': 'http://localhost:8000',
      '/api/orders': 'http://localhost:8081',
      '/api/stats': 'http://localhost:8082',
    },
  },
});
