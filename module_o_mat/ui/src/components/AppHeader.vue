<script setup lang="ts">
import { onBeforeUnmount, onMounted, ref } from "vue";
import { RouterLink } from "vue-router";

type ThemePreference = "light" | "dark" | "system";

const THEME_KEY = "module-o-mat:theme";
const stored = localStorage.getItem(THEME_KEY);
const theme = ref<ThemePreference>(stored === "light" || stored === "dark" || stored === "system" ? stored : "system");
const logoSrc = `${import.meta.env.BASE_URL}logo.svg`;
const brandGlitching = ref(false);
const brandHardGlitch = ref(false);
const themeGlitching = ref(false);
const themeHardGlitch = ref(false);

const timers: number[] = [];

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
  for (const timer of timers) window.clearTimeout(timer);
  timers.length = 0;
}

function scheduleGlitch(options: {
  isBusy: () => boolean;
  apply: (glitching: boolean, hard: boolean) => void;
  minWait: number;
  waitSpan: number;
}) {
  if (prefersReducedMotion()) return;

  const waitTimer = window.setTimeout(() => {
    if (options.isBusy()) {
      scheduleGlitch({ ...options, minWait: 500, waitSpan: 900 });
      return;
    }

    const hard = Math.random() < 0.28;
    options.apply(true, hard);
    const burstTimer = window.setTimeout(() => {
      options.apply(false, false);
      scheduleGlitch(options);
    }, 90 + Math.random() * 220);
    timers.push(burstTimer);
  }, options.minWait + Math.random() * options.waitSpan);
  timers.push(waitTimer);
}

onMounted(() => {
  applyTheme(theme.value);
  scheduleGlitch({
    isBusy: () => themeGlitching.value,
    apply: (glitching, hard) => {
      brandGlitching.value = glitching;
      brandHardGlitch.value = hard;
    },
    minWait: 3500,
    waitSpan: 9000,
  });
  scheduleGlitch({
    isBusy: () => brandGlitching.value,
    apply: (glitching, hard) => {
      themeGlitching.value = glitching;
      themeHardGlitch.value = hard;
    },
    minWait: 5200,
    waitSpan: 11000,
  });
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
      :class="{ 'brand-glitch': brandGlitching, 'brand-glitch-hard': brandHardGlitch }"
    >
      <img :src="logoSrc" alt="" width="80" height="80" class="brand-logo size-20 shrink-0" />
      <span class="brand-name font-brand text-[2rem] leading-none tracking-[0.14em] text-primary">
        module-O-mat
      </span>
    </RouterLink>

    <div
      class="theme-mark flex items-center gap-3"
      :class="{ 'brand-glitch': themeGlitching, 'brand-glitch-hard': themeHardGlitch }"
    >
      <a
        href="/"
        class="theme-label text-sm font-semibold text-inherit no-underline opacity-70 transition-opacity duration-150 hover:opacity-100"
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
