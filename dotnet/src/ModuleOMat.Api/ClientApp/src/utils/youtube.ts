const YOUTUBE_ID =
  /(?:youtube\.com\/(?:watch\?(?:[^#]*&)?v=|embed\/|shorts\/)|youtu\.be\/)([A-Za-z0-9_-]{11})/

export function youtubeVideoId(url: unknown): string | null {
  if (typeof url !== 'string') return null
  const match = url.trim().match(YOUTUBE_ID)
  return match?.[1] ?? null
}

export function isValidYoutubeUrl(url: unknown): boolean {
  return youtubeVideoId(url) != null
}

export function youtubeWatchUrl(url: string): string | null {
  const id = youtubeVideoId(url)
  return id ? `https://www.youtube.com/watch?v=${id}` : null
}

export function youtubeEmbedUrl(
  url: string,
  { autoplay = false, mute = false }: { autoplay?: boolean; mute?: boolean } = {},
): string | null {
  const id = youtubeVideoId(url)
  if (!id) return null

  const params = new URLSearchParams()
  if (autoplay) params.set('autoplay', '1')
  if (mute) params.set('mute', '1')
  const query = params.toString()
  const base = `https://www.youtube-nocookie.com/embed/${id}`
  return query ? `${base}?${query}` : base
}
