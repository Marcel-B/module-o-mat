<script setup lang="ts">
import { onMounted, ref } from 'vue'
import { RouterLink } from 'vue-router'

type ThemePreference = 'light' | 'dark' | 'system'

const THEME_KEY = 'module-o-mat:theme'
const stored = localStorage.getItem(THEME_KEY)
const theme = ref<ThemePreference>(
  stored === 'light' || stored === 'dark' || stored === 'system' ? stored : 'system',
)
const logoSrc = `${import.meta.env.BASE_URL}logo.svg`

function systemTheme(): 'light' | 'dark' {
  return window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light'
}

function applyTheme(next: ThemePreference) {
  theme.value = next
  const resolved = next === 'system' ? systemTheme() : next
  document.documentElement.classList.toggle('p-dark', resolved === 'dark')
  document.documentElement.setAttribute('data-theme', resolved)
  document.documentElement.setAttribute('data-theme-source', next === 'system' ? 'system' : 'user')

  if (next === 'system') {
    localStorage.removeItem(THEME_KEY)
  } else {
    localStorage.setItem(THEME_KEY, next)
  }
}

onMounted(() => {
  applyTheme(theme.value)
  window.matchMedia('(prefers-color-scheme: dark)').addEventListener('change', () => {
    if ((localStorage.getItem(THEME_KEY) || 'system') === 'system') applyTheme('system')
  })
})
</script>

<template>
  <header class="app-header">
    <RouterLink to="/" class="app-brand">
      <img :src="logoSrc" alt="" width="36" />
      <span>ModuleOMat</span>
    </RouterLink>

    <div class="header-actions">
      <a href="/" class="ui-switcher">Oberflächen</a>
      <div class="theme-toggle">
        <Button
          icon="pi pi-sun"
          rounded
          text
          :severity="theme === 'light' ? 'primary' : 'secondary'"
          aria-label="Helles Erscheinungsbild"
          @click="applyTheme('light')"
        />
        <Button
          icon="pi pi-desktop"
          rounded
          text
          :severity="theme === 'system' ? 'primary' : 'secondary'"
          aria-label="System-Erscheinungsbild"
          @click="applyTheme('system')"
        />
        <Button
          icon="pi pi-moon"
          rounded
          text
          :severity="theme === 'dark' ? 'primary' : 'secondary'"
          aria-label="Dunkles Erscheinungsbild"
          @click="applyTheme('dark')"
        />
      </div>
    </div>
  </header>
</template>
