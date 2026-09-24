# Karabiner config

## Guides

The rest of what has been learned here lives in `docs/`, one file per kind of rule. Read the one
that matches what you are about to write, before writing it.

- [docs/click-rules.md](docs/click-rules.md) — moving the pointer and clicking: coordinates, the
  cursor restore, warp-to-click gaps, and when posting events is filtered.
- [docs/accessibility-rules.md](docs/accessibility-rules.md) — pressing a control by name with
  `ax-press`: the resident helper a rule sends its request to, finding labels, the Accessibility
  grant and its rebuilds, what a press costs, walk direction, and opening a context menu without the
  mouse.
- [docs/accessibility-modes.md](docs/accessibility-modes.md) — why a press can log success and do
  nothing in an Electron app: Chromium's basic and complete accessibility modes, the 2s switch the
  helper waits for, and reproducing the first press after an app launch without relaunching it.
- [docs/load-errors.md](docs/load-errors.md) — why a rule can reload cleanly and never fire:
  manipulators Karabiner drops at load, the daemon log that names them, and what `install` checks.
- [docs/menu-bar-rules.md](docs/menu-bar-rules.md) — driving an app's own menus when it will not
  give a chord up.
- [docs/system-shortcut-rules.md](docs/system-shortcut-rules.md) — driving a macOS system action
  whose trigger cannot be synthesized: rebinding its `symbolichotkeys` record to a chord no key can
  reach, owning the fn key, and the `fn_function_keys` translation a rule's output still passes
  through.
- [docs/pauses.md](docs/pauses.md) — when `hold_down_milliseconds` is load-bearing and when it is
  superstition, and probing several values per round on a rule with equivalent chords.
- [docs/workflow.md](docs/workflow.md) — editing `karabiner.json`, testing under the live-config
  lock from a worktree, and what the session-title prefixes mean.
- [docs/debugging.md](docs/debugging.md) — what to suspect when a rule misbehaves, timing a press
  from the keypress, and measuring against the Claude app with video.

## Adding keyboard shortcuts (Colemak convention)

When I request a new shortcut or ask to tweak an existing shortcut, I'll state the app in the first line of my chat, e.g. "ChatGPT" or "Claude". That means to constrain the shortcut to that app.

I type in the **Colemak** layout. When I ask for a keyboard shortcut and don't say
"physical" or "virtual", I mean the **virtual key in Colemak** — the character
printed on the key I press, as Colemak produces it.

Karabiner's `from.key_code`, however, names the **physical key position** (by its
QWERTY label / scancode). So you must convert the virtual key I name back into the
physical key that produces it in Colemak before writing the rule.

## Rules

- **`from.key_code`** — convert the virtual key I name → physical key (table below).
- **`to` key_code** — leave as the literal virtual key I name; do **not** convert it.
  (Exception: some Claude-app shortcuts need the `to` side converted too — see
  "Exception" below **before** writing any Claude-app rule.)
- **`to` `shell_command`** — no key involved, nothing to convert.
- Digits (0–9) and most symbols are **not** remapped by Colemak — use them as-is on
  both sides.
- **Check the earlier manipulators on the same `key_code` before binding a chord.** Karabiner runs
  the first match, and a `from` with `optional: ["any"]` matches every superset chord: the global
  Cmd+M disable swallowed Cmd+Shift+M until the Claude app was exempted, while the Claude app's
  Cmd+. rule has no optional modifiers, which is what lets Cmd+Option+. fall through to a later rule.
- **Check which rules *emit* the key, too.** Karabiner never runs one manipulator's output through
  later rules, so an app-scoped remap of an arrow is skipped whenever the arrow came from vi mode
  rather than the keyboard. The emitting rule needs its own app-scoped copies, placed ahead of its
  generic manipulators.
- **Check what the app itself already binds to the chord, too.** A rule takes the chord from the app
  without a word. The menu bar's key equivalents are one System Events read (`AXMenuItemCmdChar` and
  `AXMenuItemCmdModifiers` of each menu item), and the ChatGPT app keeps my own overrides in
  `~/.codex/keybindings.json`, over the `defaultKeybindings` of the command registry in its
  `app.asar`: Cmd+Shift+F was already Toggle File Tree there. The Claude app's are literal
  `cmd+<x>` / `cmd+shift+<x>` strings in `Contents/Resources/ion-dist/assets/v1/*.js` (not `app.asar`),
  some behind a flag (`shortcut:c?["cmd+l","cmd+alt+l"]:"cmd+alt+l"`), so a listed chord may do nothing
  for me; `--else-key` hands it back either way. Brave's
  are `brave.accelerators` in
  `~/Library/Application Support/BraveSoftware/Brave-Browser/Default/Preferences`, with extensions'
  own shortcuts under `extensions.commands` there; a System Events walk of Brave's menus ran past 60s
  without finishing. When the rule's target exists on only some screens, `--else-key` hands the
  chord back everywhere else. A chord the app handles in a view rather than a menu item (Calendar's Ctrl+arrow resize and nudge) shows up in neither place;
  an empty menu read is not proof the chord is free, and it also means a menu-bar sequence cannot
  reach it.
- **Check what macOS itself binds, too**, which neither of those reads can see. The F-row is largely
  spoken for: Ctrl+F1-F7 is the keyboard-navigation family (menu bar, Dock, toolbar, window pane),
  Cmd+F5 is VoiceOver, and Option on a brightness or volume key opens that settings pane.
  `com.apple.symbolichotkeys` is where the system's own bindings are stored, so it answers what a
  chord costs before the rule takes it — and it is also how a system action's trigger is *moved* onto
  a chord a rule can emit ([docs/system-shortcut-rules.md](docs/system-shortcut-rules.md)).

After editing `karabiner.json`, run `npm run build`: it rewrites the file in exactly the format
Karabiner-Elements writes, so Karabiner's own saves leave no diff ([docs/workflow.md](docs/workflow.md)).

Always add a `description` (and a `(physical key <x> in Colemak)` note when it helps,
like the em-issues rule) so the mapping is self-documenting.

### Worked examples

- "Map `Cmd+D` → `Cmd+U`": virtual `d` is on physical `g`. Rule: `from` key_code
  `g`, `to` key_code `u`. → **Cmd+G → Cmd+U**.
- "em issues on `Cmd+Ctrl+Option+e`": virtual `e` is on physical `k`. Rule: `from`
  key_code `k`. (This is the existing `em issues` rule.)

## Virtual (Colemak) → physical (Karabiner `key_code`)

Only keys that differ are worth memorizing; the rest map to themselves.

| Virtual | Physical | | Virtual | Physical |
|---------|----------|-|---------|----------|
| d       | g        | | n       | j        |
| e       | k        | | o       | semicolon|
| f       | e        | | p       | r        |
| g       | t        | | r       | s        |
| i       | l        | | s       | d        |
| j       | y        | | t       | f        |
| k       | n        | | u       | i        |
| l       | u        | | y       | o        |
|         |          | | ;       | p        |

Unchanged (physical == virtual): `a b c h m q v w x z`, all digits, and Space/Enter/etc.

## Exception: some Claude-app shortcuts need the `to` side converted too

The Claude desktop app (`com.anthropic.claudefordesktop`) re-translates **some** of
Karabiner's output through the macOS Colemak input source
(https://github.com/anthropics/claude-code/issues/68859). For those shortcuts,
emitting the literal virtual key sends the app the wrong character (emitting `u`
arrives as `l`), so the `to` side must be converted with the table above:

- To send the app `Cmd+K`, emit key_code `n` (the `Cmd+J -> Cmd+K, Cmd+3` rule).
- To send the app `Cmd+Shift+U`, emit key_code `i` (the `Cmd+. -> Cmd+Shift+U` rule).

But not every shortcut is affected: the Show Diff rule (`Cmd+Shift+G`) emits a
literal key_code `d` and the app receives `Cmd+Shift+D`, and the `Cmd+Shift+E` rule
emits a literal key_code `e`. The app presumably matches some shortcuts by character
(re-translated) and others by key position (e.g. menu accelerators), but which is
which is only known empirically.

**Shortcut: if converting the `to` side would produce the same key_code as the `from`
side, the app is matching by position — emit the literal virtual key.** A rule whose
two sides are identical does nothing, so a request to "fix" a shortcut that lands on
the wrong physical key can only mean position matching. That is the `Cmd+Shift+E`
rule: I press physical `k` (which types `e`), the app's own shortcut fires on physical
`e` (which types `f` — the key I'd describe as the "F" key), so the rule maps
`from` key_code `k` → `to` literal key_code `e`. Requests of the form "map
Cmd+Shift+<X> (physical) to Cmd+Shift+<Y> (virtual)" where `<Y>` sits on physical
`<X>` are this same case.

Otherwise, when a Claude-app rule's `to` side emits a Colemak-remapped letter: start
with the converted key (two of the four known cases needed it), test, and record which
form worked in the rule's comment. Keys Colemak leaves unchanged (digits, most symbols,
`m`, etc.) look the same either way, which can mask a missing conversion — check the
table even when a rule "already works". This applies **only** to Claude-app rules;
everywhere else, leave the `to` side as the literal virtual key.

## Communication

- Report outcomes tersely: what was found, what was done — "1 instance: AGENTS.md. Removed and amended." Skip process narration and thoroughness reassurances; verify silently and state conclusions.
- Report a change as a bulleted list of fragments, not prose. "Default to warp-and-click." — not a paragraph restating what the new guidance says and why it matters.
- One idea per bullet. Name the change, not its justification: "Cost noted (~150ms)", "Diagnostic added".
- Learnings go under their own `📚 Learnings` heading after the change bullets, never as a bullet
  among them. What was built and what was written down are two reports, and a doc edit listed
  beside the rule it came from reads as part of the rule.
- Do not re-explain reasoning already established in the conversation, and do not re-argue a correction while reporting it. It was agreed; just say what landed.
- Omit anything with no consequence: "working tree clean", "JSON valid", "lint passed", "no incidental changes". Verification is assumed. Report a check only when it *failed* or changed what you did.
- Do not narrate git state — branches, refs, what is checked out where, what will conflict, who
  must rebase. git refuses anything unsafe and conflicts are the agent's to resolve, so a deferred
  fast-forward is one fragment: "Local main left at 95f33ab -- leaving the pull to the other
  branch." Not a paragraph on why it deferred and what the other branch faces.
- Keep caveats and side observations to one line each.
