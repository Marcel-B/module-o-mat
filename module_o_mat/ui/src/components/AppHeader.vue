<script setup lang="ts">
import { onMounted, ref } from "vue";
import { RouterLink } from "vue-router";

type ThemePreference = "light" | "dark" | "system";

const THEME_KEY = "module-o-mat:theme";
const stored = localStorage.getItem(THEME_KEY);
const theme = ref<ThemePreference>(stored === "light" || stored === "dark" || stored === "system" ? stored : "system");
const logoSrc = `${import.meta.env.BASE_URL}logo.svg`;

function systemTheme(): "light" | "dark" {
  return window.matchMedia("(prefers-color-scheme: dark)").matches ? "dark" : "light";
}

function applyTheme(next: ThemePreference) {
  theme.value = next;
  const resolved = next === "system" ? systemTheme() : next;
  document.documentElement.classList.toggle("p-dark", resolved === "dark");
  document.documentElement.setAttribute("data-theme", resolved);
  document.documentElement.setAttribute("data-theme-source", next === "system" ? "system" : "user");

  if (next === "system") {
    localStorage.removeItem(THEME_KEY);
  } else {
    localStorage.setItem(THEME_KEY, next);
  }
}

onMounted(() => {
  applyTheme(theme.value);
  window.matchMedia("(prefers-color-scheme: dark)").addEventListener("change", () => {
    if ((localStorage.getItem(THEME_KEY) || "system") === "system") applyTheme("system");
  });
});
</script>

<template>
  <header
    class="sticky top-0 z-20 flex min-h-24 items-center justify-between gap-4 border-b border-header-border bg-header px-6 py-3 backdrop-blur-lg"
  >
    <RouterLink to="/" class="flex items-center gap-3 text-inherit no-underline">
      <img :src="logoSrc" alt="" width="80" height="80" class="size-20 shrink-0" />
      <span 
        class="font-brand text-[2rem] leading-none tracking-[0.14em] text-primary dark:[text-shadow:0_0_16px_color-mix(in_srgb,var(--p-primary-color)_55%,transparent)]"
      >module-O-mat</span>
    </RouterLink>

    <div class="flex items-center gap-3">
      <a
        href="/"
        class="text-sm font-semibold text-inherit no-underline opacity-70 transition-opacity duration-150 hover:opacity-100"
      >
        Theme
      </a>
      <div class="flex gap-0.5">
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

