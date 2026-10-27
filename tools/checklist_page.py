#!/usr/bin/env python3
"""Build the interactive playtest checklist page (a claude.ai artifact) from the repo's markdown checklist.

The page carries its own data (sections and items, parsed from the markdown) and its state (which items are
ticked, and a note per item). When the owner ticks something the page republishes itself with the new state
(the artifact capability), so ticks are kept on every device. Re-running this keeps the state you pass in:

    python3 tools/checklist_page.py production/qa/playtest-checklist-2026-10-25.md OUT.html [STATE.json]

Item ids are "s<section>-<n>" (n counts items within a section), so a new section or a new item at the end
of a section never disturbs existing ticks.
"""
import html
import json
import re
import sys

SRC, OUT = sys.argv[1], sys.argv[2]
STATE = {"checked": {}, "notes": {}}
if len(sys.argv) > 3:
    with open(sys.argv[3]) as f:
        STATE.update(json.load(f))


def inline(md):
    s = html.escape(md, quote=False)
    s = re.sub(r"\*\*(.+?)\*\*", r"<strong>\1</strong>", s)
    s = re.sub(r"`(.+?)`", r"<code>\1</code>", s)
    return s


title, pre, sections = "", [], []
cur = None
for line in open(SRC).read().splitlines():
    if line.startswith("# "):
        title = line[2:].strip()
    elif line.startswith("## "):
        m = re.match(r"##\s+(\d+)\.\s+(.*)", line)
        num, rest = (m.group(1), m.group(2)) if m else (str(len(sections) + 1), line[3:])
        cur = {"n": int(num), "title": inline(rest.strip()), "notes": [], "items": []}
        sections.append(cur)
    elif line.startswith("  - Note: "):
        continue  # notes come back from the page's state, not the markdown
    elif re.match(r"- \[[ xX]\]", line):
        if cur is None:
            continue
        iid = "s%d-%d" % (cur["n"], len(cur["items"]) + 1)
        cur["items"].append({"id": iid, "html": inline(line[5:].strip())})
        if line[3] in "xX":
            STATE["checked"].setdefault(iid, True)
    elif line.strip():
        if cur is None:
            pre.append(line.strip())
        else:
            cur["notes"].append(inline(line.strip()))

# before section 1: an intro paragraph, then the "Keys:" paragraph (which ends with a sentence of advice)
text = " ".join(pre)
intro_part, _, key_part = text.partition("Keys:")
keys, tail = [], ""
for m in re.finditer(r"\*\*(.+?)\*\*\s*([^·]*)", key_part):
    v = m.group(2).strip()
    parts = re.split(r"(?<=\))\.\s+", v, maxsplit=1)
    if len(parts) == 2:
        v, tail = parts[0], parts[1]
    keys.append({"k": m.group(1).strip(), "v": v.strip().rstrip(".")})
DATA = {
    "title": title,
    "intro": inline((intro_part.strip() + " " + tail.strip()).strip()),
    "keys": keys,
    "sections": sections,
}


def safe_json(obj):
    return json.dumps(obj, ensure_ascii=False).replace("</", "<\\/")


page = open(__file__.replace("checklist_page.py", "checklist_page.template.html")).read()
RESET = ":root{color-scheme:light;padding-top:env(safe-area-inset-top);padding-bottom:env(safe-area-inset-bottom)}body{margin:0;font:14px system-ui,sans-serif}img{max-width:100%}[hidden]{display:none!important}"
try:
    RESET = open(__file__.replace("checklist_page.py", "checklist_reset.css")).read().strip()  # the exact skeleton reset, read back from a publish
except OSError:
    pass
page = page.replace("/*__DATA__*/", safe_json(DATA)).replace("/*__STATE__*/", safe_json(STATE))
page = page.replace('/*__RESET__*/""', json.dumps(RESET).replace("</", "<\\/"))
open(OUT, "w").write(page)
print("sections", len(sections), "items", sum(len(s["items"]) for s in sections), "checked", len(STATE["checked"]))
