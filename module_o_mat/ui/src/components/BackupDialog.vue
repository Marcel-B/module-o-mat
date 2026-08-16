<script setup lang="ts">
import { ref } from 'vue'
import type { FileUploadSelectEvent } from 'primevue/fileupload'

interface Props {
  visible?: boolean
}

interface Emits {
  close: []
  export: []
  import: [file: File | null]
}

defineProps<Props>()
const emit = defineEmits<Emits>()
const zipFile = ref<File | null>(null)

function onSelect(event: FileUploadSelectEvent) {
  zipFile.value = event.files?.[0] || null
}

function submitImport() {
  emit('import', zipFile.value)
}
</script>

<template>
  <Dialog
    id="backup-modal"
    :visible="visible"
    modal
    header="Datensicherung"
    :style="{ width: 'min(34rem, 96vw)' }"
    :draggable="false"
    @update:visible="emit('close')"
  >
    <div class="grid gap-6">
      <section id="backup-export-section">
        <h4 class="mb-1.5 font-semibold">Export</h4>
        <p class="mb-3 text-[0.92rem] text-surface-600">
          Exportiert alle Module, Typen, YouTube-Videos und PDF-Anleitungen als ZIP-Datei.
          Soft-gelöschte Einträge sind nicht enthalten.
        </p>
        <Button
          id="export-backup-button"
          icon="pi pi-download"
          label="Backup herunterladen"
          @click="emit('export')"
        />
      </section>

      <section id="backup-import-section">
        <h4 class="mb-1.5 font-semibold">Import</h4>
        <p class="mb-3 text-[0.92rem] text-surface-600">
          Stellt ein zuvor erstelltes Backup wieder her.
          <strong>Alle vorhandenen Daten werden dabei ersetzt.</strong>
        </p>
        <form
          id="backup-import-form"
          class="rounded-[0.85rem] border border-dashed border-content-border bg-drop p-4 text-center"
          @submit.prevent="submitImport"
        >
          <p class="mb-3 text-[0.92rem] text-surface-600">ZIP hierher ziehen oder Datei auswählen (max. 100 MB)</p>
          <FileUpload
            mode="basic"
            accept=".zip,application/zip"
            :auto="false"
            choose-label="ZIP auswählen"
            custom-upload
            @select="onSelect"
          />
          <div v-if="zipFile" class="mt-3 flex items-center justify-start gap-2">
            <span>{{ zipFile.name }}</span>
            <Button type="button" label="Abbrechen" text size="small" @click="zipFile = null" />
          </div>
          <div class="mt-3 flex items-center justify-end gap-2">
            <Button
              id="close-backup-button"
              type="button"
              label="Schließen"
              severity="secondary"
              @click="emit('close')"
            />
            <Button id="import-backup-button" type="submit" label="Backup importieren" />
          </div>
        </form>
      </section>
    </div>
  </Dialog>
</template>
