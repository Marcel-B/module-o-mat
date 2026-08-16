import { defineStore } from 'pinia'
import { computed, ref } from 'vue'
import * as api from '../api/inventory'
import type { InventoryStats, Module, ModuleFilters, ModulePayload, ModuleType } from '../types'
import { groupModules } from '../utils/format'

const emptyFilters = (): ModuleFilters => ({
  q: '',
  type: '',
  minHp: '',
  maxHp: '',
})

export const useInventoryStore = defineStore('inventory', () => {
  const modules = ref<Module[]>([])
  const stats = ref<InventoryStats | null>(null)
  const moduleTypes = ref<ModuleType[]>([])
  const manufacturers = ref<string[]>([])
  const loading = ref(false)
  const filters = ref<ModuleFilters>(emptyFilters())
  let filterTimer: ReturnType<typeof setTimeout> | null = null

  const filtersActive = computed(() => {
    const { q, type, minHp, maxHp } = filters.value
    return Boolean(q.trim() || type || String(minHp).trim() || String(maxHp).trim())
  })

  const groupedModules = computed(() => groupModules(modules.value))
  const usedTypes = computed(() =>
    [...new Set(moduleTypes.value.filter((type) => type.used).map((type) => type.name))].sort(
      (a, b) => a.localeCompare(b, 'de'),
    ),
  )
  const typeNames = computed(() =>
    [...new Set(moduleTypes.value.map((type) => type.name))].sort((a, b) =>
      a.localeCompare(b, 'de'),
    ),
  )

  async function fetchModules(): Promise<void> {
    loading.value = true
    try {
      const data = await api.listModules(filters.value)
      modules.value = data.modules || []
      stats.value = data.stats || null
    } finally {
      loading.value = false
    }
  }

  async function fetchLookups(): Promise<void> {
    const [typesPayload, manufacturersPayload] = await Promise.all([
      api.listModuleTypes(),
      api.listManufacturers(),
    ])
    moduleTypes.value = typesPayload.module_types || []
    manufacturers.value = manufacturersPayload.manufacturers || []
  }

  async function bootstrap(): Promise<void> {
    await Promise.all([fetchModules(), fetchLookups()])
  }

  function setFilters(next: Partial<ModuleFilters>): void {
    filters.value = { ...filters.value, ...next }
    scheduleFetch()
  }

  function clearFilters(): void {
    filters.value = emptyFilters()
    scheduleFetch(0)
  }

  function scheduleFetch(delay = 300): void {
    if (filterTimer) clearTimeout(filterTimer)
    filterTimer = setTimeout(() => {
      void fetchModules()
    }, delay)
  }

  async function loadModule(id: number | string): Promise<Module> {
    const data = await api.getModule(id)
    return data.module
  }

  async function saveNew(payload: ModulePayload, pdfFile: File | null): Promise<Module> {
    const { module } = await api.createModule(payload)
    if (pdfFile) {
      const updated = await api.uploadManual(module.id, pdfFile)
      await refreshAfterWrite()
      return updated.module
    }
    await refreshAfterWrite()
    return module
  }

  async function saveEdit(
    id: number | string,
    payload: ModulePayload,
    { pdfFile, removeManual }: { pdfFile: File | null; removeManual: boolean },
  ): Promise<Module> {
    await api.updateModule(id, payload)
    if (removeManual) {
      await api.deleteManual(id)
    }
    if (pdfFile) {
      await api.uploadManual(id, pdfFile)
    }
    await refreshAfterWrite()
    return (await api.getModule(id)).module
  }

  async function saveDuplicate(
    sourceId: number | string,
    payload: ModulePayload,
    { pdfFile, copyManual }: { pdfFile: File | null; copyManual: boolean },
  ): Promise<Module> {
    const { module } = await api.duplicateModule(sourceId, {
      module: payload,
      copyManual: Boolean(copyManual) && !pdfFile,
    })
    if (pdfFile) {
      await api.uploadManual(module.id, pdfFile)
    }
    await refreshAfterWrite()
    return (await api.getModule(module.id)).module
  }

  async function removeModule(id: number | string): Promise<void> {
    await api.deleteModule(id)
    await refreshAfterWrite()
  }

  async function addType(name: string): Promise<void> {
    await api.createModuleType(name)
    await fetchLookups()
  }

  async function renameType(id: number | string, name: string): Promise<void> {
    await api.updateModuleType(id, name)
    await Promise.all([fetchLookups(), fetchModules()])
  }

  async function removeType(id: number | string): Promise<void> {
    await api.deleteModuleType(id)
    await Promise.all([fetchLookups(), fetchModules()])
  }

  async function restoreBackup(file: File): Promise<void> {
    await api.importBackup(file)
    await bootstrap()
  }

  async function downloadBackup(): Promise<void> {
    await api.exportBackup()
  }

  async function refreshAfterWrite(): Promise<void> {
    await Promise.all([fetchModules(), fetchLookups()])
  }

  return {
    modules,
    stats,
    moduleTypes,
    manufacturers,
    loading,
    filters,
    filtersActive,
    groupedModules,
    usedTypes,
    typeNames,
    bootstrap,
    fetchModules,
    fetchLookups,
    setFilters,
    clearFilters,
    loadModule,
    saveNew,
    saveEdit,
    saveDuplicate,
    removeModule,
    addType,
    renameType,
    removeType,
    restoreBackup,
    downloadBackup,
  }
})
