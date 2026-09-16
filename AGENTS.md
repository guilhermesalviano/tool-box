# AGENTS.md

Guidance for AI coding agents working in this repository.

## What this is

`tool-box` is a modular collection of server and macOS automation scripts, background monitors, and system utilities. Each tool lives in an isolated folder under `tools/<name>/` — or under `apps/<name>/` for GUI applications, or `omarchy/<name>/` when it only works on the Omarchy desktop — and is dispatched through the unified `./toolbox` CLI.

---

## Commands

### Fresh-machine setup (`./install.sh`)
- `./install.sh` — Interactive, idempotent setup for a new clone: first offers zsh + Oh My Zsh (unattended; old `~/.zshrc` saved as `~/.zshrc.pre-oh-my-zsh`) with the `zsh-autosuggestions`, `zsh-syntax-highlighting` and `fast-syntax-highlighting` plugins cloned into `$ZSH_CUSTOM/plugins`, enabled via a `# >>> tool-box zsh plugins >>>` block in `~/.zshrc` (only `fast-syntax-highlighting` is sourced — the two highlighters conflict; `zsh-syntax-highlighting` is the fallback), and `chsh` to zsh. This runs before the aliases step so aliases land in the new `~/.zshrc`. Then offers to install shell aliases, checks/offers to install each tool's external dependency (`aria2`, `python3`, `jq`, `ripgrep`), bootstraps the mac-monitor virtualenv, and — only when an `omarchy` CLI is detected — offers to install the Ask AI / Search Web Omarchy plugins. Confirms before any system-modifying step (package install, LaunchAgent, shell rc edits); safe to re-run.

### Global CLI (`./toolbox`)
- `./toolbox list` — List all installed tools and their descriptions.
- `./toolbox new <tool-name>` — Scaffold a new tool from `tools/_template/`.
- `./toolbox <tool-name> [action|args]` — Dispatch a command to a specific tool.

### Torrent DL (`torrent-dl`)
- `./toolbox torrent-dl '<link>'` — Download a torrent from a magnet link, a `.torrent` URL, or a local `.torrent` file, via `aria2c` (must be installed separately: `brew install aria2` / `apt-get install aria2`).
- `./toolbox torrent-dl '<link>' -o <dir>` — Set the destination directory (default `~/Downloads/torrents`).
- `./toolbox torrent-dl '<link>' -s <minutes>` — Keep seeding for N minutes after completion (default `0`, no seeding).

### Disk Cleaner (`disk-cleaner`)
- `./toolbox disk-cleaner` — Interactively clean caches, trash, and temp files on macOS or Linux (asks per step).
- `./toolbox disk-cleaner --yes|--all` — Assume "yes" for every step, except the Docker steps (see below), which always prompt.
- `./toolbox disk-cleaner --dry-run` — Preview what would be cleaned without deleting anything.
- `./toolbox disk-cleaner --docker-volumes` — Also offer to prune unused Docker volumes (off by default; may contain database data).

### Aliases (`aliases`)
- `./toolbox aliases install` — Add Tool-Box shell aliases (`tb`, `tb-clean`, `tb-mon-*`, etc.) to `~/.zshrc`/`~/.bashrc`/`~/.bash_profile`, detected from `$SHELL`. Idempotent, marked by `# >>> tool-box aliases >>>` / `# <<< tool-box aliases <<<`.
- `./toolbox aliases uninstall` — Remove that marked block.
- `./toolbox aliases status` — Show which rc files have the aliases installed.
- `./toolbox aliases list` — List all available aliases and what they expand to.

### Swain Macros (`swain-macros`) — GUI app
- `./toolbox swain-macros install` — One-time setup on Ubuntu/GNOME (runs `install.sh`): apt packages, udev rule for the mouse and `/dev/uinput`, app menu entry. Run as the normal user; it calls `sudo` itself.
- `./toolbox swain-macros [--background]` — Open the GTK app that maps macros to the Redragon Swain side buttons (`--background` starts hidden).

### Ask AI (`ask-agent`) — Omarchy only
- `./toolbox ask-agent [question...]` — Open the inline answer panel inside Omarchy's search (Super + Space). Requires the `toolbox.ask-agent` plugin (`./omarchy/ask-agent/install.sh`).
- `./toolbox ask-agent --headless <question...>` — Print an answer to stdout without opening a window (machine-facing: stdout is only the answer, stderr only errors).
- `./omarchy/ask-agent/install.sh --check` — Validate the plugin with `omarchy plugin validate`, without installing.
- `./omarchy/ask-agent/install.sh` — Copy the plugin to `~/.config/omarchy/plugins/toolbox.ask-agent/`, enable it (it replaces `omarchy.menu`), retire the old `<username>.menu` patch install, and restart the shell. Backs up to `~/.local/state/toolbox-ask-agent/<timestamp>/`.
- `./omarchy/ask-agent/test.sh` — Local tests; issues no AI requests.
- Backend is Omarchy's default agent (`omarchy default agent`, re-read per question). Inline answers: Codex (`codex exec --sandbox read-only --ephemeral`) and Claude (`claude --print --tools "" --strict-mcp-config --no-session-persistence`), resolved via `mise which <agent>` then `PATH`. Any other agent makes `answer.sh` exit 3 and the pane offers "Open in <agent>" (`omarchy agent prompt`). `answer.sh --agent-info` prints `{id,name,inline}`. Overrides: `TOOLBOX_AGENT_WORKDIR` (default `~/Work`), `TOOLBOX_AGENT_TIMEOUT` (default `180`), `TOOLBOX_AGENT_BIN` (`TOOLBOX_AGENT_CODEX_BIN` still honored for Codex).

### Calendar (`calendar`) — Omarchy only
- `./toolbox calendar add [name]` — Add a calendar by its private iCal address (read hidden from the terminal, checked by downloading it, never passed on argv). Stored in `~/.config/toolbox-calendar/calendars.conf` (mode 600).
- `./toolbox calendar list` / `remove <name|number>` / `sync` / `status` — Manage calendars (addresses masked), sync now, show last sync and errors.
- `./omarchy/calendar/install.sh [--check]` — Validate, copy to `~/.config/omarchy/plugins/toolbox.calendar/`, and enable (replaces `omarchy.clock`, keeping its bar settings).
- `./omarchy/calendar/test.sh` — Python recurrence/parsing tests, node tests for `Events.js`, plugin validation. No network.
- Output: `~/.local/state/toolbox-calendar/events.json`, window 45 days back to 120 days ahead. Bar settings: `nextEventMinutes` (default 60, `0` hides the next event), `notifyMinutes` (default 30, `0` disables notifications).

### Web Search (`web-search`) — Omarchy only
- `./toolbox web-search [query...]` — Search the internet in Omarchy's default browser. With no query, opens the `toolbox.web-search` search box.
- `./omarchy/web-search/install.sh --check` — Validate the plugin and prerequisites (`jq`, `omarchy-launch-browser`) without installing.
- `./omarchy/web-search/install.sh` — Copy the plugin to `~/.config/omarchy/plugins/toolbox.web-search/` and enable it.
- `TOOLBOX_SEARCH_URL` — URL template with a literal `%s` placeholder (default Google). Must start with `http://` or `https://`; the query is URL-encoded via `jq -sRr @uri` before substitution.

### Mac Monitor (`mac-monitor`)
- `./toolbox mac-monitor setup` — Create `.venv/` and install Glances into it, without starting the collector.
- `./toolbox mac-monitor report [YYYY-MM-DD]` — Generate the aggregated CPU and Memory report via AWK (defaults to today).
- `./toolbox mac-monitor status` — Check if the monitor daemon and LaunchAgent are active, sample count, and log file size.
- `./toolbox mac-monitor logs [-f]` — View the latest CSV log lines (`-f` to follow in real-time).
- `./toolbox mac-monitor start` — Start the collector daemon in the background.
- `./toolbox mac-monitor stop` — Stop the collector daemon.
- `./toolbox mac-monitor restart` — Restart the collector daemon.
- `./toolbox mac-monitor install-service` — Install and load the macOS LaunchAgent (`~/Library/LaunchAgents/com.guilhermesalviano.toolbox-monitor.plist`).
- `./toolbox mac-monitor uninstall-service` — Unload and remove the LaunchAgent.

---

## Repository layout

- `install.sh` — Interactive fresh-machine setup (see above). Not dispatched through `toolbox`; run directly.
- `toolbox` — Master executable CLI dispatcher. Looks up `tools/<name>/` first, then `apps/<name>/`, then `omarchy/<name>/`, and routes to `manage.sh` or `run.sh`. `list` prints the three groups separately; `new` always scaffolds into `tools/`.
- `tools/` — Modular tools directory:
  - `tools/torrent-dl/` — Torrent downloader (magnet link, `.torrent` URL, or local `.torrent` file) via `aria2c`:
    - `run.sh` — Entry point; `-o/--output`, `-s/--seed-minutes` flags.
    - `README.md` — Tool documentation.
  - `tools/disk-cleaner/` — Cross-platform (macOS/Linux) disk space cleaner:
    - `run.sh` — Interactive cleanup script; asks per step, `-y`/`--all`/`--dry-run`/`--docker-volumes` flags.
    - `README.md` — Tool documentation.
  - `tools/aliases/` — Shell alias installer for the Tool-Box CLI:
    - `aliases.sh` — Self-locating alias definitions (sourced, not executed; works from bash and zsh).
    - `manage.sh` — Tool-specific controller (`install`, `uninstall`, `status`, `list`).
    - `README.md` — Tool documentation.
  - `tools/mac-monitor/` — Continuous Mac CPU & Memory monitor:
    - `collector.py` — Python streaming collector daemon reading metrics from Glances and handling midnight CSV rotation.
    - `report.sh` — AWK script calculating daily mean CPU, max CPU, mean Memory, max Memory, and sample count.
    - `manage.sh` — Tool-specific controller (`start`, `stop`, `status`, `report`, `logs`, `install-service`, `uninstall-service`).
    - `launchd/com.guilhermesalviano.toolbox-monitor.plist.template` — LaunchAgent definition for macOS boot/login persistence. Has no absolute paths baked in; `manage.sh install-service` renders it with the actual `ROOT_DIR`/`HOME` via `sed` before installing, since a clone can live anywhere.
    - `README.md` — Tool documentation (first `# Title` line is shown in `./toolbox list`).
  - `tools/_template/` — Starter boilerplate for new tools (`run.sh` and `README.md`).
- `apps/` — GUI applications; dispatched by `./toolbox` just like `tools/`:
  - `apps/swain-macros/` — Linux (Ubuntu/GNOME, Wayland and X11) macro app for the Redragon Swain mouse side buttons (Holtek `04d9:fc63`):
    - `run.sh` — Entry point; launches the app, or `install.sh` with `install`.
    - `install.sh` — One-time setup (apt deps, udev rule, `uinput` module, desktop launcher).
    - `swain-macros` — Python launcher for the `swain_macros` package.
    - `swain_macros/` — `app.py` (GTK4/libadwaita UI), `engine.py` (grabs the mouse via evdev and re-emits events through `uinput`), `macro.py` (macro language parser/player), `config.py` (`~/.config/swain-macros/config.json`, autostart).
    - `data/` — udev rule, `.desktop` template (`@EXEC@` placeholder), app icon.
    - `README.md` — Tool documentation.
- `omarchy/` — Omarchy shell plugins; each folder is a plugin (`manifest.json` + QML) and is also dispatched by `./toolbox` via its `run.sh`. Installers copy only the listed plugin files (no symlinks; `omarchy plugin validate` must pass) to `~/.config/omarchy/plugins/<id>/`:
  - `omarchy/ask-agent/` — Plugin `toolbox.ask-agent` (kinds `menu`, `bar-widget`; `clonedFrom: omarchy.menu`, so calls to `omarchy.menu` route to it). Inline AI answers inside the Super + Space search panel:
    - `manifest.json`, `Menu.qml`, `MenuModel.js`, `BarWidget.qml` — Full copy of Omarchy's stock menu plugin plus the toolbox changes (Ask AI mode, `programs` Apps provider, Search Web fallback row, bundled `menu.jsonc` source). Does not receive upstream menu fixes automatically; diff against `/usr/share/omarchy/shell/plugins/menu/` after Omarchy updates.
    - `AskPane.qml` — The answer pane; runs the plugin's own `answer.sh`.
    - `menu.jsonc` — Rows the plugin adds (Ask AI, Search Web, the Apps override), merged between Omarchy's defaults and the user extension.
    - `run.sh` — Entry point; summons the menu panel, or `--headless` to delegate to `answer.sh`.
    - `answer.sh` — Machine-facing agent backend (Codex, Claude inline; exit 3 for other agents); stdout is only the answer, stderr only errors.
    - `install.sh` — Stages and validates in a tmpdir, installs and enables the plugin, retires the legacy patched `<username>.menu` clone (marker `.toolbox-ask-agent`), its `~/.local/bin` launcher and extension symlink, then restarts the shell.
    - `test.sh` — Local tests; issues no AI requests. Not wired into `toolbox`; run directly.
    - `README.md` — Tool documentation.
  - `omarchy/calendar/` — Plugin `toolbox.calendar` (kind `bar-widget`; `clonedFrom: omarchy.clock`). Read-only Google Calendar events via private iCal addresses:
    - `manifest.json`, `BarWidget.qml`, `Panel.qml`, `Model.js` — Omarchy's stock clock plus events: the widget runs `sync.py` every 5 minutes and on popup open, watches `events.json`, and appends the next timed event to the label; the panel adds event dots, day selection, and the selected day's event list.
    - `Events.js` — Pure event math (normalize, per-day overlap, bar label, click URL, sync status); tested by `test_events.js` under node.
    - `sync.py` — Standard-library ICS fetch/parse with RRULE expansion (DAILY/WEEKLY/MONTHLY/YEARLY, INTERVAL, COUNT, UNTIL, BYDAY with ordinals, BYMONTHDAY, BYMONTH, BYSETPOS, EXDATE, RECURRENCE-ID overrides). HTTPS only; a failing calendar keeps its previous events. File-locked so several bars do not sync at once. Tested by `test_sync.py`.
    - `notify.sh` — Sends one event notification via `omarchy notification send` (click opens the link), deduplicated by a stamp directory per occurrence under `~/.local/state/toolbox-calendar/notified/`.
    - `run.sh` — `toolbox calendar` subcommands.
    - `install.sh`, `test.sh`, `README.md`.
  - `omarchy/web-search/` — Plugin `toolbox.web-search` (kind `overlay`). Internet search via `omarchy-launch-browser`:
    - `manifest.json`, `WebSearch.qml` — Search-box overlay; summon payload `{"query": "..."}` searches immediately.
    - `run.sh` — Entry point; URL-encodes the query and launches the default browser, or opens the search box without a query.
    - `install.sh` — Stages, validates, installs and enables the plugin. Needs `jq`.
    - `test.sh` — Local tests. Not wired into `toolbox`; run directly.
    - `README.md` — Tool documentation.
- `logs/` — Centralized log directory (gitignored):
  - `glances-YYYY-MM-DD.csv` — Daily CSV metric files.
  - `monitor.pid` — Process ID file of the active collector.
  - `monitor-service.log` / `monitor-service-err.log` — Daemon stdout/stderr logs.
- `.venv/` — Shared Python virtual environment (gitignored) containing `glances`, `psutil`, etc.
- `.gitignore` — Ignores `logs/`, `.venv/`, `__pycache__/`, `.DS_Store`.
- `README.md` — User documentation in Portuguese.
- `AGENTS.md` — This file.

---

## Runtime Constraints & Conventions

1. **Log File Contract (`mac-monitor`)**:
   The CSV log files must be written to:
   `logs/glances-YYYY-MM-DD.csv`
   With the exact header format:
   ```csv
   now.iso,now.custom,cpu.total,mem.used,mem.percent
   ```
   - `$1`: `now.iso` (ISO 8601 timestamp)
   - `$2`: `now.custom` (Formatted local timestamp)
   - **`$3`**: **`cpu.total` (%)**
   - `$4`: `mem.used` (Bytes)
   - **`$5`**: **`mem.percent` (%)**
   
   **CRITICAL**: Do NOT change column positions or header names. External scripts and the user's manual AWK one-liners rely directly on `$3` being CPU% and `$5` being Memory%.

2. **Daily Rotation**:
   The collector process must handle date changes at midnight automatically. When the date changes:
   - Close and flush the previous day's CSV file.
   - Open `logs/glances-<new-date>.csv`.
   - Write the CSV header if the new file is empty.
   - Flush every sample immediately (`f.flush()`) so real-time reports always reflect current data.

3. **Tool Structure**:
   Every tool inside `tools/<name>/` (or `apps/<name>/`, `omarchy/<name>/`) must:
   - Be self-contained in its own subdirectory. Put it in `apps/` if it is a GUI application, in `omarchy/` if it is useless outside Omarchy; everything else goes in `tools/`.
   - Provide an executable entrypoint: `manage.sh` (for daemons/services with subcommands) or `run.sh` (for simple runnable scripts).
   - Have a `README.md` whose first line is `# <Tool Name>` so `./toolbox list` can auto-discover it.
   - Use the shared Python virtual environment at `../../.venv/bin/python3` if Python is required. Exception: `swain-macros` uses the system `python3` because PyGObject (GTK) and evdev come from apt.

4. **macOS LaunchAgents**:
   - Label naming convention: `com.guilhermesalviano.<service-name>`.
   - Ship a `.plist.template` in `tools/<name>/launchd/`, never a plist with real paths baked in — a clone can live anywhere. Use `__PLACEHOLDER__` tokens and have the tool's `install-service` command render them via `sed` (see `mac-monitor/manage.sh`) into `${HOME}/Library/LaunchAgents/`.
   - Set `WorkingDirectory` to the `tool-box` project root.
   - Use absolute paths in `ProgramArguments` pointing to `.venv/bin/python3` and the tool script.

---

## Adding a New Tool

1. Scaffold using the CLI:
   ```bash
   ./toolbox new <tool-name>
   ```
2. Implement your logic in `tools/<tool-name>/run.sh` (or create Python/Bash scripts in that folder).
3. Update `tools/<tool-name>/README.md` with description and instructions.
4. Verify with:
   ```bash
   ./toolbox list
   ./toolbox <tool-name>
   ```
