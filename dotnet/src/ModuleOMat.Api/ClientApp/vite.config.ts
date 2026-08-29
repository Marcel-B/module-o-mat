import { fileURLToPath, URL } from 'node:url'
import { defineConfig } from 'vite'
import vue from '@vitejs/plugin-vue'
import tailwindcss from '@tailwindcss/vite'
import Components from 'unplugin-vue-components/vite'
import { PrimeVueResolver } from '@primevue/auto-import-resolver'

const apiProxy = process.env.VITE_API_PROXY || 'http://127.0.0.1:5173'

export default defineConfig({
  base: '/ui/',
  resolve: {
    alias: {
      '@': fileURLToPath(new URL('./src', import.meta.url)),
    },
  },
  plugins: [
    vue(),
    tailwindcss(),
    Components({
      dts: true,
      resolvers: [PrimeVueResolver()],
    }),
    {
      name: 'spa-services-ready',
      configureServer(server) {
        const notify = () => console.log('Starting the development server')
        const attach = () => {
          const http = server.httpServer
          if (!http) {
            return
          }

          if (http.listening) {
            notify()
          } else {
            http.once('listening', notify)
          }
        }
        attach()
        return attach
      },
    },
  ],
  server: {
    host: '127.0.0.1',
    port: Number(process.env.PORT) || 5012,
    strictPort: true,
    proxy: {
      '/api': {
        target: apiProxy,
        changeOrigin: true,
        timeout: 600_000,
        proxyTimeout: 600_000,
      },
    },
  },
})
