<script lang="ts" setup>
import { Button, Menu } from "primevue";
import { useRouter } from "vue-router";
import { ref } from "vue";

const emit = defineEmits<{
  action: [];
}>();

const menu = ref<Menu | null>(null);
const router = useRouter();
const items = ref([
  {
    label: "Neues Modul",
    icon: "pi pi-pencil",
    command: () => router.push("/modules/new"),
  },
  {
    label: "Typen verwalten",
    icon: "pi pi-list",
    command: () => router.push("/types"),
  },
  {
    separator: true,
  },
  {
    label: "Datensicherung",
    icon: "pi pi-database",
    command: () => router.push("/backup"),
  },
]);

function toggle(event: Event) {
  emit("action");
  menu.value?.toggle(event);
}
</script>
<template>
  <Button
    id="action-menu-button"
    icon="pi pi-bars"
    severity="primary"
    text
    class="p-button-rounded"
    aria-label="Aktionen"
    @click="toggle"
  />
  <Menu ref="menu" id="overlay_menu" :model="items" popup />
</template>
