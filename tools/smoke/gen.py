import os, sys
here = os.path.dirname(os.path.abspath(__file__))
root = os.path.join(here, "..", "..", "src")
scenario_path = sys.argv[1] if len(sys.argv) > 1 else os.path.join(here, 'scenario.lua')
scenario = open(scenario_path).read()
def lua_str(s):
    n = 2
    while ("]" + "=" * n + "]") in s: n += 1
    return "[" + "=" * n + "[" + s + "]" + "=" * n + "]"
def mods(d):
    out = []
    for f in sorted(os.listdir(os.path.join(root, d))):
        if not f.endswith(".lua"): continue
        name = f[:-4]
        cls = "ModuleScript"
        if name.endswith(".server"): name, cls = name[:-7], "Script"
        if name.endswith(".client"): name, cls = name[:-7], "LocalScript"
        src = open(os.path.join(root, d, f)).read()
        if name == "ProfileService":
            src = open(os.path.join(here, "ps_stub.lua")).read()
        out.append('[ %s ] = { class = %s, source = %s }' % (lua_str(name), lua_str(cls), lua_str(src)))
    return ",\n".join(out)
prelude = open(os.path.join(here, "mock_prelude.lua")).read()
print("local M = (function()\n" + prelude + "\nend)()")
print("local TREE_SHARED = {\n" + mods("shared") + "\n}")
print("local TREE_SERVER = {\n" + mods("server") + "\n}")
print("local TREE_CLIENT = {\n" + mods("client") + "\n}")
print("local TREE_COMMON = {\n" + mods("common") + "\n}")
print("local TREE_WAR = {\n" + mods("war/server") + "\n}")
print("local ARGS_OUT = " + repr(sys.argv[2]) if len(sys.argv) > 2 else "")
print(scenario)
