# Models (Blender -> Roblox)

Props are built by script in Blender (no GPU needed) and uploaded to Roblox as Model assets through Open Cloud.
The game loads them by asset ID (`src/shared/Assets.lua`) and falls back to generated blocks for anything missing.

    BLENDER=/home/user/scratch-blender/blender-4.2.3-linux-x64/blender   # 4.2 LTS linux tarball from download.blender.org
    $BLENDER -b --python tools/models/streetlight.py      # -> tools/models/out/*.fbx (+ *_preview.obj)
    $BLENDER -b --python tools/models/props.py            # nine props x conditions A/B/C
    $BLENDER -b --python tools/models/weapons.py          # the six held weapons (grip at origin, blade along +Y)
    $BLENDER -b --python tools/models/front.py            # the Front's props: sandbags A/B, low sandbags, trucks A/B, hedgehog, ammo crate
    $BLENDER -b --python tools/models/front_buildings.py  # Farmhouse/Hall x 4 stages (intact, damaged, ruined, rubble)
    $BLENDER -b --python tools/models/hideout.py          # hideout modules: bench x3 tiers, vault, bunks, generator, turret, forge, medbay
    $BLENDER -b --python tools/models/compound.py         # hideout wall panel + gate frame, raid arena wall/pillar/gate shells
    $BLENDER -b --python tools/models/firearms.py         # the Front's seven firearms (grip at origin, barrel along +Y)
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
