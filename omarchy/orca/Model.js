// Pure data shaping for the toolbox.orca widget. No Qt here, so it runs under
// node (see test.sh). Input is snapshot.sh's output:
//   { running, error?, worktrees: [...], terminals: [...] }
// worktrees are `orca worktree ps --json` rows: worktreeId, displayName, repo,
// branch, path, status, unread, isArchived, lastActivityAt and agents[] with
// paneKey, agentType, state (working|blocked|waiting|done), taskTitle,
// displayName, prompt, toolName, stateStartedAt. terminals are
// `orca terminal list --json` rows: handle, worktreeId, tabId, leafId, title.

var ACTIVE_STATES = { working: true, blocked: true, waiting: true }
var ATTENTION_STATES = { blocked: true, waiting: true }

function text(value) {
  return value === undefined || value === null ? "" : String(value)
}

function oneLine(value, max) {
  var s = text(value).replace(/\s+/g, " ").trim()
  return s.length > max ? s.slice(0, max - 1) + "…" : s
}

function baseName(path) {
  var parts = text(path).replace(/\/+$/, "").split("/")
  return parts[parts.length - 1] || ""
}

function branchName(branch) {
  return text(branch).replace(/^refs\/heads\//, "")
}

function workspaceName(row) {
  return text(row.displayName) || branchName(row.branch) || baseName(row.path) || text(row.worktreeId)
}

function agentLabel(agentType) {
  var names = { claude: "Claude", codex: "Codex", gemini: "Gemini", opencode: "OpenCode", cursor: "Cursor", pi: "Pi" }
  var key = text(agentType).toLowerCase()
  return names[key] || (key ? key.charAt(0).toUpperCase() + key.slice(1) : "Agent")
}

function stateLabel(state) {
  var labels = { working: "Working", blocked: "Needs approval", waiting: "Waiting for you", done: "Done" }
  return labels[state] || text(state)
}

// "3m", "2h", "1d": how long an agent has been in its current state.
function durationLabel(sinceMs, nowMs) {
  var since = Number(sinceMs)
  if (!isFinite(since) || since <= 0) return ""
  var minutes = Math.max(0, Math.floor((nowMs - since) / 60000))
  if (minutes < 1) return "now"
  if (minutes < 60) return minutes + "m"
  if (minutes < 1440) return Math.floor(minutes / 60) + "h"
  return Math.floor(minutes / 1440) + "d"
}

// paneKey is "<tabId>:<leafId>"; terminal rows carry both halves separately.
function terminalIndex(terminals) {
  var byPane = {}
  var firstByWorktree = {}
  for (var i = 0; i < (terminals || []).length; i++) {
    var t = terminals[i]
    if (!t || !t.handle) continue
    if (t.tabId && t.leafId) byPane[t.tabId + ":" + t.leafId] = t.handle
    if (t.worktreeId && !firstByWorktree[t.worktreeId]) firstByWorktree[t.worktreeId] = t.handle
  }
  return { byPane: byPane, firstByWorktree: firstByWorktree }
}

function normalize(snapshot, nowMs) {
  var result = { running: false, error: "", workspaces: [], workspaceCount: 0, activeAgents: 0, attention: 0 }
  if (!snapshot || snapshot.running !== true) {
    result.error = snapshot ? text(snapshot.error) : ""
    return result
  }
  result.running = true
  var terminals = terminalIndex(snapshot.terminals)
  var rows = snapshot.worktrees || []

  for (var i = 0; i < rows.length; i++) {
    var row = rows[i]
    if (!row || row.isArchived === true) continue
    var agents = []
    var rawAgents = row.agents || []
    for (var j = 0; j < rawAgents.length; j++) {
      var a = rawAgents[j]
      if (!a || !ACTIVE_STATES[a.state]) continue
      agents.push({
        paneKey: text(a.paneKey),
        handle: terminals.byPane[a.paneKey] || "",
        name: agentLabel(a.agentType),
        state: a.state,
        stateLabel: stateLabel(a.state),
        attention: ATTENTION_STATES[a.state] === true,
        task: oneLine(a.taskTitle || a.displayName || a.prompt, 80),
        tool: oneLine(a.toolName, 30),
        since: durationLabel(a.stateStartedAt, nowMs)
      })
      result.activeAgents++
      if (ATTENTION_STATES[a.state]) result.attention++
    }
    result.workspaces.push({
      id: text(row.worktreeId),
      name: workspaceName(row),
      repo: text(row.repo),
      branch: branchName(row.branch),
      unread: row.unread === true,
      handle: terminals.firstByWorktree[row.worktreeId] || "",
      agents: agents,
      working: agents.length > 0,
      attention: agents.some(function(agent) { return agent.attention })
    })
  }

  // Workspaces that need you first, then busy ones; Orca's own order otherwise.
  result.workspaces = result.workspaces
    .map(function(w, index) { return { w: w, index: index } })
    .sort(function(x, y) {
      var rank = function(w) { return w.attention ? 0 : (w.working ? 1 : 2) }
      return rank(x.w) - rank(y.w) || x.index - y.index
    })
    .map(function(entry) { return entry.w })
  result.workspaceCount = result.workspaces.length
  return result
}

function summary(model) {
  if (!model.running) return "Orca is not running"
  var parts = [model.workspaceCount + (model.workspaceCount === 1 ? " workspace" : " workspaces")]
  parts.push(model.activeAgents + (model.activeAgents === 1 ? " agent running" : " agents running"))
  if (model.attention > 0) parts.push(model.attention + " need" + (model.attention === 1 ? "s" : "") + " you")
  return parts.join(" · ")
}

if (typeof module !== "undefined") {
  module.exports = {
    normalize: normalize,
    summary: summary,
    durationLabel: durationLabel,
    workspaceName: workspaceName
  }
}
