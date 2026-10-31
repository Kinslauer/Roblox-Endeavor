# Endeavor — project memory

Read this first in every session. It is the short, current state of the project; docs/ has the long form.

## What this is
A Roblox experience ("Endeavor", universe 10773835758) with two places:
- **Endeavor** (start place 120490278050491, built from `default.project.json`): permadeath, always-on PvP open world
  in a ruined cyberpunk megacity. Melee combat inspired by Cursed Gear (flickering cursed energy / Black Flash,
  cybernetics, raids, devour) and Deepwoken (posture, parry, feint, stat-gated skills). Destruction & salvage,
  hideouts with wear/repair/upgrade economy, raids on compounds.
- **Front** (place 81481823786216, built from `war.project.json`): the war world. Cold War era, TTK/Tarkov-style
  simulated firearms, factions Union vs Pact, a moving hill, global ever-tipping ticket scales, recruits ordered from a
  conduit's locker, permadeath recruits whose gear drops damaged, entrenching, staged structures, artillery.
Conduits "tap in" from Neural Net terminals in Endeavor and are teleported to the Front; the profile (ProfileService
store `ConduitCharacter_v2`) is shared by both places.

## Layout
- `src/shared` → ReplicatedStorage.Shared (Config = every tunable; Weapons, Armor, Cybernetics, Skills, Items, Props,
  Firearms, Hideout, Remotes, Assets = every uploaded model id). `src/common` → ServerScriptService.Server.Common in both
  places (Net, PlayerData, ProfileService, Recruit, ModelAssets = asset loader/cache/spawner). `src/server` = Endeavor systems, `src/war/server` = Front systems, `src/client` and
  `src/war/client` = the two clients (one LocalScript each).
- Every client->server remote goes through `Net.On` (rate limit + arg types). Clients only send intent.
- Entry points (`Main.server.lua`) wrap everything in pcall and print `STARTUP FAILED: ...` on error.
- Docs: `README.md` (features + controls), `docs/DESIGN.md`, `docs/systems/destruction-and-salvage.md`,
  `docs/maps/*.png` (generated top-down maps), `vendor/combat-system` (reference code the combat was ported from).

## How to work
- Tools live outside the repo in this cloud env: Luau CLI at `/home/user/scratch-luau/{luau,luau-compile,luau-analyze}`,
  Rojo at `/home/user/scratch-rojo/rojo`. If missing: Luau from github.com/luau-lang/luau releases (luau-ubuntu.zip),
  Rojo 7.5.1 linux zip from github.com/rojo-rbx/rojo releases.
- **Check code**: `luau-compile --text file.lua` and `luau-analyze file.lua` (ignore Unknown global/require/type noise).
- **Smoke tests (no Roblox needed)**: `python3 tools/smoke/gen.py [tools/smoke/{scenario,war,stress,client}.lua] > /tmp/x.lua && luau /tmp/x.lua`.
  `scenario` = Endeavor end to end (84 checks), `war` = Front (34), `stress` = budgets under load, `client` = the
  Endeavor client boots. They run the real scripts against a small mock of Roblox (`tools/smoke/mock_prelude.lua`);
  the mock is lenient about property names, so a real-Roblox error can still slip through.
- **Real-server check**: Open Cloud Luau execution (`ROBLOX_API_KEY` with Luau Execution Sessions: Write) runs a script
  on a real server of the published place: see the pattern in this session's scratch `run_luau.py` (POST
  `cloud/v2/universes/{u}/places/{p}/luau-execution-session-tasks`, poll, read `/logs`). Use it to reproduce errors.
- **Publish**: `ROBLOX_API_KEY=... ROJO=/home/user/scratch-rojo/rojo tools/publish.sh [endeavor|front|all]`.
  The key is an Open Cloud key the user created (Place Management: Write + Luau Execution: Write on Endeavor).
  It is NOT in the repo; a new session must ask the user for it again (or they store it as an environment secret).
  Roblox sometimes answers 409 "server busy" on the start place; the script retries, and a later retry works.
- Maps: `tools/smoke/dumpworld.lua` / `dumpfront.lua` + `tools/smoke/map.py` draw the generated worlds.
- Commit style: one commit per round, push to `claude/roblox-permadeath-openworld-cj3jfk` (the only branch; no PRs).
- The user tests in Studio (File → Open from Roblox, so DataStores work) or the Roblox app; Studio's Play button
  cannot teleport between places. They cannot see logs easily: ask for F9 → Server/Client tab screenshots.

## Decisions the user made (do not relitigate)
- No classes: weapon = moveset; skills unlock from effective stats + worn armor/cyber tags.
- Flickering cursed energy = Black Flash timing mechanic (tap E before impact; 3 chained = Black Flash + Zone).
- Catching thrown chunks is timing-based (grab press within 0.25s of impact).
- Gore level Restricted (label set in Creator Dashboard, not code); dismemberment, pools, persistent corpses.
- Hideout outlives permadeath; raids can strip it. Compound only stands while the owner is online.
- Front: separate place; realistic weapon handling with every part simulated; moving hill awards tickets; no rounds;
  recruit permadeath drops everything damaged; conscript bodies are not loot; income only while deployed.
- Entrenching: foxholes and low sandbags only, on open ground.
- Controls are the Cursed Gear layout: E flicker, F block/parry, Q dodge, X interact, M devour/app, R/Y/V skills,
  Z feint, G grab/throw, H drop, Shift sprint, Tab inventory, L loadout, J attributes, O hideout, N recruit app,
  P helmetcam. Front: LMB fire, RMB aim, R reload, T rack/unjam, B selector, 1/2 switch, G frag, H dressing, Q/E lean,
  K artillery, F dig, V sandbags, M app.

## State (2026-10-31)
- Both places published and starting cleanly (Endeavor v20, Front v10). Front v10 verified on a real server:
  Battlefield.Init builds 57 mesh structures, 621 sandbag nests, 14 wrecks, 36 hedgehogs, 27 crates in 3.9s, no warnings.
  Endeavor v20 predates the Animator fix, mirrored Raider, three new enemies, returning-player fast path, weapons in
  hand: publish it (`tools/publish.sh endeavor`) once the user has closed Studio (409 until then). Spawn fall-through fixed by anchoring the
  character for Config.SpawnSettle after placing it.
- User reported keys not working in Studio before v16; v16 adds visible swing arcs, block outline, sprint and a
  controls card. If keys still do nothing, get the F9 Client tab log.
- **Models are made here, not by the user** (they are "just a gamer"): Blender 4.2 runs headless in this env
  (`/home/user/scratch-blender/...`), props are built by script (`tools/models/`, see its README), previewed with a
  software rasterizer, uploaded as Model assets via Open Cloud (`tools/models/upload.py`, key needs Assets: Write,
  key user id 3155619052), and wired by ID in `src/shared/Assets.lua` with A/B/C condition variants. The nine street
  props + streetlight + 3 chunks, and the building kits (5 district styles x 3 heights x intact/collapsed,
  `tools/models/buildings.py`, bmesh-merged to ~7 MeshParts each, `Assets.Buildings` + `Assets.PickBuilding`) are
  done (Endeavor v18). Model loading is in `src/common/ModelAssets.lua` (cache, dress, anchor, bottom pivot).
  Enemy rigs (Raider/Brute/Shocker/Warden, `tools/models/raider.py` + `enemies.py`) are R15 limb meshes jointed by
  `src/server/Rigs.lua` (Motor6Ds from limb positions, Animator created before replication, Roblox's public R15
  idle/walk anims). Left limbs must be at -X. Display mannequins stand on magenta pads by the test armory.
  Weapons in hand: `tools/models/weapons.py` -> `Assets.Weapons` (6 ids), welded into RightHand by `src/server/HeldWeapons.lua`
  (players on every Stats.Apply, NPCs via `NPCs.Types[t].Weapon`, arena mannequins too). Grip offsets unverified in-game.
  Front props (`tools/models/front.py` -> `Assets.Front`): sandbag nests A/B tile the trench lips and nests, trucks A/B,
  hedgehogs on sector edges, ammo crates; a soldier's stacked sandbags carry the LowSandbags mesh inside the collider
  part. Everything falls back to the old generated boxes when an asset fails to load.
  Front staged buildings (`tools/models/front_buildings.py` -> `Assets.FrontBuildings`, Farmhouse 18x16x9 and Hall
  24x20x12, four stages each) replace the box structures; Battlefield picks the kit nearest the wanted width.
  Hideout modules (`tools/models/hideout.py` -> `Assets.Hideout`): bench per tier, vault, bunks, generator, turret, forge,
  medbay; each mesh sits inside its collider part (`dress()` in Hideouts.lua), prompts stay on the part.
  Sounds: 25 synthesized effects + 3 ambient loops (city hum, wind, Front wind with distant guns) (`tools/sounds/synth.py`, uploaded as Audio assets) in `src/shared/Sounds.lua`; both
  clients play them from their existing event handlers (`Sounds.Play(name, partOrPosition)`). Unheard by me: verify in-game.
  Still placeholder: custom animations, arena/raid geometry, hideout walls (generated slabs).
  Known limit: MeshPart CollisionFidelity can't be set from scripts, so collapsed stumps may collide as hulls.
- All balance numbers are first guesses pending the user's playtest checklist.

## Open items
- Next art: hideout walls/gate,
  animations (hooks exist: `CombatEvent` "Swing"). Awaiting the user's in-game look at the rigs (animation playback can't be verified from the Luau execution API).
- The user's playtest checklist (pending).
- Front: real 20-player frame-rate test; war world art; vehicles are intentionally absent.
- Experience internal name is still "Conduit" (cosmetic; rename in Configurations → Basic Settings).
