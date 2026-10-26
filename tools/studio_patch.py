#!/usr/bin/env python3
"""Emit a Luau script that patches the open Studio place from one git revision to the working tree.

Studio is kept in sync with the repo by pushing scripts through the Studio MCP server. Whole-file
pushes are expensive for big files, so this computes minimal exact-string hunks (with enough context
to be unique) per changed file under src/, and emits one Luau program that applies them and reports
how many hunks matched. New files are written whole.

Usage: python3 tools/studio_patch.py [BASE_REV=HEAD] > /tmp/patch.lua
"""
import difflib
import json
import os
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BASE = sys.argv[1] if len(sys.argv) > 1 else "HEAD"

PARENTS = {"shared": "game.ReplicatedStorage.Shared", "server": "game.ServerScriptService.Server", "client": "game.StarterPlayer.StarterPlayerScripts.Client"}


def git(*args):
    return subprocess.run(["git", *args], cwd=ROOT, check=True, capture_output=True, text=True).stdout


def studio_name(path):
    base = os.path.basename(path)
    for suffix, cls in ((".server.lua", "Script"), (".client.lua", "LocalScript"), (".lua", "ModuleScript")):
        if base.endswith(suffix):
            return base[: -len(suffix)], cls
    return None, None


def hunks(old_text, new_text, context=2):
    """Exact-string (old, new) pairs. Overlapping hunks are merged so each one applies independently."""
    old, new = old_text.splitlines(keepends=True), new_text.splitlines(keepends=True)
    sm = difflib.SequenceMatcher(a=old, b=new, autojunk=False)
    ops = [op for op in sm.get_opcodes() if op[0] != "equal"]
    if not ops:
        return []
    # expand context until each old block is unique, then merge overlapping/adjacent ranges
    ranges = []
    for _, i1, i2, j1, j2 in ops:
        c = context
        while True:
            a1, a2 = max(0, i1 - c), min(len(old), i2 + c)
            block = "".join(old[a1:a2])
            if old_text.count(block) == 1 or (a1 == 0 and a2 == len(old)):
                break
            c += 2
        ranges.append([a1, a2, i1, i2, j1, j2])
    merged = []
    for r in sorted(ranges):
        if merged and r[0] <= merged[-1][1]:
            m = merged[-1]
            m[1] = max(m[1], r[1])
            m[3], m[5] = r[3], r[5]  # extend to the later op's end (old and new)
        else:
            merged.append(r)
    out = []
    for a1, a2, i1, i2, j1, j2 in merged:
        # new block = leading context + the new text spanning the merged ops + trailing context
        # map old[a1:i_first] context via the matcher: context lines are equal in both, so take them from old
        first_i1 = min(op[1] for op in ops if a1 <= op[1] and op[2] <= a2)
        first_j1 = min(op[3] for op in ops if a1 <= op[1] and op[2] <= a2)
        last_i2 = max(op[2] for op in ops if a1 <= op[1] and op[2] <= a2)
        last_j2 = max(op[4] for op in ops if a1 <= op[1] and op[2] <= a2)
        old_block = "".join(old[a1:a2])
        new_block = "".join(old[a1:first_i1]) + "".join(new[first_j1:last_j2]) + "".join(old[last_i2:a2])
        out.append((old_block, new_block))
    return out


def main():
    changed = git("status", "--porcelain", "--", "src").splitlines()
    if not changed and BASE != "HEAD":
        # clean tree: patch Studio from BASE up to HEAD (e.g. after Studio lost unsaved pushes)
        changed = []
        for line in git("diff", "--name-status", BASE, "HEAD", "--", "src").splitlines():
            status, path = line.split("\t", 1)
            changed.append(f"{'??' if status.startswith('A') else ' M'} {path}")
    lines = [
        'local HttpService = game:GetService("HttpService")',
        "local report = {}",
        "local function patch(scr, hunks_json)",
        "\tlocal hunks = HttpService:JSONDecode(hunks_json)",
        "\tlocal src, n = scr.Source, 0",
        "\tfor _, h in hunks do",
        "\t\tlocal i, j = src:find(h[1], 1, true)",
        "\t\tif i then src = src:sub(1, i - 1) .. h[2] .. src:sub(j + 1); n += 1 end",
        "\tend",
        "\tscr.Source = src",
        '\ttable.insert(report, scr.Name .. " " .. n .. "/" .. #hunks)',
        "end",
        "local function put(parent, name, class, json)",
        "\tlocal s = parent:FindFirstChild(name)",
        "\tif not s then s = Instance.new(class); s.Name = name; s.Parent = parent end",
        "\ts.Source = HttpService:JSONDecode(json)",
        '\ttable.insert(report, name .. " written")',
        "end",
    ]
    for entry in changed:
        status, path = entry[:2], entry[3:].strip()
        if not path.endswith(".lua"):
            continue
        folder = path.split("/")[1]
        name, cls = studio_name(path)
        parent = PARENTS.get(folder)
        if not parent or not name:
            continue
        with open(os.path.join(ROOT, path), encoding="utf-8") as f:
            new_text = f.read()
        if status.strip() in ("??", "A"):
            lines.append(f'put({parent}, "{name}", "{cls}", [==[{json.dumps(new_text)}]==])')
            continue
        old_text = git("show", f"{BASE}:{path}")
        hs = hunks(old_text, new_text)
        if not hs:
            continue
        lines.append(f'patch({parent}:FindFirstChild("{name}"), [==[{json.dumps(hs)}]==])')
    lines.append('return table.concat(report, "; ")')
    print("\n".join(lines))


if __name__ == "__main__":
    main()
