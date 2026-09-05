---
name: prettydiff
description: Show a git diff in the Claude Desktop side panel instead of dumping it into chat or linking to GitHub. Use when asked to see a diff, a commit, or what changed — "show me the diff", "what did that commit change", "render the diff".
---

# Prettydiff (a diff in the side panel)

A diff pasted into chat is unreadable at any length, and a GitHub link leaves the app. Render it
to a local HTML file and send it with `SendUserFile` — no publishing, no network.

## Procedure

```bash
./scripts/prettydiff.py <rev-or-range> [-- <path>...] [--out FILE]
```

It prints the path it wrote. Then send that path with `SendUserFile`, `display: "render"`, which
opens it in the side panel.

- No argument: the working tree against `HEAD`. Exits `no diff` when clean.
- A single commit (`a5c09f3`, `HEAD~2`): `git show`, with author and date in the subhead.
- A range (`main..HEAD`, `origin/main..HEAD`): `git diff`.
- `-- <path>` narrows to those paths, exactly as git takes it.
- `--out` sets the file; the default is `$CLAUDE_SCRATCHPAD/prettydiff.html`, or the system temp
  directory. Writing to the session scratchpad keeps it out of the repo.

## What the page does, and why

Monokai on `#272822`, 8px monospace, additions green and deletions pink. Both were asked for; keep
them unless asked otherwise, and change the number rather than the mechanism when the ask is
"smaller".

Two things are load-bearing, and a rewrite that drops them regresses:

- **`<meta name="viewport" content="width=device-width, initial-scale=1">`.** Without it the panel
  lays the page out at a narrow emulated width and scales it up, so an 8px font renders like 12px
  and every line runs off the right edge. This looks like a font-size problem and is not one.
- **Wrapping, not scrolling.** `white-space: pre-wrap` with `overflow-wrap: anywhere`, a hanging
  indent so a wrapped line clears the `+`/`-` gutter, `min-width: 0` everywhere, and no
  `overflow-x: auto` container. The panel is narrow and resizes; a diff that scrolls sideways in it
  is a diff you cannot read.

Below about 7px, hinting detail drops on a non-Retina display and legibility falls off faster than
the number suggests — say so rather than shrinking silently.
