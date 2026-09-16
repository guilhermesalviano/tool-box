# Web Search — Internet search from Omarchy

This folder is an Omarchy shell plugin, **`toolbox.web-search`**: a search box
overlay. Type a query and press Enter; the result opens in the system's default
browser through Omarchy's `omarchy-launch-browser` command. No terminal is
opened.

```bash
./omarchy/web-search/install.sh --check # Validate the plugin and prerequisites
./omarchy/web-search/install.sh         # Install and enable the plugin
./omarchy/web-search/test.sh            # Local tests; no browser is opened
```

The installer copies the plugin files to
`~/.config/omarchy/plugins/toolbox.web-search/` and enables it. Rerun it after
editing files here.

With the `toolbox.ask-agent` menu plugin installed, open **Super + Space** and
choose **Search Web**. When you type text that matches no installed app or
Omarchy setting, the menu also offers **Search Web: _your text_**. Press Enter
to search for that exact text.

Open the search box from anywhere, for example from a Hyprland keybinding:

```bash
omarchy-shell shell summon toolbox.web-search '{}'
omarchy-shell shell summon toolbox.web-search '{"query":"linux audio"}' # search immediately
```

You can also run:

```bash
./toolbox web-search
./toolbox web-search 'weather in São Paulo'
./toolbox web-search --help
```

The default search URL is Google. Override it with a URL template containing a
literal `%s` placeholder:

```bash
TOOLBOX_SEARCH_URL='https://duckduckgo.com/?q=%s' ./toolbox web-search 'linux audio'
```

The search box and menu run inside the Omarchy shell, so they only see
`TOOLBOX_SEARCH_URL` if it is set in the desktop session environment (for
example `~/.config/uwsm/env`), not just in a terminal.

The query is URL-encoded before substitution, including quotes, ampersands,
Unicode, and shell metacharacters. The URL must use `http://` or `https://`.

Omarchy exposes the default browser through XDG settings, but Linux does not
standardize a user's default search engine. This tool therefore uses the
default browser and a configurable search-engine URL.
