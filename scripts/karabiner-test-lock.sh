#!/bin/sh
# Mutex for the live Karabiner config (~/.config/karabiner/karabiner.json).
#
# Karabiner-Elements reads exactly one file, which is also the main checkout's
# working-tree copy. Worktrees can edit their own karabiner.json freely, but
# testing a rule means installing it into that single live slot -- and asking
# the user to press keys. Both are single-slot resources, so testing is
# serialized through this lock.
#
# The pre-test contents of the live file are snapshotted inside the lock, so
# release restores byte-exactly whatever was there (committed or not), and a
# lock abandoned by a dead session can still be recovered by `break`.
#
#   acquire [label] [session]
#                     take the lock and snapshot the live config, saying so if that
#                     file already differs from HEAD; `session` names
#                     the Claude session holding it, so a denied request can say
#                     which chat to go to (falls back to $KARABINER_SESSION)
#   install <file>    replace the live config (atomic; waits for reload), refusing
#                     rules Karabiner's linter rejects, and failing if the daemon
#                     logs an error loading it
#   release           restore the snapshot and drop the lock
#                     --keep     drop the lock, leave the live config as it is
#                     --force    restore even if the live config changed
#                     --if-mine  no-op unless this session took the lock
#   status            who holds it, since when, whether stale
#   break             force-release a lock left behind by a dead session
set -eu

ROOT=${KARABINER_ROOT:-$(git worktree list --porcelain | head -1 | sed 's/^worktree //')}
LIVE="$ROOT/karabiner.json"
LOCK="$ROOT/.claude/karabiner-test.lock"
BACKUP="$LOCK/karabiner.json.pre"
STALE_SECONDS=${KARABINER_LOCK_STALE:-1800}
LOG="${KARABINER_LOG:-$HOME/.local/share/karabiner/log/console_user_server.log}"
# The root daemon's log, world-readable: the only one that names a manipulator
# dropped at load.
DAEMON_LOG="${KARABINER_DAEMON_LOG:-/var/log/karabiner/core_service.log}"
CLI="${KARABINER_CLI:-/Library/Application Support/org.pqrs/Karabiner-Elements/bin/karabiner_cli}"

SELF=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
NOW=$(date +%s)
# The worktree identifies the lock's owner, but the user's question when a
# request is denied is "which of my chats is that?" -- so record the session
# too. The id is in the environment; the human-readable title is not, so the
# caller passes it (the `test` skill reads it from get_session "self").
SESSION_ID=${CLAUDE_CODE_HOST_SESSION_ID:-${CLAUDE_SESSION_ID:-}}

die() { printf '%s\n' "$*" >&2; exit 1; }
field() { cat "$LOCK/$1" 2>/dev/null || printf '(unknown)'; }
age() {
  held=$(cat "$LOCK/acquired" 2>/dev/null || printf '%s' "$NOW")
  printf '%s' $(( NOW - held ))
}
holder_report() {
  printf 'held by   %s\n' "$(field label)"
  printf 'session   %s\n' "$(field session)"
  if [ -s "$LOCK/session_id" ]; then printf 'session id %s\n' "$(field session_id)"; fi
  printf 'worktree  %s\n' "$(field worktree)"
  printf 'branch    %s\n' "$(field branch)"
  printf 'age       %sm (stale after %sm)\n' "$(( $(age) / 60 ))" "$(( STALE_SECONDS / 60 ))"
}
owned() { [ "$(field worktree)" = "$SELF" ]; }
# STALE_SECONDS=0 means "treat any lock as abandoned" -- the documented override
# for breaking a live lock once the user has confirmed nobody is mid-test.
is_stale() { [ "$(age)" -ge "$STALE_SECONDS" ]; }

# Print what log $1 has written past byte offset $2. Karabiner rotates a log at
# 256KB (x.log -> x.1.log), so one now shorter than the offset has rotated since,
# and the rest of the old file comes first.
since() {
  if [ "$(wc -c < "$1")" -lt "$2" ]; then
    tail -c "+$(( $2 + 1 ))" "${1%.log}.1.log" 2>/dev/null
    cat "$1"
  else
    tail -c "+$(( $2 + 1 ))" "$1"
  fi
}

# Replace the live config atomically so Karabiner never observes a partial file,
# then wait for it to report the reload. Prints a warning rather than failing if
# the log is unavailable -- the replacement itself still succeeded. Leaves the
# daemon log's size from before the replace in $daemon_mark, where `install`
# reads this reload's errors; empty when nothing was replaced, so there is no
# reload to check.
#
# Deliberately does NOT validate: restoring a snapshot must always be possible.
# A snapshot that will not parse is still what was live before, and refusing to
# put it back would strand the branch's test config in the live slot -- the one
# outcome this whole mechanism exists to prevent. Validation belongs on the
# forward install (see the `install` command), where a bad file is the caller's.
replace_live() {
  src=$1
  daemon_mark=
  # Karabiner hashes the config and skips the reload when the content is
  # unchanged, so waiting for a log line here would always time out. Verified:
  # an identical atomic replace logs nothing, a differing one logs in ~20ms.
  if cmp -s "$src" "$LIVE"; then
    printf 'live config already identical -- nothing to reload\n'; return 0
  fi
  mark=0
  [ -f "$LOG" ] && mark=$(wc -c < "$LOG")
  daemon_mark=0
  [ -r "$DAEMON_LOG" ] && daemon_mark=$(wc -c < "$DAEMON_LOG")
  tmp="$ROOT/.karabiner.json.tmp.$$"
  cat "$src" > "$tmp"
  mv "$tmp" "$LIVE"
  [ -f "$LOG" ] || { printf 'installed (no Karabiner log; reload unverified)\n'; return 0; }
  n=0
  while [ "$n" -lt 50 ]; do
    if since "$LOG" "$mark" | grep -q 'core_configuration is updated'; then
      printf 'installed and reloaded\n'; return 0
    fi
    sleep 0.2; n=$(( n + 1 ))
  done
  printf 'installed, but Karabiner did not log a reload within 10s -- check the log\n' >&2
}

# Run Karabiner's own linter over the file's rules before they go live. It names
# a broken rule by its description, where the daemon's log shows only a
# truncated dump of the manipulator; `rejected` still covers everything outside
# the rules. The linter reads a rules file for distribution, which needs a
# `title`: without one it misreads the whole object as a single rule. --silent
# drops the path and the "ok", leaving only errors.
lint() {
  [ -x "$CLI" ] || return 0
  errors=$(node -e 'const c = JSON.parse(require("fs").readFileSync(process.argv[1], "utf8"))
    const rules = (c.profiles || []).flatMap(p => (p.complex_modifications || {}).rules || [])
    process.stdout.write(JSON.stringify({ title: "karabiner.json", rules }))' "$1" |
    "$CLI" --silent --lint-complex-modifications /dev/stdin) && return 0
  printf 'Karabiner rejects rules in %s (live config left untouched):\n%s\n' "$1" "$errors" >&2
  exit 1
}

# Print the errors the daemon logged loading what `replace_live` just put in
# place. A reload is no proof the rules loaded: the daemon drops a manipulator it
# cannot parse, loads the rest, and both processes log "core_configuration is
# updated." either way. Nothing marks the end of a load, so wait well past the
# errors' lag behind the daemon's own "updated": 3-6ms over seven reloads, with
# the bad manipulator first or last.
rejected() {
  [ -r "$DAEMON_LOG" ] || { printf 'no Karabiner daemon log -- dropped rules unverified\n' >&2; return 0; }
  # A file the daemon cannot parse at all logs its error instead of "updated".
  n=0
  until since "$DAEMON_LOG" "$daemon_mark" | grep -q -e 'core_configuration is updated' -e '\[error\]'; do
    [ "$n" -lt 50 ] || { printf 'Karabiner daemon did not log the reload within 10s -- dropped rules unverified\n' >&2; return 0; }
    sleep 0.2; n=$(( n + 1 ))
  done
  sleep 0.3
  since "$DAEMON_LOG" "$daemon_mark" | sed -n '/ Load .*karabiner\.json\.\.\./,$p' | grep '\[error\]' || :
}

# The snapshot is content, not a commit, and nothing here compares it to `main`.
# A live file that is already *behind* main is therefore preserved and restored
# as faithfully as uncommitted work is -- and the staleness surfaces much later,
# as a fast-forward refusing against a file that is missing rules already
# shipped. Say so at acquire instead, while the window is still one session
# wide. Never a refusal: surviving uncommitted work in the live slot is the
# point of the snapshot, and only the caller knows which kind theirs is.
stale_note() {
  stat=$(git -C "$ROOT" diff --numstat HEAD -- karabiner.json 2>/dev/null) || return 0
  [ -n "$stat" ] || return 0
  added=$(printf '%s\n' "$stat" | awk '{print $1}')
  removed=$(printf '%s\n' "$stat" | awk '{print $2}')
  printf 'note: the live config differs from HEAD by +%s -%s lines, and the snapshot has that too\n' "$added" "$removed"
  [ "$added" = "0" ] || return 0
  printf '      deletions only -- the live file looks behind `main` rather than ahead of it, so\n'
  printf '      releasing will put that back; check it before testing on top of it\n'
}

cmd=${1:-status}
case "$cmd" in

  acquire)
    if mkdir "$LOCK" 2>/dev/null; then
      cp "$LIVE" "$BACKUP"
      printf '%s\n' "$SELF" > "$LOCK/worktree"
      printf '%s\n' "$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo '(detached)')" > "$LOCK/branch"
      printf '%s\n' "${2:-$(basename "$SELF")}" > "$LOCK/label"
      printf '%s\n' "${3:-${KARABINER_SESSION:-(unnamed session)}}" > "$LOCK/session"
      printf '%s\n' "$SESSION_ID" > "$LOCK/session_id"
      printf '%s\n' "$NOW" > "$LOCK/acquired"
      printf 'acquired -- live config snapshotted\n'
      stale_note
    elif owned; then
      # Re-acquiring must not re-snapshot: the backup would capture the test
      # config and the real pre-test state would be lost.
      printf 'already held by this worktree (snapshot preserved)\n'
    else
      printf 'LOCKED -- the session "%s" is testing.\n' "$(field session)" >&2
      holder_report >&2
      is_stale && printf '\nLock is stale; `break` it after confirming with the user.\n' >&2
      exit 1
    fi
    ;;

  install)
    [ -d "$LOCK" ] || die 'no lock held -- run `acquire` first'
    owned || { printf 'lock held by another session:\n' >&2; holder_report >&2; exit 1; }
    [ -n "${2:-}" ] || die 'usage: install <file>'
    [ -f "$2" ] || die "no such file: $2"
    node -e 'JSON.parse(require("fs").readFileSync(process.argv[1],"utf8"))' "$2" 2>/dev/null \
      || die "invalid JSON: $2 (live config left untouched)"
    lint "$2"
    replace_live "$2"
    # The daemon logs a file's errors only when it reloads, and an unchanged file
    # does not reload -- so keep each reload's verdict, and let an unchanged retry
    # repeat it rather than pass. A file other than the last one installed has no
    # verdict here.
    if [ -n "$daemon_mark" ]; then
      rejected > "$LOCK/rejected"
    elif ! cmp -s "$2" "$LOCK/installed"; then
      rm -f "$LOCK/rejected"
    fi
    # Recorded before any failure below: the file is live either way, and
    # `release` refuses to restore over a live file it does not recognize.
    cp "$2" "$LOCK/installed"
    if [ -s "$LOCK/rejected" ]; then
      printf 'REJECTED -- Karabiner logged errors loading it, and what they name will not fire:\n' >&2
      cat "$LOCK/rejected" >&2
      exit 1
    fi
    ;;

  release)
    mode=${2:-}
    # `ship` releases only a lock this session took. A branch that was never
    # tested holds no lock, and another session's lock is theirs to restore --
    # neither is worth a message, so both exit quietly.
    if [ "$mode" = "--if-mine" ]; then
      [ -n "$SESSION_ID" ] && [ -d "$LOCK" ] && [ "$(field session_id)" = "$SESSION_ID" ] || exit 0
      mode=
    fi
    [ -d "$LOCK" ] || { printf 'no lock held\n'; exit 0; }
    owned || { printf 'lock held by another session; refusing to release:\n' >&2; holder_report >&2; exit 1; }
    [ -f "$BACKUP" ] || die 'snapshot missing -- refusing to release; restore the live config by hand'

    if [ "$mode" = "--keep" ]; then
      rm -rf "$LOCK"
      printf 'lock dropped; live config left as it is\n'
      exit 0
    fi

    # What the live file should contain right now: the last thing installed, or
    # the snapshot if nothing was. Anything else means the live file changed
    # underneath us -- a hand edit, or Karabiner rewriting it after a change in
    # its settings window -- and blindly restoring would destroy that change.
    if [ -f "$LOCK/installed" ]; then expected=$LOCK/installed; else expected=$BACKUP; fi
    if [ "$mode" != "--force" ] && ! cmp -s "$expected" "$LIVE"; then
      printf 'The live config changed since this lock was taken.\n' >&2
      printf 'Restoring the snapshot would discard that change.\n\n' >&2
      printf '  keep the current live config:  %s release --keep\n' "$0" >&2
      printf '  restore anyway:                %s release --force\n' "$0" >&2
      printf '\nSnapshot of the pre-test config: %s\n' "$BACKUP" >&2
      exit 1
    fi

    if cmp -s "$BACKUP" "$LIVE"; then
      printf 'live config already matches the snapshot\n'
    else
      replace_live "$BACKUP"
    fi
    rm -rf "$LOCK"
    printf 'released\n'
    ;;

  status)
    [ -d "$LOCK" ] || { printf 'unlocked\n'; exit 0; }
    owned && printf 'LOCKED by this worktree\n' || printf 'LOCKED by another session\n'
    holder_report
    is_stale && printf 'STALE -- presumed abandoned\n'
    exit 0
    ;;

  break)
    [ -d "$LOCK" ] || { printf 'no lock held\n'; exit 0; }
    if ! is_stale; then
      printf 'Lock is only %sm old and may still be in use:\n' "$(( $(age) / 60 ))" >&2
      holder_report >&2
      printf 'Confirm with the user, then re-run with KARABINER_LOCK_STALE=0.\n' >&2
      exit 1
    fi
    if [ -f "$BACKUP" ] && ! cmp -s "$BACKUP" "$LIVE"; then
      replace_live "$BACKUP"
      printf 'restored the abandoned snapshot\n'
    fi
    rm -rf "$LOCK"
    printf 'lock broken\n'
    ;;

  *) die "unknown command: $cmd (acquire|install|release|status|break)" ;;
esac
