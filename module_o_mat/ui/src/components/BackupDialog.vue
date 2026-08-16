<script setup lang="ts">
import { ref } from 'vue'
import type { FileUploadSelectEvent } from 'primevue/fileupload'

defineProps<{
  visible?: boolean
}>()

const emit = defineEmits<{
  close: []
  export: []
  import: [file: File | null]
}>()
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
    <div class="backup-stack">
      <section id="backup-export-section">
        <h4>Export</h4>
        <p>
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
        <h4>Import</h4>
        <p>
          Stellt ein zuvor erstelltes Backup wieder her.
          <strong>Alle vorhandenen Daten werden dabei ersetzt.</strong>
        </p>
        <form id="backup-import-form" class="upload-drop" @submit.prevent="submitImport">
          <p>ZIP hierher ziehen oder Datei auswählen (max. 100 MB)</p>
          <FileUpload
            mode="basic"
            accept=".zip,application/zip"
            :auto="false"
            choose-label="ZIP auswählen"
            custom-upload
            @select="onSelect"
          />
          <div v-if="zipFile" class="file-row">
            <span>{{ zipFile.name }}</span>
            <Button type="button" label="Abbrechen" text size="small" @click="zipFile = null" />
          </div>
          <div class="dialog-actions">
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

<style scoped>
.backup-stack {
  display: grid;
  gap: 1.5rem;
}

h4 {
  margin: 0 0 0.4rem;
}

p {
  margin: 0 0 0.75rem;
  color: var(--p-surface-600);
  font-size: 0.92rem;
}

.file-row,
.dialog-actions {
  display: flex;
  align-items: center;
  justify-content: flex-end;
  gap: 0.5rem;
  margin-top: 0.75rem;
}

.file-row {
  justify-content: flex-start;
}
</style>
