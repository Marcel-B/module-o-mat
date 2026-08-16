<script setup lang="ts">
import { onBeforeUnmount, onMounted, ref } from "vue";
import { RouterLink } from "vue-router";

type ThemePreference = "light" | "dark" | "system";

const THEME_KEY = "module-o-mat:theme";
const stored = localStorage.getItem(THEME_KEY);
const theme = ref<ThemePreference>(stored === "light" || stored === "dark" || stored === "system" ? stored : "system");
const logoSrc = `${import.meta.env.BASE_URL}logo.svg`;
const glitching = ref(false);
const hardGlitch = ref(false);

let waitTimer = 0;
let burstTimer = 0;

function systemTheme(): "light" | "dark" {
  return window.matchMedia("(prefers-color-scheme: dark)").matches ? "dark" : "light";
}

function prefersReducedMotion(): boolean {
  return window.matchMedia("(prefers-reduced-motion: reduce)").matches;
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

function clearGlitchTimers() {
  window.clearTimeout(waitTimer);
  window.clearTimeout(burstTimer);
}

function scheduleGlitch() {
  if (prefersReducedMotion()) return;

  waitTimer = window.setTimeout(() => {
    hardGlitch.value = Math.random() < 0.28;
    glitching.value = true;
    burstTimer = window.setTimeout(() => {
      glitching.value = false;
      hardGlitch.value = false;
      scheduleGlitch();
    }, 90 + Math.random() * 220);
  }, 3500 + Math.random() * 9000);
}

onMounted(() => {
  applyTheme(theme.value);
  scheduleGlitch();
  window.matchMedia("(prefers-color-scheme: dark)").addEventListener("change", () => {
    if ((localStorage.getItem(THEME_KEY) || "system") === "system") applyTheme("system");
  });
});

onBeforeUnmount(clearGlitchTimers);
</script>

<template>
  <header
    class="sticky top-0 z-20 flex min-h-24 items-center justify-between gap-4 border-b border-header-border bg-header px-6 py-3 backdrop-blur-lg"
  >
    <RouterLink
      to="/"
      class="brand-mark flex items-center gap-3 text-inherit no-underline"
      :class="{ 'brand-glitch': glitching, 'brand-glitch-hard': hardGlitch }"
    >
      <img :src="logoSrc" alt="" width="80" height="80" class="brand-logo size-20 shrink-0" />
      <span class="brand-name font-brand text-[2rem] leading-none tracking-[0.14em] text-primary">
        module-O-mat
      </span>
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

