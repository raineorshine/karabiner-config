# Raine's Karabiner Config

This is my [Karabiner](https://karabiner-elements.pqrs.org) setup for custom key bindings.

The default config file is located at `~/.config/karabiner/karabiner.json`.

- Disable Cmd+M to minimize globally.
  - [any] + Command + `m` → Command + Option + Shift + `m`
- Claude app: Cmd+J -> Cmd+K, Cmd+3
  - Command + `j` → Command + `n`, Command + `3`
- Claude app: Cmd+P -> click project selector (physical key r in Colemak)
  - Command + `r` → `Move cursor to (315, 875)`, `Left Click`
- Claude app: Cmd+Shift+P -> click Create PR button (physical key r in Colemak)
  - Command + Shift + `r` → `/usr/bin/osascript -l JavaScript "$HOME/.config/karabiner/scripts/restore-mouse-position.js"`, `Move cursor to (656, 875)`, `Left Click`
- Claude app: Cmd+Shift+G -> click empty sidebar (230, 940), Cmd+Shift+D
  - Command + Shift + `g` → `/usr/bin/osascript -l JavaScript "$HOME/.config/karabiner/scripts/restore-mouse-position.js"`, `Move cursor to (230, 940)`, `Left Click`, Command + Shift + `d`
- Claude app: Cmd+Shift+U -> click plan usage button (696, 938) (physical key i in Colemak)
  - Command + Shift + `i` → `Move cursor to (696, 938)`, `Left Click`
- Claude app: Cmd+B -> Cmd+.
  - Command + `b` → Command + `.`
- Claude app: Cmd+Option+B -> Cmd+\
  - Command + Option + `b` → Command + `\`
- Claude app: Cmd+. -> Cmd+Shift+U
  - Command + `.` → Command + Shift + `i`
- Claude app: Cmd+T -> Ctrl+` (physical key f in Colemak)
  - Command + `f` → Ctrl + `` ` ``
- Claude app: Cmd+Shift+E -> Cmd+K, type 'archive', Enter, Cmd+1 (physical key k in Colemak)
  - Command + Shift + `k` → Command + `n`, `a`, `s`, `c`, `h`, `l`, `v`, `k`, `return_or_enter`, Command + `1`
- Claude app: Cmd+Shift+1 -> menu bar, View > Previous Sidebar Tab; Cmd+Shift+2 -> menu bar, View > Next Sidebar Tab
  - Command + Shift + `1` → fn + Ctrl + `f2`, `v`, `↓`, `r`, `s`, `k`, `v`, `return_or_enter`
  - Command + Shift + `2` → fn + Ctrl + `f2`, `v`, `↓`, `j`, `k`, `x`, `f`, `return_or_enter`
- Quick Chars
  - L-Option + `'` → `` ` ``
  - L-Option + `t` → `~`
  - L-Option + `h` → `-`
  - L-Option + `q` → `=`
  - L-Shift + L-Option + `q` → `+`
  - L-Option + `u` → `_`
  - L-Option + `b` → `|`, `|`
  - [L-Shift] + L-Option + `Space` → `Space`
  - L-Option + `,` → `<`
  - L-Option + `.` → `>`
- Better Braces: Alt + o/i
  - L-Option + `l` → `[`
  - L-Option + `;` → `]`
  - L-Shift + L-Option + `l` → `{`
  - L-Shift + L-Option + `;` → `}`
  - L-Command + L-Option + `l` → L-Command + `[`
- Desktop Navigation: Right shift + brackets
  - R-Shift + `[` → L-Ctrl + `←`
  - R-Shift + `]` → L-Ctrl + `→`
- Launch apps: Right shift + letters
  - R-Shift + `a` → `open '/Applications/Utilities/Activity Monitor.app'`
  - R-Shift + `c` → `open '/Applications/Calendar.app'`
  - R-Shift + `e` → `open '/Applications/Sublime Text.app'`
  - R-Shift + `f` → `open /System/Library/CoreServices/Finder.app`
  - R-Shift + `g` → `open '/Applications/GitHub Desktop.app'`
  - R-Shift + `h` → `open '/Applications/Google Chrome.app'`
  - R-Shift + `n` → `open '/Applications/Notion.app'`
  - R-Shift + `k` → `open '/Applications/Karabiner-Elements.app'`
  - R-Shift + `m` → `open '/Applications/Messages.app'`
  - R-Shift + `s` → `open '/Applications/Spotify.app'`
  - R-Shift + `t` → `open '/Applications/iTerm.app'`
  - R-Shift + `v` → `open '/Applications/Brave Browser.app'`
  - R-Shift + `w` → `open '/Applications/WhatsApp.app'`
  - R-Shift + `z` → `open '/Applications/zoom.us.app'`
- Move italic to Cmd + Ctrl + i to make room for easy tab navigation
  - Command + Ctrl + `l` → Command + `l`
- Tab Navigation: Cmd + h/i
  - Command + `h` → Command + L-Shift + `[`
  - Command + `l` → Command + L-Shift + `]`
- GitHub notifications: Cmd + Option + t
  - L-Command + L-Option + `t` → `open 'https://github.com/notifications'`
- em issues: Cmd + Ctrl + Option + e (physical key k in Colemak)
  - L-Command + L-Ctrl + L-Option + `k` → `open 'https://github.com/cybersemics/em/issues/'`
- Chromium DevTools: Clear site data, focus page, and reload: Cmd + Option + r
  - Command + Option + `r` → `/usr/bin/osascript -l JavaScript "$HOME/.config/karabiner/scripts/clear-site-data.js"`
- Shortwave: Cmd+B -> Cmd+/
  - Command + `b` → Command + `slash`
- Shortwave: Cmd+Option+B -> Cmd+\
  - Command + Option + `b` → Command + `\`
- Shortwave: Option+A -> click Always apply on the label toast (1272, 890)
  - Option + `a` → `/usr/bin/osascript -l JavaScript "$HOME/.config/karabiner/scripts/restore-mouse-position.js"`, `Move cursor to (1272, 890)`, `Left Click`
- Notion: Cmd+Shift+E -> click archive on top notification (166, 135) (physical key k in Colemak)
  - Command + Shift + `k` → `/usr/bin/osascript -l JavaScript "$HOME/.config/karabiner/scripts/mouse-click.js" 166 135`
- Messages: Cmd+E -> open the emoji picker for the last received message (physical key k in Colemak)
  - Command + `k` → `/usr/bin/osascript -l JavaScript "$HOME/.config/karabiner/scripts/restore-mouse-position.js" 1.4`, `Move cursor to (360, 890)`, `Right Click`, `/usr/bin/osascript -l JavaScript "$HOME/.config/karabiner/scripts/move-to-tapback-picker.js"`, `Left Click`


## karabiner-config-to-markdown

This README is automatically generated from `karabiner.json` using [karabiner-config-to-markdown](https://github.com/raineorshine/karabiner-config-to-markdown).

