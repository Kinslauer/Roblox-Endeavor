# Upload FBX models to Roblox through the Open Cloud Assets API. Usage: upload.py name path [name path ...]
# Prints "name assetId" lines. Needs roblox_key next to this script.
import json, sys, os, time, urllib.request, uuid
S = os.path.dirname(os.path.abspath(__file__))
KEY = os.environ["ROBLOX_API_KEY"]
USER = "3155619052"
def multipart(fields, filename, data, ctype):
    b = "----rbx" + uuid.uuid4().hex
    body = b""
    for k, v in fields.items():
        body += f"--{b}\r\nContent-Disposition: form-data; name=\"{k}\"\r\nContent-Type: application/json\r\n\r\n{v}\r\n".encode()
    body += f"--{b}\r\nContent-Disposition: form-data; name=\"fileContent\"; filename=\"{filename}\"\r\nContent-Type: {ctype}\r\n\r\n".encode() + data + f"\r\n--{b}--\r\n".encode()
    return body, f"multipart/form-data; boundary={b}"
def req(method, url, body=None, ctype=None):
    r = urllib.request.Request(url, data=body, method=method, headers={"x-api-key": KEY, **({"Content-Type": ctype} if ctype else {})})
    try:
        with urllib.request.urlopen(r, timeout=180) as resp: return resp.status, json.loads(resp.read().decode() or "{}")
    except urllib.error.HTTPError as e: return e.code, e.read().decode()
args = sys.argv[1:]
for name, path in zip(args[::2], args[1::2]):
    meta = json.dumps({"assetType": "Model", "displayName": name, "description": "Endeavor prop (generated in Blender)", "creationContext": {"creator": {"userId": USER}}})
    body, ctype = multipart({"request": meta}, os.path.basename(path), open(path, "rb").read(), "model/fbx")
    code, op = req("POST", "https://apis.roblox.com/assets/v1/assets", body, ctype)
    if code != 200: print(name, "FAILED", code, op); continue
    opid = op["operationId"] if "operationId" in op else op.get("path", "").split("/")[-1]
    asset = None
    for _ in range(60):
        time.sleep(3)
        code, st = req("GET", f"https://apis.roblox.com/assets/v1/operations/{opid}")
        if isinstance(st, dict) and st.get("done"):
            asset = st.get("response", {}).get("assetId"); err = st.get("error"); break
    print(name, asset or f"FAILED {err if asset is None else ''}")
