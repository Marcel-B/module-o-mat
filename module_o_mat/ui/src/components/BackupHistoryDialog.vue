<script setup lang="ts">
import { computed, ref, watch } from 'vue'
import type { DataTablePageEvent } from 'primevue/datatable'
import DataTable from 'primevue/datatable'
import Column from 'primevue/column'
import Tag from 'primevue/tag'
import { listBackupHistory } from '../api/inventory'
import { formatBytes, formatDateTime } from '../utils/format'
import type { BackupRun } from '../types'

interface Props {
  visible?: boolean
}

interface Emits {
  close: []
}

const props = defineProps<Props>()
const emit = defineEmits<Emits>()

const PAGE_SIZE = 5
const runs = ref<BackupRun[]>([])
const total = ref(0)
const first = ref(0)
const loading = ref(false)

const emptyMessage = computed(() =>
  loading.value ? '' : 'Es sind noch keine Sicherungen dokumentiert.',
)

async function loadPage(page: number) {
  loading.value = true
  try {
    const data = await listBackupHistory(page)
    runs.value = data.backup_runs || []
    total.value = data.total || 0
    first.value = (Math.max(data.page, 1) - 1) * PAGE_SIZE
  } finally {
    loading.value = false
  }
}

function onPage(event: DataTablePageEvent) {
  void loadPage(event.page + 1)
}

watch(
  () => props.visible,
  (visible) => {
    if (visible) void loadPage(1)
  },
  { immediate: true },
)
</script>

<template>
  <Dialog
    id="backup-history-modal"
    :visible="visible"
    modal
    header="Sicherungshistorie"
    :style="{ width: 'min(46rem, 96vw)' }"
    :draggable="false"
    @update:visible="emit('close')"
  >
    <p class="mb-4 text-[0.92rem] text-surface-600">
      Dokumentierte Nextcloud-Sicherungen, neueste zuerst. Es werden jeweils fünf Einträge geladen.
    </p>

    <DataTable
      id="backup-history-table"
      :value="runs"
      lazy
      paginator
      paginator-template="FirstPageLink PrevPageLink PageLinks NextPageLink LastPageLink"
      :rows="PAGE_SIZE"
      :total-records="total"
      :first="first"
      :loading="loading"
      data-key="id"
      size="small"
      class="text-sm"
      :empty-message="emptyMessage"
      @page="onPage"
    >
      <Column header="Datum / Uhrzeit">
        <template #body="{ data }">
          {{ formatDateTime(data.occurred_at) }}
        </template>
      </Column>
      <Column field="filename" header="ZIP-Datei">
        <template #body="{ data }">
          {{ data.filename || '—' }}
        </template>
      </Column>
      <Column header="Größe">
        <template #body="{ data }">
          {{ data.size_bytes == null ? '—' : formatBytes(data.size_bytes) }}
        </template>
      </Column>
      <Column header="Status">
        <template #body="{ data }">
          <Tag
            :value="data.success ? 'Erfolgreich' : 'Fehlgeschlagen'"
            :severity="data.success ? 'success' : 'danger'"
          />
        </template>
      </Column>
    </DataTable>

    <template #footer>
      <Button
        id="close-backup-history-button"
        type="button"
        label="Schließen"
        severity="secondary"
        @click="emit('close')"
      />
    </template>
  </Dialog>
</template>
