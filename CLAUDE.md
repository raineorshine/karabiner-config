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

## Exception: the Claude app converts the `to` side too

The Claude desktop app (`com.anthropic.claudefordesktop`) re-translates Karabiner's
output through the macOS Colemak input source
(https://github.com/anthropics/claude-code/issues/68859). So for any rule scoped to
the Claude app, convert **both** sides with the table above — the `from` side as
usual, and the `to` side so the re-translation lands on the intended key. Emitting
the literal virtual key sends the app the wrong character (e.g. emitting `u` arrives
as `l`).

- To send the app `Cmd+K`, emit key_code `n` (the `Cmd+J -> Cmd+K, Cmd+3` rule).
- To send the app `Cmd+Shift+U`, emit key_code `i` (the `Cmd+. -> Cmd+Shift+U` rule).

Keys Colemak leaves unchanged (digits, most symbols, `m`, etc.) look the same either
way, which can mask a missing conversion — check the table even when a rule "already
works". This applies **only** to Claude-app rules; everywhere else, leave the `to`
side as the literal virtual key.
