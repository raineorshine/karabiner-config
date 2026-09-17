#!/bin/sh
# Copy scripts/extension-options/ into the live checkout's scripts/bin/extension-options/, which is
# where Brave loads the extension from, whichever worktree this runs from. Brave keeps the path an
# unpacked extension was loaded from, so loading it straight from a worktree would break it once that
# worktree is removed.
#
# Load it once: brave://extensions > Developer mode > Load unpacked > the path this prints. After
# that, a manifest.json change (the Cmd+Shift+, shortcut, the popup) needs the reload button on the
# extension's card; the pages are read from disk each time the popup opens. Having the extension
# reload itself is not a substitute: chrome.runtime.reload() from its own page left it unloaded (still
# blocked 8s later) in Brave 1.95, measured on a copy loaded with --load-extension rather than Load
# unpacked, which was not tried.
#
# The manifest's "key" pins the extension id, mncnjnpmhmdjonlledbijmjdfdenkkbi, so the id does not
# follow the load path. Brave keeps the shortcut assignment under the id.
set -eu

ROOT=${KARABINER_ROOT:-$(git worktree list --porcelain | head -1 | sed 's/^worktree //')}
HERE=$(cd "$(dirname "$0")" && pwd)
OUT="$ROOT/scripts/bin/extension-options"

mkdir -p "$OUT"
rsync -a --delete "$HERE/extension-options/" "$OUT/"

printf 'installed %s\n' "$OUT"
