# Workflow: editing, testing, shipping

## Editing `karabiner.json`

**The file is kept in exactly the format Karabiner-Elements writes, and `npm run build` puts it
there.** Karabiner rewrites the live file whenever it saves it: keys sorted at every level, 4-space
indent, every object and array expanded one item per line, non-ASCII literal, no trailing newline —
byte-for-byte `JSON.stringify(<keys sorted>, null, 4)`, which `scripts/format-karabiner.js`
reproduces. Any other style is a pending whole-file diff: a hand-compacted file once left 1500 lines
of uncommitted change in the main checkout after Karabiner rewrote it, and that blocked the ship's
fast-forward of the live config. So edit however is convenient — a serializer round-trip is fine —
and let `npm run build` format before committing; `install` refuses a file that is not formatted.
`npm run build` also regenerates `README.md` from the rules.

**Never run prettier on `karabiner.json`.** The repo's `.prettierrc.json` is 2-space and would
rewrite the whole file; `.prettierignore` lists it.

**`comment` goes on the rule, beside `description`, never inside a manipulator.** Karabiner drops a
manipulator with a key it does not know and loads the rest, so the rule never fires. It reached the
live file twice before `install` learned to refuse it ([load-errors.md](load-errors.md)).

**Adjacent `shell_command`s in one `to` array collapse to the last one.** Two spawns back to back
run once, and the survivor is the later one — no error, nothing logged. Join them into one
`shell_command` with `;`, or put an event with `hold_down_milliseconds` between them. For helper
requests, chain with `--then` inside one request instead
([accessibility-rules.md](accessibility-rules.md)).

**A branch cut before the reformat runs the old tooling.** Its `npm run build` is its own
`package.json`'s, which only regenerates the README, and its ship skill is its own checkout's copy —
so a rule hand-written there stays compact through the whole ship, and the rebase carries it onto the
reformatted base as-is. The ship's `format-karabiner.js --check` after the squash catches it; on such
a branch, rebase first and then build, so the formatter that runs is main's.

## Testing a change (worktrees + the live-config lock)

`~/.config/karabiner/karabiner.json` is both the main checkout's working file and the only file
Karabiner-Elements reads. Worktrees keep their own copy, which Karabiner ignores — so **editing is
parallel, testing is serial**. Testing also contends for the user's keyboard and the real pointer
(`ax-press`, `mouse-click.js` and `move-to-tapback-picker.js` drive actual input). The **test** skill
is the full procedure; landing on main is the **ship** skill.

### When to take the lock

- Develop in a worktree under `.claude/worktrees/`. Leave the main checkout as the live slot.
- **Never copy a branch config over the live file directly.** Testing goes through the mutex in
  `scripts/karabiner-test-lock.sh`, which snapshots the live config first and restores it
  byte-exactly on release — including uncommitted work.
- Acquire late, release fast: writing the rule, the Colemak conversion, and `npm run build` need
  no lock. Take it only for the keypress test — and before building a helper change, which goes live
  the moment it builds ([ax-press-helper.md](ax-press-helper.md)).
- **Install and lock as soon as the rule is ready to test; do not wait to be told.** If `status`
  says `unlocked`, acquire, install, and hand back with the press to make — the user should never
  have to invoke the test skill themselves. Only a lock held by another session defers the install,
  and then say which chat holds it.
- **Finish the dry run before handing the turn back.** A rule whose target has not been resolved
  reads as "ready to test", and the next turn is then spent discovering the dry run fails. If the dry
  run needs something only the user can do (a particular screen open, an Accessibility regrant), ask
  for exactly that and say the dry run is what it unblocks.

### What the lock covers, and what it does not

- **The lock is the main checkout's; ask `status`, never `ls`.** The desktop app copies the main
  checkout's ignored `.claude/` contents into a new worktree, lock directory included, so a
  worktree's own `.claude/karabiner-test.lock/` names whoever held the lock at that moment and never
  changes.
- **Run the lock script with an explicit `cd` into the worktree.** It derives the owner from the
  shell's cwd, and the Bash tool's cwd drifts back to the main checkout mid-session: a lock taken from
  there snapshots the live file, and `install karabiner.json` then compares the live file with itself
  and reports "already identical" while installing nothing.
- **A lock broken out from under you took the installed config with it.** `break` restores the
  snapshot before dropping the lock, so the branch's rules are gone from the live file and nothing in
  this session says so. Re-acquire and re-install before asking for another press.
- Run `status` before committing `karabiner.json` from the main checkout. While another worktree
  holds the lock, the live file contains *their* rules.
- The lock covers the ax-press helper as well as the file: `scripts/build-ax-press.sh` refuses while
  another worktree holds it, post-ship rebuilds included ([ax-press-helper.md](ax-press-helper.md)).
- **The snapshot is content, not a commit, and nothing checks it against `main`.** `release` puts
  back byte-exactly what was live at `acquire`, so a live file *already* behind `main` then is put
  back just as faithfully. `acquire` notes when the live file differs from HEAD and names the
  deletions-only case, which is the shape of a live file behind `main`; only the caller knows whether
  the difference is theirs. Left unnoticed, it surfaces later as a fast-forward refusing against a
  file missing rules already shipped; `git -C <main> checkout -- karabiner.json` before the
  fast-forward is the fix then. Another session's test config shows up as additions instead, and
  that one is theirs to release.
- Shipping pushes to `origin/main` from the worktree, so a main checkout dirty with someone else's
  test config does not block landing. The local `main` fast-forwards whenever it next can; until
  then the live file lags the shipped rule — say so, since the user cannot see it.
- **Test a guard on a live resource without the live resource.** A refusal tested by running the
  real script does the harm the guard exists to prevent when the guard is wrong. Point
  `KARABINER_ROOT` at a scratch directory holding a hand-made lock, and run only the guard, cut out of
  the script, with a stand-in line for whatever it protects. Testing the lock script's install checks
  is in [load-errors.md](load-errors.md).

## Shell traps in the Bash tool

- `set -e` is inert: a failing `false`, or a heredoc'd `python3` that raises, does not stop the rest
  of the command line. Chain a check and the steps behind it with `&&`; a learnings commit shipped
  past its own failed content check this way.
- The shell is zsh, where `path` is the array tied to `PATH`: a loop variable named `path`
  (`while read -r id path`) empties `PATH`, and every later command in the loop reports
  `command not found`. Name it something else.
- `log` is a zsh builtin; call `/usr/bin/log`.

## Editing skills and docs

The repo's skills live in `.github/skills/<name>/SKILL.md`; `.claude/skills` is a symlink to that
directory. Git only ever names the `.github/` path — a diff that mentions `.github/skills/...` after
you edited `.claude/skills/...` is the same file, not a stray change.

**Docs are edited in parallel too, so fetch before restructuring one.** Every session's `learn` pass
writes into the same files, and two sessions once split the same doc the same day. Before moving
sections, `git fetch origin` and read `git log HEAD..origin/main -- AGENTS.md docs .github/skills`.
When a rebase collides with another restructure, keep one structure and port the other side's
additions into it; resolving hunk by hunk interleaves two layouts.

## Session titles

The prefix glossary arrives in every session from the `emotive` plugin, and nothing here repeats it.
These are the rows this repo can state exactly.

- 📦 means the rule was installed into the live slot and driven with real keypresses through the
  `test` skill, so it is shippable without re-testing. `npm run build` is formatting and README
  generation, not a gate.
- 🚀 ships to `origin/main`, squashed and fast-forwarded with no PR; the `ship` skill is that
  procedure and sets the prefix itself, once the push lands. 📦 holds until then.
- 🚙 is what this repo waits on the user for: a decision, or a batch of presses only they can make.
- 🔍 is inert here — the live config is guarded by the lock rather than by a warning to other
  sessions.
- 🔓 / 🔒 track `scripts/karabiner-test-lock.sh`, the mutex over the live config and the real input,
  and the skill that moves the lock sets them, not the response: 🔓 before acquiring and while queued
  or denied, 🔒 from acquired until the release, then 📦 or whatever stage the branch reached. When
  the answer to the hand-back was to ship, the release is `ship` step 0's, and it clears 🔒 the same
  way — a release that leaves the prefix standing puts a second holder in the sidebar. A session that
  sees another 🔒 leaves the live config and the input alone.
- 💾 covers the install into the live slot; a worktree editing its own `karabiner.json` is lock-free
  and is not 💾 work.
