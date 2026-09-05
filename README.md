# Raine's Karabiner Config

This is my [Karabiner](https://karabiner-elements.pqrs.org) setup for custom key bindings.

The default config file is located at `~/.config/karabiner/karabiner.json`.

- Disable Cmd+M to minimize globally.
  - [any] + Command + `M` → Command + Option + Shift + `M`
- Claude: ⌘J → ⌘K, ⌘3 (New Session)
  - Command + `J` → Command + `N`, Command + `3`
- Claude: ⌥N → New Chat (physical key j in Colemak)
  - Option + `J` → Command + `N`, `return_or_enter`
- Claude: ⌘P → Choose Project (physical key r in Colemak)
  - Command + `R` → `"$HOME/.config/karabiner/scripts/bin/karabiner-config-ax-press" com.anthropic.claudefordesktop "{}" --role AXPopUpButton --sibling "Add another folder" --first --nth 2 --log`
- Claude: ⇧⌘P → Create PR (physical key r in Colemak)
  - Command + Shift + `R` → `Move cursor to (656, 875)`, `Left Click`
- Claude: ⇧⌘G → Show Diff
  - Command + Shift + `G` → `Move cursor to (230, 940)`, `Left Click`, Command + Shift + `D`
- Claude: ⇧⌘U → Usage (physical key i in Colemak)
  - Command + Shift + `I` → `"$HOME/.config/karabiner/scripts/bin/karabiner-config-ax-press" com.anthropic.claudefordesktop "Usage: {}" --role AXPopUpButton --log`
- Claude: ⌘B → ⌘. (Toggle Primary Sidebar)
  - Command + `B` → Command + `.`
- Claude: ⌥⌘B → ⌘\ (Toggle Secondary Sidebar)
  - Command + Option + `B` → Command + `\`
- Claude: ⌘. → ⇧⌘U (Choose Model)
  - Command + `.` → Command + Shift + `I`
- Claude: ⌘T → ⌃` (Toggle Terminal) (physical key f in Colemak)
  - Command + `F` → Ctrl + `` ` ``
- Claude: ⇧⌘E → Archive Session via its ⋮ menu, then select the next chat in the project (physical key k in Colemak)
  - Command + Shift + `K` → `/usr/local/bin/node "$HOME/.config/karabiner/scripts/claude-archive-next.js"`
- Claude: ⇧⌘1 → Go to Chat; ⇧⌘2 → Go to Code
  - Command + Shift + `1` → fn + Ctrl + `f2`, `T`, `;`, `return_or_enter`, `C`, `H`, `A`, `F`, `return_or_enter`
  - Command + Shift + `2` → fn + Ctrl + `f2`, `T`, `;`, `return_or_enter`, `C`, `;`, `G`, `K`, `return_or_enter`
- Claude: ⌥⌘. → Chat Context Menu
  - Command + Option + `.` → `"$HOME/.config/karabiner/scripts/bin/karabiner-config-ax-press" com.anthropic.claudefordesktop "More options for {}" --role AXPopUpButton --label-from "{}, rename session" --action AXShowMenu --first --log`
- Claude app: Cmd+R → open the session's PR link (via accessibility) (physical key s in Colemak)
  - Command + `S` → `"$HOME/.config/karabiner/scripts/bin/karabiner-config-ax-press" com.anthropic.claudefordesktop "#{}" --role AXLink --log`
- Quick Chars
  - L-Option + `'` → `` ` ``
  - L-Option + `T` → `~`
  - L-Option + `H` → `-`
  - L-Option + `Q` → `=`
  - L-Shift + L-Option + `Q` → `+`
  - L-Option + `U` → `_`
  - L-Option + `B` → `|`, `|`
  - [L-Shift] + L-Option + `Space` → `Space`
  - L-Option + `,` → `<`
  - L-Option + `.` → `>`
- Better Braces: Alt + O/I
  - L-Option + `L` → `[`
  - L-Option + `;` → `]`
  - L-Shift + L-Option + `L` → `{`
  - L-Shift + L-Option + `;` → `}`
  - L-Command + L-Option + `L` → L-Command + `[`
- Desktop Navigation: Right shift + brackets
  - R-Shift + `[` → L-Ctrl + `←`
  - R-Shift + `]` → L-Ctrl + `→`
- Launch apps: Right shift + letters
  - R-Shift + `A` → `open '/Applications/Utilities/Activity Monitor.app'`
  - R-Shift + `C` → `open '/Applications/Calendar.app'`
  - R-Shift + `E` → `open '/Applications/Sublime Text.app'`
  - R-Shift + `F` → `open /System/Library/CoreServices/Finder.app`
  - R-Shift + `G` → `open '/Applications/GitHub Desktop.app'`
  - R-Shift + `H` → `open '/Applications/Google Chrome.app'`
  - R-Shift + `N` → `open '/Applications/Notion.app'`
  - R-Shift + `K` → `open '/Applications/Karabiner-Elements.app'`
  - R-Shift + `M` → `open '/Applications/Messages.app'`
  - R-Shift + `S` → `open '/Applications/Spotify.app'`
  - R-Shift + `T` → `open '/Applications/iTerm.app'`
  - R-Shift + `V` → `open '/Applications/Brave Browser.app'`
  - R-Shift + `W` → `open '/Applications/WhatsApp.app'`
  - R-Shift + `Z` → `open '/Applications/zoom.us.app'`
- Move italic to Cmd + Ctrl + I to make room for easy tab navigation
  - Command + Ctrl + `L` → Command + `L`
- Tab Navigation: Cmd + H/I
  - Command + `H` → Command + L-Shift + `[`
  - Command + `L` → Command + L-Shift + `]`
- GitHub notifications: Cmd + Option + T
  - L-Command + L-Option + `T` → `open 'https://github.com/notifications'`
- em issues: Cmd + Ctrl + Option + E (physical key k in Colemak)
  - L-Command + L-Ctrl + L-Option + `K` → `open 'https://github.com/cybersemics/em/issues/'`
- Chromium DevTools: Clear site data, focus page, and reload: Cmd + Option + R
  - Command + Option + `R` → `/usr/bin/osascript -l JavaScript "$HOME/.config/karabiner/scripts/clear-site-data.js"`
- Shortwave: Cmd+B → Cmd+/
  - Command + `B` → Command + `slash`
- Shortwave: Cmd+Option+B → Cmd+\
  - Command + Option + `B` → Command + `\`
- Shortwave: Option+A → press Always apply on the label toast
  - Option + `A` → `"$HOME/.config/karabiner/scripts/bin/karabiner-config-ax-press" com.electron.shortwave "Always apply" --log`
- Notion: Cmd+Shift+E → click archive on top notification (166, 135) (physical key k in Colemak)
  - Command + Shift + `K` → `/usr/bin/osascript -l JavaScript "$HOME/.config/karabiner/scripts/mouse-click.js" 166 135`
- Messages: Cmd+E → open the emoji picker for the last received message (physical key k in Colemak)
  - Command + `K` → `/usr/bin/osascript -l JavaScript "$HOME/.config/karabiner/scripts/restore-mouse-position.js" 1.4`, `Move cursor to (360, 890)`, `Right Click`, `/usr/bin/osascript -l JavaScript "$HOME/.config/karabiner/scripts/move-to-tapback-picker.js"`, `Left Click`
- ChatGPT: Cmd+Shift+C → copy the last response (press its Copy button via accessibility)
  - Command + Shift + `C` → `"$HOME/.config/karabiner/scripts/bin/karabiner-config-ax-press" com.openai.codex Copy --sibling "Good response" --log`
- Karabiner-Elements: ⌘1-9, ⌘0 → settings sections (via accessibility)
  - Command + `1` → `"$HOME/.config/karabiner/scripts/bin/karabiner-config-ax-press" org.pqrs.Karabiner-Elements.Settings "Simple Modifications" --role AXStaticText --first --ancestor AXRow --set AXSelected=true --log`
  - Command + `2` → `"$HOME/.config/karabiner/scripts/bin/karabiner-config-ax-press" org.pqrs.Karabiner-Elements.Settings "Function Keys" --role AXStaticText --first --ancestor AXRow --set AXSelected=true --log`
  - Command + `3` → `"$HOME/.config/karabiner/scripts/bin/karabiner-config-ax-press" org.pqrs.Karabiner-Elements.Settings "Complex Modifications" --role AXStaticText --first --ancestor AXRow --set AXSelected=true --log`
  - Command + `4` → `"$HOME/.config/karabiner/scripts/bin/karabiner-config-ax-press" org.pqrs.Karabiner-Elements.Settings "Parameters" --role AXStaticText --first --ancestor AXRow --set AXSelected=true --log`
  - Command + `5` → `"$HOME/.config/karabiner/scripts/bin/karabiner-config-ax-press" org.pqrs.Karabiner-Elements.Settings "Devices" --role AXStaticText --first --ancestor AXRow --set AXSelected=true --log`
  - Command + `6` → `"$HOME/.config/karabiner/scripts/bin/karabiner-config-ax-press" org.pqrs.Karabiner-Elements.Settings "Virtual Keyboard" --role AXStaticText --first --ancestor AXRow --set AXSelected=true --log`
  - Command + `7` → `"$HOME/.config/karabiner/scripts/bin/karabiner-config-ax-press" org.pqrs.Karabiner-Elements.Settings "Profiles" --role AXStaticText --first --ancestor AXRow --set AXSelected=true --log`
  - Command + `8` → `"$HOME/.config/karabiner/scripts/bin/karabiner-config-ax-press" org.pqrs.Karabiner-Elements.Settings "UI" --role AXStaticText --first --ancestor AXRow --set AXSelected=true --log`
  - Command + `9` → `"$HOME/.config/karabiner/scripts/bin/karabiner-config-ax-press" org.pqrs.Karabiner-Elements.Settings "Update" --role AXStaticText --first --ancestor AXRow --set AXSelected=true --log`
  - Command + `0` → `"$HOME/.config/karabiner/scripts/bin/karabiner-config-ax-press" org.pqrs.Karabiner-Elements.Settings "Misc" --role AXStaticText --first --ancestor AXRow --set AXSelected=true --log`


## karabiner-config-to-markdown

This README is automatically generated from `karabiner.json` using [karabiner-config-to-markdown](https://github.com/raineorshine/karabiner-config-to-markdown).

