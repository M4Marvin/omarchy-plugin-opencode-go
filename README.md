# OpenCode Go Usage

An Omarchy Quattro bar widget for OpenCode Go usage and recent token history.

## Install

```bash
omarchy plugin add ~/.config/omarchy/plugins/local.opencode-go --no-enable
# Add local.opencode-go to the right section when ready:
omarchy bar add local.opencode-go --section right
```

## Account

The widget reads the active key from `~/.local/share/opencode/auth.json` (`opencode-go` entry) and labels it `Go`.

## The bar

The bar shows a usage gauge, the window it is tracking, and that window's
percentage — for example `Wk · 20%`. It turns urgent when the weekly window
falls behind an even spending pace. Left click opens details, right or middle
click refreshes, and `R` refreshes from inside the panel.

## The panel

Each limit window gets a percentage, its dollar cap, a meter, its reset
countdown, and how far ahead of or behind an even pace it is. The tick on each
meter marks where an even spender would be right now: fill to the left of it is
ahead of pace, fill to the right is behind. Below that, the last seven days of
token use and cost, with today highlighted.

## Settings

Both settings live in the bar widget settings.

| Setting | Default | Notes |
| --- | --- | --- |
| Percentage shown in the bar | `Weekly` | `5-hour`, `Weekly`, `Monthly`, or `Highest`. `Highest` follows whichever window is furthest along. |
| Refresh interval (seconds) | `300` | 60–3600. |

The 5-hour rolling limit is $12, weekly is $30, and monthly is $60.

## Removal

```bash
omarchy bar remove local.opencode-go
omarchy plugin remove local.opencode-go --yes
```

## License

MIT.
