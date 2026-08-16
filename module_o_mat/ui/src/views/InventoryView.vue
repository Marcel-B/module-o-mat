<script setup lang="ts">
import { computed, defineAsyncComponent, onMounted, ref, watch } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { storeToRefs } from 'pinia'
import { useToast } from 'primevue/usetoast'
import { useConfirm } from 'primevue/useconfirm'
import { useInventoryStore } from '../stores/inventory'
import { ApiError } from '../api/client'
import { routeParam } from '../utils/format'
import type { Module, ModuleFormMode, ModuleFormSubmit, ModuleType } from '../types'
import ModuleFilters from '@/components/ModuleFilters.vue'
import ModuleTable from '@/components/ModuleTable.vue'
import ModuleDialog from '@/components/ModuleDialog.vue'
import TypeManagerDialog from '@/components/TypeManagerDialog.vue'
import BackupDialog from '@/components/BackupDialog.vue'

const PriceHistoryDialog = defineAsyncComponent(
  () => import('../components/PriceHistoryDialog.vue'),
)

const route = useRoute()
const router = useRouter()
const toast = useToast()
const confirm = useConfirm()
const store = useInventoryStore()
const { groupedModules, modules, stats, filtersActive, loading, manufacturers, typeNames, moduleTypes } =
  storeToRefs(store)

const currentModule = ref<Module | null>(null)
const saving = ref(false)
const formModes: ModuleFormMode[] = ['new', 'edit', 'duplicate', 'show']

function routeName(): string {
  return String(route.name ?? '')
}

const moduleMode = computed<ModuleFormMode | null>(() => {
  const name = routeName()
  if (formModes.includes(name as ModuleFormMode)) return name as ModuleFormMode
  return null
})

const moduleDialogVisible = computed(() => {
  if (!moduleMode.value) return false
  if (routeName() === 'new') return true
  return Boolean(currentModule.value && String(currentModule.value.id) === routeParam(route.params.id))
})
const typesVisible = computed(() => routeName() === 'types')
const backupVisible = computed(() => routeName() === 'backup')
const priceHistoryVisible = computed(
  () =>
    routeName() === 'price-history' &&
    Boolean(currentModule.value && String(currentModule.value.id) === routeParam(route.params.id)),
)

function closeDialogs() {
  router.push('/')
}

function notifyError(error: unknown, fallback = 'Die Aktion ist fehlgeschlagen.') {
  const message = error instanceof ApiError ? error.message : fallback
  toast.add({ severity: 'error', summary: 'Fehler', detail: message, life: 5000 })
}

async function loadRoutedModule() {
  if (!['show', 'edit', 'duplicate', 'price-history'].includes(routeName())) {
    currentModule.value = null
    return
  }

  try {
    currentModule.value = await store.loadModule(routeParam(route.params.id))
  } catch (error) {
    notifyError(error, 'Modul wurde nicht gefunden.')
    closeDialogs()
  }
}

onMounted(async () => {
  try {
    await store.bootstrap()
    await loadRoutedModule()
  } catch (error) {
    notifyError(error, 'Daten konnten nicht geladen werden. Läuft die Phoenix-API auf Port 4000?')
  }
})

watch(
  () => [route.name, route.params.id],
  () => {
    loadRoutedModule()
  },
)

async function onSaveModule({ payload, pdfFile, removeManual, copyManual }: ModuleFormSubmit) {
  saving.value = true
  try {
    const id = routeParam(route.params.id)
    if (routeName() === 'edit') {
      await store.saveEdit(id, payload, { pdfFile, removeManual })
      toast.add({ severity: 'success', summary: 'Gespeichert', detail: 'Modul wurde aktualisiert.', life: 3000 })
    } else if (routeName() === 'duplicate') {
      await store.saveDuplicate(id, payload, { pdfFile, copyManual })
      toast.add({ severity: 'success', summary: 'Gespeichert', detail: 'Modul wurde dupliziert.', life: 3000 })
    } else {
      await store.saveNew(payload, pdfFile)
      toast.add({ severity: 'success', summary: 'Gespeichert', detail: 'Modul wurde angelegt.', life: 3000 })
    }
    closeDialogs()
  } catch (error) {
    notifyError(error, 'Modul konnte nicht gespeichert werden.')
  } finally {
    saving.value = false
  }
}

function askDelete(module: Module) {
  confirm.require({
    header: 'Modul löschen',
    message: `Soll das Modul ${module.name} wirklich gelöscht werden? Diese Aktion kann nicht rückgängig gemacht werden.`,
    icon: 'pi pi-exclamation-triangle',
    rejectLabel: 'Abbrechen',
    acceptLabel: 'Löschen',
    acceptClass: 'p-button-danger',
    rejectProps: { id: 'cancel-delete-eurorack-module-button' },
    acceptProps: { id: 'confirm-delete-eurorack-module-button' },
    accept: async () => {
      try {
        await store.removeModule(module.id)
        toast.add({
          severity: 'success',
          summary: 'Gelöscht',
          detail: `Modul "${module.name}" wurde gelöscht.`,
          life: 3000,
        })
      } catch (error) {
        notifyError(error, 'Modul konnte nicht gelöscht werden.')
      }
    },
  })
}

async function onCreateType(name: string) {
  try {
    await store.addType(name)
    toast.add({ severity: 'success', summary: 'Typ hinzugefügt', detail: `Typ "${name}" wurde hinzugefügt.`, life: 3000 })
  } catch (error) {
    notifyError(error, 'Typ konnte nicht angelegt werden.')
  }
}

async function onRenameType({ id, name }: { id: number; name: string }) {
  try {
    await store.renameType(id, name)
    toast.add({ severity: 'success', summary: 'Aktualisiert', detail: `Typ "${name}" wurde aktualisiert.`, life: 3000 })
  } catch (error) {
    notifyError(error, 'Typ konnte nicht umbenannt werden.')
  }
}

async function onDeleteType(type: ModuleType) {
  try {
    await store.removeType(type.id)
    toast.add({ severity: 'success', summary: 'Gelöscht', detail: `Typ "${type.name}" wurde gelöscht.`, life: 3000 })
  } catch (error) {
    notifyError(error, 'Typ konnte nicht gelöscht werden.')
  }
}

async function onExportBackup() {
  try {
    await store.downloadBackup()
  } catch (error) {
    notifyError(error, 'Backup konnte nicht heruntergeladen werden.')
  }
}

async function onImportBackup(file: File | null) {
  if (!file) {
    toast.add({ severity: 'warn', summary: 'Datei fehlt', detail: 'Bitte zuerst eine ZIP-Datei auswählen.', life: 4000 })
    return
  }

  try {
    await store.restoreBackup(file)
    toast.add({
      severity: 'success',
      summary: 'Importiert',
      detail: 'Backup wurde importiert. Alle bisherigen Daten wurden ersetzt.',
      life: 4000,
    })
    closeDialogs()
  } catch (error) {
    notifyError(error, 'Import fehlgeschlagen.')
  }
}
</script>

<template>
  <div class="page-head">
    <h1>Eurorack-Module</h1>
    <div class="head-actions">
      <Button id="backup-button" label="Datensicherung" severity="secondary" @click="router.push('/backup')" />
      <Button
        id="manage-module-types-button"
        label="Typen verwalten"
        severity="secondary"
        @click="router.push('/types')"
      />
      <Button id="new-eurorack-module-button" label="Neues Modul" @click="router.push('/modules/new')" />
    </div>
  </div>

  <ModuleFilters />

  <ModuleTable
    :modules="modules"
    :groups="groupedModules"
    :stats="stats"
    :filters-active="filtersActive"
    :loading="loading"
    @delete="askDelete"
  />

  <ModuleDialog
    :visible="moduleDialogVisible"
    :mode="moduleMode || 'new'"
    :module="routeName() === 'new' ? null : currentModule"
    :manufacturers="manufacturers"
    :types="typeNames"
    :saving="saving"
    @close="closeDialogs"
    @submit="onSaveModule"
  />

  <TypeManagerDialog
    :visible="typesVisible"
    :types="moduleTypes"
    @close="closeDialogs"
    @create="onCreateType"
    @rename="onRenameType"
    @delete="onDeleteType"
  />

  <BackupDialog
    :visible="backupVisible"
    @close="closeDialogs"
    @export="onExportBackup"
    @import="onImportBackup"
  />

  <PriceHistoryDialog
    :visible="priceHistoryVisible"
    :module="currentModule"
    @close="closeDialogs"
  />
</template>

<style scoped>
.head-actions {
  display: flex;
  flex-wrap: wrap;
  gap: 0.5rem;
}
</style>
