<script setup lang="ts">
import { onBeforeUnmount, onMounted, ref } from "vue";

const canvas = ref<HTMLCanvasElement | null>(null);

let persist: HTMLCanvasElement | null = null;
let frame = 0;
let running = false;
let beamX = 0;
let lastTs = 0;
let observer: ResizeObserver | null = null;

function prefersReducedMotion(): boolean {
  return window.matchMedia("(prefers-reduced-motion: reduce)").matches;
}

function phosphorColor(): string {
  return getComputedStyle(document.documentElement).getPropertyValue("--p-primary-color").trim() || "#2ee6a0";
}

function signal(xNorm: number, time: number): number {
  const live = time * 2.15 + xNorm * Math.PI * 2 * 2.6;
  let y = Math.sin(live) * 0.22;
  y += Math.sin(live * 2.2 + 0.35) * 0.08;
  y += Math.sin(time * 0.65) * 0.05;

  const hump = 0.34 + Math.sin(time * 0.42) * 0.05;
  const dh = xNorm - hump;
  y += Math.exp(-dh * dh * 70) * Math.sin(time * 2.8) * 0.22;

  const spike = 0.52 + Math.sin(time * 0.5) * 0.04;
  const ds = xNorm - spike;
  y += Math.exp(-ds * ds * 920) * 0.92;
  const dt = xNorm - (spike + 0.02);
  y -= Math.exp(-dt * dt * 1500) * 0.72;

  return Math.max(-1, Math.min(1, y));
}

function sizeCanvas() {
  const el = canvas.value;
  if (!el) return;

  const rect = el.getBoundingClientRect();
  const dpr = Math.min(window.devicePixelRatio || 1, 2);
  const width = Math.max(1, Math.floor(rect.width * dpr));
  const height = Math.max(1, Math.floor(rect.height * dpr));

  if (el.width === width && el.height === height) return;

  el.width = width;
  el.height = height;
  persist ??= document.createElement("canvas");
  persist.width = width;
  persist.height = height;
  beamX = 0;
}

function drawPath(ctx: CanvasRenderingContext2D, width: number, height: number, time: number, color: string) {
  const mid = height * 0.5;
  const amp = height * 0.42;
  const steps = Math.max(80, Math.floor(width / 2));

  ctx.strokeStyle = color;
  ctx.lineWidth = Math.max(1.2, height * 0.05);
  ctx.lineCap = "round";
  ctx.lineJoin = "round";
  ctx.shadowColor = color;
  ctx.shadowBlur = height * 0.22;
  ctx.beginPath();

  for (let i = 0; i <= steps; i++) {
    const x = (i / steps) * width;
    const y = mid - signal(i / steps, time) * amp;
    if (i === 0) ctx.moveTo(x, y);
    else ctx.lineTo(x, y);
  }

  ctx.stroke();
}

function drawStatic() {
  const el = canvas.value;
  if (!el) return;
  sizeCanvas();
  const ctx = el.getContext("2d");
  if (!ctx) return;
  ctx.clearRect(0, 0, el.width, el.height);
  drawPath(ctx, el.width, el.height, 0, phosphorColor());
}

function tick(ts: number) {
  if (!running) return;
  frame = window.requestAnimationFrame(tick);

  const el = canvas.value;
  const layer = persist;
  if (!el || !layer) return;

  const ctx = el.getContext("2d");
  const phosphor = layer.getContext("2d");
  if (!ctx || !phosphor) return;

  const width = el.width;
  const height = el.height;
  if (width < 8 || height < 8) return;
  const color = phosphorColor();
  const dt = Math.min(0.05, lastTs ? (ts - lastTs) / 1000 : 0.016);
  lastTs = ts;
  const time = ts / 1000;
  const mid = height * 0.5;
  const amp = height * 0.42;
  const sweepSec = 2.2;
  let remain = (width / sweepSec) * dt;
  const step = Math.max(1, width / 220);

  phosphor.globalCompositeOperation = "destination-in";
  phosphor.fillStyle = "rgba(0,0,0,0.84)";
  phosphor.fillRect(0, 0, width, height);
  phosphor.globalCompositeOperation = "source-over";
  phosphor.strokeStyle = color;
  phosphor.fillStyle = "#e9fff6";
  phosphor.lineWidth = Math.max(1.3, height * 0.048);
  phosphor.lineCap = "round";
  phosphor.shadowColor = color;
  phosphor.shadowBlur = height * 0.2;

  while (remain > 0) {
    if (beamX >= width - 1) {
      beamX = 0;
      remain = 0;
      break;
    }

    const advance = Math.min(step, remain, width - 1 - beamX);
    const x0 = beamX;
    beamX += advance;
    const y0 = mid - signal(x0 / width, time) * amp;
    const y1 = mid - signal(beamX / width, time) * amp;
    phosphor.beginPath();
    phosphor.moveTo(x0, y0);
    phosphor.lineTo(beamX, y1);
    phosphor.stroke();
    remain -= advance;
  }

  phosphor.shadowBlur = height * 0.45;
  phosphor.beginPath();
  phosphor.arc(beamX, mid - signal(beamX / width, time) * amp, Math.max(1.5, height * 0.06), 0, Math.PI * 2);
  phosphor.fill();

  ctx.clearRect(0, 0, width, height);
  ctx.drawImage(layer, 0, 0);
}

onMounted(() => {
  sizeCanvas();
  observer = new ResizeObserver(() => {
    sizeCanvas();
    if (!running) drawStatic();
  });
  if (canvas.value) observer.observe(canvas.value);

  if (prefersReducedMotion()) {
    drawStatic();
    return;
  }

  running = true;
  lastTs = 0;
  frame = window.requestAnimationFrame(tick);
});

onBeforeUnmount(() => {
  running = false;
  window.cancelAnimationFrame(frame);
  observer?.disconnect();
});
</script>

<template>
  <div class="header-scope mx-1 hidden min-w-[7rem] flex-1 sm:block" aria-hidden="true">
    <canvas ref="canvas" class="header-scope-canvas" />
  </div>
</template>
