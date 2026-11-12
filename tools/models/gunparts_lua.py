# Writes src/shared/GunParts.lua from the component builds: tools/models/out/Gun_<variant>.json (anchors, written by
# gunparts.py --components) and out/gun_uploads.txt ("Gun_<variant>_<Component> <assetId>" lines from upload.py).
import json, os, sys
S = os.path.dirname(os.path.abspath(__file__))
ids = dict(l.split() for l in open(os.path.join(S, "out", "gun_uploads.txt")) if len(l.split()) == 2 and l.split()[1].isdigit())
anc = lambda v: json.load(open(os.path.join(S, "out", f"Gun_{v}.json")))["anchors"]
V = lambda p: "Vector3.new(%s, %s, %s)" % tuple(p)
# game gun id -> (receiver variant, muzzle variant, {barrel option: variant})
GUNS = {
    "AKM": ("AK", "AK", {"Standard": "AK", "Short": "AKShort", "Long": "AKLong"}),
    "AK47": ("AK47", "AK47", {"Standard": "AK", "Short": "AKShort", "Long": "AKLong"}),
    "M16A1": ("AR20", "AR20", {"Standard": "AR20", "Short": "AR10", "Long": "AR20", "Carbine": "AR16"}),
    "M14": ("M14", "M14", {"Standard": "M14", "Short": "M14Short", "Long": "M14Long"}),
    "M1Garand": ("Garand", "Garand", {"Standard": "Garand", "Short": "GarandShort", "Long": "GarandLong"}),
}
out = []
for gun, (recv, muz, barrels) in GUNS.items():
    a0 = anc(barrels["Standard"])
    out.append(f'\t{gun} = {{ Grip = "Rifle", Receiver = {ids[f"Gun_{recv}_Receiver"]}, Muzzle = {ids[f"Gun_{muz}_Muzzle"]}, Optic = {V(a0["Optic"])},\n\t\tBarrels = {{')
    for opt, var in barrels.items():
        a = anc(var)
        out.append(f'\t\t\t{opt} = {{ Asset = {ids[f"Gun_{var}_Barrel"]}, Muzzle = {V(a["Muzzle"])}, Under = {V(a["Under"])}, End = {V(a["MuzzleEnd"])} }},')
    out.append("\t\t} },")
acc = {"Suppressor": ("Suppressor", "Muzzle"), "Compensator": ("Compensator", "Muzzle"), "PSO": ("ScopePSO", "Optic"),
       "Colt3x": ("ScopeColt", "Optic"), "Foregrip": ("Foregrip", "Under")}
al = [f'\t{k} = {{ Asset = {ids["Gun_" + v]}, At = "{at}" }},' for k, (v, at) in acc.items()]
src = open(os.path.join(S, "gunparts_template.lua")).read().replace("--GUNS--", "\n".join(out)).replace("--ACCESSORIES--", "\n".join(al))
open(os.path.join(S, "..", "..", "src", "shared", "GunParts.lua"), "w").write(src)
print("wrote GunParts.lua", len(GUNS), "guns")
