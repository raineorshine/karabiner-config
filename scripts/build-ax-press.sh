#!/bin/sh
# Build scripts/ax-press.swift into the live checkout's scripts/bin/, where the rules that use it
# point, whichever worktree this runs from, and (re)load the LaunchAgent that keeps it serving. The
# binary is named karabiner-config-ax-press because that name is what the Accessibility list shows,
# and a bare "ax-press" there would say nothing about where it came from a year on.
#
# Signing: ad-hoc, with an explicit designated requirement naming only the signing identifier. TCC
# records that requirement with the Accessibility grant, and a recompile still satisfies it, so the
# grant survives rebuilds; an ad-hoc signature's implicit requirement pins the code hash, which
# changes with every compile. Changing the --identifier below costs a full regrant.
# docs/accessibility-rules.md has the regrant procedure.
#
# Serving: rules do not launch the binary. launchd runs it with --serve and hands it the socket at
# scripts/bin/ax-press.sock, and rules pipe their arguments there through nc. The agent is restarted
# after every build, so it never serves an old binary.
set -eu

ROOT=${KARABINER_ROOT:-$(git worktree list --porcelain | head -1 | sed 's/^worktree //')}
HERE=$(cd "$(dirname "$0")" && pwd)
OUT="$ROOT/scripts/bin/karabiner-config-ax-press"
SOCKET="$ROOT/scripts/bin/ax-press.sock"
IDENTIFIER="com.raine.karabiner-config-ax-press"
LABEL="$IDENTIFIER"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"
DOMAIN="gui/$(id -u)"

# swiftc goes through xcrun, which refuses to run anything while the selected Xcode's license is
# unaccepted -- as it is after an Xcode update until someone runs `sudo xcodebuild -license`. The
# Command Line Tools carry their own swiftc and are unaffected.
if ! swiftc --version >/dev/null 2>&1 && [ -x /Library/Developer/CommandLineTools/usr/bin/swiftc ]; then
  export DEVELOPER_DIR=/Library/Developer/CommandLineTools
fi

mkdir -p "$ROOT/scripts/bin"
swiftc -O -swift-version 5 -o "$OUT.new" "$HERE/ax-press.swift"
codesign --force --sign - --identifier "$IDENTIFIER" -r="designated => identifier \"$IDENTIFIER\"" "$OUT.new"
mv -f "$OUT.new" "$OUT"

# ProcessType Interactive gives the server an app's resource limits, which is to say none; a
# standard job gets a daemon's, and Karabiner's own console server, one of those, runs at scheduling
# priority 20 where an app runs at 31 or above. ThrottleInterval 1: a server that finds the grant
# missing exits after replying, and the default ten seconds would hold the next press that long once
# the grant is back. RunAtLoad and --prime: the server switches on the Claude app's complete
# accessibility when the app launches, not at the first press, which then waited 2.1s after every
# relaunch; that needs the server running before any rule has connected to it.
mkdir -p "$HOME/Library/LaunchAgents"
cat > "$PLIST.new" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>Label</key>
	<string>$LABEL</string>
	<key>ProgramArguments</key>
	<array>
		<string>$OUT</string>
		<string>--serve</string>
		<string>--prime</string>
		<string>com.anthropic.claudefordesktop</string>
	</array>
	<key>RunAtLoad</key>
	<true/>
	<key>Sockets</key>
	<dict>
		<key>Listeners</key>
		<dict>
			<key>SockPathName</key>
			<string>$SOCKET</string>
			<key>SockPathMode</key>
			<integer>384</integer>
		</dict>
	</dict>
	<key>ProcessType</key>
	<string>Interactive</string>
	<key>ThrottleInterval</key>
	<integer>1</integer>
</dict>
</plist>
EOF

if cmp -s "$PLIST.new" "$PLIST" && launchctl print "$DOMAIN/$LABEL" >/dev/null 2>&1; then
  rm -f "$PLIST.new"
  # -k replaces a running server with one on the new binary.
  launchctl kickstart -k "$DOMAIN/$LABEL"
else
  mv -f "$PLIST.new" "$PLIST"
  launchctl bootout "$DOMAIN/$LABEL" 2>/dev/null || true
  # bootout returns before the job is fully gone, and a bootstrap that lands first fails with an
  # I/O error, so retry briefly.
  tries=0
  until launchctl bootstrap "$DOMAIN" "$PLIST" 2>/dev/null; do
    tries=$((tries + 1))
    if [ "$tries" -ge 20 ]; then
      launchctl bootstrap "$DOMAIN" "$PLIST"
      break
    fi
    sleep 0.1
  done
fi

printf 'built %s (ad-hoc, designated => identifier "%s"); serving on %s\n' "$OUT" "$IDENTIFIER" "$SOCKET"
