#!/bin/sh
# Build scripts/ax-press.swift into the live checkout's scripts/bin/, where the rules that use it
# point, whichever worktree this runs from. The binary is named karabiner-config-ax-press because
# that name is what the Accessibility list shows, and a bare "ax-press" there would say nothing
# about where it came from a year on.
#
# Signing: create-signing-cert.sh makes a stable self-signed identity the first time it runs, and
# that is what keeps the Accessibility grant across rebuilds -- TCC pins the grant to the signature,
# and an ad-hoc one changes with every compile. Recompiling is free while the identity and the
# --identifier below both stay the same; changing either costs a full regrant, as does falling back
# to ad-hoc. docs/accessibility-rules.md has the regrant procedure.
#
# KARABINER_ADHOC=1 skips the identity entirely, for a build that must not block on a keychain
# dialog. It costs the grant.
set -eu

ROOT=${KARABINER_ROOT:-$(git worktree list --porcelain | head -1 | sed 's/^worktree //')}
HERE=$(cd "$(dirname "$0")" && pwd)
OUT="$ROOT/scripts/bin/karabiner-config-ax-press"
IDENTIFIER="com.raine.karabiner-config-ax-press"

if [ -n "${KARABINER_ADHOC:-}" ]; then
  IDENTITY="-"
else
  IDENTITY=$("$HERE/create-signing-cert.sh" || true)
  [ -n "$IDENTITY" ] || IDENTITY="-"
fi

mkdir -p "$ROOT/scripts/bin"
swiftc -O -swift-version 5 -o "$OUT" "$HERE/ax-press.swift"

# The first build with a new identity puts up a keychain dialog asking to let codesign use the key.
# Wait for it, but not forever: an unattended build should end up ad-hoc rather than hanging.
if [ "$IDENTITY" != "-" ]; then
  printf '==> Signing as "%s" (approve the keychain dialog if one appears)\n' "$IDENTITY" >&2
  codesign --force --sign "$IDENTITY" --identifier "$IDENTIFIER" "$OUT" >/dev/null 2>&1 &
  SIGNER=$!
  WAITED=0
  while kill -0 "$SIGNER" 2>/dev/null && [ "$WAITED" -lt 120 ]; do
    sleep 1
    WAITED=$((WAITED + 1))
  done
  if kill -0 "$SIGNER" 2>/dev/null; then
    kill "$SIGNER" 2>/dev/null || true
    printf 'warning: signing timed out waiting for the keychain dialog; falling back to ad-hoc.\n' >&2
    IDENTITY="-"
  elif ! wait "$SIGNER"; then
    printf 'warning: codesign failed; falling back to ad-hoc.\n' >&2
    IDENTITY="-"
  fi
fi

if [ "$IDENTITY" = "-" ]; then
  codesign --force --sign - --identifier "$IDENTIFIER" "$OUT" >/dev/null 2>&1 || true
  printf 'note: ad-hoc signed. Accessibility must be granted again after every build.\n' >&2
fi

printf 'built %s (signed by %s)\n' "$OUT" "$IDENTITY"
