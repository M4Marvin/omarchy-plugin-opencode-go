.pragma library

var ROLLING_MS = 5 * 60 * 60 * 1000
var WEEK_MS = 7 * 24 * 60 * 60 * 1000
var MONTHLY_MS = 30 * 24 * 60 * 60 * 1000

function number(value, fallback) {
  var parsed = Number(value)
  return isFinite(parsed) ? parsed : fallback
}

function clamp(value, minimum, maximum) {
  return Math.max(minimum, Math.min(maximum, value))
}

function windowMs(kind) {
  if (kind === "rolling") return ROLLING_MS
  if (kind === "monthly") return MONTHLY_MS
  return WEEK_MS
}

// The three limit windows the collector reports, in the order the panel lists
// them. `tag` is the compact form the bar uses; `dollars` is the plan limit the
// window is measured against when the API omits one.
var WINDOWS = [
  { key: "rolling", label: "5h", tag: "5h", dollars: 12 },
  { key: "weekly", label: "Weekly", tag: "Wk", dollars: 30 },
  { key: "monthly", label: "Monthly", tag: "Mo", dollars: 60 }
]

// Values of the `barWindow` setting, mapped to the window they select.
// "Highest" is not a window — it tracks whichever one is furthest along.
var BAR_WINDOW_CHOICES = {
  "5-hour": "rolling",
  "Weekly": "weekly",
  "Monthly": "monthly",
  "Highest": "highest"
}

function windowSpec(key) {
  for (var i = 0; i < WINDOWS.length; i++) if (WINDOWS[i].key === key) return WINDOWS[i]
  return WINDOWS[1]
}

function barWindowKey(choice) {
  return BAR_WINDOW_CHOICES[String(choice || "")] || "weekly"
}

// Resolves the window the bar label should show, as {key, spec, window}, or
// null when the account has no usable data for it yet.
function barWindow(account, choice, nowMs) {
  if (!account) return null
  var key = barWindowKey(choice)
  if (key !== "highest") {
    var single = normalizeWindow(account[key], key, nowMs)
    return single ? { key: key, spec: windowSpec(key), window: single } : null
  }
  var best = null
  for (var i = 0; i < WINDOWS.length; i++) {
    var spec = WINDOWS[i]
    var w = normalizeWindow(account[spec.key], spec.key, nowMs)
    if (w && (!best || w.percent > best.window.percent)) best = { key: spec.key, spec: spec, window: w }
  }
  return best
}

// window: raw collector window {status, percent(0-100), resetsAt}; kind: "rolling"|"weekly"|"monthly"
function normalizeWindow(window, kind, nowMs) {
  if (!window) return null
  var percent = clamp(number(window.percent, 0) / 100, 0, 1)
  var resetMs = Date.parse(String(window.resetsAt || ""))
  if (!isFinite(resetMs)) resetMs = 0
  return {
    kind: String(kind || "weekly"),
    percent: percent,
    remaining: 1 - percent,
    resetMs: resetMs,
    limitDollars: number(window.limitDollars, 0)
  }
}

function expectedRemaining(window, nowMs) {
  if (!window || window.resetMs <= 0) return 0
  return clamp((window.resetMs - nowMs) / windowMs(window.kind), 0, 1)
}

// Share of the window's budget an even spender would have used by now.
function expectedUsed(window, nowMs) {
  return 1 - expectedRemaining(window, nowMs)
}

function behindPace(window, nowMs) {
  if (!window || window.resetMs <= 0) return false
  return window.remaining + 0.0005 < expectedRemaining(window, nowMs)
}

function paceDifference(window, nowMs) {
  if (!window) return 0
  return window.remaining - expectedRemaining(window, nowMs)
}

function paceText(window, nowMs) {
  if (!window || window.resetMs <= 0) return ""
  var points = Math.round(Math.abs(paceDifference(window, nowMs)) * 100)
  if (points === 0) return "on pace"
  return points + "% " + (behindPace(window, nowMs) ? "behind" : "ahead")
}

function resetText(window, nowMs) {
  if (!window || window.resetMs <= 0) return ""
  if (window.resetMs <= nowMs) return "resetting now"
  return "resets in " + countdown(window.resetMs, nowMs)
}

function parseCollector(text) {
  try {
    var parsed = JSON.parse(String(text || ""))
    if (!parsed || typeof parsed !== "object" || parsed.label !== "Go" || typeof parsed.status !== "string") {
      return { ok: false, error: "Could not parse OpenCode Go usage" }
    }
    var account = {
      label: "Go",
      active: true,
      status: parsed.status,
      rolling: parsed.rolling || null,
      weekly: parsed.weekly || null,
      monthly: parsed.monthly || null
    }
    return {
      ok: true,
      data: {
        account: account,
        recentDays: Array.isArray(parsed.recentDays) ? parsed.recentDays : [],
        updatedAt: String(parsed.updatedAt || ""),
        error: String(parsed.error || "")
      }
    }
  } catch (error) {
    return { ok: false, error: "Could not parse OpenCode Go usage" }
  }
}

function percent(value) {
  return Math.round(clamp(number(value, 0), 0, 1) * 100) + "%"
}

function countdown(resetMs, nowMs) {
  if (!resetMs || resetMs <= nowMs) return "now"
  var minutes = Math.max(0, Math.floor((resetMs - nowMs) / 60000))
  var days = Math.floor(minutes / 1440)
  var hours = Math.floor((minutes % 1440) / 60)
  var mins = minutes % 60
  if (days > 0) return days + "d " + hours + "h"
  if (hours > 0) return hours + "h " + mins + "m"
  return mins + "m"
}

function tokenCount(value) {
  var amount = Math.max(0, number(value, 0))
  if (amount >= 1000000) return (amount / 1000000).toFixed(amount >= 100000000 ? 0 : 1).replace(/\.0$/, "") + "M"
  if (amount >= 1000) return (amount / 1000).toFixed(amount >= 100000 ? 0 : 1).replace(/\.0$/, "") + "K"
  return String(Math.round(amount))
}

function dayTokens(day) {
  return Math.max(0, number(day && day.tokens, 0))
}

function dayCost(day) {
  return Math.max(0, number(day && day.cost, 0))
}

function money(value) {
  var amount = Math.max(0, number(value, 0))
  if (amount >= 100) return "$" + Math.round(amount)
  if (amount >= 10) return "$" + amount.toFixed(1).replace(/\.0$/, "")
  return "$" + amount.toFixed(2)
}

function dateKey(ms) {
  var date = new Date(ms)
  function pad(value) { return (value < 10 ? "0" : "") + value }
  return date.getFullYear() + "-" + pad(date.getMonth() + 1) + "-" + pad(date.getDate())
}

function isToday(day, nowMs) {
  return !!day && String(day.date || "") === dateKey(nowMs)
}

function recentTotal(days) {
  var list = Array.isArray(days) ? days : []
  var total = 0
  for (var i = 0; i < list.length; i++) total += dayTokens(list[i])
  return total
}

function recentCostTotal(days) {
  var list = Array.isArray(days) ? days : []
  var total = 0
  for (var i = 0; i < list.length; i++) total += dayCost(list[i])
  return total
}

function recentPeak(days) {
  var list = Array.isArray(days) ? days : []
  var peak = 0
  for (var i = 0; i < list.length; i++) peak = Math.max(peak, dayTokens(list[i]))
  return peak
}

function dayLabel(value) {
  var match = /^(\d{4})-(\d{2})-(\d{2})$/.exec(String(value || ""))
  if (!match) return "—"
  var date = new Date(Number(match[1]), Number(match[2]) - 1, Number(match[3]))
  return ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"][date.getDay()]
}

var exportsObject = {
  ROLLING_MS: ROLLING_MS,
  WEEK_MS: WEEK_MS,
  MONTHLY_MS: MONTHLY_MS,
  WINDOWS: WINDOWS,
  BAR_WINDOW_CHOICES: BAR_WINDOW_CHOICES,
  windowMs: windowMs,
  windowSpec: windowSpec,
  barWindowKey: barWindowKey,
  barWindow: barWindow,
  normalizeWindow: normalizeWindow,
  expectedRemaining: expectedRemaining,
  expectedUsed: expectedUsed,
  behindPace: behindPace,
  paceDifference: paceDifference,
  paceText: paceText,
  resetText: resetText,
  parseCollector: parseCollector,
  percent: percent,
  countdown: countdown,
  tokenCount: tokenCount,
  dayTokens: dayTokens,
  dayCost: dayCost,
  money: money,
  dateKey: dateKey,
  isToday: isToday,
  recentTotal: recentTotal,
  recentCostTotal: recentCostTotal,
  recentPeak: recentPeak,
  dayLabel: dayLabel
}

if (typeof module !== "undefined" && module.exports) module.exports = exportsObject
