import { describe, expect, it } from 'vitest'
import {
  ampsToMilliamps,
  fits,
  hasMissingDraw,
  milliampsToAmps,
  psuCapacity,
  railStatus,
  remaining,
  suggestRemovals,
  sumDraw,
} from './power'

function mod(id: number, plus12: number | null, minus12: number | null, plus5: number | null = null) {
  return {
    id,
    current_draw_plus12v_ma: plus12,
    current_draw_minus12v_ma: minus12,
    current_draw_plus5v_ma: plus5,
  }
}

describe('power', () => {
  it('summiert den Verbrauch und zählt fehlende Werte als 0', () => {
    expect(sumDraw([mod(1, 100, 20, 5), mod(2, 50, null), mod(3, null, null)])).toEqual({
      plus12: 150,
      minus12: 20,
      plus5: 5,
    })
  })

  it('erkennt Module ohne Verbrauchsangabe', () => {
    expect(hasMissingDraw(mod(1, null, null, 30))).toBe(true)
    expect(hasMissingDraw(mod(1, 0, null))).toBe(false)
  })

  it('rechnet Ampere in mA um', () => {
    expect(ampsToMilliamps(1.2)).toBe(1200)
    expect(ampsToMilliamps(0.25)).toBe(250)
    expect(ampsToMilliamps(null)).toBeNull()
    expect(milliampsToAmps(1500)).toBe(1.5)
  })

  it('prüft leere Netzteil-Schienen nicht, 0 mA aber schon', () => {
    const open = psuCapacity({ psu_plus12v_ma: 1000, psu_minus12v_ma: 500, psu_plus5v_ma: null })
    expect(open.plus5).toBe(Number.POSITIVE_INFINITY)
    expect(fits(mod(1, 10, 10, 1), open)).toBe(true)
    expect(railStatus(open.plus5, 50)).toBe('none')

    const none = psuCapacity({ psu_plus12v_ma: 1000, psu_minus12v_ma: 500, psu_plus5v_ma: 0 })
    expect(fits(mod(1, 10, 10, 1), none)).toBe(false)
    expect(fits(mod(1, 10, 10), none)).toBe(true)
  })

  it('bewertet die Auslastung je Schiene', () => {
    expect(railStatus(1000, 500)).toBe('ok')
    expect(railStatus(1000, 800)).toBe('warn')
    expect(railStatus(1000, 1001)).toBe('over')
    expect(railStatus(0, 0)).toBe('none')
    expect(railStatus(0, 5)).toBe('over')
  })

  it('schlägt nichts vor, solange alles passt', () => {
    expect(suggestRemovals([mod(1, 100, 50)], { plus12: 200, minus12: 100, plus5: 0 })).toEqual([])
  })

  it('streicht das Modul, das die Überlast am stärksten abbaut', () => {
    const modules = [mod(1, 100, 10), mod(2, 400, 50), mod(3, 120, 10)]
    // 620 mA bei 500 mA Kapazität: Modul 2 allein reicht.
    expect(suggestRemovals(modules, { plus12: 500, minus12: 500, plus5: 0 })).toEqual([2])
  })

  it('berücksichtigt mehrere überlastete Schienen und nimmt kleine Module wieder auf', () => {
    const modules = [mod(1, 300, 10), mod(2, 50, 200), mod(3, 300, 150), mod(4, 20, 20)]
    const capacity = { plus12: 500, minus12: 250, plus5: 0 }
    const removed = suggestRemovals(modules, capacity)
    expect(removed).toEqual([3])
    const kept = modules.filter((m) => !removed.includes(m.id))
    const left = remaining(capacity, sumDraw(kept))
    expect(left.plus12).toBeGreaterThanOrEqual(0)
    expect(left.minus12).toBeGreaterThanOrEqual(0)
  })
})
