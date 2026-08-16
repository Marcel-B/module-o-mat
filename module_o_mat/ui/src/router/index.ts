import { createRouter, createWebHistory } from 'vue-router'
import InventoryView from '@/views/InventoryView.vue'

const router = createRouter({
  history: createWebHistory(import.meta.env.BASE_URL),
  routes: [
    { path: '/', name: 'index', component: InventoryView, meta: { title: 'Eurorack-Module' } },
    {
      path: '/modules/new',
      name: 'new',
      component: InventoryView,
      meta: { title: 'Neues Modul erfassen' },
    },
    {
      path: '/modules/:id',
      name: 'show',
      component: InventoryView,
      meta: { title: 'Modul anzeigen' },
    },
    {
      path: '/modules/:id/edit',
      name: 'edit',
      component: InventoryView,
      meta: { title: 'Modul bearbeiten' },
    },
    {
      path: '/modules/:id/duplicate',
      name: 'duplicate',
      component: InventoryView,
      meta: { title: 'Modul duplizieren' },
    },
    {
      path: '/modules/:id/price-history',
      name: 'price-history',
      component: InventoryView,
      meta: { title: 'Preisverlauf' },
    },
    {
      path: '/types',
      name: 'types',
      component: InventoryView,
      meta: { title: 'Typen verwalten' },
    },
    {
      path: '/backup',
      name: 'backup',
      component: InventoryView,
      meta: { title: 'Datensicherung' },
    },
  ],
})

router.afterEach((to) => {
  const title = to.meta.title || 'ModuleOMat'
  document.title = `${title} · ModuleOMat`
})

export default router
