<script setup lang="ts">
import { computed, onMounted, ref, watch } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { useToast } from 'primevue/usetoast'
import { useConfirm } from 'primevue/useconfirm'
import { ApiError } from '../api/client'
import { listModules } from '../api/inventory'
import { deleteRack, getRack, listRacks, updateRack } from '../api/racks'
import type { Module, Rack, RackPayload } from '../types'
import { routeParam } from '../utils/format'
import {
  RAILS,
  type RailKey,
  ampsToMilliamps,
  fits,
  formatMa,
  hasMissingDraw,
  milliampsToAmps,
  moduleDraw,
  overload,
  psuCapacity,
  railStatus,
  remaining,
  suggestRemovals,
  sumDraw,
} from '../utils/power'

const route = useRoute()
const router = useRouter()
const toast = useToast()
const confirm = useConfirm()

const rack = ref<Rack | null>(null)
const otherRacks = ref<Rack[]>([])
const modules = ref<Module[]>([])
const loading = ref(true)
const saving = ref(false)

const name = ref('')
const psuAmps = ref<Record<RailKey, number | null>>({ plus12: null, minus12: null, plus5: null })

const search = ref('')
const typeFilter = ref<string | null>(null)
const onlyFits = ref(false)
const onlyFree = ref(false)

const psuFields: Record<RailKey, 'psu_plus12v_ma' | 'psu_minus12v_ma' | 'psu_plus5v_ma'> = {
  plus12: 'psu_plus12v_ma',
  minus12: 'psu_minus12v_ma',
  plus5: 'psu_plus5v_ma',
}

const moduleById = computed(() => new Map(modules.value.map((module) => [module.id, module])))

const rackModules = computed<Module[]>(() =>
  (rack.value?.module_ids ?? [])
    .map((id) => moduleById.value.get(id))
    .filter((module): module is Module => Boolean(module)),
)

const hasPsu = computed(() =>
  Boolean(rack.value && RAILS.some(({ key }) => rack.value![psuFields[key]] != null)),
)
const capacity = computed(() =>
  rack.value ? psuCapacity(rack.value) : { plus12: 0, minus12: 0, plus5: 0 },
)
const used = computed(() => sumDraw(rackModules.value))
const left = computed(() => remaining(capacity.value, used.value))
const over = computed(() => overload(capacity.value, used.value))
const overloadedRails = computed(() => RAILS.filter(({ key }) => over.value[key] > 0))
const removals = computed(
  () => new Set(hasPsu.value ? suggestRemovals(rackModules.value, capacity.value) : []),
)
const missingDraw = computed(() => rackModules.value.filter(hasMissingDraw))
const totalHp = computed(() => rackModules.value.reduce((total, module) => total + module.hp, 0))

const usedElsewhere = computed(() => {
  const map = new Map<number, string[]>()
  for (const other of otherRacks.value) {
    for (const id of other.module_ids) {
      map.set(id, [...(map.get(id) ?? []), other.name])
    }
  }
  return map
})

const typeOptions = computed(() =>
  [...new Set(modules.value.flatMap((module) => [module.type, ...(module.subtypes ?? [])]))].sort(
    (a, b) => a.localeCompare(b, 'de'),
  ),
)

const candidates = computed(() => {
  const inRack = new Set(rack.value?.module_ids ?? [])
  const query = search.value.trim().toLowerCase()
  return modules.value.filter((module) => {
    if (inRack.has(module.id)) return false
    if (query && !`${module.manufacturer} ${module.name}`.toLowerCase().includes(query)) return false
    if (typeFilter.value && module.type !== typeFilter.value && !(module.subtypes ?? []).includes(typeFilter.value)) {
      return false
    }
    if (onlyFree.value && usedElsewhere.value.has(module.id)) return false
    if (onlyFits.value && !fits(module, left.value)) return false
    return true
  })
})

function railLabel(key: RailKey): string {
  return RAILS.find((rail) => rail.key === key)?.label ?? key
}

function drawText(value: number | null): string {
  return value == null ? '—' : String(value)
}

function percent(key: RailKey): number {
  const cap = capacity.value[key]
  if (cap <= 0) return used.value[key] > 0 ? 100 : 0
  return Math.round((used.value[key] / cap) * 100)
}

function barColor(key: RailKey): string {
  const status = railStatus(capacity.value[key], used.value[key])
  if (status === 'over') return 'var(--p-red-500)'
  if (status === 'warn') return 'var(--p-amber-500)'
  return 'var(--p-primary-color)'
}

function notifyError(error: unknown, fallback: string) {
  const message = error instanceof ApiError ? error.message : fallback
  toast.add({ severity: 'error', summary: 'Fehler', detail: message, life: 5000 })
}

function syncForm(next: Rack) {
  name.value = next.name
  psuAmps.value = {
    plus12: milliampsToAmps(next.psu_plus12v_ma),
    minus12: milliampsToAmps(next.psu_minus12v_ma),
    plus5: milliampsToAmps(next.psu_plus5v_ma),
  }
}

async function load() {
  loading.value = true
  try {
    const id = routeParam(route.params.id)
    const [rackPayload, rackList, modulePayload] = await Promise.all([
      getRack(id),
      listRacks(),
      listModules(),
    ])
    rack.value = rackPayload.rack
    otherRacks.value = rackList.racks.filter((entry) => entry.id !== rackPayload.rack.id)
    modules.value = modulePayload.modules
    syncForm(rackPayload.rack)
  } catch (error) {
    notifyError(error, 'Rack wurde nicht gefunden.')
    router.push('/racks')
  } finally {
    loading.value = false
  }
}

onMounted(load)
watch(() => route.params.id, load)

async function persist(patch: Partial<RackPayload>) {
  if (!rack.value) return
  const previous = rack.value
  const payload: RackPayload = {
    name: previous.name,
    psu_plus12v_ma: previous.psu_plus12v_ma,
    psu_minus12v_ma: previous.psu_minus12v_ma,
    psu_plus5v_ma: previous.psu_plus5v_ma,
    module_ids: previous.module_ids,
    ...patch,
  }
  // Optimistisch anzeigen, damit die Rechnung sofort reagiert.
  rack.value = { ...previous, ...payload }
  saving.value = true
  try {
    const { rack: saved } = await updateRack(previous.id, payload)
    rack.value = saved
  } catch (error) {
    rack.value = previous
    syncForm(previous)
    notifyError(error, 'Rack konnte nicht gespeichert werden.')
  } finally {
    saving.value = false
  }
}

function saveName() {
  const next = name.value.trim()
  if (!rack.value || next === rack.value.name) return
  if (!next) {
    name.value = rack.value.name
    return
  }
  persist({ name: next })
}

function savePsu() {
  if (!rack.value) return
  const patch: Partial<RackPayload> = {}
  for (const { key } of RAILS) {
    const ma = ampsToMilliamps(psuAmps.value[key])
    if (ma !== rack.value[psuFields[key]]) patch[psuFields[key]] = ma
  }
  if (Object.keys(patch).length > 0) persist(patch)
}

function addModule(module: Module) {
  if (!rack.value) return
  persist({ module_ids: [...rack.value.module_ids, module.id] })
}

function removeModule(module: Module) {
  if (!rack.value) return
  persist({ module_ids: rack.value.module_ids.filter((id) => id !== module.id) })
}

function removeSuggested() {
  if (!rack.value || removals.value.size === 0) return
  persist({ module_ids: rack.value.module_ids.filter((id) => !removals.value.has(id)) })
}

function rowClass(module: Module) {
  return removals.value.has(module.id) ? 'rack-row-remove' : undefined
}

function askDelete() {
  const current = rack.value
  if (!current) return
  confirm.require({
    header: 'Rack löschen',
    message: `Soll das Rack „${current.name}“ wirklich gelöscht werden? Die Module bleiben im Inventar erhalten.`,
    icon: 'pi pi-exclamation-triangle',
    rejectLabel: 'Abbrechen',
    acceptLabel: 'Löschen',
    acceptClass: 'p-button-danger',
    accept: async () => {
      try {
        await deleteRack(current.id)
        toast.add({ severity: 'success', summary: 'Gelöscht', detail: `Rack „${current.name}“ wurde gelöscht.`, life: 3000 })
        router.push('/racks')
      } catch (error) {
        notifyError(error, 'Rack konnte nicht gelöscht werden.')
      }
    },
  })
}
</script>

<template>
  <ProgressBar v-if="loading" mode="indeterminate" style="height: 3px" />

  <div v-else-if="rack" id="rack-planner" class="flex flex-col gap-6">
    <!-- Kopf: Name -->
    <section class="module-table-shell rounded-2xl border border-content-border bg-content p-6 max-[780px]:p-4">
      <div class="flex flex-wrap items-center justify-between gap-3">
        <div class="flex min-w-0 flex-1 items-center gap-2 max-[780px]:basis-full">
          <RouterLink to="/racks">
            <Button icon="pi pi-arrow-left" severity="secondary" text rounded aria-label="Alle Racks" />
          </RouterLink>
          <InputText
            id="rack-name"
            v-model="name"
            class="min-w-0 flex-1 text-xl font-semibold"
            aria-label="Name des Racks"
            @blur="saveName"
            @keydown.enter="($event.target as HTMLInputElement).blur()"
          />
        </div>
        <div class="flex items-center gap-2">
          <i v-if="saving" class="pi pi-spin pi-spinner text-surface-500" aria-label="Speichert" />
          <span class="text-sm text-surface-600">
            {{ rackModules.length }} {{ rackModules.length === 1 ? 'Modul' : 'Module' }} · {{ totalHp }} HP
          </span>
          <Button icon="pi pi-trash" severity="danger" text rounded aria-label="Rack löschen" @click="askDelete" />
        </div>
      </div>
    </section>

    <div class="grid gap-6 lg:grid-cols-[minmax(0,22rem)_minmax(0,1fr)]">
      <!-- Netzteil -->
      <section
        id="rack-psu"
        class="rounded-2xl border border-content-border bg-content p-5"
      >
        <h2 class="mb-1 text-base font-semibold text-primary">Netzteil</h2>
        <p class="mb-4 text-sm text-surface-600">
          Maximaler Strom je Schiene in Ampere. Leere Felder werden nicht geprüft, fehlt eine Schiene, trag 0 ein.
        </p>
        <Message v-if="!hasPsu" severity="info" size="small" class="mb-4">
          Nächster Schritt: Trag die Werte deines Netzteils ein.
        </Message>
        <div class="flex flex-col gap-3">
          <div v-for="{ key, label } in RAILS" :key="key" class="flex items-center gap-3">
            <label :for="`psu-${key}`" class="w-14 shrink-0 text-sm font-semibold">{{ label }}</label>
            <InputNumber
              v-model="psuAmps[key]"
              :input-id="`psu-${key}`"
              mode="decimal"
              locale="de-DE"
              :min="0"
              :max="100"
              :min-fraction-digits="0"
              :max-fraction-digits="3"
              suffix=" A"
              placeholder="z. B. 1,2 A"
              fluid
              @blur="savePsu"
              @keydown.enter="savePsu"
            />
          </div>
        </div>

        <h2 class="mb-3 mt-6 text-base font-semibold text-primary">Verbrauch</h2>
        <div id="rack-usage" class="flex flex-col gap-4">
          <div v-for="{ key, label } in RAILS" :key="key" :id="`usage-${key}`">
            <div class="mb-1 flex items-baseline justify-between text-sm">
              <span class="font-semibold">{{ label }}</span>
              <span>
                {{ formatMa(used[key]) }} /
                {{ rack[psuFields[key]] == null ? '—' : formatMa(capacity[key]) }}
                <span v-if="Number.isFinite(capacity[key]) && capacity[key] > 0" class="text-surface-600">({{ percent(key) }} %)</span>
              </span>
            </div>
            <div v-if="rack[psuFields[key]] != null" class="h-2 overflow-hidden rounded-full bg-content-border">
              <div
                class="h-full rounded-full transition-all duration-300"
                :style="{ width: `${Math.min(100, percent(key))}%`, background: barColor(key) }"
              />
            </div>
            <div class="mt-1 text-xs" :class="left[key] < 0 ? 'font-semibold text-danger' : 'text-surface-600'">
              <template v-if="left[key] < 0">{{ formatMa(-left[key]) }} zu viel</template>
              <template v-else-if="rack[psuFields[key]] != null">{{ formatMa(left[key]) }} frei</template>
              <template v-else>kein Netzteil-Wert, wird nicht geprüft</template>
            </div>
          </div>
        </div>

        <Message v-if="hasPsu && overloadedRails.length > 0" id="rack-overload" severity="error" size="small" class="mt-4">
          <div>
            Überlastet auf {{ overloadedRails.map((rail) => rail.label).join(', ') }}.
            <template v-if="removals.size > 0">
              {{ removals.size === 1 ? 'Entferne das markierte Modul' : `Entferne die ${removals.size} markierten Module` }}, um wieder im Limit zu liegen.
            </template>
          </div>
          <Button
            v-if="removals.size > 0"
            id="remove-suggested-button"
            label="Markierte entfernen"
            size="small"
            severity="danger"
            class="mt-2"
            @click="removeSuggested"
          />
        </Message>
        <Message v-if="missingDraw.length > 0" id="rack-missing-draw" severity="warn" size="small" class="mt-4">
          {{ missingDraw.length }} {{ missingDraw.length === 1 ? 'Modul hat' : 'Module haben' }} keine
          Verbrauchsangabe. Der tatsächliche Verbrauch liegt vermutlich höher.
        </Message>
      </section>

      <div class="flex min-w-0 flex-col gap-6">
        <!-- Module im Rack -->
        <section id="rack-modules" class="rounded-2xl border border-content-border bg-content p-5">
          <h2 class="mb-3 text-base font-semibold text-primary">Im Rack</h2>
          <DataTable
            :value="rackModules"
            data-key="id"
            size="small"
            class="text-sm"
            :row-class="rowClass"
          >
            <template #empty>
              <p class="py-6 text-center text-surface-600">Noch keine Module eingeplant. Füg unten welche hinzu.</p>
            </template>
            <Column header="Modul">
              <template #body="{ data }">
                <div class="flex flex-wrap items-center gap-1.5">
                  <span>{{ data.manufacturer }} – {{ data.name }}</span>
                  <Tag v-if="removals.has(data.id)" severity="danger" value="Entfernen" />
                  <Tag v-if="hasMissingDraw(data)" severity="warn" value="ohne Angabe" />
                </div>
              </template>
            </Column>
            <Column field="type" header="Typ" />
            <Column field="hp" header="HP" />
            <Column header="+12 V">
              <template #body="{ data }">{{ drawText(data.current_draw_plus12v_ma) }}</template>
            </Column>
            <Column header="−12 V">
              <template #body="{ data }">{{ drawText(data.current_draw_minus12v_ma) }}</template>
            </Column>
            <Column header="+5 V">
              <template #body="{ data }">{{ drawText(data.current_draw_plus5v_ma) }}</template>
            </Column>
            <Column header="" class="w-12">
              <template #body="{ data }">
                <Button
                  icon="pi pi-minus"
                  severity="secondary"
                  text
                  rounded
                  :aria-label="`${data.name} entfernen`"
                  @click="removeModule(data)"
                />
              </template>
            </Column>
          </DataTable>
        </section>

        <!-- Modulauswahl -->
        <section id="rack-candidates" class="rounded-2xl border border-content-border bg-content p-5">
          <h2 class="mb-3 text-base font-semibold text-primary">Module hinzufügen</h2>
          <div class="mb-3 flex flex-wrap items-center gap-3">
            <IconField>
              <InputIcon class="pi pi-search text-sm" />
              <InputText
                id="rack-candidate-search"
                v-model="search"
                size="small"
                placeholder="Hersteller oder Name"
                class="w-64"
              />
            </IconField>
            <Select
              id="rack-candidate-type"
              v-model="typeFilter"
              :options="typeOptions"
              placeholder="Alle Typen"
              show-clear
              size="small"
              class="w-52"
            />
            <label class="flex items-center gap-2 text-sm">
              <ToggleSwitch v-model="onlyFits" input-id="rack-only-fits" :disabled="!hasPsu" />
              <span>Nur was noch passt</span>
            </label>
            <label class="flex items-center gap-2 text-sm">
              <ToggleSwitch v-model="onlyFree" input-id="rack-only-free" />
              <span>Nur Module, die in keinem anderen Rack sind</span>
            </label>
          </div>
          <DataTable
            :value="candidates"
            data-key="id"
            size="small"
            class="text-sm"
            paginator
            :rows="15"
            sort-field="manufacturer"
            :sort-order="1"
          >
            <template #empty>
              <p class="py-6 text-center text-surface-600">Keine passenden Module gefunden.</p>
            </template>
            <Column field="manufacturer" header="Modul" sortable>
              <template #body="{ data }">
                <div class="flex flex-wrap items-center gap-1.5">
                  <span>{{ data.manufacturer }} – {{ data.name }}</span>
                  <Tag v-if="hasMissingDraw(data)" severity="warn" value="ohne Angabe" />
                  <Tag
                    v-if="usedElsewhere.has(data.id)"
                    severity="secondary"
                    :value="`in ${usedElsewhere.get(data.id)!.join(', ')}`"
                  />
                  <Tag
                    v-if="hasPsu && !fits(data, left)"
                    severity="danger"
                    value="passt nicht"
                    v-tooltip.top="`Würde überschreiten: ${RAILS.filter(({ key }) => moduleDraw(data)[key] > left[key]).map(({ key }) => railLabel(key)).join(', ')}`"
                  />
                </div>
              </template>
            </Column>
            <Column field="type" header="Typ" sortable />
            <Column field="hp" header="HP" sortable />
            <Column field="current_draw_plus12v_ma" header="+12 V" sortable>
              <template #body="{ data }">{{ drawText(data.current_draw_plus12v_ma) }}</template>
            </Column>
            <Column field="current_draw_minus12v_ma" header="−12 V" sortable>
              <template #body="{ data }">{{ drawText(data.current_draw_minus12v_ma) }}</template>
            </Column>
            <Column field="current_draw_plus5v_ma" header="+5 V" sortable>
              <template #body="{ data }">{{ drawText(data.current_draw_plus5v_ma) }}</template>
            </Column>
            <Column header="" class="w-12">
              <template #body="{ data }">
                <Button
                  icon="pi pi-plus"
                  text
                  rounded
                  :aria-label="`${data.name} hinzufügen`"
                  @click="addModule(data)"
                />
              </template>
            </Column>
          </DataTable>
        </section>
      </div>
    </div>
  </div>
</template>

<style scoped>
:deep(.rack-row-remove) > td {
  background: color-mix(in srgb, var(--p-red-500) 14%, transparent) !important;
}
</style>
