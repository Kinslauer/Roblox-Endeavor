# Runs a Luau script on a real server of a published place (Open Cloud Luau execution) and prints its logs.
# Usage: python3 tools/realserver/run_luau.py <placeId> <script.lua>   (ROBLOX_API_KEY=proxy-injected on the Roblox-Endeavor env)
import json, os, sys, time, urllib.error, urllib.request
U, P = "10773835758", sys.argv[1]
src = open(sys.argv[2]).read()
H = {"x-api-key": os.environ.get("ROBLOX_API_KEY", "proxy-injected"), "Content-Type": "application/json"}
def req(url, data=None, method="GET"):
    r = urllib.request.Request(url, data=json.dumps(data).encode() if data else None, headers=H, method=method)
    return json.load(urllib.request.urlopen(r, timeout=120))
base = f"https://apis.roblox.com/cloud/v2/universes/{U}/places/{P}/luau-execution-session-tasks"
for a in range(6):
    try:
        t = req(base, {"script": src, "timeout": "280s"}, "POST"); break
    except urllib.error.HTTPError as e:
        print("start", e.code, e.read()[:200]); time.sleep(20*(a+1))
path = t["path"]
while True:
    time.sleep(5)
    t = req("https://apis.roblox.com/cloud/v2/" + path)
    if t["state"] not in ("QUEUED", "PROCESSING"): break
print("state:", t["state"], json.dumps(t.get("error") or t.get("output"))[:2000])
logs = req("https://apis.roblox.com/cloud/v2/" + path + "/logs")
for l in logs.get("luauExecutionSessionTaskLogs", []):
    for m in l.get("messages", []): print(m)
