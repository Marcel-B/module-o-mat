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

function escapeHtml(value) {
  return String(value)
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#39;")
}

function notesLabel(point) {
  const notes = point?.notes
  if (typeof notes === "string" && notes.trim() !== "") return notes.trim()
  return null
}

function renderNotesHtml(point) {
  const label = notesLabel(point)
  if (!label) return ""

  const url = typeof point?.source_url === "string" ? point.source_url.trim() : ""
  const safeLabel = escapeHtml(label)

  if (url) {
    return `<a class="price-history-tooltip__link" href="${escapeHtml(url)}" target="_blank" rel="noopener noreferrer">${safeLabel}</a>`
  }

  return `<span>${safeLabel}</span>`
}

function getOrCreateTooltip(chart) {
  let tooltipEl = chart.canvas.parentNode.querySelector(".price-history-tooltip")

  if (!tooltipEl) {
    tooltipEl = document.createElement("div")
    tooltipEl.className = "price-history-tooltip"
    tooltipEl.style.opacity = "0"
    tooltipEl.style.pointerEvents = "none"
    chart.canvas.parentNode.appendChild(tooltipEl)
  }

  return tooltipEl
}

function externalTooltipHandler(context) {
  const {chart, tooltip} = context
  const tooltipEl = getOrCreateTooltip(chart)

  if (tooltip.opacity === 0) {
    tooltipEl.style.opacity = "0"
    tooltipEl.style.pointerEvents = "none"
    return
  }

  if (tooltip.body) {
    const title = tooltip.title?.[0] || ""
    const lines = tooltip.dataPoints
      .map((item) => {
        const point = item.dataset.pointMeta?.[item.dataIndex]
        const notesHtml = renderNotesHtml(point)
        const amount = formatEuro(item.parsed.y)
        const detail = notesHtml ? `${notesHtml}: ${escapeHtml(amount)}` : escapeHtml(amount)
        return `<div class="price-history-tooltip__row">${detail}</div>`
      })
      .join("")

    tooltipEl.innerHTML = `
      <div class="price-history-tooltip__title">${escapeHtml(title)}</div>
      ${lines}
    `
  }

  const {offsetLeft: positionX, offsetTop: positionY} = chart.canvas

  tooltipEl.style.opacity = "1"
  tooltipEl.style.pointerEvents = "auto"
  tooltipEl.style.left = `${positionX + tooltip.caretX}px`
  tooltipEl.style.top = `${positionY + tooltip.caretY}px`
}

function buildChartConfig(chartData) {
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
          enabled: false,
          external: externalTooltipHandler,
          callbacks: {
            title(items) {
              const item = items[0]
              if (!item) return ""
              return formatDateLabel(item.label)
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
