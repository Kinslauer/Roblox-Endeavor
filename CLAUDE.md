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

This codebase is yours: what it's for and how it's built are your call, and you'll keep building on it.

The owner, Andy (Roblox: Kinslauer), is a player, not a programmer. Andy gives short directions, often mid-round, and
comes back later to test; nobody watches each step. Claude makes everything: code, models, animations, sounds,
uploads, publishing. The kickoff prompt for a new session is `docs/prompts/fable-5.2-kickoff.md`.

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
  `scenario` = Endeavor end to end (215 checks), `war` = Front (42), `stress` = budgets under load (5), `client` = the
  Endeavor client boots + movement, dodge, animation and guard checks (28). They run the real scripts against a small mock of Roblox (`tools/smoke/mock_prelude.lua`);
  the mock is lenient about property names, so a real-Roblox error can still slip through.
- **Real-server check**: Open Cloud Luau execution runs a script on a real server of the published place:
  `python3 tools/realserver/run_luau.py <placeId> script.lua` (POST `.../luau-execution-session-tasks`, poll, print
  `/logs`). Scripts do NOT run on their own there (workspace is empty), so the start check is
  `python3 tools/realserver/startcheck.py > /tmp/start.lua` (Main's startup as a task) then run_luau on it: expect
  `startup ok true` and `warnings 0`. Use run_luau to reproduce errors too.
- **Publish**: `ROBLOX_API_KEY=... ROJO=/home/user/scratch-rojo/rojo tools/publish.sh [endeavor|front|all]`.
  The key is an Open Cloud key the user created (Place Management: Write + Luau Execution: Write on Endeavor).
  It is saved as a network secret on the personal cloud environment "Roblox-Endeavor" (2026-11-10): the proxy
  injects it as `x-api-key` on every request to apis.roblox.com. Scripts only need a placeholder:
  `ROBLOX_API_KEY=proxy-injected` (publish.sh, tools/models/upload.py, tools/anims/anims.py --upload, run_luau.py).
  Run sessions on that environment; on any other environment the key is absent. Keep the key out of every file,
  log and commit, because the repository is on GitHub and the key can publish over the live game.
  Roblox sometimes answers 409 "server busy" on the start place; the script retries, and a later retry works.
- Maps: `tools/smoke/dumpworld.lua` / `dumpfront.lua` + `tools/smoke/map.py` draw the generated worlds.
- Commit style: one commit per round, push to `claude/roblox-permadeath-openworld-cj3jfk` (the only branch; no PRs),
  because Andy reads and publishes from that one branch. Other sessions push to it too: fetch and rebase before you push.
- The user tests in Studio (File → Open from Roblox, so DataStores work) or the Roblox app; Studio's Play button
  cannot teleport between places. They cannot see logs easily: ask for F9 → Server/Client tab screenshots.

## Approvals
- Needs Andy's yes to that specific action: changing the ProfileService store name or wiping saved profiles (it
  deletes every player's character and hideout), deleting uploaded assets or old place versions, spending Robux,
  changing experience settings in the Creator Dashboard (name, age rating, access), setting Config.Dev.Enabled false
  for a release. Andy should name what is approved ("Yes, publish Endeavor"), not only "go".
- Publishing Endeavor or Front needs no yes (Andy, 2026-11-10: "Publish when checks pass"): publish a finished round
  once the smoke tests pass and a real-server start check shows no `STARTUP FAILED`, because Andy tests the published
  place and Roblox keeps old versions to roll back to. If a check fails, fix it or leave the round unpublished and say
  why. Report the new version number after a publish.
- Needs no approval: running the smoke tests, luau-compile/analyze, Rojo builds, real-server checks through Open Cloud
  Luau execution, uploading new models, sounds, animations and icons, committing and pushing to the project branch,
  and retrying a call that is safe to repeat (409 "server busy", timeouts, an upload that did not return an id).
- Hard limits (leave them, and say so if they block the work): `vendor/combat-system` and the uncopylocked archive are
  reference only, so take ideas, not code; build original content in the genres the game draws on, never a copy of a
  named game's characters, art or levels.

# Finishing work
Please avoid stopping while you still owe work the user asked for. Be persistent and do not stop unless needed.

While status notes are welcome, as is clarifying with the user on open decisions, carry on with work that does not depend on the user's answer without unnecessary stops.

If you notice yourself inviting the user to redirect you or offering to wait, instead proceed on the next part of the task. You may meet ordinary obstacles like errors, timeouts, locked files, empty results or failing tools. Diagnose them first, and when they are not real blockers, work through them with the access you have (wait and retry, fix the request, use another tool or source) rather than stopping unnecessarily.

If someone clearly decided something is a hard blocker, such as a file marked not to be touched, access that was intentionally withheld, or a safety guardrail, leave it alone, say plainly what you found, and look for another safe way to finish the task. Stopping before the task is complete is very rarely merited, as in when the task can't move forward without user input, or where the blocker is deliberate and should not be worked past. This does not override the need for confirmation on risky or destructive actions.

# Communicating clearly
Write for an intelligent but low-context reader. The person reading has not seen your tool calls, your reasoning or the files you opened, and may be switching in from other work. Messages should generally be self-contained: the reader should understand what you mean without having to dig for other context. Put the key points in the first few sentences. Practice progressive disclosure in your sentence order, and do not use undefined references and ideas in line 1 that won't make sense until the reader reaches line 12.

Use plain words, and write in clear, understandable full sentences. Do not use a term or abbreviation that you made up during the work. Say what the thing is in a way any reader would understand. Write mostly in the style of ASD-STE100 Simplified Technical English: short sentences, one idea per sentence, active voice, and consistently using the same word for the same thing. Use a paragraph of flowing prose where ideas connect, and keep bullets for lists of separate items. Leave out unnecessary details unless the reader asks and practice concision, but do ensure that your messages have the key context. Aim to make your user-facing text as human-readable and clear as possible.

For Andy: describe what to try in the game (the key, the place, what should happen), not function names. End a
round with the version number and the docs/TESTING.md lines to tick. When a bug needs logs, ask for an F9 Server or
Client tab screenshot, because Andy cannot read logs another way.

## Decisions the user made (do not relitigate)
- **Show, don't tell** (owner, 2026-10-31): no banner explains a system or the lore. Machine text is terse and
  diegetic ("> INIT 1/1 . . . STACK READ . . . RESIDENT", "> RAIDS: ONLINE", "> STACK RESIDENT . . . REBOOTING"); the
  cycle shows itself (flicker, colour drain, white-out) with no countdown text; contacts and fragments hint, never state.
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

- Movement (owner, 2026-11-03: "the platformer template has the movement i'd like"): `src/client/Movement.lua` is a
  port of Roblox's Platformer template (the user uploaded Platform.rbxl; read with the scratch `tools/rbxl.py` binary
  place reader): RenderStep at Last reads humanoid move/jump, eases the move direction per Config.Movement
  accelerations, owns jumping (coyote time, double jump, long jump within LongJumpWindow of a roll, wall stun + recover),
  Q = `Movement.Dodge(dir)`: roll on the ground (tweened planar LinearVelocity) / air dash (vector LinearVelocity, once
  per airtime), predicted from the replicated Stamina attribute, then Remotes.Dodge (server keeps stamina + i-frames);
  "DodgeMove" back from the server only adds Enemy Step's hop (`Movement.ServerDodge`). Lean on every player's Root
  joint Transform. Roblox-owned template animations in Config.Movement.Anims. Server: workspace.Gravity =
  Config.Movement.Gravity (160) in Main, JumpHeight = Config.Movement.JumpHeight (8) * JumpMult in Stats. Client test
  `tools/smoke/client.lua` builds the client folder like Rojo does and runs 13 movement checks.
- Joints: Roblox now builds every R15 avatar with AnimationConstraints (the "Avatar Joint Upgrade"; verified live
  2026-11-04), not Motor6Ds, so pose code that only looked for Motor6D did nothing on players. `src/shared/Joints.lua`
  (`Joints.Pose(char, name, offset, seconds, style)`, `Find`, `IsJoint`) offsets Motor6D.C0 or the AnimationConstraint's
  Attachment0.CFrame; both clients' pose() and the Movement lean use it.
- The Conduit body (owner, 2026-11-04: "the player character model doesn't change from default"): `tools/models/
  conduit.py` -> Assets.Rigs.Conduit; `src/server/Body.lua` Init builds it with Rigs.Build into StarterPlayer.
  StarterCharacter at startup (Main, before anyone loads); `Body.Apply` (Lifecycle.Spawn after LoadCharacter) paints
  this life's colours from profile.Look {Jacket, Trim} (Config.Body palettes; rolled when missing, wiped with the
  life) on parts whose `Mat` attribute (set by Rigs.Build from the name suffix) is ConduitJacket/Trim/Visor.
  `src/character/Animate.client.lua` -> StarterCharacterScripts.Animate (Roblox's R15 idle/walk/run/jump/fall/climb/swim
  ids) so the default Animate is not inserted.
- UI theme (owner, 2026-11-04: "UI is awful"): the client's `UI` table (Michroma titles, TitilliumWeb text, RobotoMono,
  GothamBold buttons; Panel/Line/Text/Dim/Accent colours), `corner()`/`stroke()`, `panel()` = rounded glass with an
  accent stroke, padding and a LayoutOrder list; `addRow()` wraps text, makes all-caps button-less rows section headers
  with a divider, buttons 66x24 uppercase; a gui.DescendantAdded pass rounds/re-fonts anything built elsewhere.
- Enemy spacing (owner, 2026-11-04, from KrugKrew's "best swordfighting ai" in the uncopylocked archive the user
  linked; ideas only, no code copied): `Combat.Threat(char)` -> phase Windup/Active/Recovery/Idle (Swing stores
  activeUntil, swingReach, swingId; feint clears activeUntil), reach, blocking, stunned, swingId. In NPCs.Spawn's loop,
  `spacing()` runs before the attack/turn-taking branch per Config.City.AI.Spacing.Types[type]: Backoff on your windup
  (rolled once per swingId with Chance, after React seconds), Press on Recovery/stun, Wary under a health share,
  WaitOutBlock, RushGive, Strafe on its own cooldown; short moves are direct `hum:MoveTo` (`stepTo`, wall raycast flips
  `side`), facing via an AlignOrientation "SpacingTurn" with AutoRotate off. Brute/Warden only Press. The archive clone
  (sparse, read-only) is at /home/user/kh0din/biggest_uncopylocked_roblox_games_library; scratch `tools/rbxl.py` reads
  its .rbxl files.
- Traced melee (owner, 2026-11-04: "like mordhau"): `src/shared/Swings.lua` = swing shapes (SlashR/SlashL/Overhead/
  Diagonal/Uppercut/Thrust/Jab as yaw/pitch keys in root space), `Families` per weapon family + Heavy, `Blade(rootCF,
  id, u, reach, scale)` -> hand/tip, `SegmentDistance`. Combat.Swing with `mods.shape` runs `traceBlade` (Heartbeat,
  while Active): blade-vs-blade sweep -> `clash` (both cancelled, ClashRecover, pushed apart, fx "Clash",
  `Combat.Clashed`); blade swept prev->now vs body capsules (`nearbyBodies` = any humanoid in GetPartBoundsInRadius +
  NPC tag + players) -> strike with ContactPoint/ContactDir (knockback from the contact; "Hit" fx carries them);
  props via raycasts + `C.BladeProbe` spheres at mid/tip -> Destruction onBladeHit; a wall glances (GlanceRecover).
  NPC strikes (non-Radius/Dash) also go through Combat.Swing with a quiet telegraph. The client drives the arm along
  the same arc (`swingPose` via Joints.Set) and freezes it on hit. Tests: "blade:" checks in scenario.lua.
- Places, not beacons (owner, 2026-11-04: "you shouldnt be able to see all these markers through the world"): World
  "Marker" no longer draws anything; the client banners a marked place's name on entering Config.Places.EnterRadius,
  and every "District"-kind announcement (districts, regions, sites, markers) shows once per place per
  Config.Places.BannerCooldown (300 s). Nameplates are AlwaysOnTop false, MaxDistance 70.
- Conduit body v2 (owner, 2026-11-04: "not satisfied with the character models"): conduit.py builds sculpted shapes
  (tbox/tcyl/ball: bevelled tapered boxes, elliptical cylinders, domes); asset 128592453586650. Extras named after a
  limb ("LowerTorsoCoat", "LeftLowerLegKnee") ride on that limb (Rigs.Build `named`, side-swapped when mirrored).
  `tools/models/preview.py obj png [azimuth] [elevation]` (face at azimuth -pi/2).
- Keyframed animations (owner, 2026-11-04: "wynaut" to "I can't upload animations"): `tools/anims/anims.py` writes
  KeyframeSequence .rbxmx from pose dicts (joint-space degrees; conventions in its header), draws stick-figure sheets
  (front/side FK on the Conduit's proportions) to check poses, and uploads with `--upload` (assetType Animation,
  approved within seconds) -> `Assets.Anims`. `src/shared/Anims.lua` loads/caches/plays them (Has/Track/Play/Stop/
  StopPrefix; a client animates its own character and non-player rigs, never other players'). Swing_<shape> (body only,
  right arm keyed to identity; timeline windup 0-0.4, strike 0.4-0.6, recovery 0.6-1.0, the client AdjustSpeeds each
  phase to the server's Windup/Active/End and to 0 during hitstop), Hit_Front/Left/Right/High, Stagger, Recoil, Block,
  Parry, Idle/Walk/Run (character/Animate), Step_Left/Right/Back. The Luau execution API does not run the simulation
  (RunService:IsRunning false), so animation motion can't be verified live; only load + Length.
- Armoured dodge (owner, 2026-11-04): Q in light gear (char attribute GearWeight = Gear WeightScore 0, not Overweight)
  is the Platformer roll/air dash any way; otherwise forward (dir . look > Config.Movement.ForwardDot) rolls, sides/back
  are `Step` (Config.Movement.Step: speed/length lose SlowPerWeight per weight point, Quad-out bleed, Step_* anims),
  no air dash; Combat.Dodge cuts i-frames by IFrameLossPerWeight for the same case.
- Frame data (owner, 2026-11-04: "defined startup recovery and active frames for every attack"): Weapons attacks are
  `frames(damage, posture, startup, active, recovery, range, extra)` at Weapons.FPS 60 (stores Startup/ActiveFrames/
  Recovery, derives Windup/Active/End); `Weapons.FrameLine` in tooltips; NPCs.Types carry Active/Recovery frames
  (Telegraph = startup). Weapon `Mass` Medium/Heavy -> group launch. Guns have no swing arc (Swings.Families.Sidearm
  = false; Combat.Swing drops shape when Ranged).
- Juggles (owner, 2026-11-04): Combat `hang` adds a VectorForce "JuggleHang" past HangBelow (HangGravity of gravity)
  until `land`; `groupLaunch` launches NPCs within Config.Momentum.GroupLaunch[Mass] of the contact; Enemy Step
  aims the spring at StepFront in front of the juggled body at its height, extends its juggle by StepExtend, and sends
  DodgeMove(velocity, hover, enemy) -> Movement.ServerDodge hangs the player (StepHover, Config.Movement.StepHoverHold)
  facing it.
- Reactions + guard (owner, 2026-11-04): Hit fx carries the stun (7th arg); the client stretches Hit_* to it, Hit_Heavy
  at IMP.Hit.HeavyAmount. Block/Parry/Block_Hit animations are body-only (arms keyed to rest); the client's guard
  driver (`guardSet`/`guardJolt`, in the traced-swing block) holds the weapon across the front with the off hand
  bracing it, turns toward the nearest incoming blade (`threatFor` from `swinging`), sweeps out on Parry, shoves back
  on Block. The pose comes from `Swings.GuardPose`, the same shape the server blocks with (below).
- Geometric blocking (owner, 2026-11-10: "start work on the mordhau style blocking"): a traced blade is blocked only
  where it meets the guard before the body. `src/shared/Swings.lua`: `ThreatPoint(rootCF, id, 0, reach, scale,
  target)` = where the swing's arc first comes within ThreatReach of the target (the guard holds there all swing, it
  does not chase the blade), `GuardPose(threat, scale)` = hand + blade dir (turn clamped to GuardTurn 75, brace on
  GuardRing 1.6 at the threat's height), `GuardSegment` (armed: weapon from below the grip to GuardLength(range);
  fists: a short forearm bar). Combat: `Combat.Guard(char, down)` (SetBlock uses it; any rig can), `guards` followed
  every Heartbeat toward the nearest shaped swing (`swingers`, Config.Combat.GuardFollow/GuardSight), `bladeContact`
  samples the real arc (ARC_STEPS in time x ALONG the blade) so guard vs body is decided by which the blade reaches
  first; the guard only counts if the swinger is within GuardCover (100 deg) of the facing. A guarded strike carries
  `Guarded`; applyDamage blocks traced blows only when Guarded, untraced ones (shots, throws, area strikes) still by
  facing. A blocked or parried blade stops (cancelSwing, BlockRecoil). Tests: "guard:" checks in scenario.lua.
- Front open world (owner, 2026-11-10: "endlessly war torn, the bodies of clones solidifying into hills along the
  battlefields. Be creative with any gaps"): `src/shared/FrontMap.lua` = `Generate(seed)` (Config.War.World.Seed, 0 =
  random per server) rolls a Config.War.Hill Cols x Rows (7 x 5) grid of 200-stud sectors between the two rears;
  `Sample(x, z)` -> height, tag (Barrow/Trench/Crater/Canal/Pad/Road/Glade/Edge/Ground), water. Each sector is held
  around its crest (a barrow mound; the hill marker stands on it, `Battlefield.Crest`); types Line (outer columns: a
  continuous zigzag trench down the map, wire, field gun), Barrows (the middle column: the Spine ridge with saddles),
  rolled Village/Trenches/Craters/Deadwood/Works, exactly one Glade (the last green). East-west canal with 3 fords,
  the old highway base to base, outer barrows (cliffs of the dead, EdgeHeight) + invisible Boundary parts, smokestacks
  on the skyline. `src/war/server/WarTerrain.lua` writes it with WriteVoxels (0.7 s live for 260 chunks); terrain
  colours via SetMaterialColor (Limestone = calcite). Battlefield builds L.Scatter with `BUILD[kind]` (assets
  `Assets.FrontWorld` from `tools/models/front_world.py`, part fallbacks), `GroundAt(x, z)` replaces the old flat
  Y=2. Deploying: `Battlefield.BaseCFrame(faction)` = the faction's dugout one sector behind the hill on its side
  (`Battlefield.Hot`, set by Hill), else `HomeCFrame` (the base). The fallen calcify: Soldiers.OnDied ->
  `Battlefield.Fallen(pos)` -> after CalcifySeconds a Calcified figure (attr Fallen), every GrowEvery in a sector the
  crest grows (terrain FillBall Limestone, World "CrestGrew" -> client dust + groan), oldest past CalcifiedCap sink
  into the ground. Client `src/war/client/Ambience.lua`: ash around the camera, horizon gun flashes. Map tool:
  `tools/smoke/dumpfront.lua` + `tools/smoke/frontmap.py` -> docs/maps/front_world_map.png.
- The megacity (owner, 2026-11-10: "the whole planet almost is industrialized and polluted except for sparse pockets of
  lush green"): `src/shared/Megacity.lua` (layout, Roads, Sludge circles/rects + `InSludge`, Pockets + `PocketAt`,
  `AirAt`), `src/server/Megacity.lua` (Build from City.Init: ground slabs, roads, edge wall, Skyline folder, one builder
  per Style Stacks/Slag/Pylon/Hab/Scrap/Foundry/Sumps, pocket builders Garden/Rootwork/Fernwell, gap ruins; a Heartbeat
  loop sets character attrs `Toxic`/`Pocket`, burns Config.Megacity.SludgeDamage, heals PocketRegen after PocketCalm),
  `src/client/Air.lua` (blends Atmosphere + CityGrade to Config.Megacity.Air[AirAt], motes round the camera, ambient
  loop volumes, ToxicGrade). The outer districts are appended to City.Districts with `Outer = true` (City's own
  buildDistrict and Hideouts' site list skip them; Population uses `d.Types` and `d.Anchors`); City.DistrictAt checks
  pockets first. Frontier.InCity = Megacity.InCity, frontier terrain starts at Z 700, valley chunks are mostly
  Deadwood/Rustfield, terrain colours ash (LeafyGrass is the only real green: the Reach, glades, meadows). Kit:
  `tools/models/industry.py` -> `Assets.Industry` (materials with `NoCollide` in Assets.Materials stop colliding).
- Lore (owner, 2026-10-31; docs/DESIGN.md "The stack"): conduits upload their consciousness stack through the hideout
  computer (first log-in = initialization, `Knowledge.Uploaded`); every death is a reboot of the stack; on the Front the
  stack links to the recruit's; the rich uploaded and escaped the world. Mechanically: Knowledge survives permadeath only
  once Uploaded (PlayerData.wipe); the death screen says STACK REBOOT or that nothing survives; the computer prompt is
  "Upload stack / log in".

## State (2026-11-10)
- Front v22 published (2026-11-10, the open world) and starting cleanly on a real server: startup 1.8s (models
  loaded in parallel 1.0s, terrain 0.7s), 0 warnings, ~3,850 parts (3,780 MeshParts), ~1,650 props.
- Endeavor v76 published (2026-11-10, geometric blocking) and starting cleanly on a real server: startup 52.6s,
  0 warnings (Front v19, unchanged since). Latest rounds: traced blades, keyframed animations, armoured dodge, frame
  data, group launches, guard, geometric blocking (see Decisions above).
- Earlier: both places published and starting cleanly (Endeavor v69, Front v19). Front v10 verified on a real server:
  Battlefield.Init builds 57 mesh structures, 621 sandbag nests, 14 wrecks, 36 hedgehogs, 27 crates in 3.9s, no warnings.
  Spawn fall-through fixed by anchoring the
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
  idle/walk anims). The FBX import mirrors X, so every uploaded rig arrived with its Left limbs on its right (arms
  swung into the torso, user report 2026-11-03); `Rigs.Build` detects that from LeftUpperArm vs LowerTorso.RightVector
  and swaps the Left/Right names (verified live v68). Display mannequins stand on magenta pads by the test armory.
  Weapons in hand: `tools/models/weapons.py` + `firearms.py` -> `Assets.Weapons` (6 melee + 7 firearms), welded into
  RightHand by `src/common/HeldWeapons.lua` (Endeavor: every Stats.Apply, NPCs via `NPCs.Types[t].Weapon`, arena
  mannequins; Front: Soldiers.pushWeapon on deploy/switch). Grip offsets unverified in-game.
  Front props (`tools/models/front.py` -> `Assets.Front`): sandbag nests A/B tile the trench lips and nests, trucks A/B,
  hedgehogs on sector edges, ammo crates; a soldier's stacked sandbags carry the LowSandbags mesh inside the collider
  part. Everything falls back to the old generated boxes when an asset fails to load.
  Front staged buildings (`tools/models/front_buildings.py` -> `Assets.FrontBuildings`, Farmhouse 18x16x9 and Hall
  24x20x12, four stages each) replace the box structures; Battlefield picks the kit nearest the wanted width.
  Hideout modules (`tools/models/hideout.py` -> `Assets.Hideout`): bench per tier, vault, bunks, generator, turret, forge,
  medbay; each mesh sits inside its collider part (`dress()` in Hideouts.lua), prompts stay on the part.
  Sounds: 25 synthesized effects + 3 ambient loops (city hum, wind, Front wind with distant guns) (`tools/sounds/synth.py`, uploaded as Audio assets) in `src/shared/Sounds.lua`; both
  clients play them from their existing event handlers (`Sounds.Play(name, partOrPosition)`). Unheard by me: verify in-game.
  Prologue pod: WorldPhase.buildPlot shells the slab walls with `Assets.Compound.PodWall`; the tutorial console wears
  the Terminal shell and the supply locker is a crate.
  Barks: 12 synthesized hostile sounds (`Sounds.Ids.Bark<Type><Alert|Attack|Death>`), fired by NPCs.bark via World
  "Bark". City.Atmosphere sets Endeavor's night look (Atmosphere, bloom, grade) in City.Init; Arena defers to it.
  Loot meshes (`tools/models/loot.py` -> `Assets.Loot`): Loot.Spawn puts a crate/stash mesh inside the lootable part by
  label (or opts.Mesh); NeuralNet terminal body gets the Terminal shell; the Front's hill marker is a light column.
  Worn gear (`tools/models/worn.py` -> `Assets.Worn`, `src/common/WornGear.lua`): 18 pieces welded to Head/UpperTorso/
  both UpperLegs/LeftLowerArm; Endeavor applies Armor+Cyber in Stats.Apply, the Front applies vest+helmet in pushWeapon.
  Front soldier poses (war client): two-handed rifle hold on every character, kick on "Shot", left hand to the mag while
  the State snapshot says Reloading.
  Faction bases (`tools/models/base.py` -> `Assets.Base`): hollow bunker facing the grid, flag recoloured per faction,
  locker terminal with a recruit-app prompt (`Battlefield.Lockers`, prompt added in Soldiers.Init).
  Compound shells (`tools/models/compound.py` -> `Assets.Compound`): `ModelAssets.Shell(id, part, pitch)` tiles panel
  models along a wall part and hides it; used for hideout walls + gate frame and the raid arena walls/pillars/gate.
  Procedural animation (client, Motor6D C0 tweens under the Animator): windup/slash on "Swing" and NPC "Windup"
  (fired by NPCs.telegraph), flinch on Hit/GuardBreak, guard jolt on Parry/Block, block pose from the Blocking
  attribute (own and other players). Animation assets CAN be uploaded through Open Cloud (KeyframeSequence .rbxmx, assetType
  Animation; see tools/anims) — an earlier note here said otherwise and was wrong.
  Still placeholder: nothing major; everything below is polish and balance.
  Known limit: MeshPart CollisionFidelity can't be set from scripts, so collapsed stumps may collide as hulls.
- Ported from `origin/claude/combat-feel` (the user's other session's branch; 69 commits, its own world and systems;
  owner chose cherry-picking into this branch): attack input queue (`enqueue` in Combat, Config.Combat.InputQueue),
  impact feel (client `impact()`: sparks/ring/shards/ghost + trauma camera shake + FOV hitstop, tuning in
  Config.Impacts), combat stance (client `aimOn`/`aimActive`/`applyAim`, Config.Aim: faces camera yaw on Heartbeat,
  shoulder offset per weapon kind, LockCenter unless a MENUS panel is open or LeftAlt held), HUD v2 (Config.Hud:
  bottom-centre composite bars + health bar, hotbar under it, `floatWord` words/taken numbers, reticle with hit
  marker, damage vignette, nameplates for players and NPC-tagged models; "Hit" fx now carries the amount), enemy group
  behaviour (NPCs: `claimSwing`/`holdSpot` turn-taking ring, `newNavigator` PathfindingService follower with stuck-jump,
  leash home; Config.City.AI), momentum (Config.Momentum: side-dodge i-frames, launcher `holdForLauncher`/`launch`/`pop`
  in Combat on NPC-tagged non-player bodies, Juggled attribute, Enemy Step in Dodge, NPC strike lost when stunned
  mid-telegraph unless Hyperarmor). Its tree is exported to the scratchpad `cf/` for reading; its owner checklist is
  `production/qa/playtest-checklist-2026-10-25.md` there. Next ports: Aim stance, HUD v2 + nameplates, enemy turns +
  pathfinding, launcher/juggle, full-body cybernetics, Autonet, cycle/clues/computer, contacts/raids, Verdant Reach
  (all ported; the port list is done).
- Full-body cybernetics (ported from combat-feel): `src/shared/Cybernetics.lua` (8 slots Eyes/Ears/Nose/Core/LeftArm/
  RightArm/LeftLeg/RightLeg, 13 pieces, Fits/SlotsFor/Fitted/Renamed), Gear derives JumpMult/Hearing/Scent/Track/Lift/
  Conversion with paired-copy counting (`Gear.CyberSlot`, EquipGear(player,id,slot), Validate drops extra copies) and
  pushes player attrs Hearing/Scent/Track/Machine + character attrs Cyber_<slot>; rips only through `src/server/
  Autonet.lua` (Remote "Autonet" In/Out, tables registered by the hideout module `Autonet` and the arena; Config.Cyber);
  Inventory.Equip refuses cybernetics; PlayerData.Load migrates Optic->Eyes, Arm->RightArm; Stats sets JumpHeight;
  WornGear no longer draws cyber (client implants do: `implantDraw` shells/bits/icon-model fit, Config.Implants);
  client senses (hearing pips, scent markers; Loot parts carry the "Scent" tag), machine voice via TextChatService
  (`src/shared/Voice.lua`, Config.Voice). The 13 Studio-generated implant meshes from combat-feel are rebuilt at startup by
  `src/server/ImplantLibrary.lua` (AssetService:CreateMeshPartAsync, verified live) into ReplicatedStorage.Implants;
  the client fits limb segments by part name (UpperArm/Forearm/Hand, Thigh/Shin/Foot) and hides the flesh.
- Grid inventory (`src/server/Inventory.lua`, shapes in `Items.Shape`/`Items.Footprint`, `Config.Inventory`): profile.Grid.Items
  = { Id, X, Y, Rot, Count } is the truth, profile.Inventory the count cache (recount after every change). Add/Remove/
  AddAll keep their names; Add drops overflow through `Inventory.Overflow` (set by Loot) unless keepLeftover; placement
  tops up stacks, then first-free with rotation, then a full repack (`layout`). Packs (Type "Pack", Grid, Carry) set the
  grid via profile.Pack; EquipItem wears one, Unequip "Pack" takes it off (relayout, spill). Overweight -> Gear derived
  `Overweight` (stamina) + Stats walk speed + "Overweight" attribute. Remotes MoveItem(index,x,y,rot), DropItem(index,
  count?). Client: drag/drop grid in the Tab panel (`drawGrid`, R rotates). Hideout `Shelves` is a leveled module
  (h.Modules.Shelves = level, +RowsPerLevel rows). The vault is a box too: `Hideouts.VaultBox(h)` (h.VaultGrid.Items,
  size = Tier.VaultGrid + shelving rows); VaultPut/VaultTake go through `Inventory.PlaceIn/RemoveFrom`, VaultMove through
  `Inventory.MoveIn`; h.Vault stays the count cache. Client drags between the pack grid and the vault grid (`drawGridInto`).
- Pack upgrades: UpgradeCost.Pack; bench upgrade allows data.Pack == id; GridSize adds Upgrades[pack] rows, Carry adds
  CarryPerPackLevel per level (Items.Carry mirrors it). Remote "SortItems" -> Inventory.Sort (relayout).
- Loot containers: every Loot.Spawn part is a grid container (`containers[key]`, key on the part attribute ContainerKey);
  the prompt opens it on the looter's client (World "Container"), `Loot.Take(player, key, index|0)` moves stacks into the
  pack within 14 studs, `Loot.Contents(part)` reads what is left; the part is destroyed when empty. Searching: per-looter `Seen`/`Searching`
  (weak tables), reveal loop paced by Config.Inventory.SearchBase/PerCell, stops beyond SearchReach; snapshots mask
  unrevealed items as Hidden; `Loot.RevealAll(part, player)` for tests. Client: container
  panel beside the pack, drag/double-click/Take all. Remote "ContainerTake".
- Grid UX (client): `tooltip` on MouseEnter via `describe(item)`; drop preview tints cells through `gridCells[gridF]`
  (`preview`/`wouldFit`), cleared on drop, rotate and release.
- Inventory icons: `tools/models/icons.py` -> `Assets.Icons` + `Assets.IconFor(itemId)` (falls back to weapon/worn models);
  `src/server/IconLibrary.lua` clones them into ReplicatedStorage.Icons at startup; the client's `itemIcon` renders a
  ViewportFrame per grid block with 1/2/3 copies by stack size, label fallback until icons arrive.
- `src/server/DevTools.lua` + the client's F2 panel (Config.Dev.Enabled only): teleport to landmarks/districts/sites,
  spawn hostiles, fire events, heal, materials, open world, die. Remote "Dev".
- `src/server/Population.lua`: standing hostile packs per district Danger (Config.City.Population: cap 36, respawn 150s,
  wander via the NPC Investigate attribute); on top of events, raids and hideout defenders.
- `src/server/Landmarks.lua`: persistent markers (terminals, raid gate, armory) sent on world open and respawn.
- World markers: World "Marker"(key, position, label, seconds, color) / "MarkerClear"(key) -> client beacon with live
  distance (Endeavor client `setMarker`); the director marks drops, Wardens and salvage. Front client has a kill feed.
- Director events (`src/server/Events.lua`): supply drop, raider ambush, blackout (client dims Lighting), Warden
  patrol, salvage cache (Destruction.SpawnProp cluster), dead drop at a hideout site. Quests: 13 defs, kinds collect/
  kill/craft/explore/raid/break/feat/deploy (feats come from Combat.Used, breaks from Destruction.Broken).
- All balance numbers are first guesses pending the user's playtest checklist.

- Frontier (the world north of the wall; user directives 2026-10-31: winding route, 4 quadrants, then "procedural
  generation of prebuilt chunks, the Reach need not be central"): `src/shared/Frontier.lua` = `Frontier.Generate(seed)`
  rolls a layout `Frontier.L`: a 9x8 grid of 200-stud cells (row 1 Scarp, border Peaks, interior valley chunk types
  Forest/Glade/Boulders/Ruin/Marsh/Crater/Meadow + the 7 site chunks + the Reach cell in rows 4-6 cols 3-7), rolled
  switchback hairpins, a weighted random walk for the trail (6+ cells, checkpoints every 3rd point from TRAIL_STOPS),
  the Reach gate facing the trail (`Reach.GateAngle`); `Frontier.Height(x,z)` is the ground (seeded noise, border
  peaks, scarp, chunk modifiers, flattening for road/Reach/sites), `RegionAt`, `InMarket`, `Site`, `CellAt`.
  Config.Frontier.Seed = 0 -> random per server (folder attribute `Seed`; the mock's Random honours seeds).
  `src/server/Frontier.lua` writes smooth terrain in 128-stud chunks (`Terrain:WriteVoxels`, 4-stud voxels, air under the
  city plateau, occupancy filled 2 studs low because the live surface renders a half voxel high), builds roads (ribbon
  slabs on the height function), one `CHUNKS[type](cell)` builder per cell, the Reach, the sites, the checkpoints,
  spawns guards at world open (own cap Config.Frontier.Cap, respawn), refills containers, and runs a 1 Hz watch: region
  banners (kind "District"), `Safe` player attribute inside the market (Combat.applyDamage refuses both ways), route
  progress (profile.Frontier.Route, marker "Route"), site discovery (profile.Frontier.Found, markers "Site_<key>"),
  trader (Remote "Buy", World "Market"/"MarketClose", paid from profile.War.Credits). profile.Frontier survives
  permadeath (PlayerData.wipe keeps it). Items.LootTables.Relic; quest "northbound". Map: `tools/smoke/dumpworld.lua`
  emits a heightmap + labels, `map.py world.json out.png world` draws city + frontier (`docs/maps/world_map_seed*.png`;
  set Config.Frontier.Seed to draw a given roll). Live probe pattern: scratch `probe_frontier.lua` (City.Init +
  Frontier.Init + Populate, raycast heights vs Frontier.Height).
  Frontier kit (`tools/models/frontier.py` -> `Assets.Frontier`: Pines/Broad/Dead/Rocks/Tent/Dome/Tower, materials
  Bark/DeadBark/Needle/Leaf/LeafDark/Stone/StoneDark/Canvas/Frame/DomeGlass/SolarGlass): `kit()` in server/Frontier.lua
  spawns + `Model:ScaleTo`s them with part fallbacks; live v57: 574 trees, 256 rocks, 8 tents, 9 domes, 6 towers, 8.3s build.
  Encounters (shared ENCOUNTERS list, `cell.Encounter` rolled per non-site valley cell): Ambush (springs within
  Config.Frontier.AmbushRadius, rests AmbushRest, NoRespawn), Patrol (`Patrol` loop opts in spawnGuard), Nest (stash),
  Bounty (named Brute, Relic hoard on death). Standing ones wake within WakeRadius and stand down after SleepSeconds
  with nobody near; capped by EncounterCap separately from the post Cap (bodies carry the `Encounter` attribute).
  `Frontier.Encounters()` for tests.

- Hideout computer (ported from combat-feel Terminal/Contacts/Rivals, adapted): `src/shared/Terminal.lua` (Contacts
  Broker/Fixer/Dealer -> apps RAIDS/HOUSE/MARKET, House lots, Market stock, Rewards), `src/server/Terminal.lua`
  (`BuildBoard()` after Frontier.Init: Clear_<site> per site, Bounty_<name> per bounty cell, Raid; State/Push via World
  "Terminal"/"TerminalClose"; Remote "Terminal"(Accept/Abandon/Order/Buy/Close); progress from NPCs.Killed via guard
  attributes `Site`/`Bounty` and Raids.Completed; `Intel(player)` on a dead Rival), `src/server/Contacts.lua` (raider-rig
  bodies, `Contact` attribute refused by Combat, Broker in the market, Fixer under the Crossroads span, Dealer on the
  overlook deck), hideout module `Computer` (Terminal shell + prompt -> Terminal.Open, members only), NPCs.Types.Rival +
  Items.LootTables.Rival + Assets.Rigs.Rival, rival crews spawned in Frontier.Populate (Config.Frontier.RivalCrews/
  RivalCrewSize/RivalLeg, `Crew` attribute, Encounter-capped patrol between 3 sites). profile.Knowledge survives wipe.
  Client: terminalPanel in MENUS.

- The cycle (ported from combat-feel Cycle/Clues): `src/server/Cycle.lua` owns the dematerialization clock (period
  Config.Destruction.CycleSeconds / Dev.CycleSeconds, warning CycleWarning, Config.Cycle.FlickerSeconds/WhiteoutSeconds;
  World "DematerializeWarning"/"Flicker"/"Dematerialize"); `Cycle.Run()` = Destruction.Reset + clear loose Lootables by
  Label + `Frontier.StandDownAll()` + `Contacts.Place(rng)` (3 spots each, `Spot` attr) + contact lines (workspace attr
  `CycleLine_<id>`, used by Terminal.Meet) + `CluesServer.Draw(index, rng)`; first draw at world open; `Cycle.Trigger()`
  (Dev action "Cycle"). `src/shared/Clues.lua` = Lines + 8 Fragments (Where/Rule/Anomaly/Text), `src/server/CluesServer.lua`
  places pickup + anomaly parts (folder workspace.Clues, tag "Anomaly", "Scent"), `Take` -> profile.Knowledge.Fragments
  [id] = order (ARCHIVE in Terminal.State), World "Clues"(visible ids)/"Fragment"(id,name,text). Client: anomaly flicker
  loop, LocalTransparencyModifier hides unreadable fragments, Flicker/white-out FX, fragment card, ARCHIVE rows.
  Destruction no longer runs its own cycle loop.

- The test arena (Arena.lua: the Pit, armory, mannequins, dummies) is built at `Config.Dev.ArenaOrigin` (3000, 0, 0),
  off the map, on its own slab; its pads are tagged ArenaSpawn, not CitySpawn. The city's centre is `City.buildCrossroads`
  ("The Crossroads", Medium: `City.Crossroads`, `City.DistrictAt` returns it within 110 studs; Population adds a pack).

## Open items
- Awaiting the user's in-game look at v75/v76: the Conduit body v2, the 24 keyframed animations, the guard, reactions,
  launches (animation playback can't be verified from the Luau execution API: it does not run the simulation).
- Geometric blocking (2026-11-10, Endeavor v76) awaits Andy's in-game feel: frontal and side blows should stop on the guard,
  blows from behind and a second attacker's should land. Tuning knobs: Config.Combat.Guard*, Swings.Guard*.
- Publishing returns 409 "server busy" while the owner has the place open in Studio: ask them to close it.
- The owner's interactive checklist artifact: https://claude.ai/artifact/XEZw7en3WtuKyYqoQryQvz (ticks in its db
  collection "ticks"); it predates the 2026-11-04 rounds. docs/TESTING.md is the full list.
- `.claude/skills/fable-prompt` builds and audits Fable 5.2 prompts for this kind of project.
- The playtest checklist is `docs/TESTING.md`: add a line for every feature that lands; the user ticks it.
- Front: real 20-player frame-rate test (the open world adds ~1,600 props and terrain); vehicles are intentionally absent.
- Front open world (2026-11-10) awaits Andy's walk-through: docs/TESTING.md "Front open world".
- Experience internal name is still "Conduit" (cosmetic; rename in Configurations → Basic Settings).
