// Unit tests for Model.js. Run: node omarchy/orca/test_model.js
const assert = require("assert")
const Model = require("./Model.js")

const now = Date.parse("2026-09-16T12:00:00Z")
const minutesAgo = (m) => now - m * 60000

const snapshot = {
  running: true,
  worktrees: [
    { worktreeId: "r1::/src/app", repo: "app", branch: "refs/heads/main", path: "/src/app", displayName: "", agents: [] },
    {
      worktreeId: "r1::/src/app-login", repo: "app", branch: "refs/heads/feat/login", path: "/src/app-login", displayName: "Login flow",
      agents: [
        { paneKey: "tab1:leaf1", agentType: "claude", state: "working", taskTitle: null, prompt: "Add the\n login   form", toolName: "Edit", stateStartedAt: minutesAgo(3) },
        { paneKey: "tab1:leaf2", agentType: "codex", state: "done", prompt: "old", stateStartedAt: minutesAgo(90) }
      ]
    },
    {
      worktreeId: "r1::/src/app-fix", repo: "app", branch: "refs/heads/fix/crash", path: "/src/app-fix",
      agents: [{ paneKey: "tab2:leaf1", agentType: "codex", state: "blocked", taskTitle: "Fix crash", stateStartedAt: minutesAgo(125) }]
    },
    { worktreeId: "r1::/src/old", repo: "app", branch: "old", path: "/src/old", isArchived: true, agents: [] }
  ],
  terminals: [
    { handle: "term_a", worktreeId: "r1::/src/app-login", tabId: "tab1", leafId: "leaf1" },
    { handle: "term_b", worktreeId: "r1::/src/app-fix", tabId: "tab2", leafId: "leaf1" }
  ]
}

const model = Model.normalize(snapshot, now)
assert.strictEqual(model.running, true)
assert.strictEqual(model.workspaceCount, 3, "archived workspaces are left out")
assert.strictEqual(model.activeAgents, 2, "done agents are not running")
assert.strictEqual(model.attention, 1)
assert.deepStrictEqual(model.workspaces.map((w) => w.name), ["fix/crash", "Login flow", "main"], "needs-you first, then working, then idle")

const login = model.workspaces[1]
assert.strictEqual(login.handle, "term_a")
assert.deepStrictEqual(login.agents, [{
  paneKey: "tab1:leaf1", handle: "term_a", name: "Claude", state: "working", stateLabel: "Working",
  attention: false, task: "Add the login form", tool: "Edit", since: "3m"
}])
assert.strictEqual(model.workspaces[0].agents[0].stateLabel, "Needs approval")
assert.strictEqual(model.workspaces[0].agents[0].since, "2h")
assert.strictEqual(model.workspaces[2].handle, "", "no terminal to switch to")

assert.strictEqual(Model.summary(model), "3 workspaces · 2 agents running · 1 needs you")

const closed = Model.normalize({ running: false, error: "Orca CLI is unavailable" }, now)
assert.strictEqual(closed.running, false)
assert.strictEqual(closed.error, "Orca CLI is unavailable")
assert.strictEqual(Model.summary(closed), "Orca is not running")
assert.strictEqual(Model.normalize(null, now).running, false)

assert.strictEqual(Model.durationLabel(now - 20000, now), "now")
assert.strictEqual(Model.durationLabel(minutesAgo(60 * 49), now), "2d")
assert.strictEqual(Model.durationLabel(undefined, now), "")
assert.strictEqual(Model.workspaceName({ path: "/src/x/" }), "x")

console.log("Model.js: all tests passed")
