// Unit tests for Model.js. Run: node omarchy/cpu-temp/test_model.js
const assert = require("assert")
const Model = require("./Model.js")

const intel = {
  source: "coretemp",
  sensors: [
    { label: "Core 0", path: "/h/temp2_input", celsius: 61, max: 100, crit: 100 },
    { label: "Package id 0", path: "/h/temp1_input", celsius: 64, max: 100, crit: 100 },
    { label: "Core 1", path: "/h/temp3_input", celsius: 66, max: 100, crit: 100 }
  ]
}
let m = Model.normalize(intel)
assert.strictEqual(m.available, true)
assert.strictEqual(m.primary.label, "Package id 0")
assert.deepStrictEqual(m.others.map((s) => s.label), ["Core 0", "Core 1"])

// AMD: Tctl stands for the CPU.
m = Model.normalize({ source: "k10temp", sensors: [{ label: "Tccd1", celsius: 50 }, { label: "Tctl", celsius: 55 }] })
assert.strictEqual(m.primary.label, "Tctl")
assert.strictEqual(m.primary.crit, null)

// No recognised label: the hottest sensor wins.
m = Model.normalize({ sensors: [{ label: "temp1", celsius: 40 }, { label: "temp2", celsius: 70 }] })
assert.strictEqual(m.primary.label, "temp2")

// Nothing usable.
for (const empty of [null, {}, { sensors: [] }, { sensors: [{ label: "x", celsius: null }] }]) {
  m = Model.normalize(empty)
  assert.strictEqual(m.available, false)
  assert.strictEqual(Model.summary(m), "No CPU temperature sensor found")
}

assert.strictEqual(Model.parseMillis("72500\n"), 72.5)
assert.strictEqual(Model.parseMillis("-264700"), -264.7)
assert.strictEqual(Model.parseMillis(""), null)
assert.strictEqual(Model.parseMillis("abc"), null)
assert.strictEqual(Model.parseMillis(undefined), null)

assert.strictEqual(Model.ceiling({ crit: 105, max: 100 }), 105)
assert.strictEqual(Model.ceiling({ crit: null, max: 90 }), 90)
assert.strictEqual(Model.ceiling(null), 100)

assert.strictEqual(Model.glyph(20, 100), "")
assert.strictEqual(Model.glyph(65, 100), "")
assert.strictEqual(Model.glyph(120, 100), "")

assert.strictEqual(Model.barText(71.6, 100, false), " 72°")
assert.strictEqual(Model.barText(71.6, 100, true), "72°")
assert.strictEqual(Model.barText(null, 100, false), "")

assert.strictEqual(Model.isHot(85, 85), true)
assert.strictEqual(Model.isHot(84.9, 85), false)
assert.strictEqual(Model.isHot(99, 0), false)
assert.strictEqual(Model.isHot(null, 85), false)

assert.strictEqual(Model.summary(Model.normalize(intel), 70.2), "CPU 70° · critical at 100°")

console.log("test_model.js: all passed")
