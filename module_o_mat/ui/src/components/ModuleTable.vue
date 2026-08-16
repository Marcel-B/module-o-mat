<script setup lang="ts">
import { computed, ref } from 'vue'
import { useRouter } from 'vue-router'
import type { MenuItem } from 'primevue/menuitem'
import { formatEuro, formatEuroRange, formatHpWidth, priceRangeTitle } from '../utils/format'
import { youtubeEmbedUrl, youtubeWatchUrl } from '../utils/youtube'
import type { InventoryStats, Module, ModuleGroup } from '../types'
import YoutubeHoverPreview from './YoutubeHoverPreview.vue'

const props = defineProps<{
  modules: Module[]
  groups: ModuleGroup[]
  stats?: InventoryStats | null
  filtersActive?: boolean
  loading?: boolean
}>()

const emit = defineEmits<{
  delete: [module: Module]
}>()
const router = useRouter()
const menu = ref<{ toggle: (event: Event) => void } | null>(null)
const menuItems = ref<MenuItem[]>([])
const activeModule = ref<Module | null>(null)

const emptyMessage = computed(() =>
  props.filtersActive ? 'Keine Module gefunden.' : 'Es sind noch keine Module erfasst.',
)

function openMenu(event: Event, module: Module) {
  activeModule.value = module
  menuItems.value = [
    {
      label: 'Preisverlauf',
      icon: 'pi pi-chart-line',
      command: () => router.push(`/modules/${module.id}/price-history`),
    },
    {
      label: 'Bearbeiten',
      icon: 'pi pi-pencil',
      command: () => router.push(`/modules/${module.id}/edit`),
    },
    {
      label: 'Duplizieren',
      icon: 'pi pi-copy',
      command: () => router.push(`/modules/${module.id}/duplicate`),
    },
    {
      separator: true,
    },
    {
      label: 'Löschen',
      icon: 'pi pi-trash',
      class: 'p-danger',
      command: () => emit('delete', module),
    },
  ]
  menu.value?.toggle(event)
}

function primaryVideo(module: Module) {
  return (module.youtube_videos || [])[0] || null
}
</script>

<template>
  <div class="inventory-table-wrap">
    <ProgressBar v-if="loading" mode="indeterminate" style="height: 3px" />

    <p v-if="!loading && modules.length === 0" id="no-eurorack-modules" class="empty-state">
      {{ emptyMessage }}
    </p>

    <table v-else id="eurorack-modules" class="inventory-table">
      <thead>
        <tr>
          <th>Modul</th>
          <th class="col-hp">HP</th>
          <th class="col-price">Kaufpreis</th>
          <th class="col-value">Wert</th>
          <th class="col-actions"></th>
        </tr>
      </thead>

      <tbody v-for="group in groups" :id="`eurorack-modules-${group.type}`" :key="group.type">
        <tr class="group-row">
          <td colspan="5">
            {{ group.type }}
            <span class="group-count">({{ group.modules.length }})</span>
          </td>
        </tr>
        <tr
          v-for="module in group.modules"
          :id="`eurorack-module-${module.id}`"
          :key="module.id"
        >
          <td class="name-cell">{{ module.manufacturer }} - {{ module.name }}</td>
          <td class="col-hp">{{ module.hp }}</td>
          <td class="col-price">{{ formatEuro(module.purchase_price) }}</td>
          <td class="col-value">
            <span :title="priceRangeTitle(module.price_range)">
              {{ formatEuroRange(module.price_range, module.current_value) }}
            </span>
          </td>
          <td class="col-actions">
            <div class="row-actions">
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

      <tfoot v-if="stats" id="inventory-stats">
        <tr>
          <td>
            {{ stats.count }} {{ stats.count === 1 ? 'Modul' : 'Module' }}
            <span class="stats-sub">{{ formatHpWidth(stats) }}</span>
          </td>
          <td class="col-hp">{{ stats.total_hp }}</td>
          <td class="col-price">{{ formatEuro(stats.total_purchase_price) }}</td>
          <td class="col-value">{{ formatEuro(stats.total_current_value) }}</td>
          <td></td>
        </tr>
      </tfoot>
    </table>

    <Menu ref="menu" :model="menuItems" popup />
  </div>
</template>
