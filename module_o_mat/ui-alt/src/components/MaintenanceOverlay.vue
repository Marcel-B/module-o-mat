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
  <div
    v-if="active"
    id="maintenance-overlay"
    class="maintenance-overlay"
    role="alertdialog"
    aria-modal="true"
    aria-labelledby="maintenance-overlay-title"
  >
    <div class="maintenance-card">
      <span class="maintenance-spinner" aria-hidden="true" />
      <h2 id="maintenance-overlay-title">Datensicherung läuft</h2>
      <p>
        Bitte warte einen Moment. Änderungen sind während der Sicherung gesperrt,
        damit der Bestand konsistent bleibt.
      </p>
    </div>
  </div>
</template>
