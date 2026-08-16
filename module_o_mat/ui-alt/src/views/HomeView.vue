<script setup lang="ts">
const features: string[] = [
  'Modulliste gruppiert nach Typ, sortiert nach Hersteller',
  'Suche, Typ- und HP-Filter inkl. Statistik (HP, Kaufpreis, Wert)',
  'Modul anlegen, anzeigen, bearbeiten, duplizieren, soft-löschen',
  'PDF-Anleitung hochladen, öffnen und entfernen',
  'YouTube-Links inkl. Hover-Vorschau',
  'Preisverlauf aus price_observations',
  'Typen verwalten (anlegen, umbenennen, löschen)',
  'Backup exportieren und importieren',
]
</script>

<template>
  <Card>
    <template #title>Platzhalter für deine Vue-Version</template>
    <template #subtitle>PrimeVue, VeeValidate + Yup und Pinia sind bereits verdrahtet.</template>
    <template #content>
      <p>
        Der Vite-Devserver läuft auf Port 5174 und proxied <code>/api</code> nach
        <code>http://localhost:4000</code>. API-Helfer liegen unter <code>src/api/</code>.
      </p>
      <p>Dieselbe Funktionalität wie die Phoenix-LiveView bzw. <code>ui/</code>:</p>
      <ul class="checklist">
        <li v-for="item in features" :key="item">{{ item }}</li>
      </ul>
      <p>
        Interaktive API-Doku:
        <a href="http://localhost:4000/api/docs" target="_blank" rel="noopener noreferrer">
          http://localhost:4000/api/docs
        </a>
      </p>
    </template>
  </Card>
</template>
