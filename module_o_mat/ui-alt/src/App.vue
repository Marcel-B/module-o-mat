<script setup lang="ts">
import { RouterLink } from 'vue-router'

const logoSrc = `${import.meta.env.BASE_URL}logo.svg`
</script>

<template>
  <div class="app-shell">
    <header class="app-header">
      <RouterLink to="/" class="app-brand">
        <img :src="logoSrc" alt="" width="36" />
        <span>ModuleOMat · eigene UI</span>
      </RouterLink>
      <a href="/" class="ui-switcher">Oberflächen</a>
    </header>
    <main class="app-main">
      <router-view />
    </main>
    <Toast />
    <ConfirmDialog />
  </div>
</template>
