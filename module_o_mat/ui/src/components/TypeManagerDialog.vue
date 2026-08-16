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
    <div class="mb-5">
      <h4 class="mb-1.5 text-[0.95rem] font-semibold">Vorhandene Typen</h4>
      <p class="mb-3 text-sm text-surface-500">Bereits verwendete Typen sind farblich hervorgehoben.</p>
      <p v-if="types.length === 0" class="mb-3 text-sm text-surface-500">Es sind noch keine Typen definiert.</p>
      <ul v-else id="module-types-list" class="m-0 flex list-none flex-wrap gap-2 p-0">
        <li v-for="type in types" :id="`module-type-${type.id}`" :key="type.id">
          <form
            v-if="editingId === type.id"
            :id="`module-type-edit-form-${type.id}`"
            class="flex items-center gap-1"
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
            <small v-if="editErrors.name" class="mt-1.5 block text-sm text-danger">{{ editErrors.name }}</small>
          </form>
          <span
            v-else
            class="inline-flex items-center gap-1 rounded-full border px-2.5 py-1 text-sm"
            :class="type.used ? 'border-transparent bg-chip-used' : 'border-content-border'"
          >
            {{ type.name }}
            <button
              v-if="!type.fallback"
              :id="`edit-module-type-${type.id}`"
              type="button"
              class="cursor-pointer border-0 bg-transparent p-0.5 text-inherit"
              :aria-label="`Typ ${type.name} bearbeiten`"
              @click="startEdit(type)"
            >
              <span class="pi pi-pencil" />
            </button>
            <button
              v-if="!type.fallback"
              :id="`delete-module-type-${type.id}`"
              type="button"
              class="cursor-pointer border-0 bg-transparent p-0.5 text-inherit"
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
      <label class="mb-1.5 block text-xs font-semibold text-surface-600" for="new-module-type">Neuer Typ</label>
      <InputText
        id="new-module-type"
        v-model="name"
        v-bind="nameAttrs"
        placeholder="z.B. Granular"
        fluid
      />
      <small v-if="errors.name" class="mt-1.5 block text-sm text-danger">{{ errors.name }}</small>
      <div class="mt-4 flex justify-end gap-2">
        <Button id="close-module-types-button" type="button" label="Schließen" severity="secondary" @click="emit('close')" />
        <Button id="add-module-type-button" type="submit" label="Hinzufügen" />
      </div>
    </form>
  </Dialog>
</template>
