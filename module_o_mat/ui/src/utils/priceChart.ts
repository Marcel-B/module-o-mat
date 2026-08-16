import type { PriceObservation } from '../types'

const SOURCE_COLORS = [
  '#0f766e',
  '#b45309',
  '#1d4ed8',
  '#be123c',
  '#7c3aed',
  '#047857',
  '#c2410c',
  '#0369a1',
]

export type PriceChartPoint = {
  x: string
  y: number
  source: string
  notes: string | null
  source_url: string | null
}

export type PriceChartDataset = {
  source: string
  points: PriceChartPoint[]
}

export type PriceChartData = {
  labels: string[]
  datasets: PriceChartDataset[]
}

export type ChartJsDataset = {
  label: string
  data: Array<number | null>
  pointMeta: Array<PriceChartPoint | null>
  borderColor: string
  backgroundColor: string
  pointBackgroundColor: string
  pointBorderColor: string
  spanGaps: boolean
  tension: number
  pointRadius: number
  pointHoverRadius: number
  borderWidth: number
}

function colorForSource(source: string): string {
  let hash = 0
  const text = String(source || '')
  for (let i = 0; i < text.length; i += 1) {
    hash = (hash * 31 + text.charCodeAt(i)) >>> 0
  }
  return SOURCE_COLORS[hash % SOURCE_COLORS.length] ?? SOURCE_COLORS[0]
}

export function buildPriceChartData(observations: PriceObservation[] = []): PriceChartData {
  const sorted = [...observations].sort((a, b) => {
    const dateCmp = String(a.observed_on).localeCompare(String(b.observed_on))
    if (dateCmp !== 0) return dateCmp
    return (a.id || 0) - (b.id || 0)
  })

  const labels = [...new Set(sorted.map((item) => item.observed_on))]
  const bySource = new Map<string, PriceChartPoint[]>()

  for (const observation of sorted) {
    const source = observation.source || 'Unbekannt'
    const points = bySource.get(source) ?? []
    points.push({
      x: observation.observed_on,
      y: Number(observation.amount),
      source,
      notes: observation.notes,
      source_url: observation.source_url,
    })
    bySource.set(source, points)
  }

  const datasets = [...bySource.entries()]
    .sort(([left], [right]) => left.localeCompare(right, 'de'))
    .map(([source, points]) => ({ source, points }))

  return { labels, datasets }
}

export function chartJsConfig(chartData: PriceChartData): {
  labels: string[]
  datasets: ChartJsDataset[]
} {
  const labels = chartData.labels || []
  const datasets = (chartData.datasets || []).map((dataset) => {
    const color = colorForSource(dataset.source)
    const byDate = new Map((dataset.points || []).map((point) => [point.x, point]))
    const pointMeta = labels.map((label) => byDate.get(label) || null)

    return {
      label: dataset.source,
      data: pointMeta.map((point) => (point ? point.y : null)),
      pointMeta,
      borderColor: color,
      backgroundColor: color,
      pointBackgroundColor: color,
      pointBorderColor: color,
      spanGaps: true,
      tension: 0.2,
      pointRadius: 4,
      pointHoverRadius: 6,
      borderWidth: 2,
    }
  })

  return { labels, datasets }
}
