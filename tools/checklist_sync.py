#!/usr/bin/env python3
"""Pull ticks and notes from the published checklist page back into the repo.

    python3 tools/checklist_sync.py PAGE.html production/qa/playtest-checklist-2026-10-25.md STATE_OUT.json

PAGE.html is the artifact's current HTML (Artifact read). Ticked checks become "- [x]" in the markdown and a
note becomes an indented "  - Note: ..." line under its check. STATE_OUT.json is what checklist_page.py takes
as its third argument, so a rebuilt page keeps every tick.
"""
import json
import re
import sys

page, md_path, state_out = sys.argv[1], sys.argv[2], sys.argv[3]
raw = open(page).read()
m = re.search(r'id="checklist-state">(.*?)</script>', raw, re.S)
state = json.loads(m.group(1).replace("<\\/", "</"))
checked, notes = state.get("checked", {}), state.get("notes", {})
out, sec, n = [], None, 0
for line in open(md_path).read().splitlines():
    if line.startswith("  - Note: "):
        continue  # regenerated below from the page's notes
    h = re.match(r"##\s+(\d+)\.", line)
    if h:
        sec, n = int(h.group(1)), 0
    item = re.match(r"- \[[ xX]\] (.*)", line)
    if item and sec is not None:
        n += 1
        iid = "s%d-%d" % (sec, n)
        out.append("- [%s] %s" % ("x" if checked.get(iid) else " ", item.group(1)))
        if notes.get(iid):
            out.append("  - Note: " + " ".join(notes[iid].split()))
        continue
    out.append(line)
open(md_path, "w").write("\n".join(out) + "\n")
json.dump(state, open(state_out, "w"), ensure_ascii=False, indent=1)
print("checked", len(checked), "notes", len(notes))
