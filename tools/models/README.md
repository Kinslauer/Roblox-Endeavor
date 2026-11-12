# Models (Blender -> Roblox)

Props are built by script in Blender (no GPU needed) and uploaded to Roblox as Model assets through Open Cloud.
The game loads them by asset ID (`src/shared/Assets.lua`) and falls back to generated blocks for anything missing.

    BLENDER=/home/user/scratch-blender/blender-4.2.3-linux-x64/blender   # 4.2 LTS linux tarball from download.blender.org
    $BLENDER -b --python tools/models/streetlight.py      # -> tools/models/out/*.fbx (+ *_preview.obj)
    $BLENDER -b --python tools/models/props.py            # nine props x conditions A/B/C
    $BLENDER -b --python tools/models/weapons.py          # the six held weapons (grip at origin, blade along +Y)
    $BLENDER -b --python tools/models/front.py            # the Front's props: sandbags A/B, low sandbags, trucks A/B, hedgehog, ammo crate
    $BLENDER -b --python tools/models/front_world.py      # the Front's open world: calcified bodies A/B, barrows A/B, wire, chimney, smokestack, dugout, field gun, stumps A/B, pylon
    $BLENDER -b --python tools/models/front_buildings.py  # Farmhouse/Hall x 4 stages (intact, damaged, ruined, rubble)
    $BLENDER -b --python tools/models/hideout.py          # hideout modules: bench x3 tiers, vault, bunks, generator, turret, forge, medbay
    $BLENDER -b --python tools/models/compound.py         # hideout wall panel + gate frame, raid arena wall/pillar/gate shells
    $BLENDER -b --python tools/models/firearms.py         # the Front's seven firearms (grip at origin, barrel along +Y)
    $BLENDER -b --python tools/models/base.py             # faction base: bunker shell, flagpole, locker terminal
    $BLENDER -b --python tools/models/worn.py             # worn armor + cybernetics (origin = limb centre), both places
    $BLENDER -b --python tools/models/loot.py             # loot crates A/B, stash bag, Neural Net terminal shell
    $BLENDER -b --python tools/models/frontier.py         # the frontier kit: pines A/B, broadleaf A/B, dead tree, rocks A/B/C, tent, greenhouse dome, solar tower
    $BLENDER -b --python tools/models/icons.py            # inventory icons for materials/consumables/ammo/packs (centre origin)
    $BLENDER -b --python tools/models/station.py          # the arrival: Whisper pistol (separate slide), the cloak, the train car shell, the Sentry rig
    $BLENDER -b --python tools/models/industry.py         # the megacity kit: smokestack, tank, cooling tower, pylon, blast furnace, junk pile, giant tree
    $BLENDER -b --python tools/models/train.py           # the realistic pass: Line 9 car, door leaf, the skinned live cloak (bones R<row>C<col> + Hood), on the texture library
    $BLENDER -b --python tools/models/gunparts.py -- <hammer|striker|revolver|rifle|all> [variant] --stills --export   # every gun part; charts -> out/chart_*.png, game models -> out/Gun_<Variant>.fbx
    $BLENDER -b --python tools/models/gunparts.py -- <ak|garand|rifle|acc> <variant> --components [--only=Barrel,Muzzle]   # one FBX per component (out/Gun_<Variant>_<Component>.fbx) + anchors (out/Gun_<Variant>.json)
    python3 tools/models/gunparts_lua.py   # anchors + uploaded ids -> src/shared/GunParts.lua
    $BLENDER -b --python tools/models/render_intro.py [-- shot ...]   # Cycles stills (aisle rider length outside pistol pistol_q kit cloak) -> out/render_*.png (CPU, ~1-2 min a shot)
    python3 tools/textures/gen.py && $BLENDER -b --python tools/textures/swatches.py   # the material library -> tools/textures/out
    python3 tools/models/preview.py out/X_preview.obj out/X.png   # software preview (Pillow), no OpenGL needed
    ROBLOX_API_KEY=... python3 tools/models/upload.py Name out/Name.fbx [...]   # prints "Name assetId"; key needs Assets: Write

Rules that matter:
- `lib.export_fbx` uses `global_scale=0.01` so 1 Blender unit = 1 stud. Without it models import 100x too big.
- Roblox drops Blender material colours. Every object is named `<Part>_<Material>` (lib does this) and
  `Assets.Materials` applies colour / material / glow from the suffix when a model loads.
- Conditions: `<Prop>_A` intact, `_B` worn, `_C` wrecked. `Assets.PickProp` rolls one on spawn and on rematerialize.
- Loaded models are dressed, anchored, and pivoted to their bounding-box bottom so they sit on the ground.
- Chunks (`Chunk_*`) are single meshes used as the physical debris piece; `Props.Defs[...].Chunks[i].Asset` names them.
- Weapons (`Wpn_*`): grip at the origin, business end along Blender +Y (pistols: grip along Y, barrel along +Z).
  Verified on a real server: the FBX import maps Blender +Y -> Roblox +Z and Blender +Z -> Roblox +Y.
  `server/HeldWeapons.lua` welds them into RightHand with `Assets.Weapons[id].Grip` picking the hand offset.

## First-person hands: hands.py (2026-11-12)
    $BLENDER -b --python tools/models/hands.py           # out/ViewHands.fbx + out/ViewHands.json (17 pieces x 3 surfaces)
    python3 tools/models/upload.py ViewHands out/ViewHands.fbx   # id -> Assets.FrontBodies.Hands
    python3 tools/models/hands_lua.py                    # out/ViewHands.json -> src/shared/HandParts.lua
Change a finger's length or a knuckle's place in `DIGITS`, then run all three: the game places every piece from
HandParts, so the model and the file must come from the same run.

## Characters: figure.py + figures.py (2026-11-12)
`blender -b --python tools/models/figure.py -- <Name|all> [--stills] [--quick] [--export]`. One-piece skinned bodies:
`figure.py` is the library (skeleton, lofted garments, weights, export, stills), `figures.py` holds one function per
character. `--export` writes `out/Skin_<Name>.fbx` and `out/Rig_<Name>.fbx` and prints a `LUA <Name> Tints = ...` line
for `Assets.Skins`. Upload both, put the ids in `Assets.Skins` and `Assets.Rigs`. The older `conduit.py`, `raider.py`,
`enemies.py` and the Sentry block of `station.py` built the retired blocky rigs; they are kept for reference.
Layered bodies (the Front's recruits): a figure's `layers={kind: [pieces]}` exports one `Skin_<kind>.fbx` per layer on
the same 15 bones (each with an "Anchor" piece so the importer keeps every bone) and `looks={name: [pieces]}` renders
one set of stills per look. `Union` exports `Recruit` (bare body + wrap + attire) and `UnionKit`, `Pact` exports
`PactKit`, `Augment` exports `CyberLimbs` and `HeavyArmor`. Which pieces show together is `Groups`/`Covers` in
`Assets.Skins`.
The Front's recruits are `Union` and `Pact` (one build, `BUILDS["Soldier"]`; upload one `Rig_Union.fbx` as
`Assets.Rigs.Soldier`). A figure's `statics={name: dict(angles, turn, tris, fused, skip)}` also exports posed,
unskinned copies with `--export` (`Fallen_<Side>.fbx` -> `Assets.FrontBodies.Fallen`, `Calcified_A/B.fbx` ->
`Assets.FrontWorld.Calcified`).
