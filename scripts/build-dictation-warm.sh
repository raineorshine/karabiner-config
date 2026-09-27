#!/bin/sh
# Build scripts/dictation-warm.c into the live checkout's scripts/bin/ and (re)load the LaunchAgent
# that keeps it running. The helper keeps DictationIM resident so the fn Dictation tap never waits on
# its cold launch -- docs/system-shortcut-rules.md. It needs no grant and touches no Karabiner rule,
# so unlike build-ax-press.sh it does not check the test lock.
set -eu

ROOT=${KARABINER_ROOT:-$(git worktree list --porcelain | head -1 | sed 's/^worktree //')}
HERE=$(cd "$(dirname "$0")" && pwd)
OUT="$ROOT/scripts/bin/karabiner-config-dictation-warm"
LABEL="com.raine.karabiner-config-dictation-warm"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"
DOMAIN="gui/$(id -u)"

mkdir -p "$ROOT/scripts/bin"
clang -O2 -Wall -o "$OUT.new" "$HERE/dictation-warm.c"
mv -f "$OUT.new" "$OUT"

# KeepAlive: launchd restarts the helper if it ever exits. Background: it only waits on a kqueue.
mkdir -p "$HOME/Library/LaunchAgents"
cat > "$PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>Label</key>
	<string>$LABEL</string>
	<key>ProgramArguments</key>
	<array>
		<string>$OUT</string>
	</array>
	<key>RunAtLoad</key>
	<true/>
	<key>KeepAlive</key>
	<true/>
	<key>ProcessType</key>
	<string>Background</string>
</dict>
</plist>
PLIST

launchctl bootout "$DOMAIN/$LABEL" 2>/dev/null || true
# bootout returns before the job is fully gone, and a bootstrap that lands first fails, so retry.
tries=0
until launchctl bootstrap "$DOMAIN" "$PLIST" 2>/dev/null; do
  tries=$((tries + 1))
  if [ "$tries" -ge 20 ]; then
    launchctl bootstrap "$DOMAIN" "$PLIST"
    break
  fi
  sleep 0.1
done

printf 'built %s; running as %s\n' "$OUT" "$LABEL"
