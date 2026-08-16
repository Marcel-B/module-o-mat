<script setup lang="ts">
import { computed, ref } from "vue";
import { useRouter } from "vue-router";
import { FilterMatchMode, FilterOperator } from "@primevue/core/api";
import { formatEuro, formatEuroRange, formatHpWidth } from "../utils/format";
import { youtubeEmbedUrl, youtubeWatchUrl } from "../utils/youtube";
import type { InventoryStats, Module, ModuleGroup } from "../types";
import YoutubeHoverPreview from "@/components/YoutubeHoverPreview.vue";
import DataTable from "primevue/datatable";
import Column from "primevue/column";

interface Props {
  modules: Module[];
  groups: ModuleGroup[];
  stats?: InventoryStats | null;
  filtersActive?: boolean;
  loading?: boolean;
}

interface Emits {
  delete: [module: Module];
}

const props = defineProps<Props>();
const emit = defineEmits<Emits>();
const router = useRouter();

type TableFilters = {
  global: { value: string | null; matchMode: string };
  type: { value: string | null; matchMode: string };
  manufacturer: { value: string | null; matchMode: string };
  hp: {
    operator: string;
    constraints: [
      { value: number | null; matchMode: string },
      { value: number | null; matchMode: string },
    ];
  };
};

const filters = ref<TableFilters>({
  global: { value: null, matchMode: FilterMatchMode.CONTAINS },
  type: { value: null, matchMode: FilterMatchMode.EQUALS },
  manufacturer: { value: null, matchMode: FilterMatchMode.EQUALS },
  hp: {
    operator: FilterOperator.AND,
    constraints: [
      { value: null, matchMode: FilterMatchMode.GREATER_THAN_OR_EQUAL_TO },
      { value: null, matchMode: FilterMatchMode.LESS_THAN_OR_EQUAL_TO },
    ],
  },
});

function filterHasValue(value: string | number | null): boolean {
  if (value == null) return false;
  if (typeof value === "string") return value.trim() !== "";
  return true;
}

const tableFiltersActive = computed(() => {
  const { global, type, manufacturer, hp } = filters.value;
  return (
    filterHasValue(global.value) ||
    filterHasValue(type.value) ||
    filterHasValue(manufacturer.value) ||
    hp.constraints.some((constraint) => filterHasValue(constraint.value))
  );
});

function clearTableFilters() {
  filters.value.global.value = null;
  filters.value.type.value = null;
  filters.value.manufacturer.value = null;
  filters.value.hp.constraints[0].value = null;
  filters.value.hp.constraints[1].value = null;
}

// Menü-Items werden in `items` gehalten
const activeModule = ref<Module | null>(null);

const emptyMessage = computed(() =>
  props.filtersActive ? "Keine Module gefunden." : "Es sind noch keine Module erfasst.",
);

function primaryVideo(module: Module) {
  return (module.youtube_videos || [])[0] || null;
}

function getName(module: Module) {
  return `${module.manufacturer} - ${module.name}`;
}

const tableModules = computed(() =>
  props.modules.map((module) => ({
    ...module,
    subtypesText: (module.subtypes ?? []).join(" "),
  })),
);
const menu = ref();
const items = ref([
  {
    label: "Preisverlauf",
    icon: "pi pi-chart-line",
    command: () => router.push(`/modules/${activeModule.value?.id}/price-history`),
  },
  {
    label: "Bearbeiten",
    icon: "pi pi-pencil",
    command: () => router.push(`/modules/${activeModule.value?.id}/edit`),
  },
  {
    label: "Duplizieren",
    icon: "pi pi-copy",
    command: () => router.push(`/modules/${activeModule.value?.id}/duplicate`),
  },
  {
    separator: true,
  },
  {
    label: "Löschen",
    icon: "pi pi-trash",
    class: "p-danger",
    command: () => router.push(`/modules/${activeModule.value?.id}/delete`),
  },
]);

const toggle = (event: Event, data: Module) => {
  activeModule.value = data;
  menu.value.toggle(event);
};
</script>

<template>
  <DataTable
    :value="tableModules"
    v-model:filters="filters"
    size="small"
    row-group-mode="subheader"
    scrollable
    scroll-height="calc(100vh - 20rem)"
    :global-filter-fields="['type', 'subtypesText', 'manufacturer', 'name', 'hp']"
    group-rows-by="type"
    class="text-sm"
    responsive-layout="scroll"
  >
  <template #header>
    <div>
      <h1 class="text-xl font-semibold mb-4">Eurorack-Module</h1>

    <div class="flex flex-wrap items-center gap-2">
        <FloatLabel variant="on">
          <IconField>
            <InputIcon class="pi pi-search text-sm" />
            <InputText
              v-model="filters.global.value"
              size="small"
              class="w-44"
              v-tooltip.top="'Suche in allen Spalten'"
            />
          </IconField>
          <label class="text-xs" for="module-search-input">Suche</label>
        </FloatLabel>
        <FloatLabel variant="on">
          <Select
            v-model="filters.type.value"
            :options="groups.map((g) => g.type)"
            show-clear
            size="small"
            class="w-36"
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
        <Button
          v-if="tableFiltersActive"
          icon="pi pi-filter-slash"
          severity="secondary"
          size="small"
          text
          rounded
          v-tooltip.top="'Filter zurücksetzen'"
          @click="clearTableFilters"
        />
    </div>
    </div>

  </template>
    <template #empty>
      <p
        v-if="!loading && modules.length === 0"
        id="no-eurorack-modules"
        class="px-4 py-10 text-center text-surface-600"
      >
        {{ emptyMessage }}
      </p>
    </template>
    <template #loading>
      <ProgressBar mode="indeterminate" style="height: 3px" />
    </template>
    <template #footer>
<div class="flex gap-4 align-baseline text-xs font-medium" v-if="stats">
   <span>
      {{ stats.count }} {{ stats.count === 1 ? "Modul" : "Module" }}
   </span>
   <span>
             {{ stats.total_hp }} HP entspricht {{ formatHpWidth(stats) }}
   </span>
<span>

   Kaufpreis:         {{ formatEuro(stats.total_purchase_price) }}
</span>
<span>

Wert: {{ formatEuro(stats.total_current_value) }}
</span>
</div>
    </template>
    <Column field="type" header="Typ" />
    <Column field="name" header="Name">
      <template #body="{ data }"> {{ getName(data) }} </template>
    </Column>
    <Column field="hp" header="HP" />
    <Column field="purchase_price" header="Kaufpreis">
      <template #body="{ data }"> {{ formatEuro(data.purchase_price) }} </template>
    </Column>
    <Column field="current_value" header="Wert">
      <template #body="{ data }">
        {{ formatEuroRange(data.price_range, data.current_value) }}
      </template>
    </Column>
    <Column width="11.5rem" header="">
      <template #body="{ data }">
        <div class="flex gap-2 justify-center align-baseline">
          <a :href="`/api/v1/modules/${data.id}/manual`" target="_blank" rel="noopener noreferrer">
            <Button :disabled="!data.has_manual" icon="pi pi-file-pdf" severity="secondary" text rounded></Button>
          </a>

          <div class="w-12 flex justify-center">
            <YoutubeHoverPreview
              v-if="primaryVideo(data)"
              :id="`open-youtube-${data.id}`"
              :watch-url="youtubeWatchUrl(primaryVideo(data).url)"
              :embed-url="youtubeEmbedUrl(primaryVideo(data).url, { autoplay: true, mute: true })"
            />
            <Button v-else icon="pi pi-youtube" severity="secondary" text rounded> </Button>
          </div>
          <RouterLink :to="`/modules/${data.id}`">
            <Button icon="pi pi-eye" text severity="secondary" rounded></Button>
          </RouterLink>
          <Button
            type="button"
            rounded
            text
            icon="pi pi-ellipsis-v"
            @click="toggle($event, data)"
            aria-haspopup="true"
            aria-controls="overlay_menu"
          />
        </div>
      </template>
    </Column>
    <template #groupheader="{ data }">
      <div class="flex items-center gap-2 font-bold">
        <span>{{ data.type }}</span>
        <span class="text-surface-600">({{ modules.filter((x) => x.type === data.type).length }}) </span>
      </div>
    </template>
  </DataTable>
  <div
    class="overflow-auto rounded-2xl border border-content-border bg-content shadow-[0_18px_40px_-28px_rgb(15_18_24/45%)]"
  >
    <ProgressBar v-if="loading" mode="indeterminate" style="height: 3px" />

    <!-- <p v-if="!loading && modules.length === 0" id="no-eurorack-modules" class="px-4 py-10 text-center text-surface-600">
      {{ emptyMessage }}
    </p>

    <table v-else id="eurorack-modules" class="w-full table-fixed border-collapse">
      <thead>
        <tr>
          <th
            class="border-b border-content-border px-[0.9rem] py-[0.7rem] text-left align-middle text-[0.78rem] font-semibold tracking-wide uppercase text-surface-600"
          >
            Modul
          </th>
          <th
            class="w-14 whitespace-nowrap border-b border-content-border px-[0.9rem] py-[0.7rem] text-left align-middle text-[0.78rem] font-semibold tracking-wide uppercase text-surface-600"
          >
            HP
          </th>
          <th
            class="w-[7.5rem] whitespace-nowrap border-b border-content-border px-[0.9rem] py-[0.7rem] text-right align-middle text-[0.78rem] font-semibold tracking-wide uppercase tabular-nums text-surface-600"
          >
            Kaufpreis
          </th>
          <th
            class="w-[7.5rem] whitespace-nowrap border-b border-content-border px-[0.9rem] py-[0.7rem] text-right align-middle text-[0.78rem] font-semibold tracking-wide uppercase tabular-nums text-surface-600"
          >
            Wert
          </th>
          <th
            class="w-[11.5rem] border-b border-content-border px-[0.9rem] py-[0.7rem] text-left align-middle max-[780px]:w-[8.5rem]"
          ></th>
        </tr>
      </thead>

      <tbody v-for="group in groups" :id="`eurorack-modules-${group.type}`" :key="group.type">
        <tr class="bg-group-row font-semibold">
          <td class="px-[0.9rem] py-[0.55rem] text-left align-middle" colspan="5">
            {{ group.type }}
            <span class="ml-1 font-medium text-surface-600">({{ group.modules.length }})</span>
          </td>
        </tr>
        <tr
          v-for="module in group.modules"
          :id="`eurorack-module-${module.id}`"
          :key="module.id"
          class="hover:bg-row-hover"
        >
          <td class="overflow-hidden px-[0.9rem] py-[0.7rem] text-left align-middle text-ellipsis whitespace-nowrap">
            {{ module.manufacturer }} - {{ module.name }}
          </td>
          <td class="w-14 whitespace-nowrap px-[0.9rem] py-[0.7rem] text-left align-middle">{{ module.hp }}</td>
          <td class="w-[7.5rem] whitespace-nowrap px-[0.9rem] py-[0.7rem] text-right align-middle tabular-nums">
            {{ formatEuro(module.purchase_price) }}
          </td>
          <td class="w-[7.5rem] whitespace-nowrap px-[0.9rem] py-[0.7rem] text-right align-middle tabular-nums">
            <span :title="priceRangeTitle(module.price_range)">
              {{ formatEuroRange(module.price_range, module.current_value) }}
            </span>
          </td>
          <td class="w-[11.5rem] px-[0.9rem] py-[0.7rem] align-middle max-[780px]:w-[8.5rem]">
            <div class="flex justify-end gap-[0.15rem]">
              <a
                v-if="module.has_manual"
                :id="`open-manual-pdf-${module.id}`"
                class="p-button p-button-text p-button-rounded p-button-sm p-button-icon-only"
                :href="`/api/v1/modules/${module.id}/manual`"
                target="_blank"
                rel="noopener noreferrer"
                aria-label="PDF öffnen"
                title="PDF öffnen"
              >
                <span class="pi pi-file-pdf" />
              </a>
              <Button
                v-else
                :id="`open-manual-pdf-${module.id}`"
                icon="pi pi-file-pdf"
                text
                rounded
                size="small"
                disabled
                aria-label="Keine PDF-Anleitung"
                v-tooltip.top="'Keine PDF-Anleitung'"
              />

              <YoutubeHoverPreview
                v-if="primaryVideo(module)"
                :id="`open-youtube-${module.id}`"
                :watch-url="youtubeWatchUrl(primaryVideo(module).url)"
                :embed-url="youtubeEmbedUrl(primaryVideo(module).url, { autoplay: true, mute: true })"
              />
              <Button
                v-else
                :id="`open-youtube-${module.id}`"
                icon="pi pi-play"
                text
                rounded
                size="small"
                disabled
                aria-label="Kein YouTube-Video"
                v-tooltip.top="'Kein YouTube-Video'"
              />

              <Button
                :id="`show-eurorack-module-${module.id}`"
                icon="pi pi-eye"
                text
                rounded
                size="small"
                aria-label="Anzeigen"
                v-tooltip.top="'Anzeigen'"
                @click="router.push(`/modules/${module.id}`)"
              />
              <Button
                :id="`actions-eurorack-module-${module.id}`"
                icon="pi pi-ellipsis-v"
                text
                rounded
                size="small"
                aria-label="Aktionen"
                v-tooltip.top="'Aktionen'"
                @click="openMenu($event, module)"
              />
            </div>
          </td>
        </tr>
      </tbody>

      <tfoot v-if="stats" id="inventory-stats" class="font-semibold">
        <tr>
          <td class="border-t-2 border-content-border px-[0.9rem] py-[0.7rem] text-left align-middle">
            {{ stats.count }} {{ stats.count === 1 ? "Modul" : "Module" }}
            <span class="mt-0.5 block text-xs font-medium text-surface-500">{{ formatHpWidth(stats) }}</span>
          </td>
          <td
            class="w-14 whitespace-nowrap border-t-2 border-content-border px-[0.9rem] py-[0.7rem] text-left align-middle"
          >
            {{ stats.total_hp }}
          </td>
          <td
            class="w-[7.5rem] whitespace-nowrap border-t-2 border-content-border px-[0.9rem] py-[0.7rem] text-right align-middle tabular-nums"
          >
            {{ formatEuro(stats.total_purchase_price) }}
          </td>
          <td
            class="w-[7.5rem] whitespace-nowrap border-t-2 border-content-border px-[0.9rem] py-[0.7rem] text-right align-middle tabular-nums"
          >
            {{ formatEuro(stats.total_current_value) }}
          </td>
          <td class="border-t-2 border-content-border"></td>
        </tr>
      </tfoot>
    </table> -->
    <Menu ref="menu" id="overlay_menu" :model="items" popup />
  </div>
</template>

