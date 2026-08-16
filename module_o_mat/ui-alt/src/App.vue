<script setup lang="ts">
import { RouterLink } from 'vue-router'
import MaintenanceOverlay from './components/MaintenanceOverlay.vue'

const logoSrc = `${import.meta.env.BASE_URL}logo.svg`
</script>

<template>
  <div class="app-shell">
    <header class="app-header">
      <RouterLink to="/" class="app-brand">
        <img :src="logoSrc" alt="" width="40" height="40" />
        <span>ModuleOMat · eigene UI</span>
      </RouterLink>
      <a href="/" class="ui-switcher">Oberflächen</a>
    </header>
    <main class="app-main">
      <router-view />
    </main>
    <Toast />
    <ConfirmDialog />
    <MaintenanceOverlay />
  </div>
</template>
