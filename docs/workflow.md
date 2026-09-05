# Workflow: editing, testing, shipping

## Editing `karabiner.json`

**Do not round-trip the file through a JSON serializer.** Karabiner-Elements writes it in its own
style — short objects on one line (`"modifiers": { "mandatory": ["command"] }`), literal non-ASCII in
descriptions — and `json.dump` reformats all 1500 lines: a 40-line rule addition became a 1446-line
diff. Nothing breaks, and Karabiner rewrites the file in its own style eventually anyway; what is
lost is the diff, which is the only review surface a commit has, and clean hunk-level merging between
the worktrees that ship into this file in parallel. Insert the new rule as text at the surrounding
indentation, and use the parser to *validate* rather than to write.

## Testing a change (worktrees + the live-config lock)

`~/.config/karabiner/karabiner.json` is both the main checkout's working file and the only file
Karabiner-Elements reads. Worktrees keep their own copy, which Karabiner ignores — so **editing is
parallel, testing is serial**. Testing also contends for my keyboard: two sessions cannot both ask
me to press a key.

- Develop in a worktree under `.claude/worktrees/`. Leave the main checkout as the live slot.
- **Never copy a branch config over the live file directly.** Testing goes through the mutex in
  `scripts/karabiner-test-lock.sh`, which snapshots the live config first and restores it
  byte-exactly on release — including uncommitted work.
- Acquire late, release fast: writing the rule, the Colemak conversion, and `npm run build` need
  no lock. Take it only for the keypress test.
- **Finish the dry run before handing the turn back.** Handing over a rule whose target has not
  been resolved reads as "ready to test", so the next thing I do is invoke the test skill and wait
  for the lock — and the turn is spent discovering the dry run fails. If the dry run needs
  something only I can do (a particular screen open, an Accessibility regrant after a rebuild), ask
  for exactly that, in those words, and say the dry run is what it unblocks. By the time the turn
  comes back to me the rule is either dry-run clean and ready to lock, or the ask is a specific
  action, not a status report.
- Run `./scripts/karabiner-test-lock.sh status` before committing `karabiner.json` from the main
  checkout. While another worktree holds the lock, the live file contains *their* rules.
- Run the lock script with an explicit `cd` into the worktree. It derives the owner from the shell's
  cwd, and the Bash tool's cwd drifts back to the main checkout mid-session: a lock taken from there
  snapshots the live file, and `install karabiner.json` then compares the live file with itself and
  reports "already identical" while installing nothing.
- **Edit `karabiner.json` in place; never reformat it.** The file is Karabiner's own 4-space format
  with short arrays inline, and both `json.dump` and `prettier` (the repo's `.prettierrc.json` is
  2-space) rewrote the whole file — 2016 insertions for a 4-line change. `.prettierignore` now lists
  `karabiner.json`, so prettier leaves it alone; `json.dump` and any other serializer still will not.
  Patch the lines, and find a block's closing bracket by counting brackets: matching an indented `]`
  finds the wrong one and silently eats the lines between.
- `set -e` is inert in the Bash tool: a failing `false`, or a heredoc'd `python3` that raises, does
  not stop the rest of the command line (probed both). Chain a check and the steps behind it with
  `&&`; the learnings commit shipped past its own failed content check this way.
- Shipping pushes to `origin/main` from the worktree, so a main checkout dirty with someone else's
  installed test config no longer blocks landing. The local `main` fast-forwards whenever it next
  can, and until it does, the live file lags the rule that was shipped — worth saying, since that is
  the one consequence the user cannot see.

Full procedure: the **test** skill. Landing it on main: the **ship** skill.

## Session titles

The chat sidebar shows a status dot (running / awaiting input / idle) and a branch glyph for
worktree sessions; neither can be set from here — `set_session_title` takes a title string and
nothing else. So a **single leading emoji on the title** is the only lever, and it is spent on
what the app cannot know: where the work stands.

| Prefix | Means |
|---|---|
| 🔒 | holds the live-config test lock right now |
| 🧪 | rule verified by keypress, still on a branch — shippable without re-testing |
| 🚀 | shipping to `main`, or shipped |
| 🚙 | parked: the work is sound and waiting on the user (a decision, a batch of presses) |
| 🪦 | dead end — kept for the findings, not to resume |
| 📚 | extracting learnings into AGENTS.md or `docs/`, or done extracting them |

**Never mention a prefix in the response** — not what it was set to, not that it was already right,
not that it was left alone. It is sidebar state; say nothing about it unless asked.

These are **stages, not flags**: exactly one prefix at a time, and setting a new one replaces
whatever was there. Set a prefix **optimistically** — when the stage *starts*, not when it succeeds —
and correct it if the stage falls over. A title that only becomes true at the end is blank for the
whole stretch the sidebar is there to describe. Only one reads cleanly at sidebar width, and 🚀 after
🧪 is noise — the later stage implies the earlier.

The lifecycle 🔒 → 🧪 → 🚀 is set by skills (`test` acquires and releases; `ship` merges), so it
stays true on its own: `test` sets 🔒 before it acquires and drops it if denied, `ship` sets 🚀 before
it builds and puts it back if the push fails. 📚 is set by hand the moment the `learn` skill is
invoked — before reading anything or making any edit. The rest are set by hand when they apply, and
nothing reconciles a title against reality — an abandoned session keeps whatever prefix it had. 🚙 in
particular is worth setting before handing back on a long-running investigation: the idle dot cannot
tell "waiting on you" from "given up on".
