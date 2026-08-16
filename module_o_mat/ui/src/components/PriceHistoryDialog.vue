<script setup lang="ts">
import { computed, nextTick, onBeforeUnmount, ref, watch } from "vue";
import type { Chart as ChartJS, TooltipItem, TooltipModel } from "chart.js";
import { Chart } from "chart.js/auto";
import { buildPriceChartData, chartJsConfig, type ChartJsDataset, type PriceChartPoint } from "../utils/priceChart";
import { formatDate, formatEuro } from "../utils/format";
import type { Module } from "../types";

interface Props {
  visible?: boolean;
  module?: Module | null;
}

interface Emits {
  close: [];
}

const props = defineProps<Props>();
const emit = defineEmits<Emits>();
const canvas = ref<HTMLCanvasElement | null>(null);
let chart: ChartJS | null = null;
let tooltipEl: HTMLDivElement | null = null;

const title = computed(() => {
  if (!props.module) return "Preisverlauf";
  return `Preisverlauf: ${props.module.manufacturer} - ${props.module.name}`;
});

const chartData = computed(() => buildPriceChartData(props.module?.price_observations || []));
const hasData = computed(() => (chartData.value.datasets || []).length > 0);

function ensureTooltip() {
  if (tooltipEl) return tooltipEl;
  tooltipEl = document.createElement("div");
  tooltipEl.className =
    "fixed z-[80] min-w-36 max-w-64 rounded-[0.7rem] bg-surface-0 px-3 py-2.5 text-surface-900 shadow-[0_12px_30px_rgb(15_18_24/22%)] pointer-events-auto opacity-0 transition-opacity duration-150";
  tooltipEl.hidden = true;
  document.body.appendChild(tooltipEl);
  return tooltipEl;
}

function hideTooltip() {
  if (!tooltipEl) return;
  tooltipEl.hidden = true;
  tooltipEl.style.opacity = "0";
}

function externalTooltip(context: { chart: ChartJS; tooltip: TooltipModel<"line"> }) {
  const { chart: instance, tooltip } = context;
  const el = ensureTooltip();
  if (tooltip.opacity === 0) {
    hideTooltip();
    return;
  }

  const titleText = tooltip.title?.[0] || "";
  const lines = (tooltip.dataPoints || [])
    .map((item: TooltipItem<"line">) => {
      const point = (item.dataset as unknown as ChartJsDataset).pointMeta?.[item.dataIndex] as
        | PriceChartPoint
        | null
        | undefined;
      const notes = typeof point?.notes === "string" ? point.notes.trim() : "";
      const url = typeof point?.source_url === "string" ? point.source_url.trim() : "";
      const amount = formatEuro(item.parsed.y);
      const notesHtml = notes
        ? url
          ? `<a class="text-primary break-words" href="${url}" target="_blank" rel="noopener noreferrer">${notes}</a>`
          : `<span>${notes}</span>`
        : "";
      return `<div>${notesHtml}<div class="font-semibold">${amount}</div></div>`;
    })
    .join("");

  el.innerHTML = `<div class="mb-1 text-xs text-surface-500">${titleText}</div><div class="space-y-2">${lines}</div>`;
  el.hidden = false;
  el.style.opacity = "1";

  const canvasRect = instance.canvas.getBoundingClientRect();
  el.style.left = `${canvasRect.left + tooltip.caretX - el.offsetWidth / 2}px`;
  el.style.top = `${canvasRect.top + tooltip.caretY - el.offsetHeight - 12}px`;
}

async function renderChart() {
  await nextTick();
  if (chart) {
    chart.destroy();
    chart = null;
  }
  if (!hasData.value || !canvas.value) return;

  const { labels, datasets } = chartJsConfig(chartData.value);
  chart = new Chart(canvas.value, {
    type: "line",
    data: { labels, datasets },
    options: {
      responsive: true,
      maintainAspectRatio: false,
      interaction: { mode: "nearest", intersect: false },
      plugins: {
        legend: { display: true, position: "bottom" },
        tooltip: {
          enabled: false,
          external: externalTooltip,
          callbacks: {
            title(items: TooltipItem<"line">[]) {
              return items[0] ? formatDate(String(items[0].label)) : "";
            },
          },
        },
      },
      scales: {
        x: {
          title: { display: true, text: "Datum" },
          ticks: {
            callback(value: string | number) {
              return formatDate(this.getLabelForValue(Number(value)));
            },
          },
        },
        y: {
          beginAtZero: false,
          title: { display: true, text: "Preis (EUR)" },
          ticks: {
            callback(value: string | number) {
              return formatEuro(Number(value));
            },
          },
        },
      },
    },
  });
}

watch(
  () => [props.visible, props.module],
  () => {
    if (props.visible) renderChart();
  },
);

onBeforeUnmount(() => {
  chart?.destroy();
  tooltipEl?.remove();
});
</script>

<template>
  <Dialog
    id="price-history-modal"
    :visible="visible"
    modal
    :header="title"
    :style="{ width: 'min(48rem, 96vw)' }"
    :draggable="false"
    @update:visible="emit('close')"
  >
    <div id="price-history-content">
      <div v-if="hasData" id="price-history-chart" class="relative h-80 w-full">
        <canvas id="price-history-canvas" ref="canvas" aria-label="Preisverlaufsdiagramm" />
      </div>
      <p v-else id="price-history-empty" class="text-surface-500">
        Für dieses Modul liegen noch keine Preisbeobachtungen vor.
      </p>
      <div class="flex justify-end pt-4">
        <Button id="close-price-history-button" label="Schließen" @click="emit('close')" />
      </div>
    </div>
  </Dialog>
</template>

