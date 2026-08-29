import { afterEach, describe, expect, it, vi } from 'vitest'
import { createModule, getMaintenance, listBackupHistory, listModules } from './inventory'

afterEach(() => {
  vi.unstubAllGlobals()
  vi.restoreAllMocks()
})

function jsonResponse(body: unknown, status = 200) {
  return {
    ok: status >= 200 && status < 300,
    status,
    headers: new Headers({ 'content-type': 'application/json' }),
    json: async () => body,
  }
}

describe('listModules', () => {
  it('setzt Filter als Query-Parameter', async () => {
    const fetchMock = vi.fn().mockResolvedValue(jsonResponse({ data: [], stats: {} }))
    vi.stubGlobal('fetch', fetchMock)

    await listModules({ q: 'Maths', type: 'Envelope', minHp: 8, maxHp: 20 })

    expect(fetchMock).toHaveBeenCalledWith(
      '/api/v1/modules?q=Maths&types=Envelope&min_hp=8&max_hp=20',
      expect.any(Object),
    )
  })

  it('laesst leere Filter weg', async () => {
    const fetchMock = vi.fn().mockResolvedValue(jsonResponse({ data: [], stats: {} }))
    vi.stubGlobal('fetch', fetchMock)

    await listModules({})

    expect(fetchMock).toHaveBeenCalledWith('/api/v1/modules', expect.any(Object))
  })
})

describe('createModule', () => {
  it('sendet das Modul im Request-Body', async () => {
    const fetchMock = vi.fn().mockResolvedValue(jsonResponse({ data: { id: 1 } }))
    vi.stubGlobal('fetch', fetchMock)

    await createModule({
      manufacturer: 'Make Noise',
      name: 'Maths',
      hp: 20,
      type: 'Envelope',
      subtypes: [],
      current_draw_plus12v_ma: null,
      current_draw_minus12v_ma: null,
      current_draw_plus5v_ma: null,
      depth_mm: null,
      description: null,
      manual_url: null,
      purchase_price: null,
      current_value: null,
      youtube_videos: [],
    })

    expect(fetchMock).toHaveBeenCalledWith(
      '/api/v1/modules',
      expect.objectContaining({
        method: 'POST',
        body: expect.stringContaining('"name":"Maths"'),
      }),
    )
  })
})

describe('getMaintenance', () => {
  it('fragt den Wartungsstatus ab', async () => {
    const fetchMock = vi.fn().mockResolvedValue(jsonResponse({ maintenance: true }))
    vi.stubGlobal('fetch', fetchMock)

    await expect(getMaintenance()).resolves.toEqual({ maintenance: true })
    expect(fetchMock).toHaveBeenCalledWith('/api/v1/maintenance', expect.any(Object))
  })
})

describe('listBackupHistory', () => {
  it('fragt Seite 1 ohne Query an', async () => {
    const fetchMock = vi.fn().mockResolvedValue(jsonResponse({ backup_runs: [], total: 0 }))
    vi.stubGlobal('fetch', fetchMock)

    await listBackupHistory()

    expect(fetchMock).toHaveBeenCalledWith('/api/v1/backup/history', expect.any(Object))
  })

  it('setzt die Seite als Query-Parameter', async () => {
    const fetchMock = vi.fn().mockResolvedValue(jsonResponse({ backup_runs: [], total: 0 }))
    vi.stubGlobal('fetch', fetchMock)

    await listBackupHistory(2)

    expect(fetchMock).toHaveBeenCalledWith('/api/v1/backup/history?page=2', expect.any(Object))
  })
})
