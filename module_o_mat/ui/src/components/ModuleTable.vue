<script setup lang="ts">
import { computed, nextTick, onMounted, ref, watch } from "vue";
import { useRouter } from "vue-router";
import { formatEuro, formatEuroRange, formatHpWidth } from "../utils/format";
import { youtubeEmbedUrl, youtubeWatchUrl } from "../utils/youtube";
import type { InventoryStats, Module, ModuleGroup } from "../types";
import ModuleFilters from "@/components/ModuleFilters.vue";
import YoutubeHoverPreview from "@/components/YoutubeHoverPreview.vue";
import { emptyTableFilters } from "../utils/tableFilters";
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
const filters = ref(emptyTableFilters());
const tableShell = ref<HTMLElement | null>(null);
const tableGlitching = ref(false);
let lastTableHeight = 0;
let tableGlitchTimer = 0;

const typeOptions = computed(() => props.groups.map((group) => group.type));

function prefersReducedMotion(): boolean {
  return window.matchMedia("(prefers-reduced-motion: reduce)").matches;
}

function currentTableHeight(): number {
  return tableShell.value?.getBoundingClientRect().height ?? 0;
}

watch(
  filters,
  async () => {
    const el = tableShell.value;
    if (!el || prefersReducedMotion()) return;

    const from = lastTableHeight || currentTableHeight();
    await nextTick();
    const to = currentTableHeight();
    lastTableHeight = to;
    if (Math.abs(from - to) < 4) return;

    el.style.transition = "none";
    el.style.height = `${from}px`;
    el.getBoundingClientRect();
    el.style.transition = "height 0.38s cubic-bezier(0.22, 1, 0.36, 1)";
    el.style.height = `${to}px`;

    const finish = (event: TransitionEvent) => {
      if (event.propertyName !== "height") return;
      el.removeEventListener("transitionend", finish);
      el.style.height = "";
      el.style.transition = "";
      lastTableHeight = currentTableHeight();
    };
    el.addEventListener("transitionend", finish);
  },
  { deep: true },
);

onMounted(() => {
  lastTableHeight = currentTableHeight();
});

function glitchTable() {
  if (prefersReducedMotion()) return;
  tableGlitching.value = false;
  window.clearTimeout(tableGlitchTimer);
  requestAnimationFrame(() => {
    tableGlitching.value = true;
    tableGlitchTimer = window.setTimeout(() => {
      tableGlitching.value = false;
    }, 340);
  });
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
  <div
    ref="tableShell"
    class="module-table-shell overflow-hidden rounded-2xl border border-content-border bg-content"
    :class="{ 'module-table-glitch': tableGlitching }"
  >
    <DataTable :value="tableModules" v-model:filters="filters" size="small" row-group-mode="subheader" scrollable
      scroll-height="calc(100vh - 23rem)" :global-filter-fields="['type', 'subtypesText', 'manufacturer', 'name', 'hp']"
      group-rows-by="type" class="text-sm p-3" responsive-layout="scroll">
      <template #header>
        <div>
          <div class="flex justify-between">
            <h1 class="mb-4 text-xl font-semibold text-primary">Eurorack-Module</h1>
            <ActionMenu @action="glitchTable" />
          </div>
          <ModuleFilters v-model="filters" :types="typeOptions" />
        </div>
      </template>
      <template #empty>
        <p v-if="!loading && modules.length === 0" id="no-eurorack-modules"
          class="px-4 py-10 text-center text-surface-600">
          {{ emptyMessage }}
        </p>
      </template>
      <template #loading>
        <ProgressBar mode="indeterminate" style="height: 3px" />
      </template>
      <template #footer>
        <div class="flex gap-4 align-baseline text-xs font-medium mt-3" v-if="stats">
          <span>
            {{ stats.count }} {{ stats.count === 1 ? "Modul" : "Module" }}
          </span>
          <span>
            {{ stats.total_hp }} HP entspricht {{ formatHpWidth(stats) }}
          </span>
          <span>
            Kaufpreis: {{ formatEuro(stats.total_purchase_price) }}
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
              <YoutubeHoverPreview v-if="primaryVideo(data)" :id="`open-youtube-${data.id}`"
                :watch-url="youtubeWatchUrl(primaryVideo(data).url)"
                :embed-url="youtubeEmbedUrl(primaryVideo(data).url, { autoplay: true, mute: true })" />
              <Button v-else icon="pi pi-youtube" severity="secondary" text rounded> </Button>
            </div>
            <RouterLink :to="`/modules/${data.id}`">
              <Button icon="pi pi-eye" text severity="secondary" rounded></Button>
            </RouterLink>
            <Button type="button" rounded text icon="pi pi-ellipsis-v" @click="toggle($event, data)"
              aria-haspopup="true" aria-controls="overlay_menu" />
          </div>
        </template>
      </Column>
      <template #groupheader="{ data }">
        <div class="flex items-center gap-2 font-bold text-primary">
          <span>{{ data.type }}</span>
          <span class="text-surface-600">({{modules.filter((x) => x.type === data.type).length}}) </span>
        </div>
      </template>
    </DataTable>
  </div>
  <div
    class="overflow-auto rounded-2xl border border-content-border bg-content shadow-[0_18px_40px_-28px_rgb(15_18_24/45%)]">
    <ProgressBar v-if="loading" mode="indeterminate" style="height: 3px" />
    <Menu ref="menu" id="overlay_menu" :model="items" popup />
  </div>
</template>
