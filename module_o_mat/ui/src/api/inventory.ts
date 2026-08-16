import type {
  BackupImportResponse,
  ManufacturersResponse,
  ModuleFilters,
  ModuleListResponse,
  ModulePayload,
  ModuleResponse,
  ModuleTypeListResponse,
  ModuleTypeResponse,
} from '../types'
import { downloadFile, jsonBody, request } from './client'

export function listModules(filters: Partial<ModuleFilters> = {}): Promise<ModuleListResponse> {
  const params = new URLSearchParams()
  const query = (filters.q || '').trim()
  if (query) params.set('q', query)
  if (filters.type) params.append('types', String(filters.type))
  if (filters.minHp !== undefined && filters.minHp !== '') params.set('min_hp', String(filters.minHp))
  if (filters.maxHp !== undefined && filters.maxHp !== '') params.set('max_hp', String(filters.maxHp))

  const suffix = params.toString() ? `?${params}` : ''
  return request<ModuleListResponse>(`/modules${suffix}`)
}

export function getModule(id: number | string): Promise<ModuleResponse> {
  return request<ModuleResponse>(`/modules/${id}`)
}

export function createModule(attrs: ModulePayload): Promise<ModuleResponse> {
  return request<ModuleResponse>('/modules', {
    method: 'POST',
    body: jsonBody({ module: attrs }),
  })
}

export function updateModule(id: number | string, attrs: ModulePayload): Promise<ModuleResponse> {
  return request<ModuleResponse>(`/modules/${id}`, {
    method: 'PATCH',
    body: jsonBody({ module: attrs }),
  })
}

export function deleteModule(id: number | string): Promise<null> {
  return request<null>(`/modules/${id}`, { method: 'DELETE' })
}

export function duplicateModule(
  id: number | string,
  { module, copyManual = true }: { module?: ModulePayload; copyManual?: boolean } = {},
): Promise<ModuleResponse> {
  return request<ModuleResponse>(`/modules/${id}/duplicate`, {
    method: 'POST',
    body: jsonBody({
      copy_manual: copyManual,
      ...(module ? { module } : {}),
    }),
  })
}

export function uploadManual(id: number | string, file: File): Promise<ModuleResponse> {
  const body = new FormData()
  body.append('file', file)
  return request<ModuleResponse>(`/modules/${id}/manual`, { method: 'PUT', body })
}

export function deleteManual(id: number | string): Promise<ModuleResponse> {
  return request<ModuleResponse>(`/modules/${id}/manual`, { method: 'DELETE' })
}

export function listModuleTypes(): Promise<ModuleTypeListResponse> {
  return request<ModuleTypeListResponse>('/module-types')
}

export function createModuleType(name: string): Promise<ModuleTypeResponse> {
  return request<ModuleTypeResponse>('/module-types', {
    method: 'POST',
    body: jsonBody({ module_type: { name } }),
  })
}

export function updateModuleType(id: number | string, name: string): Promise<ModuleTypeResponse> {
  return request<ModuleTypeResponse>(`/module-types/${id}`, {
    method: 'PATCH',
    body: jsonBody({ module_type: { name } }),
  })
}

export function deleteModuleType(id: number | string): Promise<null> {
  return request<null>(`/module-types/${id}`, { method: 'DELETE' })
}

export function listManufacturers(): Promise<ManufacturersResponse> {
  return request<ManufacturersResponse>('/manufacturers')
}

export function exportBackup(): Promise<void> {
  return downloadFile('/backup/export', 'inventory.zip')
}

export function importBackup(file: File): Promise<BackupImportResponse> {
  const body = new FormData()
  body.append('file', file)
  return request<BackupImportResponse>('/backup/import', { method: 'POST', body })
}
