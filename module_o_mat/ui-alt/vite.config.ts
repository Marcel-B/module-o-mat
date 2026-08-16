import { defineConfig } from 'vite'
import vue from '@vitejs/plugin-vue'
import Components from 'unplugin-vue-components/vite'
import { PrimeVueResolver } from '@primevue/auto-import-resolver'

export default defineConfig({
  base: process.env.VITE_BASE || (process.env.NODE_ENV === 'production' ? '/ui-alt/' : '/'),
  plugins: [
    vue(),
    Components({
      dts: true,
      resolvers: [PrimeVueResolver()],
    }),
  ],
  server: {
    port: 5174,
    proxy: {
      '/api': {
        target: 'http://localhost:4000',
        changeOrigin: true,
      },
    },
  },
})
