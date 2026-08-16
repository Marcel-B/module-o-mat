<script setup lang="ts">
import AppHeader from './components/AppHeader.vue'
import MaintenanceOverlay from './components/MaintenanceOverlay.vue'
</script>

<template>
  <div class="min-h-screen">
    <AppHeader />
    <main class="mx-auto max-w-[90rem] px-6 pb-16 pt-8 max-[780px]:px-4 max-[780px]:pb-12 max-[780px]:pt-5">
      <router-view />
    </main>
    <Toast position="top-right" />
    <ConfirmDialog />
    <MaintenanceOverlay />
  </div>
</template>
