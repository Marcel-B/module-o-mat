<script setup lang="ts">
import { RouterLink } from 'vue-router'
</script>

<template>
  <div class="app-shell">
    <header class="app-header">
      <RouterLink to="/" class="app-brand">
        <img src="/logo.svg" alt="" width="36" />
        <span>ModuleOMat · eigene UI</span>
      </RouterLink>
    </header>
    <main class="app-main">
      <router-view />
    </main>
    <Toast />
    <ConfirmDialog />
  </div>
</template>
