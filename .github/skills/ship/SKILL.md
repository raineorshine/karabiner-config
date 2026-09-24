---
name: ship
description: 'Finish a change in this karabiner config repo: regenerate README.md from karabiner.json, commit, rebase on origin/main, squash, push to origin/main, fast-forward the local main if it can, and extract the session's learnings. Use when done with a key binding change and want it landed without opening a PR.'
---

# Ship (finish feature → merge to main)

Solo-developer workflow for this Karabiner config repo. Take the current branch (possibly in a worktree), regenerate the docs, squash it to a single commit, and push it to `origin/main`. No PR.

`origin/main` is the source of truth, not the local `main` ref — the main checkout is also the live config slot, so it can be dirty (another worktree mid-test) exactly when you want to land. Pushing from the worktree keeps shipping independent of that, the way a contributor pushes without touching anyone else's checkout; the local `main` catches up whenever it can fast-forward.

## Procedure

### 0. Release the test lock

Leave the title's prefix alone here, with one exception. `🚀 ` means shipped, and nothing is
shipped until the push in step 5 lands — a title claiming it earlier is wrong for the whole ship,
and stays wrong if the ship falls over. A shipping session keeps whatever is true meanwhile, usually
`📦 `. Step 5 sets `🚀 ` once the push succeeds. Do not report this. See docs/workflow.md "Session
titles".

**The exception is `🔒 `: swap it to `📦 ` before releasing.** Arriving with it is the ordinary path
— `test` hands back with the rule still installed in the live config and the lock still held, and
"ship" is the answer that hand-back was waiting for — so the release below is what makes the prefix
false, and nothing before step 5 reads the title again. Left standing, it tells every other session
the live config is this branch's for the whole ship: a second `🔒 ` where only one can be true, and
one that stays wrong if the ship falls over short of step 5. `📦 ` is what is true instead, since a
branch that came through `test` is built and tested. A `--if-mine` that releases nothing releases no
prefix either — leave whatever is there.

```bash
./scripts/karabiner-test-lock.sh release --if-mine
```

If this branch was tested via the `test` skill, its config is still installed in the live slot and
the lock is still held. The local fast-forward in step 6 would fail on your own installed config,
so release first. `--if-mine` releases only a lock *this session* took: no lock means the branch needed no
testing (a typo fix) and is safe to ship, and another session's lock is theirs. Both are silent
no-ops — do not report them. Ship the rule you *tested* — if the branch changed after the last
test, re-test before shipping.

### 1. Build the README (must run before committing)

```bash
npm run build
```

- `npm run build` — runs `node build.js karabiner.json > README.md`, regenerating `README.md` from the current rules in `karabiner.json`.
- Works from a worktree without `npm install`: a worktree has no `node_modules`, and node resolves the main checkout's by walking up from `.claude/worktrees/<name>/`.

`README.md` is a **generated file** — never hand-edit it. If a rule's description reads badly in the README, fix the `description` field in `karabiner.json` and rebuild. Prose that is not derived from the rules (the intro, the trailing section) lives in `readme-template.txt`.

There is no lint, type check, or test suite in this repo. If `karabiner.json` changed, sanity-check that the build succeeded and that the diff of `README.md` matches the rules you edited. Commit `README.md` together with `karabiner.json` so they never drift.

### 2. Commit all staged and unstaged changes

Generate a commit message from the diff. Use an imperative, sentence-case subject (`Add …`, `Remap …`, `Move …`, `Remove …`) to match the repo's history — no `type:` prefix. Describe the binding and its purpose, e.g. `Remap Cmd+J to Cmd+K, Cmd+3 in the Claude app for Colemak bug`.

`npm run build` also rewrites `karabiner.json` in Karabiner-Elements' own format (docs/workflow.md "Editing `karabiner.json`"), so Karabiner's own saves of the live file leave no diff behind. Check `git diff` for changes you did not make — a setting changed in Karabiner's window lands in the same file — and leave them out of the commit if they are unrelated.

### 3. Rebase on origin/main

```bash
git fetch origin && git rebase origin/main
```

Rebase on `origin/main`, not the local `main` ref: another session may have pushed without the main checkout being able to fast-forward, so local `main` can be behind what you must land on.

If the rebase hits conflicts: resolve them (prefer the branch changes unless clearly wrong), `git add` the resolved files, `git rebase --continue`, and repeat until it completes. On a `README.md` conflict, don't resolve it by hand — take either side, finish the rebase, and re-run `npm run build` to regenerate it from the merged `karabiner.json`.

Skip this step and step 4 if you are already on `main` in the main checkout; commit there and go straight to step 5.

### 4. Squash all commits into one

```bash
git reset --soft origin/main && git commit -m "subject" -m "body"
```

Use a single message that describes the overall diff.

### 5. Push to origin/main

```bash
git push origin HEAD:main
```

This is the ship. It runs from the worktree and touches no other working tree, so a main checkout that is dirty — another worktree's test config installed in the live slot — cannot block it.

**If the push is rejected as non-fast-forward:** someone else landed first. Nothing was lost. Go back to **step 3** (`git fetch origin && git rebase origin/main`), redo **step 4** to re-squash onto the new base, and push again. Because `origin/main` only advances by fast-forward, at most one branch wins each round and the others rebase and retry — no merge commits, no clobbering.

**Once the push succeeds, and not before,** read the session's title
(`mcp__ccd_session_mgmt__get_session` with `"self"`) and set it back with a `🚀 ` prefix
(`mcp__ccd_session_mgmt__set_session_title`), replacing the `📦 ` rather than stacking. A rejected
push is not a ship, so retry the round above and set it only when one lands. Do not report this.

### 6. Fast-forward the local main if it can

```bash
MAIN=$(git worktree list | head -1 | awk '{print $1}') && git -C "$MAIN" merge --ff-only origin/main
```

The main checkout is `~/.config/karabiner`, whose `karabiner.json` *is* the file Karabiner-Elements reads, so this is what puts the shipped rule into the live config. It takes effect immediately; no reload.

**If it fails with "Your local changes … would be overwritten", resolving it is this session's job, not the user's.** Run `./scripts/karabiner-test-lock.sh status` first:

- **Locked:** another worktree is mid-test with its config in the live slot. Leave it — never `checkout --` their work away. The ship already happened at step 5; only the local ref and the live file lag, and the holder's release is what unblocks it. One line in the report.
- **Unlocked:** nobody's test is installed, so find out what the change is. Compare the live file with `HEAD` *parsed* (`json.load` both): equal means the diff is formatting alone — Karabiner rewriting the file in its own style, which `npm run build` now prevents for anything shipped after it — and it is safe to `checkout --` and fast-forward. Unequal means real edits someone made there (the settings window, a hand edit): copy the live file aside, then decide from what the edits are, and do not hand the user a command to run instead.

Whoever fast-forwards next picks up every commit that accumulated on `origin/main`, so a skipped one costs nothing but the delay.

### 7. Post-ship

- If `package.json` or `package-lock.json` changed, run `npm install` in the main worktree so its dependencies match.
- If `scripts/ax-press.swift` or `scripts/build-ax-press.sh` changed, rebuild the live helper from the shipped commit — the binary a test installed predates the rebase:

  ```bash
  ./scripts/build-ax-press.sh
  ```

  It refuses while another session holds the test lock, since the rebuild would swap the helper under that session's test. Refused, check `./scripts/karabiner-test-lock.sh status` again before the session ends and build once it reads `unlocked`; if it never does, **say so in the report** with the command, since the live helper lacks what just shipped until someone runs it (docs/ax-press-helper.md).
- Verify the key actually works before considering the change done — ideally *before* shipping, via the `test` skill, which installs the branch's config into the live slot under a mutex so parallel sessions do not clobber each other.
- The branch is now on `origin/main`. If this worktree is finished with, it and the branch can be cleaned up from the main checkout:

  ```bash
  BRANCH=$(git branch --show-current) && MAIN=$(git worktree list | head -1 | awk '{print $1}') && git -C "$MAIN" worktree remove <this-worktree-path> && git -C "$MAIN" branch -d "$BRANCH"
  ```

  Only do this when the user confirms the worktree is no longer needed. `git branch -d` refuses while local `main` is behind the pushed commit; `git branch -d` against `origin/main` is not a thing, so wait for step 6 to land rather than forcing with `-D`.

### 8. Check the title still says what is true

The `🚀 ` set in step 5 stays through the report and after it, until the session starts something
else — never cleared to leave a bare title. If the ship never got that far, no `🚀 ` went on and
there is nothing to undo: check the title still says what is true now (`📦 ` for a tested branch,
`🔓 ` just after a release, `🚙 ` if it waits on the user) and correct it if not. Do not report this.

### 9. Extract the learnings

Invoke the `learn` skill. A shipped change is the moment its lessons are worth writing down: the
branch is landed, nothing is pending, and whatever the session learned about the rule, the app or
the workflow is still in context — an hour later it is in nobody's. This is not optional and the
user does not have to ask for it; it is the last stage of shipping.

Put `📚 ` on the title as you invoke it — the user-level `learn` sets none itself — replacing the
`🚀 `, and put `🚀 ` back when it finishes: the session
shipped, and that is the stage it rests at.

Run it on every ship — a second ship in the same session, and a ship whose change was itself an
instruction-file edit, included. A ship that skipped it with "nothing new" was caught by the user:
the stretch since the last pass had a user correction in it, which is exactly what `learn` exists to
keep. If `learn` finds nothing worth recording, that is a normal outcome — say so in one line and move on.

### 10. Print the completion message

Print `🚀 Shipped` as the last line of the response, after the learn report.
