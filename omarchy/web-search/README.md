# Web Search — Internet search from Omarchy

Open **Super + Space**, choose **Search Web**, type a query, and press Enter.
The result opens in the system's default browser through Omarchy's
`omarchy-launch-browser` command. No terminal is opened.

When you type text that matches no installed app or Omarchy setting, the menu
also offers **Search Web: _your text_** automatically. Press Enter to use that
exact text as the web query.

If unmatched text still shows “No matches” after installing or updating the
menu integration, run `omarchy restart shell` once. `omarchy menu refresh`
only reloads menu definitions; a plugin rescan can retain older menu code.

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

The query is URL-encoded before substitution, including quotes, ampersands,
Unicode, and shell metacharacters. The URL must use `http://` or `https://`.

Omarchy exposes the default browser through XDG settings, but Linux does not
standardize a user's default search engine. This tool therefore uses the
default browser and a configurable search-engine URL.
