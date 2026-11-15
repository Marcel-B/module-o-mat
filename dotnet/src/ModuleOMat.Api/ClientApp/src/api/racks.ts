import type { RackListResponse, RackPayload, RackResponse } from '../types'
import { jsonBody, request } from './client'

export function listRacks(): Promise<RackListResponse> {
  return request<RackListResponse>('/racks')
}

export function getRack(id: number | string): Promise<RackResponse> {
  return request<RackResponse>(`/racks/${id}`)
}

export function createRack(attrs: Partial<RackPayload> & { name: string }): Promise<RackResponse> {
  return request<RackResponse>('/racks', {
    method: 'POST',
    body: jsonBody({ rack: attrs }),
  })
}

export function updateRack(id: number | string, attrs: RackPayload): Promise<RackResponse> {
  return request<RackResponse>(`/racks/${id}`, {
    method: 'PUT',
    body: jsonBody({ rack: attrs }),
  })
}

export function deleteRack(id: number | string): Promise<null> {
  return request<null>(`/racks/${id}`, { method: 'DELETE' })
}
