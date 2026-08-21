<script setup lang="ts">
import { computed } from "vue";
import type { TableFilters } from "../utils/tableFilters";

defineProps<{
  types: string[];
}>();

const filters = defineModel<TableFilters>({ required: true });

function filterHasValue(value: string | number | null): boolean {
  if (value == null) return false;
  if (typeof value === "string") return value.trim() !== "";
  return true;
}

const filtersActive = computed(() => {
  const { global, type, manufacturer, hp } = filters.value;
  return (
    filterHasValue(global.value) ||
    filterHasValue(type.value) ||
    filterHasValue(manufacturer.value) ||
    hp.constraints.some((constraint) => filterHasValue(constraint.value))
  );
});

function clearFilters() {
  filters.value.global.value = null;
  filters.value.type.value = null;
  filters.value.manufacturer.value = null;
  filters.value.hp.constraints[0].value = null;
  filters.value.hp.constraints[1].value = null;
}
</script>

<template>
  <div class="flex justify-between">

  <div id="module-filter-form" class="flex flex-wrap items-center gap-2">
    <FloatLabel variant="on">
      <IconField>
        <InputIcon class="pi pi-search text-sm" />
        <InputText
          id="module-search-input"
          v-model="filters.global.value"
          size="small"
          class="w-80"
          v-tooltip.top="'Suche in allen Spalten'"
        />
      </IconField>
      <label class="text-xs" for="module-search-input">Suche</label>
    </FloatLabel>
    <FloatLabel variant="on">
      <Select
        id="module-type-filter"
        v-model="filters.type.value"
        :options="types"
        show-clear
        size="small"
        class="w-64"
        v-tooltip.top="'Filter nach Typ'"
      />
      <label class="text-xs" for="module-type-filter">Typ</label>
    </FloatLabel>
    <FloatLabel variant="on">
      <InputNumber
        id="module-min-hp"
        v-model="filters.hp.constraints[0].value"
        size="small"
        :min="1"
        :use-grouping="false"
        input-class="w-20"
        input-id="module-min-hp"
        v-tooltip.top="'Mindest-HP'"
      />
      <label class="text-xs" for="module-min-hp">Min HP</label>
    </FloatLabel>
    <FloatLabel variant="on">
      <InputNumber
        id="module-max-hp"
        v-model="filters.hp.constraints[1].value"
        size="small"
        :min="1"
        :use-grouping="false"
        input-class="w-20"
        input-id="module-max-hp"
        v-tooltip.top="'Maximale HP'"
      />
      <label class="text-xs" for="module-max-hp">Max HP</label>
    </FloatLabel>

  </div>
      <Button
      v-if="filtersActive"
      id="clear-filters-button"
      icon="pi pi-filter-slash"
      severity="secondary"
      class="mr-1 text-primary"
      size="small"
      text
      rounded
      v-tooltip.top="'Filter zurücksetzen'"
      @click="clearFilters"
    />
  </div>
</template>
