// Unit tests for Events.js. Run: TZ=America/Sao_Paulo node omarchy/calendar/test_events.js
const assert = require("assert")
const Events = require("./Events.js")

const raw = {
  syncedAt: "2026-09-16T11:50:00-03:00",
  calendars: 1,
  errors: [],
  events: [
    { id: "b", title: "Planning", start: "2026-09-16T14:00:00-03:00", end: "2026-09-16T15:00:00-03:00", allDay: false, link: "https://meet.google.com/abc" },
    { id: "a", title: "Holiday", start: "2026-09-16", end: "2026-09-17", allDay: true },
    { id: "c", title: "Late deploy", start: "2026-09-16T23:30:00-03:00", end: "2026-09-17T00:30:00-03:00", allDay: false },
    { id: "d", title: "Trip", start: "2026-09-18", end: "2026-09-20", allDay: true },
    { title: "broken" }
  ]
}
const events = Events.normalize(raw)
const at = (iso) => new Date(iso).getTime()

assert.deepStrictEqual(events.map((e) => e.id), ["a", "b", "c", "d"], "sorted, malformed dropped, all-day first on ties")
assert.deepStrictEqual(Events.eventsForDay(events, "2026-09-16").map((e) => e.id), ["a", "b", "c"])
assert.deepStrictEqual(Events.eventsForDay(events, "2026-09-17").map((e) => e.id), ["c"], "overnight event shows on the next day")
assert.deepStrictEqual(Events.eventsForDay(events, "2026-09-19").map((e) => e.id), ["d"], "multi-day all-day event")
assert.deepStrictEqual(Events.eventsForDay(events, "2026-09-20").map((e) => e.id), [], "all-day end is exclusive")

const weeks = [{ days: ["2026-09-15", "2026-09-16", "2026-09-17"].map((key) => ({ key })) }]
assert.deepStrictEqual(Events.dayCounts(events, weeks), { "2026-09-16": 3, "2026-09-17": 1 })

assert.strictEqual(Events.barEvent(events, at("2026-09-16T12:00:00-03:00"), 60), null, "nothing within the hour")
const soon = Events.barEvent(events, at("2026-09-16T13:15:00-03:00"), 60)
assert.strictEqual(soon.id, "b")
assert.strictEqual(Events.barLabel(soon, at("2026-09-16T13:15:00-03:00")), "in 45m Planning")
assert.strictEqual(Events.barLabel(Events.barEvent(events, at("2026-09-16T14:10:00-03:00"), 60), at("2026-09-16T14:10:00-03:00")), "now Planning")
assert.strictEqual(Events.barEvent(events, at("2026-09-16T13:15:00-03:00"), 0), null, "0 disables the bar label")

assert.strictEqual(Events.eventUrl(events[1]), "https://meet.google.com/abc")
assert.strictEqual(Events.eventUrl(events[3]), "https://calendar.google.com/calendar/r/day/2026/9/18")

assert.strictEqual(Events.syncStatus(raw, at("2026-09-16T11:55:00-03:00")).text, "Synced 5m ago")
assert.strictEqual(Events.syncStatus({ calendars: 0 }, 0).problem, true)
assert.strictEqual(Events.syncStatus({ calendars: 1, errors: [{ calendar: "Work", message: "HTTP 404" }] }, 0).text, "Work: HTTP 404")

const due = (iso, minutes) => Events.dueNotifications(events, at(iso), minutes).map((e) => e.id)
assert.deepStrictEqual(due("2026-09-16T13:29:00-03:00", 30), [], "31 minutes ahead is too early")
assert.deepStrictEqual(due("2026-09-16T13:30:00-03:00", 30), ["b"], "exactly 30 minutes ahead")
assert.deepStrictEqual(due("2026-09-16T13:50:00-03:00", 30), ["b"], "late start of the shell still announces it")
assert.deepStrictEqual(due("2026-09-16T14:00:00-03:00", 30), [], "not once it has started")
assert.deepStrictEqual(due("2026-09-16T13:30:00-03:00", 0), [], "0 disables notifications")
assert.deepStrictEqual(due("2026-09-15T23:50:00-03:00", 30), [], "all-day events are never announced")
assert.strictEqual(Events.notificationKey({ id: "uid/with spaces@20260916T170000Z", startMs: 5 }), "uid_with_spaces@20260916T170000Z@5")
assert.strictEqual(Events.notificationBody(events[1], at("2026-09-16T13:30:00-03:00"), "14:00–15:00"), "in 30 min · 14:00–15:00 · click to join")

console.log("PASS: Events.js")
