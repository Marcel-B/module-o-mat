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

const HIDE_DELAY_MS = 180

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

function clamp(value, min, max) {
  return Math.min(Math.max(value, min), max)
}

function getOrCreateTooltip() {
  let tooltipEl = document.body.querySelector(".price-history-tooltip")

  if (!tooltipEl) {
    tooltipEl = document.createElement("div")
    tooltipEl.className = "price-history-tooltip"
    tooltipEl.hidden = true
    document.body.appendChild(tooltipEl)

    tooltipEl.addEventListener("mouseenter", () => {
      clearTimeout(tooltipEl._hideTimer)
      tooltipEl._hovered = true
    })

    tooltipEl.addEventListener("mouseleave", () => {
      tooltipEl._hovered = false
      scheduleHide(tooltipEl)
    })
  }

  return tooltipEl
}

function scheduleHide(tooltipEl) {
  clearTimeout(tooltipEl._hideTimer)
  tooltipEl._hideTimer = setTimeout(() => {
    if (tooltipEl._hovered) return
    tooltipEl.hidden = true
    tooltipEl.style.opacity = "0"
  }, HIDE_DELAY_MS)
}

function positionTooltip(tooltipEl, caretX, caretY) {
  const margin = 12
  const width = tooltipEl.offsetWidth || 160
  const height = tooltipEl.offsetHeight || 64
  const maxLeft = window.innerWidth - width - margin
  const maxTop = window.innerHeight - height - margin

  // Prefer above the point; if clipped, flip below.
  let left = caretX - width / 2
  let top = caretY - height - margin

  if (top < margin) {
    top = caretY + margin
  }

  left = clamp(left, margin, Math.max(margin, maxLeft))
  top = clamp(top, margin, Math.max(margin, maxTop))

  tooltipEl.style.left = `${left}px`
  tooltipEl.style.top = `${top}px`
}

function externalTooltipHandler(context) {
  const {chart, tooltip} = context
  const tooltipEl = getOrCreateTooltip()

  if (tooltip.opacity === 0) {
    scheduleHide(tooltipEl)
    return
  }

  clearTimeout(tooltipEl._hideTimer)

  if (tooltip.body) {
    const title = tooltip.title?.[0] || ""
    const lines = tooltip.dataPoints
      .map((item) => {
        const point = item.dataset.pointMeta?.[item.dataIndex]
        const notesHtml = renderNotesHtml(point)
        const amount = formatEuro(item.parsed.y)
        const detail = notesHtml
          ? `<div class="price-history-tooltip__notes">${notesHtml}</div><div class="price-history-tooltip__amount">${escapeHtml(amount)}</div>`
          : `<div class="price-history-tooltip__amount">${escapeHtml(amount)}</div>`
        return `<div class="price-history-tooltip__row">${detail}</div>`
      })
      .join("")

    tooltipEl.innerHTML = `
      <div class="price-history-tooltip__title">${escapeHtml(title)}</div>
      ${lines}
    `
  }

  const canvasRect = chart.canvas.getBoundingClientRect()
  const caretX = canvasRect.left + tooltip.caretX
  const caretY = canvasRect.top + tooltip.caretY

  tooltipEl.hidden = false
  tooltipEl.style.opacity = "1"
  positionTooltip(tooltipEl, caretX, caretY)
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

    const tooltipEl = document.body.querySelector(".price-history-tooltip")
    if (tooltipEl) {
      clearTimeout(tooltipEl._hideTimer)
      tooltipEl.remove()
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
