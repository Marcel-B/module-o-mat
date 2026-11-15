import type { Module, Rack } from '../types'

export type RailKey = 'plus12' | 'minus12' | 'plus5'

export type RailValues = Record<RailKey, number>

export const RAILS: Array<{ key: RailKey; label: string }> = [
  { key: 'plus12', label: '+12 V' },
  { key: 'minus12', label: '−12 V' },
  { key: 'plus5', label: '+5 V' },
]

/** Ab diesem Auslastungsgrad gilt eine Schiene als knapp. */
export const WARN_RATIO = 0.8

type DrawSource = Pick<
  Module,
  'current_draw_plus12v_ma' | 'current_draw_minus12v_ma' | 'current_draw_plus5v_ma'
>

export function zeroRails(): RailValues {
  return { plus12: 0, minus12: 0, plus5: 0 }
}

/** Verbrauch eines Moduls in mA; fehlende Werte zählen als 0. */
export function moduleDraw(module: DrawSource): RailValues {
  return {
    plus12: Math.max(0, module.current_draw_plus12v_ma ?? 0),
    minus12: Math.max(0, module.current_draw_minus12v_ma ?? 0),
    plus5: Math.max(0, module.current_draw_plus5v_ma ?? 0),
  }
}

/** Ein Modul ohne +12 V- und −12 V-Angabe hat keine verwertbaren Verbrauchsdaten. */
export function hasMissingDraw(module: DrawSource): boolean {
  return module.current_draw_plus12v_ma == null && module.current_draw_minus12v_ma == null
}

export function sumDraw(modules: DrawSource[]): RailValues {
  return modules.reduce<RailValues>((total, module) => {
    const draw = moduleDraw(module)
    return {
      plus12: total.plus12 + draw.plus12,
      minus12: total.minus12 + draw.minus12,
      plus5: total.plus5 + draw.plus5,
    }
  }, zeroRails())
}

/**
 * Netzteil-Kapazität in mA. Eine leere Schiene wird nicht geprüft (unendlich);
 * hat das Netzteil eine Schiene nicht, trägt man 0 ein.
 */
export function psuCapacity(rack: Pick<Rack, 'psu_plus12v_ma' | 'psu_minus12v_ma' | 'psu_plus5v_ma'>): RailValues {
  return {
    plus12: rack.psu_plus12v_ma ?? Number.POSITIVE_INFINITY,
    minus12: rack.psu_minus12v_ma ?? Number.POSITIVE_INFINITY,
    plus5: rack.psu_plus5v_ma ?? Number.POSITIVE_INFINITY,
  }
}

export function remaining(capacity: RailValues, used: RailValues): RailValues {
  return {
    plus12: capacity.plus12 - used.plus12,
    minus12: capacity.minus12 - used.minus12,
    plus5: capacity.plus5 - used.plus5,
  }
}

export function overload(capacity: RailValues, used: RailValues): RailValues {
  const left = remaining(capacity, used)
  return {
    plus12: Math.max(0, -left.plus12),
    minus12: Math.max(0, -left.minus12),
    plus5: Math.max(0, -left.plus5),
  }
}

export function isOverloaded(capacity: RailValues, used: RailValues): boolean {
  const over = overload(capacity, used)
  return over.plus12 > 0 || over.minus12 > 0 || over.plus5 > 0
}

/** Passt das Modul noch in die verbleibende Kapazität? */
export function fits(module: DrawSource, left: RailValues): boolean {
  const draw = moduleDraw(module)
  return draw.plus12 <= left.plus12 && draw.minus12 <= left.minus12 && draw.plus5 <= left.plus5
}

export type RailStatus = 'ok' | 'warn' | 'over' | 'none'

export function railStatus(capacity: number, used: number): RailStatus {
  if (!Number.isFinite(capacity)) return 'none'
  if (capacity <= 0) return used > 0 ? 'over' : 'none'
  if (used > capacity) return 'over'
  if (used >= capacity * WARN_RATIO) return 'warn'
  return 'ok'
}

/**
 * Schlägt Module vor, die entfernt werden müssen, damit alle Schienen wieder im Limit liegen.
 * Gierig: Es wird jeweils das Modul gestrichen, das die verbleibende Überlast am stärksten abbaut,
 * danach wird geprüft, ob sich gestrichene Module doch wieder unterbringen lassen.
 * Liefert die IDs der vorgeschlagenen Module (leer, wenn alles passt).
 */
export function suggestRemovals<T extends DrawSource & { id: number }>(
  modules: T[],
  capacity: RailValues,
): number[] {
  let used = sumDraw(modules)
  if (!isOverloaded(capacity, used)) return []

  const kept = [...modules]
  const removed: T[] = []

  while (isOverloaded(capacity, used) && kept.length > 0) {
    const over = overload(capacity, used)
    let bestIndex = -1
    let bestScore = 0
    let bestTotal = 0

    kept.forEach((module, index) => {
      const draw = moduleDraw(module)
      let score = 0
      for (const { key } of RAILS) {
        if (over[key] > 0) score += Math.min(draw[key], over[key]) / over[key]
      }
      const total = draw.plus12 + draw.minus12 + draw.plus5
      if (score > bestScore || (score === bestScore && score > 0 && total > bestTotal)) {
        bestIndex = index
        bestScore = score
        bestTotal = total
      }
    })

    // Keines der übrigen Module verbraucht auf einer überlasteten Schiene Strom.
    if (bestIndex < 0) break

    const [module] = kept.splice(bestIndex, 1)
    removed.push(module!)
    used = sumDraw(kept)
  }

  // Gestrichene Module mit kleinem Verbrauch wieder aufnehmen, falls sie doch noch passen.
  const restoreOrder = [...removed].sort((a, b) => {
    const da = moduleDraw(a)
    const db = moduleDraw(b)
    return da.plus12 + da.minus12 + da.plus5 - (db.plus12 + db.minus12 + db.plus5)
  })
  const finalRemoved = new Set(removed.map((module) => module.id))
  for (const module of restoreOrder) {
    if (fits(module, remaining(capacity, used))) {
      finalRemoved.delete(module.id)
      used = sumDraw([...kept, module])
      kept.push(module)
    }
  }

  return modules.filter((module) => finalRemoved.has(module.id)).map((module) => module.id)
}

/** Ampere-Eingabe (z. B. 1,2 A) in ganze mA umrechnen. */
export function ampsToMilliamps(amps: number | null | undefined): number | null {
  if (amps == null || Number.isNaN(amps)) return null
  return Math.round(amps * 1000)
}

export function milliampsToAmps(ma: number | null | undefined): number | null {
  if (ma == null) return null
  return ma / 1000
}

export function formatMa(ma: number): string {
  return `${ma.toLocaleString('de-DE')} mA`
}
