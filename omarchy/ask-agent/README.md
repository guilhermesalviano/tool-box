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

Uses your existing **Codex** installation and authentication, selected through
Omarchy's **Setup → Default → Agent**. Inline mode currently supports Codex;
other default agents produce an explanatory error in the panel.

Runs `codex exec` with a read-only sandbox, no approval prompts, and ephemeral
sessions. The installed binary is resolved with `mise which codex`, avoiding
Omarchy's update check on each question. Only the final answer is displayed.
See [OpenAI's non-interactive mode documentation](https://learn.chatgpt.com/docs/non-interactive-mode).

```bash
./toolbox ask-agent                      # Open the inline question panel
./toolbox ask-agent 'Explain swap memory' # Ask directly in the panel
./toolbox ask-agent --headless '2 + 2?'   # Print an answer for scripts
./toolbox ask-agent --help
```

Environment overrides:

| Variable | Default | Purpose |
| --- | --- | --- |
| `TOOLBOX_AGENT_WORKDIR` | `~/Work` | Existing directory used as question context |
| `TOOLBOX_AGENT_TIMEOUT` | `180` | Request timeout in seconds |
| `TOOLBOX_AGENT_CODEX_BIN` | `mise which codex` | Path to an installed Codex executable |

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
