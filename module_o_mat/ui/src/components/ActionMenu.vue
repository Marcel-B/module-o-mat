<script lang="ts" setup>
import { Button, Menu } from 'primevue';
import {useRouter} from 'vue-router';

import { ref } from 'vue'

const menu = ref<Menu | null>(null);
const toggle = (event: Event) => {
  menu.value.toggle(event);
};
const router = useRouter();
const items = ref([
  {
    label: 'Neues Modul',
    icon: 'pi pi-pencil',
    command: () => router.push('/modules/new'),
    },
  {
    label: 'Typen verwalten', 
    icon: 'pi pi-list',
    command: () => router.push('/types'),
  },
  {
    separator: true,
  },
  {
    label: 'Datensicherung',
    icon: 'pi pi-database',
    command: () => router.push('/backup'),
  },
])

</script>
<template>
<Button id="action-menu-button" icon="pi pi-bars" @click="toggle" severity="primary" text class="p-button-rounded" aria-label="Aktionen" />
<Menu ref="menu" id="overlay_menu" :model="items" popup />
</template> 