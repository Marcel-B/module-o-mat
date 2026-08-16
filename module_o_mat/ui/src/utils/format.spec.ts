import { describe, expect, it } from 'vitest'
import {
  formatBytes,
  formatDate,
  formatEuro,
  formatEuroRange,
  formatHpWidth,
  groupModules,
  priceRangeTitle,
  routeParam,
} from './format'
import type { Module } from '../types'

describe('formatEuro', () => {
  it('formatiert Betraege auf Deutsch', () => {
    expect(formatEuro(12.5)).toBe('12,50 €')
  })

  it('zeigt einen Gedankenstrich fuer leere Werte', () => {
    expect(formatEuro(null)).toBe('—')
    expect(formatEuro('')).toBe('—')
    expect(formatEuro('nope')).toBe('—')
  })
})

describe('formatEuroRange', () => {
  it('nutzt den aktuellen Wert ohne Spanne', () => {
    expect(formatEuroRange(undefined, 10)).toBe('10,00 €')
  })

  it('zeigt eine Spanne, wenn Min und Max verschieden sind', () => {
    expect(
      formatEuroRange({ min: 10, max: 20, count: 2, last_observed_on: '2024-01-02' }, 15),
    ).toBe('10,00 €–20,00 €')
  })

  it('zeigt einen einzelnen Betrag, wenn Min und Max gleich sind', () => {
    expect(
      formatEuroRange({ min: 10, max: 10, count: 1, last_observed_on: '2024-01-02' }, 10),
    ).toBe('10,00 €')
  })
})

describe('priceRangeTitle', () => {
  it('liefert undefined ohne Beobachtungen', () => {
    expect(priceRangeTitle(undefined)).toBeUndefined()
  })

  it('beschreibt Anzahl und Datum', () => {
    expect(
      priceRangeTitle({ min: 1, max: 2, count: 3, last_observed_on: '2024-05-06' }),
    ).toBe('Basierend auf 3 Beobachtung(en), zuletzt 06.05.2024')
  })
})

describe('formatDate', () => {
  it('formatiert ISO-Daten', () => {
    expect(formatDate('2024-12-31')).toBe('31.12.2024')
  })

  it('gibt leere Werte unveraendert zurueck', () => {
    expect(formatDate(null)).toBe('')
    expect(formatDate('n/a')).toBe('n/a')
  })
})

describe('formatHpWidth', () => {
  it('formatiert Zentimeter und Meter', () => {
    expect(
      formatHpWidth({
        count: 2,
        total_hp: 32,
        total_width_mm: 163,
        total_width_cm: 16.3,
        total_width_m: 0.163,
        total_purchase_price: 0,
        total_current_value: 0,
      }),
    ).toBe('16,3 cm / 0,16 m')
  })

  it('liefert einen leeren String ohne Statistik', () => {
    expect(formatHpWidth(null)).toBe('')
  })
})

describe('formatBytes', () => {
  it('formatiert Bytes, Kilobyte und Megabyte', () => {
    expect(formatBytes(512)).toBe('512 B')
    expect(formatBytes(2048)).toBe('2.0 KB')
    expect(formatBytes(1_048_576)).toBe('1.0 MB')
  })

  it('liefert einen leeren String fuer ungueltige Werte', () => {
    expect(formatBytes(Number.NaN)).toBe('')
  })
})

describe('groupModules', () => {
  it('gruppiert nach Typ und sortiert nach Hersteller', () => {
    const modules = [
      { type: 'VCO', manufacturer: 'Mutable Instruments', name: 'Plaits' },
      { type: 'Envelope', manufacturer: 'Doepfer', name: 'A-140' },
      { type: 'VCO', manufacturer: 'Make Noise', name: 'STO' },
    ] as Module[]

    const groups = groupModules(modules)

    expect(groups.map((group) => group.type)).toEqual(['Envelope', 'VCO'])
    expect(groups[1]?.modules.map((module) => module.manufacturer)).toEqual([
      'Make Noise',
      'Mutable Instruments',
    ])
  })
})

describe('routeParam', () => {
  it('nimmt den ersten Wert aus Arrays', () => {
    expect(routeParam(['abc', 'def'])).toBe('abc')
  })

  it('liefert einen leeren String ohne Wert', () => {
    expect(routeParam(undefined)).toBe('')
  })
})
