<script setup lang="ts">
import { onMounted, onUnmounted, ref } from 'vue'
import { MAINTENANCE_EVENT } from '../api/client'
import { getMaintenance } from '../api/inventory'

const IDLE_POLL_MS = 1500
const ACTIVE_POLL_MS = 800

const active = ref(false)
let timer: ReturnType<typeof setTimeout> | null = null
let cancelled = false

async function refresh(): Promise<void> {
  try {
    const status = await getMaintenance()
    if (!cancelled) active.value = Boolean(status.maintenance)
  } catch {
    if (!cancelled) active.value = false
  }
}

function schedule(): void {
  if (timer) clearTimeout(timer)
  timer = setTimeout(() => {
    void tick()
  }, active.value ? ACTIVE_POLL_MS : IDLE_POLL_MS)
}

async function tick(): Promise<void> {
  await refresh()
  if (!cancelled) schedule()
}

function onMaintenanceEvent(): void {
  active.value = true
  void tick()
}

onMounted(() => {
  void tick()
  window.addEventListener(MAINTENANCE_EVENT, onMaintenanceEvent)
})

onUnmounted(() => {
  cancelled = true
  if (timer) clearTimeout(timer)
  window.removeEventListener(MAINTENANCE_EVENT, onMaintenanceEvent)
})
</script>

<template>
  <Teleport to="body">
    <div
      v-if="active"
      id="maintenance-overlay"
      class="fixed inset-0 z-2000 flex items-center justify-center bg-overlay p-6 backdrop-blur-md"
      role="alertdialog"
      aria-modal="true"
      aria-labelledby="maintenance-overlay-title"
    >
      <div
        class="grid max-w-md justify-items-center gap-3.5 rounded-2xl border border-card-border bg-card px-8 py-9 text-center shadow-[0_24px_60px_rgb(15_18_24/28%)] dark:border-card-border-dark dark:bg-card-dark"
      >
        <ProgressSpinner stroke-width="4" style="width: 3rem; height: 3rem" />
        <h2 id="maintenance-overlay-title" class="m-0 text-xl font-semibold tracking-tight">
          Datensicherung läuft
        </h2>
        <p class="m-0 text-[0.95rem] leading-relaxed text-surface-600">
          Bitte warte einen Moment. Änderungen sind während der Sicherung gesperrt,
          damit der Bestand konsistent bleibt.
        </p>
      </div>
    </div>
  </Teleport>
</template>
