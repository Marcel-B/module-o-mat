<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import { useRouter } from 'vue-router'
import { useToast } from 'primevue/usetoast'
import { useConfirm } from 'primevue/useconfirm'
import { ApiError } from '../api/client'
import { listModules } from '../api/inventory'
import { createRack, deleteRack, listRacks } from '../api/racks'
import type { Module, Rack } from '../types'
import { formatHpCm } from '../utils/format'
import { RAILS, isOverloaded, psuCapacity, sumDraw, milliampsToAmps } from '../utils/power'

const router = useRouter()
const toast = useToast()
const confirm = useConfirm()

const racks = ref<Rack[]>([])
const modules = ref<Module[]>([])
const loading = ref(true)
const dialogVisible = ref(false)
const newName = ref('')
const nameError = ref<string | null>(null)
const creating = ref(false)

const moduleById = computed(() => new Map(modules.value.map((module) => [module.id, module])))

function rackModules(rack: Rack): Module[] {
  return rack.module_ids
    .map((id) => moduleById.value.get(id))
    .filter((module): module is Module => Boolean(module))
}

function hasPsu(rack: Rack): boolean {
  return rack.psu_plus12v_ma != null || rack.psu_minus12v_ma != null || rack.psu_plus5v_ma != null
}

function rackSummary(rack: Rack) {
  const list = rackModules(rack)
  const used = sumDraw(list)
  return {
    count: list.length,
    hp: list.reduce((total, module) => total + module.hp, 0),
    used,
    overloaded: hasPsu(rack) && isOverloaded(psuCapacity(rack), used),
  }
}

function psuText(rack: Rack): string {
  if (!hasPsu(rack)) return 'Kein Netzteil eingetragen'
  const values: Record<string, number | null> = {
    plus12: rack.psu_plus12v_ma,
    minus12: rack.psu_minus12v_ma,
    plus5: rack.psu_plus5v_ma,
  }
  return RAILS.map(({ key, label }) => {
    const amps = milliampsToAmps(values[key])
    return `${label}: ${amps == null ? '—' : `${amps.toLocaleString('de-DE')} A`}`
  }).join(' · ')
}

function notifyError(error: unknown, fallback: string) {
  const message = error instanceof ApiError ? error.message : fallback
  toast.add({ severity: 'error', summary: 'Fehler', detail: message, life: 5000 })
}

async function load() {
  loading.value = true
  try {
    const [rackPayload, modulePayload] = await Promise.all([listRacks(), listModules()])
    racks.value = rackPayload.racks
    modules.value = modulePayload.modules
  } catch (error) {
    notifyError(error, 'Racks konnten nicht geladen werden.')
  } finally {
    loading.value = false
  }
}

onMounted(load)

function openCreate() {
  newName.value = ''
  nameError.value = null
  dialogVisible.value = true
}

async function onCreate() {
  const name = newName.value.trim()
  if (!name) {
    nameError.value = 'Bitte einen Namen vergeben.'
    return
  }

  creating.value = true
  try {
    const { rack } = await createRack({ name })
    dialogVisible.value = false
    router.push(`/racks/${rack.id}`)
  } catch (error) {
    if (error instanceof ApiError && error.details && 'name' in error.details) {
      nameError.value = String(([] as string[]).concat(error.details.name ?? '')[0])
    } else {
      notifyError(error, 'Rack konnte nicht angelegt werden.')
    }
  } finally {
    creating.value = false
  }
}

function askDelete(rack: Rack) {
  confirm.require({
    header: 'Rack löschen',
    message: `Soll das Rack „${rack.name}“ wirklich gelöscht werden? Die Module bleiben im Inventar erhalten.`,
    icon: 'pi pi-exclamation-triangle',
    rejectLabel: 'Abbrechen',
    acceptLabel: 'Löschen',
    acceptClass: 'p-button-danger',
    accept: async () => {
      try {
        await deleteRack(rack.id)
        racks.value = racks.value.filter((entry) => entry.id !== rack.id)
        toast.add({ severity: 'success', summary: 'Gelöscht', detail: `Rack „${rack.name}“ wurde gelöscht.`, life: 3000 })
      } catch (error) {
        notifyError(error, 'Rack konnte nicht gelöscht werden.')
      }
    },
  })
}
</script>

<template>
  <section class="module-table-shell rounded-2xl border border-content-border bg-content p-6 max-[780px]:p-4">
    <div class="mb-6 flex flex-wrap items-center justify-between gap-3">
      <div>
        <h1 class="text-xl font-semibold text-primary">Rack-Planer</h1>
        <p class="mt-1 text-sm text-surface-600">
          Lege ein Rack an, trage das Netzteil ein und plane, welche Module hineinpassen.
        </p>
      </div>
      <div class="flex gap-2">
        <RouterLink to="/">
          <Button label="Inventar" icon="pi pi-arrow-left" severity="secondary" text />
        </RouterLink>
        <Button id="new-rack-button" label="Neues Rack" icon="pi pi-plus" @click="openCreate" />
      </div>
    </div>

    <ProgressBar v-if="loading" mode="indeterminate" style="height: 3px" />

    <p v-else-if="racks.length === 0" id="no-racks" class="py-10 text-center text-surface-600">
      Es gibt noch keine Racks. Leg mit „Neues Rack“ das erste an.
    </p>

    <ul v-else id="rack-list" class="m-0 grid list-none gap-4 p-0 sm:grid-cols-2 xl:grid-cols-3">
      <li
        v-for="rack in racks"
        :id="`rack-${rack.id}`"
        :key="rack.id"
        class="flex flex-col gap-3 rounded-xl border border-content-border p-4"
      >
        <div class="flex items-start justify-between gap-2">
          <RouterLink :to="`/racks/${rack.id}`" class="text-lg font-semibold text-inherit no-underline hover:text-primary">
            {{ rack.name }}
          </RouterLink>
          <Tag
            v-if="rackSummary(rack).overloaded"
            severity="danger"
            value="Überlastet"
          />
          <Tag v-else-if="hasPsu(rack)" severity="success" value="Im Limit" />
        </div>
        <div class="text-sm text-surface-600">
          {{ rackSummary(rack).count }} {{ rackSummary(rack).count === 1 ? 'Modul' : 'Module' }} ·
          {{ rackSummary(rack).hp }} HP ({{ formatHpCm(rackSummary(rack).hp) }})
        </div>
        <div class="text-xs text-surface-600">{{ psuText(rack) }}</div>
        <div class="mt-auto flex justify-end gap-1">
          <Button
            icon="pi pi-trash"
            severity="danger"
            text
            rounded
            :aria-label="`Rack ${rack.name} löschen`"
            @click="askDelete(rack)"
          />
          <RouterLink :to="`/racks/${rack.id}`">
            <Button label="Planen" icon="pi pi-sliders-h" severity="secondary" />
          </RouterLink>
        </div>
      </li>
    </ul>
  </section>

  <Dialog
    id="new-rack-dialog"
    v-model:visible="dialogVisible"
    modal
    header="Neues Rack"
    :style="{ width: 'min(28rem, 96vw)' }"
    :draggable="false"
  >
    <form id="new-rack-form" @submit.prevent="onCreate">
      <label class="mb-1.5 block text-xs font-semibold text-surface-600" for="new-rack-name">Name</label>
      <InputText
        id="new-rack-name"
        v-model="newName"
        placeholder="z. B. Reise-Case 84 HP"
        fluid
        autofocus
        :invalid="Boolean(nameError)"
      />
      <small v-if="nameError" class="mt-1.5 block text-sm text-danger">{{ nameError }}</small>
      <p class="mt-3 text-sm text-surface-600">Im nächsten Schritt trägst du das Netzteil ein.</p>
      <div class="mt-4 flex justify-end gap-2">
        <Button type="button" label="Abbrechen" severity="secondary" @click="dialogVisible = false" />
        <Button id="create-rack-button" type="submit" label="Anlegen" :loading="creating" />
      </div>
    </form>
  </Dialog>
</template>
