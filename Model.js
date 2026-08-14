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

function behindPace(window, nowMs) {
  if (!window || window.resetMs <= 0) return false
  return window.remaining + 0.0005 < expectedRemaining(window, nowMs)
}

function paceDifference(window, nowMs) {
  if (!window) return 0
  return window.remaining - expectedRemaining(window, nowMs)
}

function paceText(window, nowMs) {
  if (!window) return "No limit"
  var points = Math.round(Math.abs(paceDifference(window, nowMs)) * 100)
  if (points === 0) return "On pace"
  return points + "% " + (behindPace(window, nowMs) ? "behind pace" : "ahead of pace")
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

function recentTotal(days) {
  var list = Array.isArray(days) ? days : []
  var total = 0
  for (var i = 0; i < list.length; i++) total += dayTokens(list[i])
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
  windowMs: windowMs,
  normalizeWindow: normalizeWindow,
  expectedRemaining: expectedRemaining,
  behindPace: behindPace,
  paceDifference: paceDifference,
  paceText: paceText,
  parseCollector: parseCollector,
  percent: percent,
  countdown: countdown,
  tokenCount: tokenCount,
  dayTokens: dayTokens,
  recentTotal: recentTotal,
  recentPeak: recentPeak,
  dayLabel: dayLabel
}

if (typeof module !== "undefined" && module.exports) module.exports = exportsObject
