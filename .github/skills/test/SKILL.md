---
name: test
description: "Test a Karabiner rule from a worktree by installing it into the live config under a mutex, so parallel sessions do not clobber each other. Use when trying out, verifying, or debugging a key binding before shipping it — 'does this shortcut work', 'try this rule', 'test this binding'."
---

# Test (try a rule against the live config)

Karabiner-Elements reads exactly one file: `~/.config/karabiner/karabiner.json`, which is
*also* the main checkout's working-tree copy. Worktrees keep their own `karabiner.json`, but
Karabiner never reads those — so **editing is parallel, testing is serial**.

Testing contends for two single-slot resources: the live file, and the user's keyboard. Two
agents cannot both ask the user to press a key while two configs fight over one file. So a test
takes a mutex, held across the whole human interaction, not just the file copy.

`scripts/karabiner-test-lock.sh` is that mutex. It snapshots the live config *inside the lock*
before overwriting it, so release puts back byte-exactly whatever was there — committed or not —
and a lock abandoned by a dead session is still recoverable.

## Division of labor

| Where | What it holds | Rule |
|---|---|---|
| `~/.config/karabiner` (main checkout) | the live config Karabiner reads; `main` | Don't develop here. Treat it as the live slot. |
| `.claude/worktrees/*` | one branch each, own `karabiner.json` | All rule editing happens here, in parallel, lock-free. |
| `~/.config/karabiner/.claude/karabiner-test.lock/` | the mutex + the pre-test snapshot | Held only while actually testing. A worktree's copy of this directory is stale; ask `status`. |

**Acquire late, release fast.** Writing the rule, checking the Colemak mapping, and
`npm run build` need no lock. Take it only for the keypress test itself. An ax-press rule can be
`--dry-run` from a shell first — it resolves the target without pressing — so acquire only once that
passes. The exception is a change to the ax-press helper itself: building it replaces the live
binary, so acquire before `scripts/build-ax-press.sh` (docs/ax-press-helper.md).

## Procedure

### 1. Check the lock before starting

```bash
./scripts/karabiner-test-lock.sh status
```

If another session holds it, **do not wait in a loop.** The lock names the holding session, so
tell the user which chat it is and how long it has held the lock, then either continue with
lock-free work on this branch or ask the user — they are the one pressing keys, so they know
whether a test is genuinely in flight.

### 2. Acquire

Prefix this session's title with `🔓 ` first (`set_session_title`, replacing any existing lifecycle
prefix — see docs/workflow.md "Session titles"). Set it before the acquire, not after: if the acquire
is denied, drop the prefix again. Do not report this.

```bash
./scripts/karabiner-test-lock.sh acquire "what you are testing" "<this session's title>"
```

Pass this session's title as the third argument (read it from `get_session` with `"self"`, or set
`$KARABINER_SESSION`). It is recorded alongside the host session id, so a session denied the lock
can name the chat that holds it instead of only its worktree. Omitting it records
`(unnamed session)`.

Snapshots the live config into the lock. Re-running from the same worktree is a no-op and will
not re-snapshot, so an interrupted session can safely resume.

Once the acquire succeeds, swap the prefix to `🔒 ` — the lock is now actually held, so a session
denied the lock can spot the holder in the sidebar. Do not report this.

### 3. Install this branch's config

```bash
./scripts/karabiner-test-lock.sh install karabiner.json
```

Validates the JSON and runs Karabiner's own linter over the rules first (either failure leaves the
live config untouched), replaces it atomically so Karabiner never sees a half-written file, then
waits for Karabiner to log `core_configuration is updated.` — positive confirmation of the reload,
not a blind sleep. A reload is not proof every rule loaded: the daemon drops a manipulator it cannot
parse and loads the rest, so install then reads `/var/log/karabiner/core_service.log` and exits
`REJECTED` with the daemon's errors (docs/load-errors.md). A rejected config stays installed under
the lock; fix it and install again rather than asking for presses.
"already identical -- nothing to reload" means the branch's config matches what was already live;
Karabiner hashes the file and skips reloading unchanged content. A `REJECTED` file installed again
unchanged fails again with the errors recorded the first time.

Working *in the main checkout* instead? Skip this step. The live file is already your working
file — just hold the lock so no worktree installs over you mid-test.

### 4. Test with the user

Ask the user to press the key, and say what you expect to happen. Karabiner rules are global, so
also name the app the rule is scoped to. Per docs/debugging.md: a handful of presses cannot tell 100%
from 90% — if the behavior is at all probabilistic, say so rather than declaring it fixed.

### 5. Iterate without releasing

Edit `karabiner.json` in the worktree and re-run `install`. The lock stays held, so a
debugging loop costs one acquire and one release no matter how many rounds it takes.

### 6. Release

Swap the prefix to `🔓 ` before releasing. Do not report this.

```bash
./scripts/karabiner-test-lock.sh release
```

Restores the snapshot and drops the lock. Do this as soon as the last press is done — do not hold
it while writing up results or shipping.

Once it is released, retitle again: `📦 ` if the rule passed and is worth shipping without
re-testing, otherwise drop the `🔓 ` prefix entirely. Do not report this.

If the live config changed underneath you, release refuses rather than discarding the change, and
offers `--keep` (drop the lock, leave the live config alone) or `--force` (restore anyway). That
happens when someone hand-edited the live file, or when Karabiner rewrote it after a change in its
settings window. Pick `--keep` if the change was intentional; the snapshot path is printed either
way.

### 7. Ship

Release first, then follow the `ship` skill. It pushes to `origin/main` and then fast-forwards the
main checkout if that checkout is clean — which is what puts the rule in the live config, because
that working tree *is* the live file. While another worktree holds the lock the fast-forward waits;
the ship has still happened.

## Hazards

- **Do not commit `karabiner.json` from the main checkout while another worktree holds the lock.**
  The live file contains *their* rules, and staging it would land those on `main`. Run `status`
  first. (Shipping itself is unaffected: it pushes to `origin/main` from the worktree. What defers
  is the main checkout's local fast-forward, which refuses to overwrite the installed test config
  and lands once the holder releases.)
- **Do not change anything in the Karabiner settings window while a lock is held.** Karabiner
  writes profile and device settings into the same file, so the edit lands on the test config and
  is caught as drift on release.
- **A rule that fires globally can interfere with the test itself** — including the keys you use
  to drive other tools. Scope rules to an app where possible.

## A lock held for hours

**Age is not abandonment, at any age.** `status` prints how long the lock has been held and the
clock time it was taken, and stops there: a lock taken at 02:00 and still held at 09:00 is the
ordinary shape of this workflow — a rule installed for the user to press keys on, and a user who
went to bed. Nothing expires on its own, and the slot frees when they come back, try the rule and
the holder releases.

So `break` is never something to reach for from the age alone. It refuses on its own and needs the
user's word that nobody is mid-test — restoring the snapshot first, so recovery is well defined:

```bash
./scripts/karabiner-test-lock.sh break --confirmed
```

Ask before running it, and say what breaking costs: the rule the holder installed for the user goes
away, and their session is left believing it still holds the lock.

If everything is wedged, the snapshot is a plain file at
`~/.config/karabiner/.claude/karabiner-test.lock/karabiner.json.pre`; copy it over
`~/.config/karabiner/karabiner.json` by hand and delete that lock directory.
