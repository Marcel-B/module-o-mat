<script setup lang="ts">
import { computed } from 'vue'
import type { Module, ModuleFormMode, ModuleFormSubmit } from '../types'
import ModuleForm from './ModuleForm.vue'

interface Props {
  visible?: boolean
  mode?: ModuleFormMode
  module?: Module | null
  manufacturers?: string[]
  types?: string[]
  saving?: boolean
}

const props = withDefaults(
  defineProps<Props>(),
  {
    mode: 'new',
    manufacturers: () => [],
    types: () => [],
  },
)

const emit = defineEmits<{
  close: []
  submit: [value: ModuleFormSubmit]
}>()

const title = computed(() => {
  if (props.mode === 'edit') return 'Modul bearbeiten'
  if (props.mode === 'duplicate') return 'Modul duplizieren'
  if (props.mode === 'show') return 'Modul anzeigen'
  return 'Neues Modul erfassen'
})
</script>

<template>
  <Dialog
    id="eurorack-module-modal"
    :visible="visible"
    modal
    :header="title"
    :style="{ width: 'min(42rem, 96vw)' }"
    :breakpoints="{ '640px': '96vw' }"
    :draggable="false"
    @update:visible="emit('close')"
  >
    <ModuleForm
      :mode="mode"
      :module="module"
      :manufacturers="manufacturers"
      :types="types"
      :saving="saving"
      @cancel="emit('close')"
      @submit="emit('submit', $event)"
    />
  </Dialog>
</template>
