# OpenCode Go Usage

An Omarchy Quattro bar widget for OpenCode Go usage and recent token history.

## Install

```bash
omarchy plugin add ~/.config/omarchy/plugins/local.opencode-go --no-enable
# Add local.opencode-go to the right section when ready:
omarchy bar add local.opencode-go --section right
```

## Account

The widget reads the active key from the `opencode-go` entry in OpenCode's auth file and labels it `Go`. By default this is `~/.local/share/opencode/auth.json`; set `OPENCODE_AUTH_JSON` to use another file.

## Local usage history

Daily token history is read from OpenCode's SQLite database and only includes assistant messages whose provider is `opencode-go`; usage from the Zen provider (`opencode`) is excluded. The default database is `~/.local/share/opencode/opencode.db`, or `$XDG_DATA_HOME/opencode/opencode.db` when `XDG_DATA_HOME` is set. Set `OPENCODE_DB` to use another database.

## Limits and settings

The 5-hour rolling limit is $12, weekly is $30, and monthly is $60. Left click opens details; right/middle click refreshes; press `R` in the panel. The default refresh interval is five minutes and can be changed in the bar widget settings (60–3600 seconds).

## Removal

```bash
omarchy bar remove local.opencode-go
omarchy plugin remove local.opencode-go --yes
```

## License

MIT.
