# Ask AI — Answers inside Omarchy search

Press **Super + Space**, type **`ask How do I change my wallpaper?`**, then
press **Enter**. The answer appears inside the search panel. You can also
search for **Ask AI**, open it, type your question, and press Enter.

- Read and scroll through the answer without opening a terminal.
- Select text or use **Copy answer**.
- Use **Cancel** to stop a request, or **Retry** after an error.
- **Escape** or **‹ Search** returns to ordinary search. Closing the menu
  cancels a running request.
- Each question starts a separate conversation; previous answers are not sent.
- Questions are sent only when submitted, never while typing in search.

## Backend

Answers come from **OpenCode** by default, using its existing installation and
sign-in. Without OpenCode installed, Omarchy's **default agent** (**Setup →
Default → Agent**) answers instead; set `TOOLBOX_AGENT` to pick another agent.
The agent is read again for every question, so switching it takes effect
immediately; the pane title shows which one answers (for example **Ask AI ·
OpenCode**).

| Agent | How it answers | Kept read-only by |
| --- | --- | --- |
| OpenCode | inside the menu: `opencode run --format json` (1.x `--pure`, session deleted afterwards; 2.x `--standalone`) | inline config turning off every tool (MCP included) and denying every permission |
| Codex | inside the menu: `codex exec`, ephemeral session | Codex's read-only sandbox, no approval prompts |
| Claude Code | inside the menu: `claude --print`, no saved session | `--tools ""` (no tools at all) and `--strict-mcp-config` (no MCP servers) |
| Any other agent | **Open in <agent>** button: the question opens in that agent's terminal through `omarchy agent prompt` | the agent's usual Omarchy launch |

Inline answers are limited to agents whose one-shot mode can be locked to
text-only replies and has been tested here. The executable is resolved with
`mise which <agent>`, then `PATH` (OpenCode: mise's `opencode` tool first), avoiding Omarchy's update check on each
question. Only the final answer is displayed.

```bash
./toolbox ask-agent                      # Open the inline question panel
./toolbox ask-agent 'Explain swap memory' # Ask directly in the panel
./toolbox ask-agent --headless '2 + 2?'   # Print an answer for scripts
./toolbox ask-agent --help
```

Environment overrides:

| Variable | Default | Purpose |
| --- | --- | --- |
| `TOOLBOX_AGENT` | `opencode` if installed, else Omarchy's default agent | Agent id that answers (`opencode`, `claude`, `codex`, …) |
| `TOOLBOX_AGENT_WORKDIR` | `~/Work` | Existing directory used as question context |
| `TOOLBOX_AGENT_TIMEOUT` | `180` | Request timeout in seconds |
| `TOOLBOX_AGENT_BIN` | `mise which <agent>` | Path to the agent's executable (`TOOLBOX_AGENT_CODEX_BIN` still works for Codex) |

Desktop launches inherit the shell service's environment. Temporary prompt,
response, and diagnostic files are private and removed on completion or cancel.

## Installation and maintenance

This folder is an Omarchy shell plugin, **`toolbox.ask-agent`**. It is a full
copy of Omarchy's menu plugin (`Menu.qml`, `MenuModel.js`, `BarWidget.qml`)
with the toolbox changes built in, because JSONC actions alone cannot render
an answer. Its manifest declares `clonedFrom: omarchy.menu`, so Super + Space,
the bar button, and every `omarchy.menu` call use it. Packaged Omarchy files
are never modified.

Besides Ask AI, the plugin:

- ships its own menu rows in `menu.jsonc` (Ask AI, Search Web, and an Apps
  override). They are merged between Omarchy's defaults and your
  `~/.config/omarchy/extensions/omarchy-menu.jsonc`, which stays yours to edit.
- lists apps through a `programs` provider that reads `.desktop` files directly,
  working around an Omarchy bug where menu plugins outside Omarchy's own
  folder get an empty app list
  ([omacom/omarchy#11762](https://github.com/omacom/omarchy/issues/11762)).
- shows **Search Web** and the unmatched-text fallback only while the
  `toolbox.web-search` plugin is installed.

```bash
./omarchy/ask-agent/install.sh --check # Validate the plugin without installing
./omarchy/ask-agent/install.sh         # Install, enable, and restart the shell
./omarchy/ask-agent/test.sh            # Local tests; no AI requests
```

The installer copies the plugin files to
`~/.config/omarchy/plugins/toolbox.ask-agent/` (a copy, not a link: Omarchy
refuses symlinks in plugins), enables it, and restarts the shell so the new
menu code loads. Rerun it after editing files here. Backups of the previous
plugin and `shell.json` are saved under
`~/.local/state/toolbox-ask-agent/<timestamp>/`. It also retires the older
patch-based install: the `<username>.menu` clone, the
`~/.local/bin/toolbox-ask-agent` link, and a menu extension symlinked into
this repo (restored to Omarchy's empty template).

Because the menu is a copy, Omarchy updates to its own menu do not reach it.
After an Omarchy update, compare and bring over any changes you want:

```bash
diff -u /usr/share/omarchy/shell/plugins/menu/Menu.qml omarchy/ask-agent/Menu.qml
```

This copy is based on Omarchy 4.0.4.

To return to the stock menu, run `omarchy plugin disable toolbox.ask-agent`.
