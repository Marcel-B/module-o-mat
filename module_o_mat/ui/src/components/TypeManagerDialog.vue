<script setup lang="ts">
import { ref } from 'vue'
import { useForm } from 'vee-validate'
import { toTypedSchema } from '@vee-validate/yup'
import { moduleTypeSchema } from '../validation/schemas'
import type { ModuleType } from '../types'

withDefaults(
  defineProps<{
    visible?: boolean
    types?: ModuleType[]
  }>(),
  {
    types: () => [],
  },
)

const emit = defineEmits<{
  close: []
  create: [name: string]
  rename: [value: { id: number; name: string }]
  delete: [type: ModuleType]
}>()

const editingId = ref<number | null>(null)

const { defineField, errors, handleSubmit, resetForm } = useForm({
  validationSchema: toTypedSchema(moduleTypeSchema),
  initialValues: { name: '' },
})

const { defineField: defineEditField, errors: editErrors, handleSubmit: handleEditSubmit, resetForm: resetEditForm } =
  useForm({
    validationSchema: toTypedSchema(moduleTypeSchema),
    initialValues: { name: '' },
  })

const [name, nameAttrs] = defineField('name')
const [editName, editNameAttrs] = defineEditField('name')

const onCreate = handleSubmit((values) => {
  emit('create', values.name)
  resetForm({ values: { name: '' } })
})

function startEdit(type: ModuleType) {
  editingId.value = type.id
  resetEditForm({ values: { name: type.name } })
}

function cancelEdit() {
  editingId.value = null
}

const onRename = handleEditSubmit((values) => {
  if (editingId.value == null) return
  emit('rename', { id: editingId.value, name: values.name })
  editingId.value = null
})
</script>

<template>
  <Dialog
    id="module-types-modal"
    :visible="visible"
    modal
    header="Typen verwalten"
    :style="{ width: 'min(36rem, 96vw)' }"
    :draggable="false"
    @update:visible="emit('close')"
  >
    <div class="mb-block">
      <h4>Vorhandene Typen</h4>
      <p class="hint">Bereits verwendete Typen sind farblich hervorgehoben.</p>
      <p v-if="types.length === 0" class="hint">Es sind noch keine Typen definiert.</p>
      <ul v-else id="module-types-list" class="type-chips">
        <li v-for="type in types" :id="`module-type-${type.id}`" :key="type.id">
          <form
            v-if="editingId === type.id"
            :id="`module-type-edit-form-${type.id}`"
            class="edit-row"
            @submit.prevent="onRename"
          >
            <InputText
              :id="`module-type-edit-name-${type.id}`"
              v-model="editName"
              v-bind="editNameAttrs"
            />
            <Button type="submit" icon="pi pi-check" text rounded aria-label="Speichern" />
            <Button
              type="button"
              icon="pi pi-times"
              text
              rounded
              aria-label="Bearbeiten abbrechen"
              @click="cancelEdit"
            />
            <small v-if="editErrors.name" class="field-error">{{ editErrors.name }}</small>
          </form>
          <span v-else class="type-chip" :class="{ used: type.used }">
            {{ type.name }}
            <button
              v-if="!type.fallback"
              :id="`edit-module-type-${type.id}`"
              type="button"
              class="chip-btn"
              :aria-label="`Typ ${type.name} bearbeiten`"
              @click="startEdit(type)"
            >
              <span class="pi pi-pencil" />
            </button>
            <button
              v-if="!type.fallback"
              :id="`delete-module-type-${type.id}`"
              type="button"
              class="chip-btn"
              :aria-label="`Typ ${type.name} löschen`"
              @click="emit('delete', type)"
            >
              <span class="pi pi-times" />
            </button>
          </span>
        </li>
      </ul>
    </div>

    <form id="module-type-form" @submit.prevent="onCreate">
      <label class="field-label" for="new-module-type">Neuer Typ</label>
      <InputText
        id="new-module-type"
        v-model="name"
        v-bind="nameAttrs"
        placeholder="z.B. Granular"
        fluid
      />
      <small v-if="errors.name" class="field-error">{{ errors.name }}</small>
      <div class="dialog-actions">
        <Button id="close-module-types-button" type="button" label="Schließen" severity="secondary" @click="emit('close')" />
        <Button id="add-module-type-button" type="submit" label="Hinzufügen" />
      </div>
    </form>
  </Dialog>
</template>

<style scoped>
.mb-block {
  margin-bottom: 1.25rem;
}

h4 {
  margin: 0 0 0.4rem;
  font-size: 0.95rem;
}

.hint {
  margin: 0 0 0.75rem;
  color: var(--p-surface-500);
  font-size: 0.85rem;
}

.type-chips {
  display: flex;
  flex-wrap: wrap;
  gap: 0.5rem;
  padding: 0;
  margin: 0;
  list-style: none;
}

.type-chip {
  display: inline-flex;
  align-items: center;
  gap: 0.25rem;
  padding: 0.3rem 0.55rem;
  border-radius: 999px;
  border: 1px solid var(--p-content-border-color);
  font-size: 0.85rem;
}

.type-chip.used {
  background: color-mix(in srgb, var(--p-primary-color) 18%, transparent);
  border-color: transparent;
}

.chip-btn {
  border: 0;
  background: transparent;
  color: inherit;
  cursor: pointer;
  padding: 0.1rem;
}

.edit-row {
  display: flex;
  align-items: center;
  gap: 0.25rem;
}

.dialog-actions {
  display: flex;
  justify-content: flex-end;
  gap: 0.5rem;
  margin-top: 1rem;
}
</style>
