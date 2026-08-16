import { defineStore } from 'pinia'
import { ref } from 'vue'
import type { Module } from '../types'

export const useInventoryStore = defineStore('inventory', () => {
  const modules = ref<Module[]>([])
  const loading = ref(false)

  return { modules, loading }
})
