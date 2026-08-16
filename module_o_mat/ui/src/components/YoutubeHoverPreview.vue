<script setup lang="ts">
import { onBeforeUnmount, ref } from 'vue'

const props = defineProps<{
  id: string
  watchUrl?: string | null
  embedUrl?: string | null
}>()

const overlay = ref<HTMLDivElement | null>(null)

function hide() {
  overlay.value?.remove()
  overlay.value = null
}

function show(event: MouseEvent) {
  if (!props.embedUrl) return
  hide()

  const node = document.createElement('div')
  node.id = `youtube-preview-${props.id}`
  node.className =
    'pointer-events-none fixed z-50 w-80 max-w-[min(20rem,calc(100vw-1.5rem))] overflow-hidden rounded-xl border border-content-border bg-content shadow-[0_18px_40px_rgb(15_18_24_/_28%)]'

  const iframe = document.createElement('iframe')
  iframe.src = props.embedUrl
  iframe.title = 'YouTube-Vorschau'
  iframe.className = 'aspect-video block h-auto w-full border-0'
  iframe.allow =
    'accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture'
  iframe.allowFullscreen = true
  node.appendChild(iframe)
  document.body.appendChild(node)
  overlay.value = node

  const rect = (event.currentTarget as HTMLElement).getBoundingClientRect()
  const overlayRect = node.getBoundingClientRect()
  let top = rect.bottom + 8
  let left = rect.right - overlayRect.width
  if (left < 8) left = 8
  if (top + overlayRect.height > window.innerHeight - 8) {
    top = Math.max(8, rect.top - overlayRect.height - 8)
  }
  node.style.top = `${top}px`
  node.style.left = `${left}px`
}

onBeforeUnmount(hide)
</script>

<template>
  <a
    :id="id"
    class="p-button p-button-text p-button-rounded p-button-sm p-button-icon-only"
    :href="watchUrl ?? undefined"
    target="_blank"
    rel="noopener noreferrer"
    aria-label="YouTube-Video öffnen"
    title="YouTube-Video öffnen"
    @mouseenter="show"
    @mouseleave="hide"
  >
    <span class="pi pi-play" />
  </a>
</template>
