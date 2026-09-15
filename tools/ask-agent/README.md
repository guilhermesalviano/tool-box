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

This project extends a **user-owned clone** of Omarchy's menu plugin because
JSONC actions alone cannot render an answer. Packaged Omarchy files are never
modified. Ordinary app search and menu navigation remain available.

The existing menu extension at
`~/.config/omarchy/extensions/omarchy-menu.jsonc` must include the
`toolbox-ask-agent` entry in this directory's `omarchy-menu.jsonc`.
On this machine it is already linked to that file. Preserve other custom
entries when adding the row on another machine.

```bash
./tools/ask-agent/install.sh --check # Check compatibility without installing
./tools/ask-agent/install.sh         # Clone, patch, and enable the menu
./tools/ask-agent/test.sh            # Local tests; no AI requests
```

The installer uses `omarchy plugin clone omarchy.menu` and applies `menu.patch`
plus `AskPane.qml` to `~/.config/omarchy/plugins/<username>.menu/`. It links
`~/.local/bin/toolbox-ask-agent` to `run.sh`. It refuses to overwrite an existing
menu clone not owned by this integration. Backups are saved under
`~/.local/state/toolbox-ask-agent/<timestamp>/`.

After an Omarchy update, run the compatibility check and reinstall to incorporate
an updated stock menu. If the patch no longer applies, update it before
installing. Reinstallation backs up and replaces this integration's menu clone.

To return to the stock menu, run `omarchy plugin disable <username>.menu` and
remove the `toolbox-ask-agent` row from the menu extension. The clone and backups
can remain on disk. The installer also backs up `shell.json` for recovery.
