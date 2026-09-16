# Orca — Workspaces and agents in the Omarchy bar

This folder is an Omarchy shell plugin, **`toolbox.orca`**: a bar widget for
Orca, the IDE for running coding agents in parallel.

- **Bar:** `󰉋 3  󰚩 2` — open Orca workspaces and running agents. It turns the
  urgent colour when an agent needs approval or is waiting for your answer,
  and leaves the bar while Orca is closed.
- **Panel (left click):** every workspace with its repo, and under it each
  running agent: Claude, Codex…, its state (working, needs approval, waiting
  for you), the tool it is using, how long it has been in that state and its
  task. Workspaces that need you come first, then busy ones.
- **Click a workspace or agent** to bring Orca to the front on that terminal.
  **Right click** the bar icon to just focus Orca.

It only reads from Orca; it never sends input to an agent.

## Setup

Open Orca at least once (that registers its CLI), then:

```bash
./omarchy/orca/install.sh   # install and add to the bar, after your workspaces widget
```

## Commands

```bash
./toolbox orca          # workspaces and running agents, in the terminal
./toolbox orca json     # the raw snapshot the widget reads
./toolbox orca focus    # bring Orca to the front
```

## Settings

In `~/.config/omarchy/shell.json`, on the `toolbox.orca` bar entry:

| Setting | Default | Meaning |
| --- | --- | --- |
| `refreshSeconds` | `10` | How often the bar checks Orca. The open panel checks every 3 seconds. |

## How it works

- `snapshot.sh` runs Orca's CLI (`~/.config/orca/linux-orca-cli-shim/orca`,
  override with `TOOLBOX_ORCA_CLI`): `worktree ps --json` for workspaces and
  their agents, `terminal list --json` for terminal handles. Each check takes
  about a quarter of a second. When Orca is closed the shim refuses to run and
  the widget hides.
- `Model.js` turns that into the list: archived workspaces and finished agents
  are left out, and each agent is matched to its terminal
  (`paneKey` = `tabId:leafId`).
- `focus.sh` runs `orca terminal switch --terminal <handle>` and focuses the
  Orca window with `hyprctl`.
- `Panel.qml` is the bar button and dropdown, built on Omarchy's `Panel`,
  `WidgetButton` and `KeyboardPanel`.

Orca's JSON field names are not a documented API; they were read from Orca
1.4.204. If an update renames them, the widget shows workspaces without agents
until `Model.js` is adjusted.

To remove it from the bar: `omarchy plugin disable toolbox.orca`.

```bash
./omarchy/orca/test.sh   # model tests, closed-Orca snapshot, plugin validation
```
