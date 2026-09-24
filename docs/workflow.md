# Workflow: editing, testing, shipping

## Editing `karabiner.json`

**The file is kept in exactly the format Karabiner-Elements writes, and `npm run build` puts it
there.** Karabiner rewrites the live file whenever it saves it: keys sorted at every level, 4-space
indent, every object and array expanded one item per line, non-ASCII literal, no trailing newline —
byte-for-byte `JSON.stringify(<keys sorted>, null, 4)`, which `scripts/format-karabiner.js`
reproduces (checked against a file Karabiner had just rewritten). Any other style is a pending
whole-file diff: the file used to be hand-compacted (`"modifiers": { "mandatory": ["command"] }`),
Karabiner's rewrite of it left 1500 lines of uncommitted change in the main checkout, and that
blocked the ship's fast-forward of the live config. So edit however is convenient — a serializer
round-trip is fine now — and let `npm run build` format before committing; `install` refuses a file
that is not formatted. What the format protects is the diff, the only review surface a commit has,
and clean hunk-level merging between the worktrees that ship into this file in parallel.

**A branch cut before the reformat conflicts on every line of `karabiner.json` when rebased.** Format
the branch's file and commit that first (`npm run build`), then rebase: both sides are then in one
format and only the real edits conflict.

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
- **Install and lock as soon as the rule is ready to test; do not wait to be told.** If `status`
  says `unlocked`, acquire, install, and hand back with the press to make — the user should never
  have to invoke the test skill themselves. Only a lock held by another session defers the install,
  and then say which chat holds it.
- **Finish the dry run before handing the turn back.** Handing over a rule whose target has not
  been resolved reads as "ready to test", so the next thing I do is invoke the test skill and wait
  for the lock — and the turn is spent discovering the dry run fails. If the dry run needs
  something only I can do (a particular screen open, an Accessibility regrant), ask for exactly
  that, in those words, and say the dry run is what it unblocks. By the time the turn
  comes back to me the rule is either dry-run clean and ready to lock, or the ask is a specific
  action, not a status report.
- Run `./scripts/karabiner-test-lock.sh status` before committing `karabiner.json` from the main
  checkout. While another worktree holds the lock, the live file contains *their* rules.
- The lock covers the ax-press helper as well as the file: `scripts/build-ax-press.sh` replaces the
  one live binary, so it refuses while another worktree holds the lock, post-ship rebuilds included.
  Build once `status` reads `unlocked` ([accessibility-rules.md](accessibility-rules.md)).
- A worktree's own `.claude/karabiner-test.lock/` is not the lock. The desktop app copies the main
  checkout's ignored `.claude/` contents into a worktree when it creates one, lock directory
  included, so that copy names whoever held the lock at that moment and never changes. The lock is
  the main checkout's; ask `karabiner-test-lock.sh status`, never `ls`.
- Test a guard on a live resource without the live resource. A refusal tested by running the real
  script does the harm the guard exists to prevent when the guard is wrong. Point `KARABINER_ROOT` at
  a scratch directory holding a hand-made lock, and run only the guard, cut out of the script, with
  a stand-in line for whatever it protects.
- Run the lock script with an explicit `cd` into the worktree. It derives the owner from the shell's
  cwd, and the Bash tool's cwd drifts back to the main checkout mid-session: a lock taken from there
  snapshots the live file, and `install karabiner.json` then compares the live file with itself and
  reports "already identical" while installing nothing.
- **Never run prettier on `karabiner.json`.** The repo's `.prettierrc.json` is 2-space and would
  rewrite the whole file; `.prettierignore` lists it. Karabiner's format comes from `npm run build`.
- **`comment` goes on the rule, beside `description`, never inside a manipulator.** Karabiner drops a
  manipulator with a key it does not know and loads the rest, so the rule never fires. It reached the
  live file twice before `install` learned to refuse it ([load-errors.md](load-errors.md)).
- **A worktree's own `.claude/karabiner-test.lock/` means nothing.** A new worktree can arrive with a
  copy of the main checkout's `.claude/`, including a lock some other session held at that moment.
  The script only reads the lock under the main checkout, so `status` is the answer, not `ls`.
- `set -e` is inert in the Bash tool: a failing `false`, or a heredoc'd `python3` that raises, does
  not stop the rest of the command line (probed both). Chain a check and the steps behind it with
  `&&`; the learnings commit shipped past its own failed content check this way.
- The Bash tool's shell is zsh, where `path` is the array tied to `PATH`: a loop variable named `path`
  (`while read -r id path`) empties `PATH`, and every later command in the loop reports
  `command not found`, `jq` and `sed` included. Name it something else.
- **The snapshot is content, not a commit, and nothing checks it against `main`.** `release` restores
  byte-exactly what was live at `acquire`, which is the point — it must survive uncommitted work —
  but it also means that a live file *already* behind `main` when the lock was taken is put back
  just as faithfully, however long the lock was held. Note that a ship cannot cause this: its
  `merge --ff-only` refuses against an installed test config, which is the whole reason it defers.
  `acquire` now says so when the live file already differs from HEAD, and names the deletions-only
  case specifically, which is the shape of a live file behind `main` rather than ahead of it. It is
  a note, not a refusal — surviving uncommitted work is the point, and only the caller knows which
  kind theirs is. Left unnoticed, the same thing surfaces much later as a fast-forward refusing
  against a file missing rules already shipped; `git -C <main> checkout -- karabiner.json` before
  the fast-forward is the fix then. Another session's test config shows up as additions instead,
  and that one is theirs to release.
- Shipping pushes to `origin/main` from the worktree, so a main checkout dirty with someone else's
  installed test config no longer blocks landing. The local `main` fast-forwards whenever it next
  can, and until it does, the live file lags the rule that was shipped — worth saying, since that is
  the one consequence the user cannot see.

Full procedure: the **test** skill. Landing it on main: the **ship** skill.

## Editing a skill

The repo's skills live in `.github/skills/<name>/SKILL.md`; `.claude/skills` is a symlink to that
directory. Either path edits the same file, but git only ever names the `.github/` one — a diff
that mentions `.github/skills/...` after you edited `.claude/skills/...` is the same file, not a
stray change.

## Session titles

The prefix glossary arrives in every session from the `emotive` plugin, and nothing here repeats it.
These are the rows this repo can state exactly.

- 📦 means the rule was installed into the live slot and driven with real keypresses through the
  `test` skill, so it is shippable without re-testing. `npm run build` only regenerates `README.md`
  from `karabiner.json`; it is part of shipping, not a gate.
- 🚀 ships to `origin/main`, squashed and fast-forwarded with no PR; the `ship` skill is that
  procedure and sets the prefix itself, once the push lands. 📦 holds until then.
- 🚙 is what this repo waits on the user for: a decision, or a batch of presses only they can make.
- 🔍 is inert here — the live config is guarded by the lock rather than by a warning to other
  sessions.

**The live config is one file, and this checkout is it.** `~/.config/karabiner` *is* the main
checkout, so its working-tree `karabiner.json` is the single file Karabiner-Elements reads, and the
real mouse and keyboard are just as shared — `scripts/ax-press.swift`, `mouse-click.js` and
`move-to-tapback-picker.js` drive actual input, so two sessions testing at once fight over the
pointer. `scripts/karabiner-test-lock.sh` is the mutex over both. The skill that moves the lock sets
the prefixes, not the response: 🔓 before acquiring and while queued or denied, 🔒 from acquired until
the release, then 📦 or whatever stage the branch reached. That release is `ship` step 0's whenever
the answer to the hand-back was to ship, and it clears 🔒 the same way — a release that leaves the
prefix standing puts a second holder in the sidebar, where only one can be true. A session that sees
another 🔒 leaves the live config and the input alone — installing over it swaps the rule under a
test already running. 💾 covers the install into that slot; a worktree editing its own
`karabiner.json` is lock-free and is not 💾 work.
