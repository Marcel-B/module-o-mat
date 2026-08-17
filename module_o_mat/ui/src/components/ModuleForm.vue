<script setup lang="ts">
import { computed, ref, watch } from 'vue'
import { useForm, type TypedSchema } from 'vee-validate'
import { toTypedSchema } from '@vee-validate/yup'
import type { AutoCompleteCompleteEvent } from 'primevue/autocomplete'
import type { FileUploadSelectEvent } from 'primevue/fileupload'
import {
  emptyModuleValues,
  formValuesToPayload,
  moduleSchema,
  moduleToFormValues,
} from '../validation/schemas'
import { formatBytes } from '../utils/format'
import type { Module, ModuleFormMode, ModuleFormSubmit, ModuleFormValues } from '../types'

interface Props {
  mode: ModuleFormMode
  module?: Module | null
  manufacturers?: string[]
  types?: string[]
  saving?: boolean
}

interface Emits {
  submit: [value: ModuleFormSubmit]
  cancel: []
}

const props = defineProps<Props>()
const emit = defineEmits<Emits>()

const readonly = computed(() => props.mode === 'show')
const submitLabel = computed(() => (props.mode === 'edit' ? 'Aktualisieren' : 'Speichern'))

const { defineField, errors, handleSubmit, resetForm, setFieldValue, values } = useForm<ModuleFormValues>({
  validationSchema: toTypedSchema(moduleSchema) as TypedSchema<ModuleFormValues>,
  initialValues: emptyModuleValues(),
})

const [manufacturer, manufacturerAttrs] = defineField('manufacturer')
const [name, nameAttrs] = defineField('name')
const [hp, hpAttrs] = defineField('hp')
const [type, typeAttrs] = defineField('type')
const [subtypes] = defineField('subtypes')
const [plus12, plus12Attrs] = defineField('current_draw_plus12v_ma')
const [minus12, minus12Attrs] = defineField('current_draw_minus12v_ma')
const [plus5, plus5Attrs] = defineField('current_draw_plus5v_ma')
const [depth, depthAttrs] = defineField('depth_mm')
const [description, descriptionAttrs] = defineField('description')
const [manualUrl, manualUrlAttrs] = defineField('manual_url')
const [purchasePrice, purchasePriceAttrs] = defineField('purchase_price')
const [currentValue, currentValueAttrs] = defineField('current_value')
const [youtubeVideos] = defineField('youtube_videos')

const manufacturerSuggestions = ref<string[]>([])
const pdfFile = ref<File | null>(null)
const removeExistingManual = ref(false)
const copySourceManual = ref(false)
const existingManual = computed(() => {
  if (removeExistingManual.value) return null
  if (!props.module?.has_manual) return null
  return {
    filename: props.module.manual_pdf_filename,
    size: props.module.manual_pdf_size_bytes,
    id: props.module.id,
  }
})

const typeOptions = computed(() => (props.types || []).map((item) => ({ label: item, value: item })))
const subtypeOptions = computed(() => (props.types || []).filter((item) => item !== values.type))

watch(
  () => props.module,
  (module) => {
    resetForm({
      values: module ? moduleToFormValues(module) : emptyModuleValues(),
    })
    pdfFile.value = null
    removeExistingManual.value = false
    copySourceManual.value = Boolean(props.mode === 'duplicate' && module?.has_manual)
  },
  { immediate: true },
)

function searchManufacturer(event: AutoCompleteCompleteEvent) {
  const query = (event.query || '').toLowerCase()
  manufacturerSuggestions.value = (props.manufacturers || []).filter((item) =>
    item.toLowerCase().includes(query),
  )
}

function toggleSubtype(item: string) {
  const current = values.subtypes || []
  if (current.includes(item)) {
    setFieldValue(
      'subtypes',
      current.filter((entry) => entry !== item),
    )
  } else {
    setFieldValue('subtypes', [...current, item])
  }
}

function addYoutube() {
  setFieldValue('youtube_videos', [...(values.youtube_videos || []), { url: '' }])
}

function removeYoutube(index: number) {
  const next = [...(values.youtube_videos || [])]
  next.splice(index, 1)
  setFieldValue('youtube_videos', next)
}

function updateYoutubeUrl(index: number, url: string | undefined) {
  const next = [...(values.youtube_videos || [])]
  const current = next[index] ?? { url: '' }
  next[index] = { ...current, url: url ?? '' }
  setFieldValue('youtube_videos', next)
}

function moveYoutube(index: number, direction: number) {
  const next = [...(values.youtube_videos || [])]
  const target = index + direction
  if (target < 0 || target >= next.length) return
    ;[next[index], next[target]] = [next[target], next[index]]
  setFieldValue('youtube_videos', next)
}

function onPdfSelect(event: FileUploadSelectEvent) {
  pdfFile.value = event.files?.[0] || null
}

function clearPdf() {
  pdfFile.value = null
}

function removeManual() {
  pdfFile.value = null
  removeExistingManual.value = true
  copySourceManual.value = false
}

const onSubmit = handleSubmit((formValues) => {
  emit('submit', {
    payload: formValuesToPayload(formValues),
    pdfFile: pdfFile.value,
    removeManual: removeExistingManual.value,
    copyManual: copySourceManual.value && !pdfFile.value && !removeExistingManual.value,
  })
})
</script>

<template>
  <form id="eurorack-module-form" class="flex min-h-0 flex-1 flex-col" @submit.prevent="onSubmit">
    <div class="grid min-h-0 grid-cols-1 gap-x-4 gap-y-4 overflow-auto pr-1 min-[781px]:grid-cols-2 pt-4">
      <div>
        <FloatLabel variant="on">
          <AutoComplete input-id="manufacturer" v-model="manufacturer" v-bind="manufacturerAttrs"
            :suggestions="manufacturerSuggestions" :disabled="readonly" dropdown size="small" complete-on-focus fluid
            @complete="searchManufacturer" />
          <label for="manufacturer">Hersteller</label>
        </FloatLabel>
        <small v-if="errors.manufacturer" class="mt-1.5 block text-sm text-danger">{{ errors.manufacturer }}</small>
      </div>

      <div>
        <FloatLabel variant="on">
          <InputText id="name" v-model="name" v-bind="nameAttrs" size="small" :disabled="readonly" fluid />
          <label class="mb-1.5 block text-xs font-semibold text-surface-600" for="name">Name</label>
        </FloatLabel>
        <small v-if="errors.name" class="mt-1.5 block text-sm text-danger">{{ errors.name }}</small>
      </div>

      <div>
        <FloatLabel variant="on">
          <InputNumber v-model="hp" v-bind="hpAttrs" input-id="hp" :min="1" size="small" :disabled="readonly"
            :use-grouping="false" fluid />
          <label class="mb-1.5 block text-xs font-semibold text-surface-600" for="hp">HP</label>
        </FloatLabel>
        <small v-if="errors.hp" class="mt-1.5 block text-sm text-danger">{{ errors.hp }}</small>
      </div>

      <div>
        <FloatLabel variant="on">
          <InputNumber v-model="purchasePrice" v-bind="purchasePriceAttrs" input-id="purchase_price" mode="decimal"
            size="small" :min="0" :min-fraction-digits="0" :max-fraction-digits="2" :disabled="readonly" locale="de-DE"
            fluid />
          <label class="mb-1.5 block text-xs font-semibold text-surface-600" for="purchase_price">Kaufpreis (€)</label>
        </FloatLabel>
        <small v-if="errors.purchase_price" class="mt-1.5 block text-sm text-danger">{{ errors.purchase_price }}</small>
      </div>

      <div>
        <FloatLabel variant="on">
          <InputNumber v-model="currentValue" v-bind="currentValueAttrs" input-id="current_value" mode="decimal"
            size="small" :min="0" :min-fraction-digits="0" :max-fraction-digits="2" :disabled="readonly" locale="de-DE"
            fluid />
          <label class="mb-1.5 block text-xs font-semibold text-surface-600" for="current_value">Wert (€)</label>
        </FloatLabel>
        <small v-if="errors.current_value" class="mt-1.5 block text-sm text-danger">{{ errors.current_value }}</small>
      </div>

      <div>
        <FloatLabel variant="on">
          <Select id="type" v-model="type" v-bind="typeAttrs" :options="typeOptions" option-label="label" size="small"
            option-value="value" :disabled="readonly" fluid />
          <label class="mb-1.5 block text-xs font-semibold text-surface-600" for="type">Typ</label>
        </FloatLabel>
        <small v-if="errors.type" class="mt-1.5 block text-sm text-danger">{{ errors.type }}</small>
      </div>

      <div id="module-subtypes" class="col-span-full">
        <span class="mb-1.5 block text-xs font-semibold text-surface-600">Subtypen</span>
        <template v-if="readonly">
          <div v-if="(subtypes || []).length" class="flex flex-wrap gap-1.5">
            <Chip v-for="item in subtypes" :id="`subtype-chip-${item}`" :key="item" :label="item"
              class="module-form-chip !bg-primary !text-primary-contrast" />
          </div>
          <p v-else id="module-subtypes-empty" class="text-[0.9rem] text-surface-500">Keine Subtypen</p>
        </template>
        <template v-else>
          <p v-if="subtypeOptions.length === 0" class="text-[0.9rem] text-surface-500">Keine weiteren Typen verfügbar.
          </p>
          <div v-else class="flex flex-wrap gap-1.5">
            <Chip v-for="item in subtypeOptions" :id="`subtype-chip-${item}`" :key="item" :label="item"
              class="module-form-chip cursor-pointer transition-transform duration-150 hover:-translate-y-px"
              :class="{ '!bg-primary !text-primary-contrast': (subtypes || []).includes(item) }"
              @click="toggleSubtype(item)" />
          </div>
        </template>
      </div>

      <div>
        <FloatLabel variant="on">
          <InputNumber v-model="plus12" v-bind="plus12Attrs" input-id="plus12" :min="0" size="small"
            :disabled="readonly" :use-grouping="false" fluid />
          <label class="mb-1.5 block text-xs font-semibold text-surface-600" for="plus12">Strombedarf +12V (mA)</label>
        </FloatLabel>
        <small v-if="errors.current_draw_plus12v_ma" class="mt-1.5 block text-sm text-danger">
          {{ errors.current_draw_plus12v_ma }}
        </small>
      </div>

      <div>
        <FloatLabel variant="on">
          <InputNumber v-model="minus12" v-bind="minus12Attrs" input-id="minus12" :min="0" size="small"
            :disabled="readonly" :use-grouping="false" fluid />
          <label class="mb-1.5 block text-xs font-semibold text-surface-600" for="minus12">Strombedarf -12V (mA)</label>
        </FloatLabel>
        <small v-if="errors.current_draw_minus12v_ma" class="mt-1.5 block text-sm text-danger">
          {{ errors.current_draw_minus12v_ma }}
        </small>
      </div>

      <div>
        <FloatLabel variant="on">
          <InputNumber v-model="plus5" v-bind="plus5Attrs" input-id="plus5" size="small" :min="0" :disabled="readonly"
            :use-grouping="false" fluid />
          <label class="mb-1.5 block text-xs font-semibold text-surface-600" for="plus5">Strombedarf +5V (mA)</label>
        </FloatLabel>
        <small v-if="errors.current_draw_plus5v_ma" class="mt-1.5 block text-sm text-danger">
          {{ errors.current_draw_plus5v_ma }}
        </small>
      </div>

      <div>
        <FloatLabel variant="on">
          <InputNumber v-model="depth" v-bind="depthAttrs" input-id="depth" :min="0" size="small" :disabled="readonly"
            :use-grouping="false" fluid />
          <label class="mb-1.5 block text-xs font-semibold text-surface-600" for="depth">Tiefe (mm)</label>
        </FloatLabel>
        <small v-if="errors.depth_mm" class="mt-1.5 block text-sm text-danger">{{ errors.depth_mm }}</small>
      </div>

      <div class="col-span-full">
        <FloatLabel variant="on">
          <Textarea id="description" v-model="description" v-bind="descriptionAttrs" :disabled="readonly" size="small"
            auto-resize rows="3" fluid />
          <label class="mb-1.5 block text-xs font-semibold text-surface-600" for="description">Beschreibung</label>
        </FloatLabel>

      </div>

      <div class="col-span-full">
        <a v-if="readonly" id="manual-url-link" :href="manualUrl || undefined" class="break-all text-primary"
          target="_blank" rel="noopener noreferrer">
          {{ manualUrl || 'Keine Angabe' }}
        </a>
        <div v-else>
          <FloatLabel variant="on">
            <InputText id="manual_url" size="small" v-model="manualUrl" v-bind="manualUrlAttrs" fluid />
            <label class="mb-1.5 block text-xs font-semibold text-surface-600" for="manual_url">Produktseite
              (URL)</label>
          </FloatLabel>
        </div>
      </div>

      <div id="manual-pdf-fields" class="col-span-full">
        <span class="mb-1.5 block text-xs font-semibold text-surface-600">PDF-Anleitung</span>
        <div v-if="existingManual" id="manual-pdf-current" class="mt-2 flex items-center gap-1.5">
          <span>
            {{ existingManual.filename }}
            <span v-if="existingManual.size" class="text-[0.9rem] text-surface-500">({{ formatBytes(existingManual.size)
            }})</span>
          </span>
          <a v-if="existingManual.id && mode !== 'duplicate'" id="open-manual-pdf-button"
            :href="`/api/v1/modules/${existingManual.id}/manual`" target="_blank" rel="noopener noreferrer"
            class="p-button p-button-text p-button-sm">
            <span class="pi pi-file-pdf" /> PDF öffnen
          </a>
          <Button v-if="!readonly" id="remove-manual-pdf-button" type="button" label="Entfernen" severity="danger" text
            size="small" @click="removeManual" />
        </div>
        <span v-else-if="readonly" class="text-[0.9rem] text-surface-500">Keine Anleitung hinterlegt.</span>

        <div v-if="!readonly" id="manual-pdf-upload"
          class="rounded-[0.85rem] border border-dashed border-content-border bg-drop p-4 text-center">
          <p class="text-[0.9rem] text-surface-500">PDF hierher ziehen oder Datei auswählen (max. 20 MB)</p>
          <FileUpload mode="basic" accept="application/pdf,.pdf" :auto="false" choose-label="PDF auswählen"
            :choose-button-props="{ size: 'small' }" custom-upload class="mt-2" @select="onPdfSelect">
            <template #filelabel></template>
          </FileUpload>
          <div v-if="pdfFile" class="mt-2 flex items-center gap-1.5">
            <span>{{ pdfFile.name }} ({{ formatBytes(pdfFile.size) }})</span>
            <Button type="button" label="Abbrechen" text size="small" @click="clearPdf" />
          </div>
        </div>
      </div>

      <div id="youtube-video-fields" class="col-span-full">
        <span class="mb-3 block text-xs font-semibold text-surface-600">YouTube-Videos</span>
        <div v-if="readonly" id="youtube-videos-show">
          <a v-for="(video, index) in youtubeVideos" :id="`youtube-video-link-${index}`" :key="`${video.url}-${index}`"
            :href="video.url" class="break-all text-primary" target="_blank" rel="noopener noreferrer">
            {{ video.url }}
          </a>
          <span v-if="!youtubeVideos?.length" class="text-[0.9rem] text-surface-500">Keine Videos hinterlegt.</span>
        </div>
        <div v-else id="youtube-videos-edit" class="flex flex-col gap-3">
          <div v-for="(video, index) in youtubeVideos" :id="`youtube-video-row-${index}`" :key="index"
            class="flex w-full min-w-0 flex-col gap-1">
            <div class="flex w-full min-w-0 items-center gap-1">
              <div class="min-w-0 flex-1">
                <FloatLabel variant="on" class="w-full">
                  <InputText :id="`youtube-${index}`" :model-value="video.url"
                    placeholder="https://www.youtube.com/watch?v=…" size="small" fluid
                    @update:model-value="updateYoutubeUrl(index, $event)" />
                  <label :for="`youtube-${index}`">Video {{ index + 1 }}</label>
                </FloatLabel>
              </div>
              <div class="flex shrink-0 items-center">
                <Button :id="`move-youtube-video-up-${index}`" type="button" icon="pi pi-arrow-up" text rounded
                  size="small" :disabled="index === 0" aria-label="Nach oben" @click="moveYoutube(index, -1)" />
                <Button :id="`move-youtube-video-down-${index}`" type="button" icon="pi pi-arrow-down" text rounded
                  size="small" :disabled="index >= (youtubeVideos?.length ?? 0) - 1" aria-label="Nach unten"
                  @click="moveYoutube(index, 1)" />
                <Button :id="`remove-youtube-video-${index}`" type="button" icon="pi pi-trash" text rounded size="small"
                  severity="danger" aria-label="Entfernen" @click="removeYoutube(index)" />
              </div>
            </div>
            <small v-if="errors[`youtube_videos[${index}].url`]" class="block text-sm text-danger">
              {{ errors[`youtube_videos[${index}].url`] }}
            </small>
          </div>
          <Button id="add-youtube-video-button" type="button" icon="pi pi-plus" label="Link hinzufügen"
            severity="secondary" size="small" @click="addYoutube" />
        </div>
      </div>
    </div>

    <div class="flex justify-end gap-2 pt-4">
      <Button :id="readonly ? 'close-eurorack-module-button' : 'cancel-eurorack-module-button'" type="button"
        size="small" :label="readonly ? 'Schließen' : 'Abbrechen'" severity="secondary" @click="emit('cancel')" />
      <Button v-if="!readonly" id="save-eurorack-module-button" type="submit" :label="submitLabel" :loading="saving"
        size="small" />
    </div>
  </form>
</template>
