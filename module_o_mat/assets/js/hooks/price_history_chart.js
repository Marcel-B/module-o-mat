import ChartModule from "../../vendor/chart.umd.js"

const Chart = ChartModule.Chart || ChartModule

const SOURCE_COLORS = [
  "#0f766e",
  "#b45309",
  "#1d4ed8",
  "#be123c",
  "#7c3aed",
  "#047857",
  "#c2410c",
  "#0369a1",
]

function colorForSource(source) {
  let hash = 0
  const text = String(source || "")

  for (let i = 0; i < text.length; i++) {
    hash = (hash * 31 + text.charCodeAt(i)) >>> 0
  }

  return SOURCE_COLORS[hash % SOURCE_COLORS.length]
}

function formatEuro(value) {
  return new Intl.NumberFormat("de-DE", {
    style: "currency",
    currency: "EUR",
  }).format(value)
}

function formatDateLabel(isoDate) {
  const [year, month, day] = String(isoDate).split("-")
  if (!year || !month || !day) return isoDate
  return `${day}.${month}.${year}`
}

function buildChartConfig(chartData) {
  const labels = chartData.labels || []
  const datasets = (chartData.datasets || []).map((dataset) => {
    const color = colorForSource(dataset.source)
    const byDate = new Map((dataset.points || []).map((point) => [point.x, point.y]))

    return {
      label: dataset.source,
      data: labels.map((label) => (byDate.has(label) ? byDate.get(label) : null)),
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

  return {
    type: "line",
    data: {labels, datasets},
    options: {
      responsive: true,
      maintainAspectRatio: false,
      interaction: {
        mode: "nearest",
        intersect: false,
      },
      plugins: {
        legend: {
          display: true,
          position: "bottom",
        },
        tooltip: {
          callbacks: {
            title(items) {
              const item = items[0]
              if (!item) return ""
              return formatDateLabel(item.label)
            },
            label(item) {
              const source = item.dataset.label || "Quelle"
              const amount = formatEuro(item.parsed.y)
              return `${source}: ${amount}`
            },
          },
        },
      },
      scales: {
        x: {
          title: {
            display: true,
            text: "Datum",
          },
          ticks: {
            callback(value) {
              const label = this.getLabelForValue(value)
              return formatDateLabel(label)
            },
          },
        },
        y: {
          beginAtZero: false,
          title: {
            display: true,
            text: "Preis (EUR)",
          },
          ticks: {
            callback(value) {
              return formatEuro(value)
            },
          },
        },
      },
    },
  }
}

const PriceHistoryChart = {
  mounted() {
    this.chart = null
    this.renderChart()
  },

  updated() {
    this.renderChart()
  },

  destroyed() {
    if (this.chart) {
      this.chart.destroy()
      this.chart = null
    }
  },

  renderChart() {
    const raw = this.el.dataset.chart
    if (!raw) return

    let chartData
    try {
      chartData = JSON.parse(raw)
    } catch (_error) {
      return
    }

    const canvas = this.el.querySelector("canvas")
    if (!canvas) return

    if (this.chart) {
      this.chart.destroy()
      this.chart = null
    }

    this.chart = new Chart(canvas, buildChartConfig(chartData))
  },
}

export default PriceHistoryChart
