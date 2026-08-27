# Adding keyboard shortcuts (Colemak convention)

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

## Click rules (move the mouse and click)

**Use a script, not Karabiner's cursor moves.** `software_function.set_mouse_cursor_position`
*warps* the cursor without posting a mouse event. Chromium/Electron apps track their hover target
from events, not from where the cursor is, so a button that only exists while its row is hovered
paints as hovered while the click hit-tests against the element underneath and activates that
instead. Every workaround fails: extra warps, one-point nudges, two-stage hovers, `mouse_key`
motion, double clicks, and dwell tuning in either direction.

`scripts/notion-archive-notification.js <x> <y>` walks the pointer there with real `CGEvent`s,
clicks with the modifier flags cleared, and restores the cursor. It takes coordinates, so reuse it
for any click rule rather than writing a new cursor-move sequence.

**`CGEventPost` works when Karabiner runs it, not when you do.** Posting CGEvents needs
Accessibility permission. `osascript` does not have it, but Karabiner does and the processes it
spawns inherit it. Run the same command from a terminal and the events are silently filtered and
the cursor never moves — that is *not* evidence the approach fails. Test a mechanism in the context
where it will actually run before ruling it out.

**If you do write a Karabiner-native click** (`pointing_button`), two non-obvious rules:

- The **last** `to` event is held down until the from key is released, so a trailing
  `pointing_button` keeps the mouse button down for as long as the chord is held — a press and
  drag, not a click. Put a `vk_none` after it.
- Mandatory modifiers are consumed on Karabiner's virtual keyboard, but the physical keys are still
  down when the click is posted, so it arrives as Shift+Click and extends a text selection across
  the page. Add `"modifiers": []` to the click.

**Coordinates** are absolute points on the main display, and only land while the target window is in
its usual position and size — say so in the rule's `comment`. `screencapture -R x,y,w,h` takes
points and returns a 2x image on this machine, which makes the pixel-to-point mapping explicit;
eyeballing a pasted screenshot does not.

**Validate before handing it over**: `karabiner_cli --lint-complex-modifications` on a
`{"title":…,"rules":[…]}` file, and `node build.js karabiner.json` to confirm the README renders.

## Debugging rules that misbehave

Learned the slow way on the Notion archive rule:

- **Use a control.** Clicking an always-visible button (the sidebar search icon) with the same
  sequence separated "synthetic clicks work in this app" from "this button is special" in a single
  press, after many rounds of theorizing had not.
- **Small samples lie near a threshold.** Once failures are probabilistic, "worked every time" over
  a handful of presses cannot distinguish 100% from 90%. Three configurations passed a short test
  and then failed in use. Do not tune to the smallest passing value — leave margin, or better,
  remove the race entirely.
- **A model that needs revising every round is the signal to stop tuning.** Five plausible models
  each explained the evidence and then broke. Stop turning knobs and find a decisive measurement.
- **Measure end-to-end.** A latency figure summed from a script's sleep constants was wrong about
  where the time actually went; timing the real command settled it in one step.

## Communication

- Report outcomes tersely: what was found, what was done — "1 instance: AGENTS.md. Removed and amended." Skip process narration and thoroughness reassurances; verify silently and state conclusions.
- Keep caveats and side observations to one line each.
