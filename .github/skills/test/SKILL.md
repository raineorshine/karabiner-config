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
| `.claude/karabiner-test.lock/` | the mutex + the pre-test snapshot | Held only while actually testing. |

**Acquire late, release fast.** Writing the rule, checking the Colemak mapping, and
`npm run build` need no lock. Take it only for the keypress test itself. An ax-press rule can be
`--dry-run` from a shell first — it resolves the target without pressing — so acquire only once that
passes.

## Procedure

### 1. Check the lock before starting

```bash
./scripts/karabiner-test-lock.sh status
```

If another session holds it, **do not wait in a loop.** Report who holds it and how long they
have had it, then either continue with lock-free work on this branch or ask the user — they are
the one pressing keys, so they know whether a test is genuinely in flight.

### 2. Acquire

```bash
./scripts/karabiner-test-lock.sh acquire "what you are testing"
```

Snapshots the live config into the lock. Re-running from the same worktree is a no-op and will
not re-snapshot, so an interrupted session can safely resume.

### 3. Install this branch's config

```bash
./scripts/karabiner-test-lock.sh install karabiner.json
```

Validates the JSON first (a bad file leaves the live config untouched), replaces it atomically so
Karabiner never sees a half-written file, then waits for Karabiner to log
`core_configuration is updated.` — positive confirmation the rules are live, not a blind sleep.
"already identical -- nothing to reload" means the branch's config matches what was already live;
Karabiner hashes the file and skips reloading unchanged content.

Working *in the main checkout* instead? Skip this step. The live file is already your working
file — just hold the lock so no worktree installs over you mid-test.

### 4. Test with the user

Ask the user to press the key, and say what you expect to happen. Karabiner rules are global, so
also name the app the rule is scoped to. Per AGENTS.md: a handful of presses cannot tell 100%
from 90% — if the behavior is at all probabilistic, say so rather than declaring it fixed.

### 5. Iterate without releasing

Edit `karabiner.json` in the worktree and re-run `install`. The lock stays held, so a
debugging loop costs one acquire and one release no matter how many rounds it takes.

### 6. Release

```bash
./scripts/karabiner-test-lock.sh release
```

Restores the snapshot and drops the lock. Do this as soon as the last press is done — do not hold
it while writing up results or shipping.

If the live config changed underneath you, release refuses rather than discarding the change, and
offers `--keep` (drop the lock, leave the live config alone) or `--force` (restore anyway). That
happens when someone hand-edited the live file, or when Karabiner rewrote it after a change in its
settings window. Pick `--keep` if the change was intentional; the snapshot path is printed either
way.

### 7. Ship

Release first, then follow the `ship` skill. Merging to `main` in the main checkout updates the
live config automatically, because that working tree *is* the live file.

## Hazards

- **Do not commit `karabiner.json` from the main checkout while another worktree holds the lock.**
  The live file contains *their* rules, and staging it would land those on `main`. Run `status`
  first. (`git merge --ff-only` protects itself — it refuses to overwrite the installed test
  config — so a `ship` that fails this way is correct; retry after the holder releases.)
- **Do not change anything in the Karabiner settings window while a lock is held.** Karabiner
  writes profile and device settings into the same file, so the edit lands on the test config and
  is caught as drift on release.
- **A rule that fires globally can interfere with the test itself** — including the keys you use
  to drive other tools. Scope rules to an app where possible.

## Stale locks

A lock older than 30 minutes is reported as `STALE` by `status`. Breaking it restores the snapshot
first, so recovery is well defined:

```bash
./scripts/karabiner-test-lock.sh break
```

Breaking a lock that is *not* yet stale requires confirming with the user that no test is in
flight, then `KARABINER_LOCK_STALE=0 ./scripts/karabiner-test-lock.sh break`. Never do this on a
hunch — the holder is mid-test with the user.

If everything is wedged, the snapshot is a plain file at
`.claude/karabiner-test.lock/karabiner.json.pre`; copy it over `~/.config/karabiner/karabiner.json`
by hand and delete the lock directory.
