<script setup lang="ts">
import { computed } from 'vue'
import { storeToRefs } from 'pinia'
import { useInventoryStore } from '../stores/inventory'
import type { ModuleFilters } from '../types'

const store = useInventoryStore()
const { filters, usedTypes } = storeToRefs(store)

const typeOptions = computed(() => [
  { label: 'Alle Typen', value: '' },
  ...usedTypes.value.map((type) => ({ label: type, value: type })),
])

function update(field: keyof ModuleFilters, value: string | number | null | undefined) {
  store.setFilters({ [field]: value ?? '' })
}
</script>

<template>
  <form
    id="module-filter-form"
    class="mb-5 grid grid-cols-1 items-end gap-3 min-[781px]:grid-cols-[minmax(0,1fr)_12rem_5.5rem_5.5rem_auto]"
    @submit.prevent
  >
    <div>
      <label class="mb-1.5 block text-xs font-semibold text-surface-600" for="module-search-input">Suche</label>
      <IconField>
        <InputIcon class="pi pi-search" />
        <InputText
          id="module-search-input"
          :model-value="filters.q"
          placeholder="Hersteller oder Modul suchen…"
          fluid
          @update:model-value="update('q', $event)"
        />
      </IconField>
    </div>

    <div>
      <label class="mb-1.5 block text-xs font-semibold text-surface-600" for="module-type-filter">Typ</label>
      <Select
        id="module-type-filter"
        :model-value="filters.type"
        :options="typeOptions"
        option-label="label"
        option-value="value"
        fluid
        @update:model-value="update('type', $event)"
      />
    </div>

    <div>
      <label class="mb-1.5 block text-xs font-semibold text-surface-600" for="module-min-hp">Min HP</label>
      <InputNumber
        id="module-min-hp"
        :model-value="filters.minHp === '' ? null : Number(filters.minHp)"
        :min="1"
        :use-grouping="false"
        fluid
        input-id="module-min-hp"
        @update:model-value="update('minHp', $event ?? '')"
      />
    </div>

    <div>
      <label class="mb-1.5 block text-xs font-semibold text-surface-600" for="module-max-hp">Max HP</label>
      <InputNumber
        id="module-max-hp"
        :model-value="filters.maxHp === '' ? null : Number(filters.maxHp)"
        :min="1"
        :use-grouping="false"
        fluid
        input-id="module-max-hp"
        @update:model-value="update('maxHp', $event ?? '')"
      />
    </div>

    <Button
      id="clear-filters-button"
      type="button"
      icon="pi pi-times"
      severity="secondary"
      outlined
      aria-label="Filter und Suche leeren"
      @click="store.clearFilters()"
    />
  </form>
</template>
