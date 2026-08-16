import { describe, expect, it } from 'vitest'
import { buildPriceChartData, chartJsConfig } from './priceChart'
import type { PriceObservation } from '../types'

function observation(overrides: Partial<PriceObservation>): PriceObservation {
  return {
    id: 1,
    amount: 100,
    currency: 'EUR',
    source: 'Schneider',
    source_url: null,
    observed_on: '2024-01-01',
    notes: null,
    ...overrides,
  }
}

describe('buildPriceChartData', () => {
  it('sortiert nach Datum und gruppiert nach Quelle', () => {
    const data = buildPriceChartData([
      observation({ id: 2, source: 'eBay', amount: 120, observed_on: '2024-02-01' }),
      observation({ id: 1, source: 'Schneider', amount: 100, observed_on: '2024-01-01' }),
      observation({ id: 3, source: 'eBay', amount: 110, observed_on: '2024-01-15' }),
    ])

    expect(data.labels).toEqual(['2024-01-01', '2024-01-15', '2024-02-01'])
    expect(data.datasets.map((dataset) => dataset.source)).toEqual(['eBay', 'Schneider'])
    expect(data.datasets[0]?.points.map((point) => point.y)).toEqual([110, 120])
  })
})

describe('chartJsConfig', () => {
  it('fuellt Luecken mit null und spanGaps', () => {
    const config = chartJsConfig(
      buildPriceChartData([
        observation({ source: 'A', amount: 10, observed_on: '2024-01-01' }),
        observation({ source: 'A', amount: 30, observed_on: '2024-01-03' }),
        observation({ source: 'B', amount: 20, observed_on: '2024-01-02' }),
      ]),
    )

    expect(config.labels).toEqual(['2024-01-01', '2024-01-02', '2024-01-03'])
    expect(config.datasets[0]?.data).toEqual([10, null, 30])
    expect(config.datasets[0]?.spanGaps).toBe(true)
  })
})
