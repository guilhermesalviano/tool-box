// Pure event math for the toolbox.calendar widget and panel. No Qt here, so
// it runs under node (see test.sh). Events come from sync.py's events.json:
//   { title, start, end, allDay, calendar, location, link, id }
// Timed events carry ISO datetimes with an offset; all-day events carry
// "yyyy-MM-dd" dates with an exclusive end, as iCal defines them.

var MINUTE = 60000

function pad2(value) {
  var n = Number(value)
  return (n < 10 ? "0" : "") + n
}

function dateKey(date) {
  return date.getFullYear() + "-" + pad2(date.getMonth() + 1) + "-" + pad2(date.getDate())
}

// Local midnight for a "yyyy-MM-dd" key. Not `new Date(key)`, which is UTC.
function dateFromKey(key) {
  var parts = String(key).split("-")
  return new Date(Number(parts[0]), Number(parts[1]) - 1, Number(parts[2]))
}

// Adds startMs/endMs (local day bounds for all-day events) and drops
// anything malformed, so the QML never has to guard a bad row.
function normalize(raw) {
  var list = raw && Array.isArray(raw.events) ? raw.events : []
  var out = []
  for (var i = 0; i < list.length; i++) {
    var e = list[i]
    if (!e || !e.start) continue
    var startMs = e.allDay ? dateFromKey(e.start).getTime() : new Date(e.start).getTime()
    var endMs = e.allDay ? dateFromKey(e.end || e.start).getTime() : new Date(e.end || e.start).getTime()
    if (!isFinite(startMs)) continue
    if (!isFinite(endMs) || endMs < startMs) endMs = startMs
    if (e.allDay && endMs === startMs) endMs = startMs + 24 * 60 * MINUTE
    out.push({
      id: String(e.id || i),
      title: String(e.title || "(No title)"),
      calendar: String(e.calendar || ""),
      location: String(e.location || ""),
      link: String(e.link || ""),
      allDay: e.allDay === true,
      startMs: startMs,
      endMs: endMs
    })
  }
  out.sort(function(a, b) { return a.startMs - b.startMs || (a.allDay === b.allDay ? 0 : a.allDay ? -1 : 1) })
  return out
}

// Overlap with the local day, so a meeting running past midnight shows on
// both days and a zero-length reminder still shows on its own.
function eventsForDay(events, key) {
  var dayStart = dateFromKey(key).getTime()
  var next = dateFromKey(key)
  next.setDate(next.getDate() + 1)
  var dayEnd = next.getTime()
  var out = []
  for (var i = 0; i < (events || []).length; i++) {
    var e = events[i]
    if (e.startMs < dayEnd && (e.endMs > dayStart || (e.endMs === e.startMs && e.startMs >= dayStart)))
      out.push(e)
  }
  return out
}

// { "yyyy-MM-dd": count } for the days of a month grid, for the dots.
function dayCounts(events, weeks) {
  var counts = {}
  for (var w = 0; w < (weeks || []).length; w++)
    for (var d = 0; d < weeks[w].days.length; d++) {
      var key = weeks[w].days[d].key
      var n = eventsForDay(events, key).length
      if (n > 0) counts[key] = n
    }
  return counts
}

// The timed event worth putting in the bar: one starting within
// `leadMinutes` wins over one already running, and nothing all-day.
function barEvent(events, nowMs, leadMinutes) {
  var lead = Number(leadMinutes)
  if (!isFinite(lead) || lead <= 0) return null
  var ongoing = null
  for (var i = 0; i < (events || []).length; i++) {
    var e = events[i]
    if (e.allDay || e.endMs <= nowMs) continue
    if (e.startMs > nowMs && e.startMs - nowMs <= lead * MINUTE) return e
    if (e.startMs <= nowMs && !ongoing) ongoing = e
  }
  return ongoing
}

function truncate(text, max) {
  var value = String(text || "")
  return value.length > max ? value.substring(0, max - 1) + "…" : value
}

function barLabel(event, nowMs) {
  if (!event) return ""
  var title = truncate(event.title, 24)
  if (event.startMs <= nowMs) return "now " + title
  var minutes = Math.max(1, Math.ceil((event.startMs - nowMs) / MINUTE))
  return "in " + minutes + "m " + title
}

// Where a click on an event goes: its meeting link, else that day in Google
// Calendar (the iCal feed carries no per-event page).
function eventUrl(event) {
  if (event && /^https:\/\//.test(event.link)) return event.link
  var day = new Date(event ? event.startMs : Date.now())
  return "https://calendar.google.com/calendar/r/day/" + day.getFullYear() + "/" + (day.getMonth() + 1) + "/" + day.getDate()
}

// Timed events starting within `minutes` that have not started yet. Callers
// dedupe by notificationKey, so an event is announced once even though this
// is asked every minute, and an event that moves is announced again.
function dueNotifications(events, nowMs, minutes) {
  var lead = Number(minutes)
  if (!isFinite(lead) || lead <= 0) return []
  var out = []
  for (var i = 0; i < (events || []).length; i++) {
    var e = events[i]
    if (!e.allDay && e.startMs > nowMs && e.startMs - nowMs <= lead * MINUTE) out.push(e)
  }
  return out
}

// Filesystem-safe and stable for one occurrence at one start time.
function notificationKey(event) {
  return (String(event.id) + "@" + event.startMs).replace(/[^A-Za-z0-9@._-]/g, "_").substring(0, 200)
}

function notificationBody(event, nowMs, timeText) {
  var minutes = Math.max(1, Math.round((event.startMs - nowMs) / MINUTE))
  var parts = ["in " + minutes + " min", timeText]
  if (event.calendar) parts.push(event.calendar)
  if (event.link) parts.push("click to join")
  else if (event.location) parts.push(event.location)
  return parts.join(" · ")
}

// "Synced 5m ago", or why nothing is showing.
function syncStatus(raw, nowMs) {
  if (!raw) return { text: "Not synced yet", problem: false }
  if (Number(raw.calendars) === 0) return { text: "No calendars yet — run: toolbox calendar add", problem: true }
  var errors = Array.isArray(raw.errors) ? raw.errors : []
  if (errors.length > 0)
    return { text: errors[0].calendar + ": " + errors[0].message, problem: true }
  var synced = new Date(raw.syncedAt).getTime()
  if (!isFinite(synced)) return { text: "Not synced yet", problem: false }
  var minutes = Math.floor((nowMs - synced) / MINUTE)
  if (minutes > 60) return { text: "Last synced " + Math.floor(minutes / 60) + "h ago", problem: true }
  return { text: minutes < 1 ? "Synced just now" : "Synced " + minutes + "m ago", problem: false }
}

if (typeof module !== "undefined") {
  module.exports = {
    dateKey: dateKey,
    normalize: normalize,
    eventsForDay: eventsForDay,
    dayCounts: dayCounts,
    barEvent: barEvent,
    barLabel: barLabel,
    eventUrl: eventUrl,
    dueNotifications: dueNotifications,
    notificationKey: notificationKey,
    notificationBody: notificationBody,
    syncStatus: syncStatus
  }
}
