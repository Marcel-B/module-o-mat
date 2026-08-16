import { describe, expect, it } from 'vitest'
import {
  emptyModuleValues,
  formValuesToPayload,
  moduleSchema,
  moduleToFormValues,
  moduleTypeSchema,
} from './schemas'
import type { Module } from '../types'

describe('moduleSchema', () => {
  it('akzeptiert ein vollstaendiges Modul', async () => {
    const values = {
      ...emptyModuleValues(),
      manufacturer: 'Make Noise',
      name: 'Maths',
      hp: 20,
      type: 'Envelope',
    }

    await expect(moduleSchema.validate(values)).resolves.toMatchObject({
      manufacturer: 'Make Noise',
      name: 'Maths',
      hp: 20,
    })
  })

  it('fordert Pflichtfelder ein', async () => {
    await expect(moduleSchema.validate(emptyModuleValues())).rejects.toThrow()
  })

  it('lehnt ungueltige YouTube-URLs ab', async () => {
    const values = {
      ...emptyModuleValues(),
      manufacturer: 'Make Noise',
      name: 'Maths',
      hp: 20,
      type: 'Envelope',
      youtube_videos: [{ url: 'https://example.com' }],
    }

    await expect(moduleSchema.validate(values)).rejects.toThrow(/YouTube/)
  })
})

describe('moduleTypeSchema', () => {
  it('fordert einen Namen', async () => {
    await expect(moduleTypeSchema.validate({ name: '   ' })).rejects.toThrow()
    await expect(moduleTypeSchema.validate({ name: 'VCO' })).resolves.toEqual({ name: 'VCO' })
  })
})

describe('moduleToFormValues / formValuesToPayload', () => {
  it('rundet leere YouTube-Zeilen und den Haupttyp in subtypes heraus', () => {
    const module = {
      manufacturer: 'Doepfer',
      name: 'A-140',
      hp: 8,
      type: 'Envelope',
      subtypes: ['Envelope', 'Utility'],
      current_draw_plus12v_ma: 20,
      current_draw_minus12v_ma: null,
      current_draw_plus5v_ma: null,
      depth_mm: 40,
      description: '  ADSR  ',
      manual_url: ' https://doepfer.de ',
      purchase_price: 80,
      current_value: 90,
      youtube_videos: [{ id: 1, url: 'https://youtu.be/abcdefghijk' }, { url: '  ' }],
    } as Module

    const payload = formValuesToPayload(moduleToFormValues(module))

    expect(payload.subtypes).toEqual(['Utility'])
    expect(payload.description).toBe('ADSR')
    expect(payload.manual_url).toBe('https://doepfer.de')
    expect(payload.youtube_videos).toEqual([{ url: 'https://youtu.be/abcdefghijk' }])
  })
})
