---
name: ship
description: 'Finish a change in this karabiner config repo: regenerate README.md from karabiner.json, commit, rebase on origin/main, squash, push to origin/main, and fast-forward the local main if it can. Use when done with a key binding change and want it landed without opening a PR.'
---

# Ship (finish feature → merge to main)

Solo-developer workflow for this Karabiner config repo. Take the current branch (possibly in a worktree), regenerate the docs, squash it to a single commit, and push it to `origin/main`. No PR.

`origin/main` is the source of truth, not the local `main` ref — the main checkout is also the live config slot, so it can be dirty (another worktree mid-test) exactly when you want to land. Pushing from the worktree keeps shipping independent of that, the way a contributor pushes without touching anyone else's checkout; the local `main` catches up whenever it can fast-forward.

## Procedure

### 0. Prefix the session title with 🚀, then release the test lock

Read the session's title (`mcp__ccd_session_mgmt__get_session` with `"self"`) and set it back with a
`🚀 ` prefix (`mcp__ccd_session_mgmt__set_session_title`), replacing any existing lifecycle prefix
rather than stacking — a shipping session was usually `🧪 ` a moment ago. Do this **now**, before any
of the work: the sidebar should say what the session is doing while it is doing it. Step 8 puts the
title back if the ship does not land. Do not report either. See docs/workflow.md "Session titles".

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

Note that Karabiner-Elements rewrites `karabiner.json` itself (reformatting, `automatic_backups/`), so check `git diff` for incidental changes you did not make and leave them out of the commit if they are unrelated.

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

### 6. Fast-forward the local main if it can

```bash
MAIN=$(git worktree list | head -1 | awk '{print $1}') && git -C "$MAIN" merge --ff-only origin/main
```

The main checkout is `~/.config/karabiner`, whose `karabiner.json` *is* the file Karabiner-Elements reads, so this is what puts the shipped rule into the live config. It takes effect immediately; no reload.

**If it fails with "Your local changes … would be overwritten":** another worktree is mid-test and has its config installed in the live slot. Leave it — never `checkout --` their work away. The ship already happened at step 5; only the local ref and the live file lag. `./scripts/karabiner-test-lock.sh status` names the holder. **Say so in the report**, with the command above, since until someone runs it the live config still lacks the rule that was just shipped.

Whoever fast-forwards next picks up every commit that accumulated on `origin/main`, so a skipped one costs nothing but the delay.

### 7. Post-ship

- If `package.json` or `package-lock.json` changed, run `npm install` in the main worktree so its dependencies match.
- Verify the key actually works before considering the change done — ideally *before* shipping, via the `test` skill, which installs the branch's config into the live slot under a mutex so parallel sessions do not clobber each other.
- The branch is now on `origin/main`. If this worktree is finished with, it and the branch can be cleaned up from the main checkout:

  ```bash
  BRANCH=$(git branch --show-current) && MAIN=$(git worktree list | head -1 | awk '{print $1}') && git -C "$MAIN" worktree remove <this-worktree-path> && git -C "$MAIN" branch -d "$BRANCH"
  ```

  Only do this when the user confirms the worktree is no longer needed. `git branch -d` refuses while local `main` is behind the pushed commit; `git branch -d` against `origin/main` is not a thing, so wait for step 6 to land rather than forcing with `-D`.

### 8. Correct the title if the ship did not land

The push in step 5 is what counts as shipped, whether or not step 6 could fast-forward. If it
succeeded, the `🚀 ` from step 0 is already right — leave it. If it failed, or the ship was abandoned
before the push, put the title back to the prefix that is true now (`🧪 ` for a tested branch, none
otherwise). Do not report this step.

### 9. Print the completion message

Print `🚀 Shipped` as the last line of the response.
