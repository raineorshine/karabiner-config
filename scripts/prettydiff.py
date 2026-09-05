#!/usr/bin/env python3
"""Render a git diff as a self-contained HTML page for the Claude Desktop side panel.

Usage: scripts/prettydiff.py [git-rev-or-range] [-- <path>...] [--out FILE]

  prettydiff.py                     working tree vs HEAD
  prettydiff.py a5c09f3             one commit (git show)
  prettydiff.py main..HEAD          a range (git diff)
  prettydiff.py a5c09f3 -- AGENTS.md
"""
import html
import os
import subprocess
import sys
import tempfile

STYLE = """
/* Monokai */
:root {
  color-scheme: dark;
  --bg:#272822; --fg:#F8F8F2; --muted:#75715E; --line:#3E3D32;
  --add-fg:#A6E22E; --add-bg:#2F3529;
  --del-fg:#F92672; --del-bg:#35272C;
  --hunk:#66D9EF; --accent:#E6DB74;
}
* { box-sizing:border-box; min-width:0; }
html, body { max-width:100%; overflow-x:hidden; }
body { margin:0; background:var(--bg); color:var(--fg); font:8px/1.45 ui-monospace,SFMono-Regular,Menlo,monospace; }
header { padding:8px 10px; border-bottom:1px solid var(--line); font-family:system-ui,-apple-system,sans-serif; }
h1 { margin:0 0 2px; font-size:10px; line-height:1.3; color:var(--accent); overflow-wrap:anywhere; }
header p { margin:0; color:var(--muted); font-size:8px; overflow-wrap:anywhere; }
.diff { padding:8px 0 20px; }
.l { white-space:pre-wrap; overflow-wrap:anywhere; word-break:break-word; padding:0 8px 0 18px; text-indent:-10px; }
.ctx { color:var(--fg); }
.add { background:var(--add-bg); color:var(--add-fg); }
.del { background:var(--del-bg); color:var(--del-fg); }
.hunk { color:var(--hunk); margin:6px 0 2px; }
.meta { color:var(--muted); }
"""

META_PREFIXES = ("diff ", "index ", "--- ", "+++ ", "commit ", "Author:", "Date:", "new file", "deleted file", "similarity ", "rename ")


def classify(line):
    if line.startswith("@@"):
        return "hunk"
    if line.startswith(META_PREFIXES):
        return "meta"
    if line.startswith("+"):
        return "add"
    if line.startswith("-"):
        return "del"
    return "ctx"


def git(*args):
    r = subprocess.run(["git", *args], capture_output=True, text=True)
    if r.returncode:
        sys.exit(r.stderr.strip() or f"git {' '.join(args)} failed")
    return r.stdout


def main():
    argv = sys.argv[1:]
    out = None
    if "--out" in argv:
        i = argv.index("--out")
        out = argv[i + 1]
        del argv[i:i + 2]

    paths = []
    if "--" in argv:
        i = argv.index("--")
        paths = argv[i:]
        argv = argv[:i]

    rev = argv[0] if argv else None
    if rev and ".." not in rev and subprocess.run(
        ["git", "rev-parse", "--verify", "--quiet", f"{rev}^{{commit}}"],
        capture_output=True).returncode == 0:
        diff = git("show", rev, *paths)
        subject = git("show", "-s", "--format=%s", rev).strip()
        meta = f"{git('rev-parse', '--short', rev).strip()} · {git('show', '-s', '--format=%an, %ad', '--date=short', rev).strip()}"
    else:
        diff = git("diff", *( [rev] if rev else [] ), *paths)
        subject = f"git diff {rev}" if rev else "Working tree"
        meta = git("rev-parse", "--abbrev-ref", "HEAD").strip()

    if not diff.strip():
        sys.exit("no diff")

    stat = [l for l in diff.split("\n") if l.startswith("diff --git")]
    meta += f" · {len(stat)} file{'s' if len(stat) != 1 else ''}"

    body = "\n".join(
        f'<div class="l {classify(l)}">{html.escape(l) or "&nbsp;"}</div>'
        for l in diff.split("\n")
    )
    page = (
        "<!doctype html>\n<meta charset=\"utf-8\">\n"
        '<meta name="viewport" content="width=device-width, initial-scale=1">\n'
        f"<title>{html.escape(subject)}</title>\n<style>{STYLE}</style>\n"
        f"<header><h1>{html.escape(subject)}</h1><p>{html.escape(meta)}</p></header>\n"
        f'<div class="diff">{body}</div>\n'
    )

    if not out:
        scratch = os.environ.get("CLAUDE_SCRATCHPAD") or tempfile.gettempdir()
        out = os.path.join(scratch, "prettydiff.html")
    with open(out, "w") as f:
        f.write(page)
    print(out)


if __name__ == "__main__":
    main()
