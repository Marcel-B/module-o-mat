import { afterEach, describe, expect, it, vi } from 'vitest'
import { ApiError, jsonBody, request } from './client'

afterEach(() => {
  vi.unstubAllGlobals()
  vi.restoreAllMocks()
})

describe('jsonBody', () => {
  it('serialisiert Payloads', () => {
    expect(jsonBody({ module: { name: 'Maths' } })).toBe('{"module":{"name":"Maths"}}')
  })
})

describe('request', () => {
  it('liest JSON bei Erfolg', async () => {
    vi.stubGlobal(
      'fetch',
      vi.fn().mockResolvedValue({
        ok: true,
        status: 200,
        headers: new Headers({ 'content-type': 'application/json' }),
        json: async () => ({ module: { id: 1 } }),
      }),
    )

    await expect(request('/modules/1')).resolves.toEqual({ module: { id: 1 } })
    expect(fetch).toHaveBeenCalledWith(
      '/api/v1/modules/1',
      expect.objectContaining({
        headers: expect.objectContaining({ 'Content-Type': 'application/json' }),
      }),
    )
  })

  it('wirft ApiError mit Servermeldung', async () => {
    vi.stubGlobal(
      'fetch',
      vi.fn().mockResolvedValue({
        ok: false,
        status: 422,
        headers: new Headers({ 'content-type': 'application/json' }),
        json: async () => ({ error: 'ungueltig', details: { name: ['fehlt'] } }),
      }),
    )

    const error = await request('/modules').catch((caught) => caught)

    expect(error).toBeInstanceOf(ApiError)
    expect(error.message).toBe('ungueltig')
    expect(error.status).toBe(422)
    expect(error.details).toEqual({ name: ['fehlt'] })
  })

  it('sendet FormData ohne JSON-Content-Type', async () => {
    const fetchMock = vi.fn().mockResolvedValue({
      ok: true,
      status: 200,
      headers: new Headers({ 'content-type': 'application/json' }),
      json: async () => ({ ok: true }),
    })
    vi.stubGlobal('fetch', fetchMock)

    const body = new FormData()
    body.append('file', new File(['pdf'], 'manual.pdf'))
    await request('/modules/1/manual', { method: 'PUT', body })

    expect(fetchMock.mock.calls[0]?.[1]?.headers).toEqual({})
  })
})
