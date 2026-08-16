import type { ApiErrorBody } from '../types'

export class ApiError extends Error {
  details: ApiErrorBody['details']
  status: number

  constructor(message: string, details: ApiErrorBody['details'] = null, status = 400) {
    super(message)
    this.name = 'ApiError'
    this.details = details
    this.status = status
  }
}

function filenameFromDisposition(header: string | null, fallback: string): string {
  if (!header) return fallback
  const utfMatch = header.match(/filename\*=UTF-8''([^;]+)/i)
  if (utfMatch?.[1]) return decodeURIComponent(utfMatch[1])
  const match = header.match(/filename="?([^"]+)"?/i)
  return match?.[1] ?? fallback
}

async function parseBody(response: Response): Promise<unknown> {
  if (response.status === 204) return null

  const contentType = response.headers.get('content-type') || ''
  if (contentType.includes('application/json')) {
    return response.json() as Promise<unknown>
  }

  return response
}

export async function request<T>(path: string, options: RequestInit = {}): Promise<T> {
  const { body, headers, ...rest } = options
  const isForm = typeof FormData !== 'undefined' && body instanceof FormData

  const response = await fetch(`/api/v1${path}`, {
    ...rest,
    body,
    headers: {
      ...(isForm ? {} : { 'Content-Type': 'application/json' }),
      ...headers,
    },
  })

  const data = await parseBody(response)

  if (!response.ok) {
    const errorBody = (data ?? {}) as ApiErrorBody
    const message = errorBody.error || `Anfrage fehlgeschlagen (${response.status})`
    throw new ApiError(message, errorBody.details || null, response.status)
  }

  return data as T
}

export async function downloadFile(path: string, fallbackName: string): Promise<void> {
  const response = await fetch(`/api/v1${path}`)

  if (!response.ok) {
    let details: ApiErrorBody['details'] = null
    let message = `Download fehlgeschlagen (${response.status})`
    const contentType = response.headers.get('content-type') || ''

    if (contentType.includes('application/json')) {
      const data = (await response.json()) as ApiErrorBody
      message = data.error || message
      details = data.details || null
    }

    throw new ApiError(message, details, response.status)
  }

  const blob = await response.blob()
  const filename = filenameFromDisposition(
    response.headers.get('content-disposition'),
    fallbackName,
  )
  const url = URL.createObjectURL(blob)
  const link = document.createElement('a')
  link.href = url
  link.download = filename
  document.body.appendChild(link)
  link.click()
  link.remove()
  URL.revokeObjectURL(url)
}

export function jsonBody(payload: unknown): string {
  return JSON.stringify(payload)
}
