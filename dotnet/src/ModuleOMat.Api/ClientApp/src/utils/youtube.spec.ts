import { describe, expect, it } from 'vitest'
import { isValidYoutubeUrl, youtubeEmbedUrl, youtubeVideoId, youtubeWatchUrl } from './youtube'

describe('youtubeVideoId', () => {
  it('erkennt watch-, short- und youtu.be-URLs', () => {
    expect(youtubeVideoId('https://www.youtube.com/watch?v=abcdefghijk')).toBe('abcdefghijk')
    expect(youtubeVideoId('https://youtu.be/abcdefghijk')).toBe('abcdefghijk')
    expect(youtubeVideoId('https://www.youtube.com/embed/abcdefghijk')).toBe('abcdefghijk')
    expect(youtubeVideoId('https://www.youtube.com/shorts/abcdefghijk')).toBe('abcdefghijk')
  })

  it('lehnt ungueltige Werte ab', () => {
    expect(youtubeVideoId(null)).toBeNull()
    expect(youtubeVideoId('https://example.com')).toBeNull()
  })
})

describe('isValidYoutubeUrl', () => {
  it('ist wahr nur fuer erkannte URLs', () => {
    expect(isValidYoutubeUrl('https://youtu.be/abcdefghijk')).toBe(true)
    expect(isValidYoutubeUrl('not-a-url')).toBe(false)
  })
})

describe('youtubeWatchUrl', () => {
  it('normalisiert auf die Watch-URL', () => {
    expect(youtubeWatchUrl('https://youtu.be/abcdefghijk')).toBe(
      'https://www.youtube.com/watch?v=abcdefghijk',
    )
  })
})

describe('youtubeEmbedUrl', () => {
  it('nutzt youtube-nocookie und optionale Parameter', () => {
    expect(youtubeEmbedUrl('https://youtu.be/abcdefghijk')).toBe(
      'https://www.youtube-nocookie.com/embed/abcdefghijk',
    )
    expect(youtubeEmbedUrl('https://youtu.be/abcdefghijk', { autoplay: true, mute: true })).toBe(
      'https://www.youtube-nocookie.com/embed/abcdefghijk?autoplay=1&mute=1',
    )
  })
})
