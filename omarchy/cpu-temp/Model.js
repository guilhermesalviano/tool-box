// Pure temperature logic for the toolbox.cpu-temp widget. No Qt here, so it
// runs under node (see test.sh). Input is sensors.sh's output:
//   { source, sensors: [{ label, path, celsius, max, crit }] }

// Thermometer glyphs from empty to full (Font Awesome, in every Nerd Font).
var GLYPHS = ["", "", "", "", ""]

// The sensor that stands for the whole CPU: the package/die reading when the
// driver has one, otherwise the hottest core.
function primaryIndex(sensors) {
  var preferred = [/^package id/i, /^tdie$/i, /^tctl$/i, /^cpu/i, /^x86_pkg_temp$/]
  for (var p = 0; p < preferred.length; p++) {
    for (var i = 0; i < sensors.length; i++) {
      if (preferred[p].test(sensors[i].label)) return i
    }
  }
  var hottest = -1
  for (var j = 0; j < sensors.length; j++) {
    if (hottest < 0 || sensors[j].celsius > sensors[hottest].celsius) hottest = j
  }
  return hottest
}

function normalize(snapshot) {
  var sensors = []
  var raw = snapshot && Array.isArray(snapshot.sensors) ? snapshot.sensors : []
  for (var i = 0; i < raw.length; i++) {
    var s = raw[i]
    if (!s || typeof s.celsius !== "number" || !isFinite(s.celsius)) continue
    sensors.push({
      label: String(s.label || "CPU"),
      path: String(s.path || ""),
      celsius: s.celsius,
      max: typeof s.max === "number" && s.max > 0 ? s.max : null,
      crit: typeof s.crit === "number" && s.crit > 0 ? s.crit : null
    })
  }
  var index = primaryIndex(sensors)
  var primary = index >= 0 ? sensors[index] : null
  return {
    available: primary !== null,
    source: snapshot && snapshot.source ? String(snapshot.source) : "",
    primary: primary,
    others: sensors.filter(function(s, k) { return k !== index })
  }
}

// A sysfs temp*_input reads in millidegrees; anything else is unreadable.
function parseMillis(text) {
  var value = String(text === undefined || text === null ? "" : text).trim()
  if (!/^-?\d+$/.test(value)) return null
  return parseInt(value, 10) / 1000
}

// The ceiling the thermometer fills up to: the sensor's critical limit, else
// its max, else 100 °C.
function ceiling(sensor) {
  if (sensor && sensor.crit) return sensor.crit
  if (sensor && sensor.max) return sensor.max
  return 100
}

function glyph(celsius, top) {
  var fraction = (celsius - 30) / Math.max(1, (top || 100) - 30)
  var step = Math.round(Math.max(0, Math.min(1, fraction)) * (GLYPHS.length - 1))
  return GLYPHS[step]
}

function degrees(celsius) {
  return Math.round(celsius) + "°"
}

function isHot(celsius, alertAt) {
  return typeof celsius === "number" && alertAt > 0 && celsius >= alertAt
}

function barText(celsius, top, vertical) {
  if (typeof celsius !== "number") return ""
  if (vertical) return degrees(celsius)
  return glyph(celsius, top) + " " + degrees(celsius)
}

function summary(model, celsius) {
  if (!model.available) return "No CPU temperature sensor found"
  var parts = ["CPU " + degrees(celsius !== undefined && celsius !== null ? celsius : model.primary.celsius)]
  if (model.primary.crit) parts.push("critical at " + degrees(model.primary.crit))
  return parts.join(" · ")
}

if (typeof module !== "undefined") {
  module.exports = {
    normalize: normalize,
    parseMillis: parseMillis,
    ceiling: ceiling,
    glyph: glyph,
    degrees: degrees,
    isHot: isHot,
    barText: barText,
    summary: summary
  }
}
