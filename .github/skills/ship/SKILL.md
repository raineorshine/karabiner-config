---
name: ship
description: 'Finish a change in this karabiner config repo: regenerate README.md from karabiner.json, commit, rebase on main, squash, fast-forward merge into main, and push. Use when done with a key binding change and want it on main without opening a PR.'
---

# Ship (finish feature → merge to main)

Solo-developer workflow for this Karabiner config repo. Take the current branch (possibly in a worktree), regenerate the docs, land it on `main` as a single commit via fast-forward merge, and push to `origin`. No PR.

## Procedure

### 0. Release the test lock

```bash
./scripts/karabiner-test-lock.sh release
```

If this branch was tested via the `test` skill, its config is still installed in the live slot and
the lock is still held. Merging would fail at step 5 on your own installed config, so release
first. Harmless to run when no lock is held. Ship the rule you *tested* — if the branch changed
after the last test, re-test before shipping.

### 1. Build the README (must run before committing)

```bash
npm run build
```

- `npm run build` — runs `node build.js karabiner.json > README.md`, regenerating `README.md` from the current rules in `karabiner.json`.

`README.md` is a **generated file** — never hand-edit it. If a rule's description reads badly in the README, fix the `description` field in `karabiner.json` and rebuild. Prose that is not derived from the rules (the intro, the trailing section) lives in `readme-template.txt`.

There is no lint, type check, or test suite in this repo. If `karabiner.json` changed, sanity-check that the build succeeded and that the diff of `README.md` matches the rules you edited. Commit `README.md` together with `karabiner.json` so they never drift.

### 2. Commit all staged and unstaged changes

Generate a commit message from the diff. Use an imperative, sentence-case subject (`Add …`, `Remap …`, `Move …`, `Remove …`) to match the repo's history — no `type:` prefix. Describe the binding and its purpose, e.g. `Remap Cmd+J to Cmd+K, Cmd+3 in the Claude app for Colemak bug`.

Note that Karabiner-Elements rewrites `karabiner.json` itself (reformatting, `automatic_backups/`), so check `git diff` for incidental changes you did not make and leave them out of the commit if they are unrelated.

### 3. Rebase on main

```bash
git rebase main
```

If the rebase hits conflicts: resolve them (prefer the branch changes unless clearly wrong), `git add` the resolved files, `git rebase --continue`, and repeat until it completes. On a `README.md` conflict, don't resolve it by hand — take either side, finish the rebase, and re-run `npm run build` to regenerate it from the merged `karabiner.json`.

Skip this step and steps 4–5 if you are already on `main` in the main checkout; go straight to step 6.

### 4. Squash all commits into one

```bash
git reset --soft main && git commit -m "subject" -m "body"
```

Use a single message that describes the overall diff.

### 5. Fast-forward merge into main

Use this exactly — it resolves the branch and main-worktree paths, so nothing is hardcoded:

```bash
BRANCH=$(git branch --show-current) && MAIN=$(git worktree list | head -1 | awk '{print $1}') && git -C "$MAIN" merge --ff-only "$BRANCH"
```

**If the merge fails with "Your local changes … would be overwritten":** another worktree is mid-test and has installed its config into the live slot. Nothing is wrong; `./scripts/karabiner-test-lock.sh status` names the holder. Retry once they release.

**If `--ff-only` fails with "Not possible to fast-forward":** another worktree merged into `main` in the meantime, so this branch is no longer a direct descendant. This is expected when running parallel agent sessions and is safe — nothing was merged or lost. Recover by re-integrating on the new `main`:

1. Go back to **step 3** (`git rebase main`) — this replays this branch's single squashed commit onto the updated `main`, surfacing any genuine conflict with the work that landed first. Resolve conflicts the same way.
2. Redo **step 4** (`git reset --soft main && git commit`) to re-squash onto the new base.
3. Retry **step 5**.

Repeat until the fast-forward succeeds. Because `main`'s ref only advances via this atomic `--ff-only` step, at most one worktree wins each round and the others simply rebase and retry — no merge commits, no clobbering.

### 6. Push and post-merge

```bash
MAIN=$(git worktree list | head -1 | awk '{print $1}') && git -C "$MAIN" push origin main
```

- Push `main` to `origin` from the main worktree.
- If `package.json` or `package-lock.json` changed, run `npm install` in the main worktree so its dependencies match.
- The main worktree is `~/.config/karabiner` — the live config Karabiner-Elements reads. After merging a `karabiner.json` change there, the new bindings take effect immediately; no reload is needed. Verify the key actually works before considering the change done — ideally *before* merging, via the `test` skill, which installs the branch's config into the live slot under a mutex so parallel sessions do not clobber each other.
- The branch is now merged into `main`. If this worktree is finished with, it and the branch can be cleaned up from the main checkout:

  ```bash
  BRANCH=$(git branch --show-current) && MAIN=$(git worktree list | head -1 | awk '{print $1}') && git -C "$MAIN" worktree remove <this-worktree-path> && git -C "$MAIN" branch -d "$BRANCH"
  ```

  Only do this when the user confirms the worktree is no longer needed.
