import type { InventoryStats, Module, ModuleGroup, PriceRange } from '../types'

const euroFormatter = new Intl.NumberFormat('de-DE', {
  style: 'currency',
  currency: 'EUR',
})

export function formatEuro(value: number | string | null | undefined): string {
  if (value == null || value === '') return '—'
  const amount = Number(value)
  if (Number.isNaN(amount)) return '—'
  return euroFormatter.format(amount)
}

export function formatEuroRange(
  range: PriceRange | undefined,
  currentValue: number | null | undefined,
): string {
  if (!range || range.min == null || range.max == null) {
    return formatEuro(currentValue)
  }

  if (Number(range.min) === Number(range.max)) {
    return formatEuro(range.min)
  }

  return `${formatEuro(range.min).replace(' €', '')}–${formatEuro(range.max)}`
}

export function priceRangeTitle(range: PriceRange | undefined): string | undefined {
  if (!range?.count || !range.last_observed_on) return undefined
  return `Basierend auf ${range.count} Beobachtung(en), zuletzt ${formatDate(range.last_observed_on)}`
}

export function formatDate(isoDate: string | null | undefined): string {
  if (!isoDate) return ''
  const [year, month, day] = String(isoDate).slice(0, 10).split('-')
  if (!year || !month || !day) return String(isoDate)
  return `${day}.${month}.${year}`
}

export function formatDateTime(isoDate: string | null | undefined): string {
  if (!isoDate) return '—'
  const date = new Date(isoDate)
  if (Number.isNaN(date.getTime())) return String(isoDate)
  return date.toLocaleString('de-DE', {
    day: '2-digit',
    month: '2-digit',
    year: 'numeric',
    hour: '2-digit',
    minute: '2-digit',
  })
}

export function formatHpWidth(stats: InventoryStats | null | undefined): string {
  if (!stats) return ''
  const cm = Number(stats.total_width_cm ?? 0).toLocaleString('de-DE', {
    minimumFractionDigits: 1,
    maximumFractionDigits: 1,
  })
  const meters = Number(stats.total_width_m ?? 0).toLocaleString('de-DE', {
    minimumFractionDigits: 2,
    maximumFractionDigits: 2,
  })
  return `${cm} cm / ${meters} m`
}

export function formatBytes(bytes: number | null | undefined): string {
  if (!Number.isFinite(bytes)) return ''
  if ((bytes as number) < 1024) return `${bytes} B`
  if ((bytes as number) < 1_048_576) return `${((bytes as number) / 1024).toFixed(1)} KB`
  return `${((bytes as number) / 1_048_576).toFixed(1)} MB`
}

export function groupModules(modules: Module[]): ModuleGroup[] {
  const sorted = [...modules].sort((a, b) => {
    const typeCmp = String(a.type || '').localeCompare(String(b.type || ''), 'de')
    if (typeCmp !== 0) return typeCmp
    return String(a.manufacturer || '').localeCompare(String(b.manufacturer || ''), 'de', {
      sensitivity: 'base',
    })
  })

  const groups: ModuleGroup[] = []
  for (const module of sorted) {
    const last = groups.at(-1)
    if (last && last.type === module.type) {
      last.modules.push(module)
    } else {
      groups.push({ type: module.type, modules: [module] })
    }
  }

  return groups
}

export function routeParam(value: string | string[] | undefined): string {
  if (Array.isArray(value)) return value[0] ?? ''
  return value ?? ''
}
