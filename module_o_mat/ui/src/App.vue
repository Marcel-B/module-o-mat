<script setup lang="ts">
import AppHeader from './components/AppHeader.vue'
import MaintenanceOverlay from './components/MaintenanceOverlay.vue'
</script>

<template>
  <div class="app-shell">
    <AppHeader />
    <main class="app-main">
      <router-view />
    </main>
    <Toast position="top-right" />
    <ConfirmDialog />
    <MaintenanceOverlay />
  </div>
</template>
