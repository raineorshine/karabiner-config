#!/bin/sh
# Build scripts/ax-press.swift into the live checkout's scripts/bin/, where the rules that use it
# point, whichever worktree this runs from. The binary is named karabiner-config-ax-press because
# that name is what the Accessibility list shows, and a bare "ax-press" there would say nothing
# about where it came from a year on.
#
# Rebuild only when the source changes. The binary is ad-hoc signed by the linker, and TCC keys the
# Accessibility grant to that signature, so every rebuild needs the grant made again (confirmed: a
# rebuild of changed source went straight from trusted=true to trusted=false) in
# System Settings > Privacy & Security > Accessibility: remove the stale karabiner-config-ax-press
# entry, then run `scripts/bin/karabiner-config-ax-press com.openai.codex "Copy response" --dry-run
# --prompt` to be asked again, and toggle the new entry on.
set -eu

ROOT=${KARABINER_ROOT:-$(git worktree list --porcelain | head -1 | sed 's/^worktree //')}
HERE=$(cd "$(dirname "$0")" && pwd)
OUT="$ROOT/scripts/bin/karabiner-config-ax-press"

mkdir -p "$ROOT/scripts/bin"
swiftc -O -swift-version 5 -o "$OUT" "$HERE/ax-press.swift"
printf 'built %s\n' "$OUT"
