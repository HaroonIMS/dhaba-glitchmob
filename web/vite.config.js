import { defineConfig, loadEnv } from 'vite';
import react from '@vitejs/plugin-react';

export default defineConfig(({ mode }) => {
  const env = loadEnv(mode, process.cwd(), '');
  const apiTarget = env.VITE_DEV_API_TARGET || 'http://localhost:8088';

  return {
    plugins: [react()],
    server: {
      proxy: {
        '/api/menu': {
          target: apiTarget,
          changeOrigin: true,
        },
        '/api/orders': {
          target: apiTarget,
          changeOrigin: true,
        },
        '/api/stats': {
          target: apiTarget,
          changeOrigin: true,
        },
      },
    },
  };
});
