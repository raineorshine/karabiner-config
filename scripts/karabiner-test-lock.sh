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
#                     take the lock and snapshot the live config; `session` names
#                     the Claude session holding it, so a denied request can say
#                     which chat to go to (falls back to $KARABINER_SESSION)
#   install <file>    replace the live config (atomic; waits for reload)
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

# Replace the live config atomically so Karabiner never observes a partial file,
# then wait for it to report the reload. Prints a warning rather than failing if
# the log is unavailable -- the replacement itself still succeeded.
#
# Deliberately does NOT validate: restoring a snapshot must always be possible.
# A snapshot that will not parse is still what was live before, and refusing to
# put it back would strand the branch's test config in the live slot -- the one
# outcome this whole mechanism exists to prevent. Validation belongs on the
# forward install (see the `install` command), where a bad file is the caller's.
replace_live() {
  src=$1
  # Karabiner hashes the config and skips the reload when the content is
  # unchanged, so waiting for a log line here would always time out. Verified:
  # an identical atomic replace logs nothing, a differing one logs in ~20ms.
  if cmp -s "$src" "$LIVE"; then
    printf 'live config already identical -- nothing to reload\n'; return 0
  fi
  mark=0
  [ -f "$LOG" ] && mark=$(wc -c < "$LOG")
  tmp="$ROOT/.karabiner.json.tmp.$$"
  cat "$src" > "$tmp"
  mv "$tmp" "$LIVE"
  [ -f "$LOG" ] || { printf 'installed (no Karabiner log; reload unverified)\n'; return 0; }
  n=0
  while [ "$n" -lt 50 ]; do
    if tail -c "+$(( mark + 1 ))" "$LOG" | grep -q 'core_configuration is updated'; then
      printf 'installed and reloaded\n'; return 0
    fi
    sleep 0.2; n=$(( n + 1 ))
  done
  printf 'installed, but Karabiner did not log a reload within 10s -- check the log\n' >&2
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
    replace_live "$2"
    cp "$2" "$LOCK/installed"
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
