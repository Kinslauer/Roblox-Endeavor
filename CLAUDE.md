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
- Docs: `README.md` (features + controls), `docs/LORE.md` (the canon: check every addition against it), `docs/DESIGN.md`, `docs/systems/destruction-and-salvage.md`,
  `docs/maps/*.png` (generated top-down maps), `vendor/combat-system` (reference code the combat was ported from).

## How to work
- Tools live outside the repo in this cloud env: Luau CLI at `/home/user/scratch-luau/{luau,luau-compile,luau-analyze}`,
  Rojo at `/home/user/scratch-rojo/rojo`. If missing: Luau from github.com/luau-lang/luau releases (luau-ubuntu.zip),
  Rojo 7.5.1 linux zip from github.com/rojo-rbx/rojo releases.
- **Check code**: `luau-compile --text file.lua` and `luau-analyze file.lua` (ignore Unknown global/require/type noise).
- **Smoke tests (no Roblox needed)**: `python3 tools/smoke/gen.py [tools/smoke/{scenario,war,stress,client}.lua] > /tmp/x.lua && luau /tmp/x.lua`.
  `scenario` = Endeavor end to end (321 checks), `war` = Front (123), `warclient` = the Front client plays the first link's stages, the screen, the controls, the gun in the view and its code-made animation (52), `stress` = budgets under load (5), `client` = the
  Endeavor client boots + movement, dodge, animation, guard, air and handling checks (44). They run the real scripts against a small mock of Roblox (`tools/smoke/mock_prelude.lua`);
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
- Fetch and rebase BEFORE publishing, not only before pushing: a publish from a stale tree puts the live place back
  to before the other sessions' rounds (happened 2026-11-12, Front v29/v32 and Endeavor v96; fixed by v33/v98).
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

## The canon (owner, 2026-11-12: "every new addition consults the canon and anything outside is rejected or changed to fit")
- `docs/LORE.md` is the story as it stands. Read it before adding any place, character, item, line of text or system
  with a story reason. An addition that contradicts a Canon or Hinted line is changed to fit or dropped; the canon is
  not quietly bent to fit it. New facts go into LORE.md in the same commit. Anything that answers one of its Open
  questions needs Andy's word first.

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
  Z feint, G grab/throw, H drop, Shift sprint, C crouch (hold: prone; sprinting: dive), Space up a stance, B whistle, Tab inventory,
  L loadout, J attributes, O hideout, N recruit app, P helmetcam. With a gun out (owner, 2026-11-11): RMB aim, V sights, R reload, T rack (single-shot guns),
  Q the wall (prone: roll); X close quarters (tap: takedown, throw or search a body; hold: neck grab or carry a body). Front: LMB fire, RMB aim, R reload (hold: keep the magazine), T rack/unjam, B selector, 1/2 switch,
  G frag, H dressing, Q/E lean (prone: roll), C crouch (hold: prone; sprinting: dive), Space up a stance / mantle,
  Z binoculars, Y check weapon (held: 1-4 change the part in a slot), K artillery, F dig, V sandbags, M app, U unlink.

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
- Front first link (owner, 2026-11-10: "wakeup in a stasis tank, the pov frantic ... Then you remember ... fall down a
  chute into a barracks ... a simulation where a city sandbox is created in wireframe ... crackdown style first person
  only"): `src/war/server/Intro.lua` runs it per player (Soldiers.Spawn hands off when `Intro.Needed`: profile
  War.IntroDone unset, or once per server while Config.Dev.Enabled and Config.War.Intro.ReplayInDev; F2 =
  Remotes.TutorialSkip skips a stage in dev). A cell per slot at Config.War.Intro.Origin (Y 1500) + SlotStep: chamber
  with three tanks (two hold clone silhouettes), cables (Beams + welded latches), hatch over a chute into a barracks.
  Stages go to the client as Remotes.Tutorial("Front", stage, data): Wake, Drain, Unlatch, Chute, Barracks, Equip,
  Equipped, Link, Sim, Drill, DrillDone, Desync, SimDone, Done, Landed. The kit = Recruit.Deploy (the order) +
  `Intro.Curate` filling empty slots from Config.War.Intro.Issue (kit.Issued: never dropped as loot); `Soldiers.Arm(..,
  {Pending, Intro})` then `Soldiers.Give(piece)` per bench prompt (pieces Primary/Sidearm/Armor/Helmet/Supplies);
  `Soldiers.Place(player, {Fresh})` drops at Battlefield.BaseCFrame with fresh weapons. s.Intro: not IsDeployed, fatal
  damage -> `Intro.Desync`, artillery -> the sim's own guns, no entrenching, reload refills spare mags. Abort (leave or
  die) refunds the locker. `src/war/server/Simulation.lua`: wireframe city of Block-stud ForceField cubes with
  SelectionBox edges (blockInfo; Guns.OnSurface chips them, Soldiers.ExplodeHook takes blasts inside a sim), a column
  falls when its footing breaks, a building collapses at CollapseShare of its ground layer; drills RANGE, BREACH,
  ASCENT, CONTACT (SimHostile figures: MoveTo + raycast shots through Soldiers.Damage), FIRE MISSION (tower).
  `src/war/client/IntroFx.lua` draws it (scripted panic camera, memory cuts to real battlefield parts, local Lighting
  per stage, shards, machine lines). "Crackdown style" read as free movement in a fully breakable city, kept grounded
  (Config.WarMovement: Shift sprint, Space mantle up to 6.6 studs, in Main.client) so the Front's realistic handling
  holds. Sounds: tools/sounds/synth_intro.py. Real-server check: tools/realserver/frontcheck.py (startup + Intro.Probe).
- Front handling (owner, 2026-11-11: "the UI and FPV are very cluttered ... you should be able to crouch and go
  prone. the game should control like Metal gear 4 ... and incorporate the modern gunplay and mechanics of MGSV";
  "metal gear also has first person controls", so the Front stays first person). Tuning: Config.WarMovement (Stance
  {Stand, Crouch, Prone}, dive, roll, Lean/Peek, SightSeconds, reload multipliers, Binoculars). Server
  (`Soldiers.SetStance(player, stance, force)`, remotes Stance/Lean/Mark): s.Stance + char attribute `Stance`,
  HipHeight (Prone 0), leg/root/neck/waist joints posed with Joints.Pose so hitboxes match (STANCE_POSE),
  `Soldiers.Eye(player, ray)` = the firing eye (prone offset, lean or peek with a side wall clamp), spread via
  `w.Steady`, recoil scaled, rising needs headroom; `Guns.Reload(w, keep, quick, careful)` (quick drops a partial
  magazine, w.Dropped); Mark checks facing, range, sight and faction, then Soldier "Marked"(model, seconds) to the
  side. Client: `src/war/client/Hud.lua` is the whole screen (Weapon/Check/Health/Stance/Aim/Flash/Hill/Scales/
  Banner/Feed/Binoculars/Dwell/Mark; `Hud.Elements` for tests); Main reads the Stance attribute (never predicts),
  paces WalkSpeed per stance, CameraOffset for prone and lean, `shove` for the dive and the prone roll, pop-up aim
  from a crouch behind low cover (`lowCoverAhead`), `holdKey` for tap-or-hold keys (C, R), binocular dwell -> Mark.
  Arms are posed per client (prone reach); legs and body by the server. Unseen live: the prone and crouch poses, the
  prone body against rough ground, the dive.
- Metal Gear handling in Endeavor (owner, 2026-11-11: "the UI and FPV are very cluttered ... you should be able to
  crouch and go prone. the game should control like Metal gear 4 ... and incorporate the modern gunplay and mechanics
  of MGSV ... it looked like i grabbed the side of the enemy's body instead of their neck"; plan approved with "yes";
  ideas only). Third person over the shoulder is the default view; the ride ends there (`setHelmetcam(false)`); P and
  V-while-aiming are first person, where only forearms, hands and the held weapon are shown. `aimActive()` (Main)
  turns the body to the camera yaw in both views, except during a takedown/cutscene (that turn is what put the
  attacker at the guard's side) and while `Handling.HoldsFacing()` (back to a wall).
  `src/client/Handling.lua` (`Began`/`Ended` keys, `Changed` -> Main's applyAim/FOV/distance, `Drop`, `AimPreset`,
  `Stance`, `Aiming`, `Sights`, `InCover`): stances (never predicted: the `Stance` attribute), dive and prone roll
  (`shove`), RMB aim, V sights, R reload, the wall (client only: rays for the wall and its open end, root placed each
  Heartbeat), and one looping arm animation for what the hands do (`wantArms`: Carry, Hold, Cover_Idle, Aim_Pistol,
  Pistol_Ready). Server, in `src/server/Stealth.lua`: `SetStance` (attrs `Stance` + `Crouched`), `SetAim` (attr
  `Aiming`), hold-up in `think` (`gunOn`: a gun within Config.Stealth.HoldUp.Range/Cone on a guard under awareness
  1 -> state "HeldUp" for Keep seconds after), `Throw` (down for Cqc.Throw.Down, `standUp`), `Grab`/`Release`
  (state "Held", attr `NeckHold`; `followHands` moves him each Heartbeat; "Choke" = forced rear takedown), `Carry`/
  `DropBody` (attr `Carrying`), remotes Stance, Aim, Cqc(action, guard?). `Rules.Cqc` (shared/Stealth) = what a tap
  and a hold of X offer; client/Stealth draws the prompt and sends them (`Key`/`KeyUp`). Stats owns speed and
  JumpHeight (0 while low or hands full). Magazines: Weapons `MagSize`/`ReloadSeconds` (Whisper 7), Combat
  `magOf`/`SyncMag`/`Reload`/`ResetMags`, attrs `Mag`/`MagSize`/`Reloading`; the pack count stays the truth.
  Takedowns: the attacker stands Takedown.RearDistance (1.5) square behind; every victim animation ends in
  `fallen(F, side)` (tools/anims) = where `layDown` turns the root flat (Takedown.Fall / Cqc.Throw.Fall, Side), and
  the client swaps to "Downed" with no fade. The attribute `Holding` belongs to thrown chunks (Destruction): the
  neck hold is `NeckHold`. Screen: vitals in a CanvasGroup that fades after Config.Hud.VitalsHold, empty skill slots
  hidden, light gem + round count bottom right, no quest line or controls card in the station. Tutorial.Start tops
  the kit up to Config.Tutorial.Kit on every ride. Prone lowers only the animation and the camera (the humanoid is
  not resized: no crawling under things yet). Tests: "stance:", "gun:", "hold-up:", "cqc:", "hold:", "carry:" in
  scenario.lua, "handling:" in client.lua.
- Station fixes (owner, 2026-11-12: "the guard got stuck on the way up", "The whisper pistol ... fired no
  projectile, instead it operated like a melee weapon", "The enemies should all ALWAYS be lootable, even in the
  tutorial, to help players get used to the loop", "All UI elements ... are either low resolution or too small to
  read"). Guards walk planned routes: Stealth `walk` follows PathfindingService waypoints (`planRoute`, off the brain
  loop; straight line until the plan arrives; Config.Stealth.Path), `Stealth.Breaker` sends the guard with the
  shortest route (`routeLength`), turnstile lanes are 3.4+ wide (a guard needs 3). Shots: Combat.Swing sends no
  "Swing" fx for a Ranged spec; the client draws "Bolt" (tracer, muzzle flash, impact dust, arm kick, camera kick);
  the client's `cameraDirection()` aims from the shoulder at what the reticle is on; a round in the head multiplies
  damage (Weapons `Headshot`, else Config.Combat.Headshot; HeadshotPlayers on players; Whisper 8 = one round on a
  Sentry). Loot: every body is lootable. `Loot.Attach(part, bundle, opts)` = a container on an existing part (no
  prop, no prompt, opts.Keep: emptied sets attribute `Looted`, the part stays), `Loot.Open(player, part)`;
  `Stealth.Search` (Cqc "Search") rolls Items.LootTables.Sentry into a downed guard's root; client: tap X on a body =
  SEARCH, hold = CARRY. A dead NPC's spoils are what was left in its pockets (300 s). UI scale: `Kit.Init` puts a
  UIScale on the HUD = viewport height / Kit.DesignHeight (680), 1 to 2.6 (`Kit.Scale()`, `Kit.Attach(screenGui)`,
  `Kit.Board(billboard)` grows a built BillboardGui once). Anything that turns real pixels into offsets inside the
  HUD divides by Kit.Scale() (panel chrome `follow`, `cellAt`, drag ghost, tooltip, hearing ring). Station signs
  are 72 pixels per stud.
- Calibres and plate (owner, 2026-11-12: "The weapons should operate on a realistic ammunition system ... different
  weapons could be compatible with the same caliber ... the whisper should shoot .22 ... can only kill if it hits
  flesh. Impacting the guard helmets would result in a ping that alerts the guard ... The guards should carry 9mm
  or 5.56"). `Weapons.Calibers[name] = { Item, Name, Pen, Head, Limb, Through }` (.22 Pen 0, 9mm 1, 5.56 2); a gun
  names `Caliber` and its `Ammo` is derived (the cartridge item: Round22, Round9, Round556; Items defs carry
  `Caliber`), so any new gun only needs `Caliber = "9mm"`; `Weapons.Chambered(itemId)` for tooltips. Plate is
  character attributes set by NPCs.Spawn from `NPCs.Types[t].Armor` (HelmetCover = share of the head from the top,
  Helmet, Vest = upper torso, Bracers = lower arms, Shins = lower legs; Sentry 1/2/1/1, Brute, Warden).
  `Combat.HitZone(model, position)` -> zone, rating (nearest limb box). In the Ranged branch of `pulse`: rating >
  Pen = stopped (fx "Ping"(model, position, zone), `Combat.Deflected`, no damage); flesh takes Head / Limb
  multipliers, defeated plate leaves `Through`. Stealth: Deflected and any wound he survives (HealthChanged) put
  the guard on Alert at once. Loot: Items.LootTables entries may be `{ Pick = { { Weight, Items = {...} }, ... } }`
  (exactly one bundle); Sentry = 9mm (30% with a DutyPistol) or 5.56. DutyPistol = Assets.GunKit.Striker17, 9mm, 15
  rounds, Noise 75. No gun takes 5.56 in Endeavor yet. PlayerData.Load renames saved "Subsonic" to Round22.
  Players have no plate zones yet (only the head multiplier). Tests: "calibre:", "plate:", "loot:" in scenario.lua.
- Long guns (owner, 2026-11-12: "a carbine firing 5.56 based off the exploded ar-15 model is next, then the ak-47
  firing 7.62x39. And the garand fires .308 or 7.62x51"). Weapons `Carbine` (5.56, 30, Auto), `AK47` (7.62x39, 30,
  Auto), `M1Garand` (7.62x51, 8, semi); calibres 7.62x39 (Pen 2) and 7.62x51 (Pen 3), items Round762x39 /
  Round762x51. Family "Rifle"; `Weapons.IsGun(def)` (Sidearm or Rifle) is the test for aim, reload and the gun camera,
  never `Family == "Sidearm"`. `def.Model = { Gun, Attachments, Scale, Grip }` + `Weapons.Held(id)` -> what
  `HeldWeapons.Attach(char, gunId, attachments, opts)` takes: the models are the Front thread's components
  (shared/GunParts; the Carbine = gun `M4A1`, the flat-top receiver with its Standard 16 inch barrel, since
  Front v36 gave the M16A1 its own carry-handle receiver), shrunk to Scale 0.5 in the hand (the parts are 0.19 studs to the inch, about twice body
  scale; pistols are still that big) on GRIPS.Shoulder. That grip matrix and the arm angles of Rifle_Ready /
  Aim_Rifle / Reload_Rifle (tools/anims) were solved together by forward kinematics (shoulders 0.86 out): change them
  together. Real-server check on the real body: aiming, the bore is exactly ahead and level, the butt 0.34 from the
  shoulder joint, the left hand 0.06 from the handguard. `def.Auto`: client `Handling.Trigger(fire)` repeats Attack
  while LMB is held. "Bolt" picks ShotRifle and a longer muzzle offset from Noise >= 100. Pack icons:
  Assets.Icons.Carbine/AK47/M1Garand (whole old models). Loot: Sentry 5.56 bundle 35% Carbine, Raider 7.62x39 (AK47
  5%), Rival 7.62x51 (Garand 8%); the armory's Supplies gives 60 of every cartridge. Not done: sentries do not hold
  or fire rifles, no rifle pose behind a wall (Cover_Idle is the pistol's), no slung second weapon, the tracer starts
  at a guess of the muzzle. Tests: "rifle:" in scenario.lua.
- Fire actions (owner, 2026-11-12: "single shot would be one round fired per action, like the whisper, you need to
  rack it every round ... semi automatic ... That would be the garand or m16a1, and the automatic happens when
  multiple rounds leave the barrel while the trigger is held. That is the ak"). Weapons `Action` = "Single" (Whisper,
  `RackSeconds`), "Auto" (AK47), default "Semi" (Carbine, M1Garand, DutyPistol); `Weapons.ActionOf(def)`. This
  replaced `def.Auto`: `Handling.Trigger` repeats only for Action "Auto". Combat: `unracked[player][weapon name]`
  set by a Single gun's shot, cleared by `Combat.Rack` (Remote "Rack", key T in Handling; busy RackSeconds, fx
  "Rack" -> Intro_Rack animation + sound) or by a finished reload; an unracked pull is a "DryFire"; character
  attribute `Chambered` (false = red round counter). The Carbine as semi-automatic is Claude's reading (Andy named
  the M16A1 semi and only the AK automatic). Tests: "action:" in scenario.lua.
- The arrival (owner, 2026-11-10: "UI and Intro sequence overhauled ... riding a train ... revealing the weapons under
  a cloak ... racking the slide ... pans behind ... zooms into the fpv ... a tutorial stealth level ... subway ...
  based off splinter cell chaos theory and batman arkham involving environmental takedowns and light level hiding";
  ideas only, everything in it is original). Per player, independent of the server phase: `profile.Intro = { Done,
  Kit, Intel }` (kept through wipe) decides it; `src/server/Tutorial.lua` (`Active`, `SpawnCFrame`, `Start`, `Finish`,
  `Replay`, `Release`, event `Finished`) builds one `Subway.Build(origin)` level per player at Config.Tutorial.Origin
  + slot * Spacing, seats the character (attr `Cutscene`, anchored), fires Remotes.Intro "Play"(car, seat, carCF) and
  waits for "Done" (or IntroTimeout); Lifecycle spawns into it first, deaths there are free and return to the last
  of 5 checkpoints; `WorldPhase.Busy = Tutorial.Active` keeps station players out of the prologue count and Emerge.
  `src/client/Intro.lua` is the cutscene (timeline `Intro.Timeline`, local props from ReplicatedStorage.IntroKit
  built by `src/server/IntroKit.lua`, anims Intro_*, hold Space to skip, ends in helmetcam). No tutorial text exists
  any more (the old step panel, Skip button and dummy drill are gone); only signs, the car display and the fragment.
- Stealth (same directive): `src/shared/Stealth.lua` (`TakedownKind`, `LightAt`, `SightRange`), `src/server/Stealth.lua`
  (levels = a Model with "StealthLight"-tagged lamps on circuits; `ExposureAt`, `Noise`, `SpawnGuard` = NPCs type
  Sentry with an Idle hook and states Patrol/Suspicious/Search/Alert/Down in attr StealthState, `Takedown`, `Breaker`,
  `SetCrouch`, `Whistle`, `Reset`; player attrs `Stealth`, char attrs `Exposure`, `Crouched`, `Takedown`; Remotes
  Takedown/Crouch/Whistle/Stealth; `Combat.Shot` breaks lamps and makes noise by weapon `Noise`), `src/client/
  Stealth.lua` (light meter, awareness diamonds and wedges, the X prompt, takedown camera and anims). Takedown spots
  are parts tagged `TakedownSpot` with attr Takedown = Panel/Rail/Ledge. Tuning: Config.Stealth. The Whisper
  (Weapons, Caliber .22, Noise 7) is the starting kit; Attack/Heavy remotes carry the camera direction for shots.
  Any place can use the system: tag lamps, call Stealth.Enter(player, levelModel), spawn guards with opts.Level.
- UI kit (same directive, replaces the 2026-11-04 theme block): `src/client/UI.lua` (`Kit.Theme`, `plate` = flat dark
  plate with a hairline edge and cyan corner ticks, `ticks`, `gauge`, `tween`, `spaced`, `keyHint`, `label`, `make`).
  Main: `bar()` (flat fill, bright edge, pale trail on loss), `panel(size, position, title, plain)` = a ScrollingFrame
  whose "Chrome" plate with a title strip follows it (AbsolutePosition/Size/Visible signals) and dims + blurs the world
  unless `plain`; hotbar slots are plates with key caps; banner fades over a rule; death screen FLATLINE; controls
  card is a plate. Main is near Luau's 200-local limit at top level: put new UI in `do` blocks or tables.
- The story joined up (owner, 2026-11-10: "fill in the gaps between the story elements and gameplay"; Claude chose
  the links): Line 9 carries stack hardware (new bodies, recruit tanks) up into the city. Every hideout site is a
  consignment bay with a freight lift in its back corner (`Hideouts` buildLift: cab, "LINE 9 . BAY nn", shaft with a
  red lamp, STACK HARDWARE crates while unclaimed; Config.Hideouts.Lift*). The station console also puts a
  "Manifest" item in the pack (`Tutorial.Consign`, once per life via data.Consigned, only with no site); claiming a
  site while carrying it costs nothing and builds a free Computer that takes no module slot (h.Consigned).
  Spawn order (`Lifecycle.PlaceFor`, also `WorldPhase.Place` for Emerge): back from the Front -> the terminal tapped
  from (`NeuralNet.ReturnCFrame`, join data From = "Front", line from `NeuralNet.Returned` using war.Tap) ->
  uploaded stack -> its hideout computer (`Hideouts.RebootCFrame`) -> bunks -> a freight lift (own bay, else a free
  one) -> street spawns. Front: `Soldiers.Unlink` (hold X "Unlink" on your own base locker, refused under fire
  Config.War.UnlinkCalm; or U between recruits, Remote "Unlink") hands the recruit's gear back to the locker and
  teleports to Config.War.HomePlaceId. Stasis tanks carry "LINE 9 . STACK HARDWARE . nn/40" plates. Green pockets
  stand outside the hour: Cycle spares loose lootables inside them, the client skips the colour drain and most of the
  white-out there; fragment "Pressed" (Where = "Pocket"); one new hinting line per contact.
- The way down (owner, 2026-11-12: "players should be able to go down there, either prompted by incentive or story";
  chose "Build it: story and incentive"): `src/server/Barrens.lua` (Init from Main, isolated in a pcall; Reset from
  Cycle.Run). The shaft head on the Sumps plaza (Config.Barrens.Head, prompt "Descend") -> one shared stealth level at
  Config.Barrens.Origin (6000, -300, 0; keep above FallenPartsDestroyHeight -500): shaft foot ("Climb"), pipe gallery
  with a "Hall" Breaker, the hall (Rows x PerRow stations: Rigs.Statue "Raider" in pale SmoothPlastic, crank, screen
  readout, line into the trunk; circuits Row1..3), office (console HANDS/OUTPUT, stores from Items.LootTables.Barrens,
  the gallery crate Overseer). Overseers = Stealth.SpawnGuard with opts.Loot "Overseer" (g.loot). Barrens.Unhook:
  slump, row circuit off, Stealth.Noise, UnhookDamage, Knowledge.Uploaded = false ("> STACK . . . NO CARRIER"),
  World "Flicker". Player attr `Below`; Leave on climb/death/new character/leave. Client World "Shaft" = fade to
  black. Air "Under" (Megacity.AirAt below Y -150). Clues Where "Sumps"/"Barrens" (fragments ShiftCard, Hands; spots
  may carry their own floor Y), one line per contact. F2 "Shaft". Tests: "barrens:" in scenario.lua.
- Lore (owner, 2026-10-31; docs/DESIGN.md "The stack"): conduits upload their consciousness stack through the hideout
  computer (first log-in = initialization, `Knowledge.Uploaded`); every death is a reboot of the stack; on the Front the
  stack links to the recruit's; the rich uploaded and escaped the world. Mechanically: Knowledge survives permadeath only
  once Uploaded (PlayerData.wipe); the death screen says STACK REBOOT or that nothing survives; the computer prompt is
  "Upload stack / log in".

- The realistic pass (owner, 2026-11-11: "redo all the models and textures, use blender to make everything more
  cohesive and realistic. starting with the intro cutscene ... keep iterating ... then extend"): one shared material
  library. `tools/textures/gen.py` makes tileable PBR sets (colour, normal, roughness, metalness, 1024, seeded numpy
  noise) per material; `tools/textures/swatches.py` turns each into a 4x4 plane .glb (upload.py sends .glb as
  model/gltf-binary) and Roblox's import makes a SurfaceAppearance from it. Scripts cannot set SurfaceAppearance maps
  (Plugin capability) but can clone one, so `src/common/SurfaceLibrary.lua` (Init first in Endeavor's Main) loads the
  swatches into ReplicatedStorage.Surfaces and `Assets.Dress` clones `Assets.Surfaces[name]` onto every MeshPart named
  "<Part>_<Name>". Models get world-scale box UVs (`lib.uv_box`, TILE in lib.py = Assets.Surfaces[].Tile), so a
  texture is the same size everywhere. New library names never reuse an old Assets.Materials name (old models have no
  UVs). `tools/models/train.py` builds the arrival on it (car 12.6 wide x 56 x 10.9 high inside after "train car is too
  small", moulded seats with cushion top 1.5, door leaf, Whisper, poncho draped by Blender cloth sim seated and
  standing); `tools/models/render_intro.py` renders Cycles stills for Andy to judge.
  Round 2 (Andy: "strip the model into its components ... There should be a cloth physics simulation on the cloak"):
  (pistol_kit.py, round 2, was replaced in round 3 by the parts library below). The cloak is one skinned MeshPart (train.py build_cloak: the standing drape plus
  the hood, bones "R<row>C<col>" on poncho rings ROWS, columns every COL_STEP segments, "Hood"; parentless bones,
  bilinear weights). A skinned upload's pivot is turned by the FBX node, so IntroKit `piece(.., origin)` resets
  PivotOffset/WorldPivot to the origin. `src/client/Cloth.lua` (`Cloth.Attach(model, char, {Extra, Manual})`): row 0
  pinned to the mesh, verlet particles with column links, slack row/diagonal links, tethers, a weak pull back to the
  drape, pushed out of the character's parts, opts.Extra models and nearby anchored plain block Parts (never meshes:
  a car shell's bounds hold the rider); writes Bone.Transform; ~0.2 ms a frame (real-server test). Intro.lua attaches
  it after the holster and back are welded; the CloakStand swap is gone.
  Round 3, the gun parts library (Andy: "make every part listed here, and we will combine them in different ways to
  make a striker fired, hammer operated, and revolver handguns ... an Ar15 ... for a rifle parallel", with a 1911A1,
  a striker pistol and AR-15 lower/upper parts charts): `tools/models/gunparts.py` (`Part`: side/plan/front prisms,
  box/span/cyl/tube/spring/rod/ball, `cut=True` cutters applied by Exact boolean with self-intersection on; inches,
  K = 0.19 studs per inch; `explode` offset or None for the tray row; `hidden` parts are left out of the game model;
  `to_game` merges by "<group>_<material>"; `stills` renders the assembled view and the numbered exploded chart).
  Platforms: `gun_hammer.py` (all 49 1911A1 chart parts), `gun_striker.py` (all 33 striker chart parts + 33b),
  `gun_revolver.py` (32 parts, the usual list for a swing-out double-action), `gun_rifle.py` (L1-L35 lower, U1-U8
  upper, B1-B10 barrel/nut/handguard/gas block/muzzle/carrier/bolt/magazine/sights). Shared accessories:
  `suppressor`, `weapon_light`. Variants -> `Assets.GunKit` (13 guns); Assets.Weapons.Whisper = GunKit.Whisper.
  Run `blender -b --python tools/models/gunparts.py -- <platform|all> [variant] --stills --export`; a full run takes
  ~7 min a variant (the Exact booleans), so run platforms in parallel processes.
  Round 4, one-piece bodies (Andy, 2026-11-12: "use moon animator and blender to create better character models?
  the ones right now look too blocky and disjointed"; Moon Animator is a Studio plugin and cannot run here, so
  animations stay code-keyframed). `tools/models/figure.py` (library) + `figures.py` (Conduit, Raider, Brute, Shocker,
  Warden, Sentry; BUILDS = the old rigs' measurements, re-proportioned by Skeleton to human joints at the same
  height: shoulders 0.65x as wide, head 0.168 H, hips at 0.48 H). Soft garments = lofted solids fused by voxel remesh,
  wrinkled, decimated; shells for hood/skirt/collar/cape; hard kit follows one bone. Weights are geometric (Weigher:
  chains torso/arm/leg/head/skirt/cape, each vertex takes the chain of its nearest source solid, then smoothed), max 4.
  One MeshPart per "<Piece>_<Material>"; one tint per piece (asserted). `--export` writes Skin_<Name>.fbx (meshes +
  15 parentless bones named after the limbs, at the limb boxes' centres) and Rig_<Name>.fbx (15 plain limbs
  "<Limb>_Proxy"); `--stills` renders front/back/action. The upload of a skinned multi-mesh FBX arrives as a Model
  with "RootPart" holding the Bones, MeshParts jointed to it by Motor6D, an AnimationController and InitialPoses.
  Game: `Assets.Rigs` = the proxy rigs, `Assets.Skins[kind] = { Id, Tints, Mats }`; `Rigs.Build(id, name, kind)` ->
  attachSkin (moves the skin so its LowerTorso bone sits on the limb, ties each bone to the nearest limb: attributes
  Limb + Rest, welds RootPart to LowerTorso, Model "Skin" tagged "Skin" inside the character, limbs Transparency 1 +
  attribute Proxy, model attribute Skinned). `src/shared/Skin.lua` (client, started from Main): each render step
  `bone.Transform = bone.CFrame^-1 * holder^-1 * limb.CFrame * Rest`, so anything that moves limbs moves the skin
  (Animator, Joints.Pose, physics); every 3rd frame past 140 studs, never past 420. `Assets.Tint(part, color)` sets
  SurfaceAppearance.Color (neutral textures Techcloth/Twill/Gauze/PlateSteel carry `Base`). Gore: a whole corpse keeps
  a cloned skin, a scattered one shows its proxy limbs. WornGear squeezes pieces to Proxy limbs (AUTHORED sizes).
  First person shows skin pieces named *LowerArm*/*Hand*. Not adapted yet: cybernetic limb art sits over the skinned
  arm (the flesh cannot be hidden per limb), the intro cloak was draped on the
  old wider body (the Front got its bodies in round 5).
  Round 5, the Front's soldiers (Andy, 2026-11-12: "These look great ... can you give the front models the same
  treatment?"). figures.py `union` (short olive jacket, canvas webbing, scarf, dust goggles, blue armband) and `pact`
  (long tan greatcoat, tall boots, gas mask, red armband) on one build (`BUILDS["Soldier"]`); recruits are clones, so
  no faces. `Rigs.lua` moved to `src/common` (both places): `Rigs.Skin(char, kind)` re-dresses a built rig,
  `Rigs.Holo(model, color)` = ForceField figure, `Rigs.Statue(kind, cf, parent, opts)` = an anchored skin (gear
  showing was `Rigs.Wear` in round 5; round 6 replaced it with layers and groups, below). attachSkin marks pieces wholly on the head with attribute `HeadPiece`. `src/war/server/Bodies.lua`:
  Init (first in the Front's Main: SurfaceLibrary, StarterCharacter = `Assets.Rigs.Soldier` with attribute
  `StockAnimations`, so `src/character/Animate` (now also in war.project.json) plays Roblox's idle/walk/run and no
  stance animations there), `Dress(char, faction)` after every LoadCharacter (Soldiers.Spawn, Intro run), `Wear`
  (pushWeapon; WornGear only on an avatar fallback), `Fallen(faction, cf, parent)` = `Assets.FrontBodies.Fallen` inside
  the RecruitRemains part. Simulation `figure` = the soldier rig as light (block fallback), the Intro's tank clones =
  Rigs.Statue, `Assets.FrontWorld.Calcified` = the soldier crawling / kneeling (figure.py `Figure.static`, statics=
  on the @figure). Front client: Skin.Start, first person shows every skin piece but HeadPiece ones.
  Round 6, strippable soldiers (Andy, 2026-11-12: "They need to be able to be stripped of all gear, so the base
  clothing layer should look more bare ... their basic battle attire acquired after leaving the tank and entering the
  barracks. They also need rigging for cybernetics and large armor sets"). A body is now layers on one skeleton: the
  base skin Model "Skin" plus Models "Layer_<kind>", each with attribute `Kind`, each a separate skinned upload whose
  bones follow the same proxy limbs (Skin.lua updates all). `Assets.Skins`: `Recruit` (the bare clone body cut into
  Head/Torso/ArmL/R/HandL/R/LegL/R/FootL/R on the new Flesh surface, the tank wrap, and the battle attire: singlet,
  trousers, boots, armband; `Factions` = per-side tints), `UnionKit` / `PactKit` (coat, face wear, webbing, gloves,
  helmet, vest, plates), `CyberLimbs` (groups CyArmL/R, CyLegL/R), `HeavyArmor` (group Heavy). `Groups = { name =
  {pieces} }`: those pieces show only while the group is on; `Covers = { piece = {pieces} }`: a showing piece hides
  those in any layer (coat hides torso and arms, a cyber arm hides the flesh arm, sleeve and glove). Rigs:
  `Skin(model, kind, tints)`, `Layer`, `Unlayer`, `Dress(model, on)`, `DressParts`, `Statue(kind, cf, parent,
  {Groups, Color, Tints, Transparency, Name})`; MeshPart attribute `BaseT` = its shown transparency. Bodies (Front):
  `Dress` (Recruit + the side's kit layer), `Look(s)` = groups from the soldier state (Under while `s.Bare`: the
  intro until the barracks; Attire after; Kit only while a Primary weapon is carried, so a conscript with the free
  pistol fights in the attire; Helmet, Vest, Plates when owned), `Wear`, `Augment(char, "CyberLimbs"|"HeavyArmor",
  groups)` (kept across Wear through character attributes `Group_<name>`), `Fallen(.., on)` + `Strip(fallen)`: a
  looted body stays, stripped to its attire (RecruitRemains attribute `Stripped`). An importer drops bones with no
  weights, so every layer carries an "Anchor" piece that attachSkin destroys. figure.py: `body`, `cut_regions`,
  `split_legs`, `under`, `singlet`, `anchor`, `cyber_arm/leg`, `heavy_armor`, a figure's `layers={kind: pieces}` and
  `looks`; figures.py `Union` (exports Recruit + UnionKit), `Pact` (PactKit), `Augment` (CyberLimbs, HeavyArmor).
  Cybernetic limbs (owner, 2026-11-12: "Cybernetics come shipped from conduits"): `Firearms.Cyber` (CyberArmL/R,
  CyberLegL/R: Group, Price, Spread, Limb), `Firearms.CyberEffect(fitted)`; the recruit app sells them (Kind
  "Cyber"), `Recruit.Order` takes `Cyber = { id = true }`, `Recruit.Deploy` -> `kit.Cyber`; Soldiers.Arm copies it
  to `s.Cyber` (part of the body from the tank on, not a barracks piece), Bodies.Wear lays the CyberLimbs layer,
  spread and Limb-zone damage use the effect, death loot / unlink / intro refund return the limbs. Both clients'
  apps have Fit / Remove. The heavy set is still given by no item (Bodies.Augment is the hook; Andy's call). Claude's choices, unconfirmed: the Kit-with-a-primary rule, the looks of both layers.
  The arrival thread owns poses, camera, controls and HUD; this pass owns models, textures and the car block in Subway.
- Guns from components (owner, 2026-11-12: "The weapons should be made from the components we animated before, and
  there can be swapped in barrels of differing sizes, attachments, muzzle devices etc. All the cold war era weapons
  ... should be remade in game, like the glock, ak47, m1 garand"). A Front rifle is assembled in game, not uploaded
  whole. Platforms `tools/models/gun_ak.py` (AK, AKShort, AKLong, AK47), `gun_garand.py` (Garand and M14, three
  barrels each), `gun_rifle.py` (AR20/AR16/AR10), `gun_acc.py` (Suppressor, Compensator, ScopePSO, ScopeColt,
  Foregrip); each has `COMPONENTS` (parts group -> Receiver/Barrel/Muzzle) and `anchors(o)` (Muzzle, Optic, Under,
  MuzzleEnd). `gunparts.py --components [--only=]` writes one FBX per component (muzzle devices and accessories at
  their own origin, plus a speck "Ref_Gunmetal" at the origin) and `out/Gun_<Variant>.json`; `gunparts_lua.py`
  writes `src/shared/GunParts.lua` (`Guns[id] = { Grip, Receiver, Muzzle, Optic, Barrels = { Standard/Short/Long =
  { Asset, Muzzle, Under, End } } }`, `Accessories`, `Pieces(gunId, attachments)`, `Key`, `MuzzleEnd`). Verified on a
  real server: a component's pivot is the FBX origin, unrotated; Roblox (x, y, z) = Blender (x, z, y).
  `HeldWeapons.Assemble(weaponId, attachments)` clones the pieces to their anchors; `HeldWeapons.Attach(char, id,
  attachments)` uses it when GunParts has the gun (attribute `Build` = the key; one-piece `Assets.Weapons` model if a
  component fails). Firearms: slot "Barrel" with `BarrelShort` / `BarrelLong` (Velocity, Spread, Recoil, Loudness
  multipliers; `Guns.AttMult`), new Defs AK47 (7.62x39), M1Garand (8 rounds, semi, 7.62x51: Andy 2026-11-12 "the garand fires .308 or 7.62x51"), Glock17, Revolver (6, semi; the pistols use
  whole GunKit models: Front attachments only fit the primary). The app's attachment button reads "Remove" when
  mounted. Still one-piece old models: SKS, Mosin, Makarov. Not done: the tracer still starts at the eye
  (`GunParts.MuzzleEnd` is there for it); Endeavor still uses whole guns (add a `Weapons.Calibers` row when
  component guns go there). Tests: "guns:" in war.lua.
- Gun families and field changes (owner, 2026-11-12: "every family of weapons has its own quirks but can be
  relatively interchangeable. Front soldiers can do it on the fly with smaller attachments or quick change barrels.
  But they can do everything at the barracks"; "the weapons are real, if they arent copyrighted we can use them,
  then build our own attachments"; his list of wanted guns is tarkovforge.com/weapons, a list of real guns only:
  that host is not on this environment's network allow list, and its models are another game's, never copied).
  Firearms: Defs carry `Family` (AK: AKM, AK47; AR: M16A1; Garand: M14, M1Garand); `Firearms.Families[f].Field` =
  slots a soldier may change away from the barracks (AK Optic/Muzzle; AR all four; Garand Muzzle; Other
  Optic/Muzzle/Grip), `CanField(def, slot)`, `FieldSeconds`, `BarracksSeconds`, `MaxSpares` 4. Order:
  `loadout.Spares` (ids; ones that do not fit or are not in the locker are left out) -> `kit.Spares` -> `s.Spares`
  ({Id, Condition}; in the State kit table). `Soldiers.FieldMod(player, slot, id|nil)` (Remote "FieldMod"): primary
  in hand, not busy, the part is a carried spare; barracks = within Config.War.BarracksReach of an own locker or
  in the first link; swaps with the pouch, w.Busy, pushWeapon rebuilds the model; refusals go back as Weapon
  "Refused"(Barracks/Busy/Missing) -> Hud.Flash. Spares drop damaged with the body and return on unlink / intro
  abort. Client: `Hud.Fit` rows above the check panel (Hud.FitSlots = keys 1-4), Main `fieldMod`; app buttons
  Carry / Leave. Display names are model designations ("G17", "3x scope"), no maker brands. Tests: "family:",
  "spares:", "field:", "barracks:" in war.lua, "parts:" in warclient.lua.
  Actions (owner, 2026-11-12: "single shot would be one round fired per action, like the whisper, you need to rack
  it every round ... semi automatic ... the garand or m16a1, and the automatic happens when multiple rounds leave
  the barrel while the trigger is held. That is the ak"): `Firearms.ActionOf(def)` -> Single (BoltAction; selector
  word "Single": Mosin), Semi, Auto ("Auto" in Modes); `ActionNames`; Catalog entries carry `Action` and the app
  prints it. The M16A1 is semi only. M4A1 and M14 keep an automatic setting (Claude's call, not Andy's words). The
  Endeavor side (the Whisper racked per shot) belongs to the train intro thread. Tests: "action:" in war.lua.
  One more per family (owner, 2026-11-12: "I added the domain, start with one additional weapon from every
  family"): a family member is a new receiver on the family's existing barrels. AK74 (gun_ak variant AK74: mag="74",
  brake="74"; 5.45x39), M4A1 (the flat-top AR16 receiver; 30 rounds), M1A (gun_garand variant M1A: synthetic=True;
  semi only); the M16A1 moved to its own receiver ARA1 (a1=True: carry handle, fixed stock; Optic anchor on the
  handle, so gunparts_lua.py now reads Optic from the receiver's variant). `Config.War.GunScale` 0.55: parts are
  0.19 studs an inch, over twice body scale, so Soldiers.pushWeapon passes `{ Scale }` to HeldWeapons.Attach for
  component guns (the Endeavor thread's finding; Endeavor uses 0.5). The site is reachable with plain curl (WebFetch
  cannot resolve it); its list has 172 guns: AK and AR variants, SCAR, G36, AUG, MDR, SA58, SKS, SVT, RPD, PKM, M60,
  pistols (M9A3, M1911, M45, Five-seveN, Glock 17/18C/19X, USP, PL-15, Desert Eagle), revolvers, bolt actions.
- The gun in the view (owner, 2026-11-12: "Can you read the page about ttk testing? It has insane gunplay and
  visuals ... This is exactly what i want for our front world and the visual aesthetic can persist for both worlds.
  The realistic gun handling, recoil, and visuals are the primary goals for weapons in the game"; the game is the
  Roblox shooter TTK Testing by Sable Digital: helmet camera, floaty aim, high lethality; ideas only, its pages say
  nothing on technique and most hosts about it are blocked here). Step 1, `src/war/client/ViewGun.lua` (tuning
  Config.WarMovement.ViewGun): the owner's HeldWeapon is hidden (LocalTransparencyModifier 1) and a local anchored
  copy under the camera is flown each render step. The gun's authored frame is `primary.CFrame * Grip.C1:Inverse()`
  (HeldWeapons' C1 is the primary part in that frame; the weld point is near the top of the receiver, not the
  pistol grip), barrel +Z; the whole pistols are authored barrel +Y (PISTOL_TURN); whole models are shrunk to
  GunScale in the copy; in the view the frame is turned half round. Everything is measured from the copy's parts
  (bounds lo/hi in the gun's frame): the line of sight (the top of the gun, or the middle of parts with attribute
  Component "Optic") runs through the eye when aimed, the firing hand sits `Rifle.Grip` / `Pistol.Grip` ahead of
  it (a rifle's grip is `Pull` ahead of the butt), `Hip` is the
  move from there. Springs (`Spring`/`StepSpring`): `Lag` (the gun trails a turn, clamped), `Recoil` (rotation and
  position kick from Weapon "Recoil"), `Camera` (a punch applied as per-frame changes that sum to zero; the old
  permanent climb in Main stays). `ViewGun.Direction()` goes to the server with Fire (the server already takes a
  direction and only checks it against the body's facing), `ScreenPoint()` moves the HUD dot (`Hud.AimAt`),
  `Muzzle()` starts the own tracer, `Flash()` is a neon ball with a shadow-casting PointLight. Arms: two IKControls
  on the own Humanoid (right hand Transform to a hand frame built on the grip: wrist back and down, palm to the
  gun; left hand Position to the barrel's Under point, at most Reach ahead; poles on the root), targets are Attachments on the copy. Scope housings fade at the eye (`OpticFade`). Measured on the
  real soldier: shoulders (+-0.9, 1.56, 0) from the root, arm 2.26 long, and the camera's eye (root + 1.5) is at
  shoulder height while the head is at 2.29: the view may look out from the chest (not changed; ask Andy).
  Step 2, animation made by code (owner, 2026-11-12, of a demo on X that could not be opened here: "this is
  incredible and was made with fable, meaning no hand drawn animations. We need this. Can you apply the same
  principles fable used here for our weapons? Start with a pistol and carbine"). `src/war/client/GunMotion.lua` is
  pure (no instances): key poses on a timeline joined by easing curves (`Curves`: seg, smooth, outBack, outCubic,
  bump), told the gun's shape, answering each step `{ Parts = { group = move }, Left, LeftWeight, Pos, Rot, Brass }`
  in the gun's own frame. `GunMotion.New(shape, T)`, `:Shot()`, `:Click()`, `:Start("Reload" { Eject, Insert, Rack }
  | "Rack" | "Draw" | "Selector")`, `:Step(dt, { BoltOpen, Checking })`. ViewGun.build buckets the copy's parts by
  the name before "_" (`MOVING`: Slide, Carrier, Charging, Magazine, Trigger; the gun models already have these as
  separate MeshParts) and measures the shape from them (action length, magazine, ejection port, the handle the off
  hand takes, TopFed for the Garand's clip); each step it sets those parts from the motion, moves the left hand's
  IK target, and throws brass (plain Parts flown by hand: gravity, one bounce by raycast). The reload starts on the
  snapshot's Reloading edge with the server's own stage times (Firearms Defs Reload), paced by the snapshot's Busy
  (wear, quick and careful reloads); an empty gun adds the rack, which the server times after Reloading ends.
  `ViewGun.Play("Rack"|"Selector"|"Click")` from Main (T, B, a dry trigger); Y held = the check pose. Tuning:
  Config.WarMovement.GunMotion (Rifle / Pistol: Travel, CycleSeconds, Well, Pouch, poses). Guns with no such parts
  (revolver, SKS, Mosin, Makarov) only get the whole-gun moves. Other players still see the old body poses. Tests:
  "gun motion:" in warclient.lua. Rule: no hand-drawn or recorded weapon animation; new weapon moves go in GunMotion.
  Not done (next steps, in order): the camera and lighting pass, layered gun sound; the revolver's cylinder and
  hammer, a bolt for the Mosin; the same in Endeavor (told the train intro thread);
  Tests: "view gun:" in warclient.lua.

- Wounds (owner, 2026-11-12: ticked every row of the reference pick page; the build plan is
  docs/Reference-Picks-Plan.md, 7 rounds, this is round 1; ideas from Tarkov's health system, nothing copied).
  `src/shared/Wounds.lua` = pure rules: parts Head/Chest/Stomach/ArmL/ArmR/LegL/LegR, each `Config.Wounds.Parts`
  share x `PartScale` (2) of max health (the Humanoid stays the pool that ends a life; a head or chest at zero
  kills too; non-bullet hits take only `HeadBlow` 0.4 on the head), `Hit` -> {Killed, Bled Light/Heavy, Broke,
  Out, Lost}, `BleedTick` (never empties a vital part on its own), `Heal` (spread over hurt parts not at zero, x
  PartScale), `Effects` (Speed, NoSprint, NoJump, Shake, Melee), `Treatments` (Bandage, Tourniquet, Hemostat,
  Splint, Painkillers, SurgeryKit), `Mend`, `Attributes`. `src/common/WoundService.lua` keeps each character's
  state in both places and sets the attributes W_<part>, Bleed_<part>, Broken_<part>, Lost_<part>, Pain,
  Concussed, WoundSpeed, WoundNoSprint, WoundNoJump, WoundShake, Hunger; `Hit`, `Bruise` (plate-stopped round),
  `Concuss`, `Treat`, `Dress` (Front H), `Feed`, `Mend`, `Replace` (cyber limb ends a loss), `HomeHeal`, `Push`; a
  full Humanoid pool restores every part but a dead limb; hard landings break legs. Endeavor: `src/server/Medicine.lua`
  (Init from Main in a pcall) wires it: Combat.applyDamage -> Hit for player victims (WoundKind from weapon family:
  Blade/Spear Cut, guns Bullet, Explosive Blast), melee x Effects.Melee, shot drift from WoundShake, plate-stopped
  rounds on players -> Bruise, Destruction.Concuss, Stats (WalkSpeed x WoundSpeed, no sprint, no jump),
  Inventory.Use (`def.Treat` / `def.Food`; a pure treatment with nothing to treat is kept), Hideouts medbay ->
  HomeHeal, Frontier's doctor cot in the Reach (`Medicine.Doctor`, Config.Wounds.Doctor), Autonet.Fitted -> Replace,
  scars (profile.Scars, Cut >= ScarMin, parts welded on the limb, wiped with the body), hunger (Ration Food 45;
  stamina regen x StaminaRegenLow under Low; starving at 0). Front: Soldiers.Spawn attaches, `Soldiers.Damage(...,
  at)` bruises under plate and wounds (zone -> part when no point), Explode concusses within Concussion.Radius,
  the dressing (H) = `WoundService.Dress` first, spread x (1 + WoundShake x SpreadPerShake); the client paces
  WalkSpeed by WoundSpeed/WoundNoSprint. `src/shared/WoundFx.lua` (both clients) = the body outline lower left
  (shows only while something is wrong), pain blur, concussion grey and sway, hunger line. Not done: a lost limb has
  no look yet, wounds do not survive a rejoin, Endeavor players still have no plate zones of their own. Tests:
  "wound:" in scenario.lua and war.lua, "woundfx:" in client.lua.

- The kit and two weapons (round 2 of docs/Reference-Picks-Plan.md; Andy: "The weapons they equip should animate onto
  the character's rig, with specific points for each weapon. The kit should revolve around having body armor or plate
  carrier, or tactical vest and a belt for attaching a sidearm, or meds or other gear"; "just a combo count in the
  corner"). Armor slots `Rig` and `Belt` (Armor.Pieces PlateCarrier, TacticalVest, DutyBelt, DropLegRig: Holster
  Hip/Thigh/Chest, Mags, Meds, Plate; `Armor.Kit(worn)`). `src/server/Kit.lua`: profile `data.Second` = the carried
  weapon; `Kit.MountFor` (Config.Kit.Long families -> Back, else the kit's holster or nil), `Kit.OnEquip` (from
  Gear.EquipWeapon: the old hand weapon goes to Second if it has a mount), `Kit.Apply` (from Stats.Apply: draws
  "KitWorn" parts, sets char attrs Vest (plate rating: Combat.HitZone), KitMags, KitMeds, Second; stows the second
  weapon as "StowedWeapon" through HeldWeapons.Attach opts {Name, Part, C0} and `seat` turns the grip-to-middle line
  onto the mount's direction, verified on the real body), `Kit.Swap` (Remote "Swap", key 1; Combat.CanSwap /
  Combat.Swapped keep the chain), `Kit.QuickMed` (Remote "QuickMed", key 2). Combat.Attack(player, aim, intent):
  the chain continues across a swap; Config.Kit.Delay (a held beat -> heavier step, label "Delay"), Roll (attack
  within Roll.Window of a dodge -> thrust), intent "Forward" (lunge, CombatEvent "Lunge" to the client) / "Back"
  (rising cut that launches, `mods.launches`); `pop(.., shot)` lets rounds keep a juggled body up on their own count
  (Config.Kit.ShotPop). `src/server/Knock.lua`: a blow that would kill a player knocks them instead (attr Knocked,
  prompts PickUp X / Finish F, death after Knock.Seconds, once per Knock.Again; Combat.CanAct false; Stats crawl).
  Client `src/client/Style.lua` (Start(gui) from Main): middle-mouse lock-on (camera lerps to the target after the
  camera step; no mark through walls), `Intent()`, keys 1/2, the combo count (upper right), the lunge push, the swap
  reach (Joints.Pose), Prone_Idle/Prone_Crawl while knocked. Tests: "kit:", "knock:" in scenario.lua, "style:" in
  client.lua. Not done: a drawn knocked pose on other players' screens, magazines and meds shown in the pouches,
  NPCs that lock on.
- Guns and ammo (round 3 of docs/Reference-Picks-Plan.md; Andy: "a whisper emp round that discharges if it hits
  the target, no immediate alert if it hits a plate, and aggro if it hits flesh"; the rest of the round from his
  ticked rows, ideas from Tarkov and Metal Gear, nothing copied). Tuning: `Config.Guns`. Endeavor: `Weapons.Loads`
  (Round22Emp, Round9AP, Round9HP, Round556AP, Round762x39AP: Pen added, Damage, Flesh, Emp), `Weapons.Round(item)`,
  `LoadsOf(cal)`. Combat: `loaded/spares/heat` per player and weapon; `ammoOf` (the load in the magazine) replaced
  weapon.Ammo in magOf/Reload/spendAmmo; `Combat.SelectLoad` (Inventory.Use of a cartridge; profile data.Load[cal]);
  Reload kinds Swap (a loaded spare: Config.Guns.Spares + KitMags), Hand (HandBase x ReloadSeconds + PerRound per
  round; also a load change), Spare (R on a full magazine); char attrs AmmoItem, Load, MagSpares, Heat, Jam,
  ArmFatigue. Ranged pulse: st(char).round from spendAmmo; EMP sets the target's `Radio` false (fx "Emp"), on plate it
  returns before Ping/Deflected; `Combat.WearPlate(model, zone, rating, 0.5 x (1 + Pen))` -> `<zone>Wear`, at
  PlateHits x rating `<zone>` 0 + `<zone>Broken` (Kit.Apply keeps VestBroken); a stopped round with |look . normal| <
  Ricochet.Dot reflects into a second raycast (fx "Ricochet"). Heat per shot (Pistol/Rifle/Auto), a cooked gun is
  refused until under Hot; drift from heat and ArmFatigue joins WoundShake. Jams `Combat.Jam(player, kind)`
  (rollJam: Base + Heat x h^2 + wear), Rack (T) clears Feed/Stovepipe, Reload clears DoubleFeed. `fatigueTick` in
  the Combat Heartbeat. Stealth guards carry attr `Radio` (callOthers reaches Config.Guns.RadioRadius while it
  works). `Kit.DropGun(cf, id)` / `Kit.Grab` (NPC spoils drop their gun beside the body; X takes it into the hand).
  Permadeath remains carry a `Tag`; `Frontier.Buy("SellTags")`. Client: Main's round counter (load name, spare bars,
  red on a jam), Load button on cartridges, fx Emp/Ricochet/PlateBreak/Jam; `Style.Gun` (RangeMark under the dot
  while aiming, sway from ArmFatigue, HeatSmoke on the held gun). Front: `Firearms.Loads` (Ammo, AmmoAP, AmmoHP: locker
  units), `LoadOf`, `JamKinds`, `JamSeconds`; Recruit.Order `Load` (kept when an order omits it), Deploy `kit.Load`,
  `kit.Loose` (Config.War.LooseMagazines). Guns: w.Load/Loose/Heat/HeatAt/JamKind/Cooked, `Guns.Heat`, `HandLoad`
  (no spare: thumb loose rounds in), Rack clears a Stovepipe, Unjam by kind, a reload clears any jam, Trigger "hot",
  Shoot: load Pen/Damage, heat spread, a glance off plate (onHit returns true when Soldiers.Damage's stopped share >=
  0.6) continues once on the mirror line (Weapon "Ricochet"). Snapshot adds Load, Loose, Heat, JamKind, Fatigue.
  Soldiers: `FatigueTick` (0.5 s loop; Def.Weight), `DropGun`/`Grab` (a dead recruit's primary lies whole; X swaps),
  tags (`s.Tags`, taken by stripping, `PayTags` at standDown). Clients: Hud.Range + el.Load, jam kind text, HOT;
  GunMotion state `Tired` sway. Tests: "ammo:", "emp:", "plate:", "heat:", "jam:", "mags:", "arms:", "drop:",
  "tags:" in scenario.lua and war.lua. Not done: NPCs who pick up guns, radios that call outside a stealth level,
  tags with the dead conduit's name, the Front's other players' views of a hot barrel.
## State (2026-11-12)
- Endeavor v107 + Front v41 (2026-11-12): guns and ammo, round 3 of the reference picks (round types and the EMP
  .22 that kills guards' radios, magazines loaded by hand, plate that wears through, glances off plate, hot barrels,
  three kinds of jam, tired arms, range marks, dropped guns grabbed into the hand, stack tags). Real servers:
  Endeavor start 7.0-8.4s, Front 4.3s, 0 warnings; dropped Duty Pistol, Carbine and AK-47 lie flat on the floor
  (0.16-0.23 studs high). Awaits Andy: docs/TESTING.md "Endeavor and Front: guns and ammo". Next: round 4 (stealth).
- Endeavor v106 (2026-11-12): the kit and two weapons, round 2 of the reference picks (rig and belt, weapons
  carried at their mounts, key 1 swap mid-combo, key 2 quick dressing, lock-on with lunge and rising cut, delayed
  and out-of-a-roll attacks, the corner combo count, shots that keep a juggle up, knocked down not dead). Awaits Andy:
  docs/TESTING.md "Endeavor: the kit and two weapons".
- Endeavor v104 + Front v39 (2026-11-12): wounds, round 1 of the reference picks (body parts, bleeds, breaks,
  pain, concussion, bruising under plate, six treatment items, surgery, medbay healing, the Reach's doctor, scars,
  hunger, the body outline). Real servers: Endeavor start 9.4s, Front 3.9s, 0 warnings; on the real Conduit body
  every limb maps to its wound part. Awaits Andy: docs/TESTING.md "Endeavor and Front: wounds". Next: round 2 (the
  kit and two weapons). Asked Andy what "120t weights and use 80b" means (the humanoid drone row).
- Endeavor v103 (2026-11-12): fire actions. The Whisper is racked by hand (T) after every round, the Carbine,
  Garand and Duty Pistol are semi-automatic, the AK-47 automatic. Real server: start 7.8s, 0 warnings. Unseen in game: the rack animation
  on the standing body. Awaits Andy: docs/TESTING.md "Endeavor: single shot, semi-automatic, automatic".
- Endeavor v102 (2026-11-12): rifles. The 5.56 Carbine (AR parts), the AK-47 (7.62x39) and the M1 Garand (7.62x51)
  with a two-handed hold, automatic fire on the first two. Real server: start 10.7s, 0 warnings; all three assemble
  (3.3, 3.4 and 4.1 studs long) and the aim pose lines the bore up dead ahead on the real body. Unseen in game: the
  hold and the reload in motion, the rifle behind a wall, the feel of automatic fire. Awaits Andy: docs/TESTING.md
  "Endeavor: rifles".
- Endeavor v95 (2026-11-12): calibres and plate. The Whisper is a .22 (stopped by any plate, one round through
  the face), sentries wear helmet / vest / bracers / shin guards and carry 9mm or 5.56, the Duty Pistol (9mm) can
  be looted. Real server: start 12.1s, 0 warnings; hit zones read right on the real Sentry body (crown and back of
  the head = helmet, face = flesh, chest = vest, belly and thigh = flesh); 200 loot rolls gave 132 9mm, 68 5.56,
  44 pistols, never both calibres. Unseen in game: where the helmet line sits against the model, the ping sound.
  Awaits Andy: docs/TESTING.md "Endeavor: calibres and plate". Open: no 5.56 gun in Endeavor yet; players have no
  plate zones. The thread "Build Front stasis tank intro" is rebuilding the Front's guns from components: new guns
  should name a `Caliber` from Weapons.Calibers.
- Endeavor v94 (2026-11-12; real server: start 7.8s, 0 warnings, 18 skinned figures on their plinths, 4 overseers, 3 stores, the shaft head on the plaza island): the way down to the barrens (Sumps shaft, Barrens Hall 2, unhooking, the trail). Andy's
  lore answers are all in docs/LORE.md. Unseen in game: the hall's look, the statues' height at the cranks, the
  overseers' routes. Awaits Andy: docs/TESTING.md "Endeavor: the way down to the barrens".
- Endeavor v92 (2026-11-12): station fixes after Andy's play of v86 ("handles INCREDIBLY well"): guards path-find,
  the Whisper shoots visibly and headshots count, every guard can be searched, the whole UI scales with the screen.
  Real server: start 12.6s, 0 warnings; routes found from every guard post to the fuse box, up the stairs and into
  the control room. Unseen in game: the UI at the new scale (blind change: watch for text that overflows its plate),
  the tracer and kick. Awaits Andy: docs/TESTING.md "Endeavor: station fixes". Andy has not yet seen v86 on the
  one-piece bodies.
- Front v35 + Endeavor v99 (2026-11-12): cybernetic limbs shipped by the conduit (shop, order, body, effects,
  loot). Awaits Andy: docs/TESTING.md "Front: cybernetic limbs shipped by the conduit". A fallen body does not show
  its metal limbs yet.
- Front v33 + Endeavor v98 (2026-11-12): realistic pass round 6, strippable soldiers (bare clone body in the tank,
  battle attire from the barracks, kit and armour as layers, looted bodies stay stripped, cybernetic limbs and a
  heavy armour set rigged but given by no item yet). Endeavor only shares Rigs/Skin/Assets. Real servers: Front start
  5.3s, 0 warnings, every group hides and shows the right pieces on both sides, 4 layers of 15 bones on one body,
  fallen bodies strip 24 -> 14 pieces; Endeavor start 7.3s, 0 warnings. Unseen in game: all of it in motion, the
  shoulder of the bare body (a crease in the stills). Awaits Andy: docs/TESTING.md "Front: the realistic pass,
  round 6". Stills in /mnt/project-files/realistic-pass/round6.
- Front v28 + Endeavor v91 (2026-11-12): realistic pass round 5, one-piece soldiers on the Front (Union, Pact, the
  fallen, the calcified, simulation figures, tank clones); Endeavor only moved Rigs to common. Real servers: Front
  start 2.9s, 0 warnings, both skins 15 bones / 18 pieces, gear pieces hide and show, 9 simulation figures and 2 tank
  clones bodied; Endeavor start 10.3s, 0 warnings. Unseen in game: the rifle hold and stances on the new body, the
  first-person view of the own body. Awaits Andy: docs/TESTING.md "Front: the realistic pass, round 5". Stills in
  /mnt/project-files/realistic-pass/round5.
- Endeavor v90 (2026-11-12): realistic pass round 4, one-piece skinned bodies for the player and every enemy with
  human proportions; real-server start 11.1s, 0 warnings; all 7 kinds skinned, 15 bones each, bones follow limbs with
  0.000 error. Unseen in game (animation and rendering cannot be checked from Open Cloud): awaits Andy's look,
  docs/TESTING.md "Endeavor: the realistic pass, round 4". Stills in /mnt/project-files/realistic-pass/round4.
- Endeavor v88 (2026-11-11): realistic pass round 3, the gun parts library (Assets.GunKit, 13 guns; the Whisper is the
  hammer-fired railed suppressed build); start 6.1s, 0 warnings. Charts in /mnt/project-files/realistic-pass/round3.
  Only the Whisper is used in game so far; the other 12 wait for Andy's word on where they go.
- Endeavor v87 (2026-11-11): realistic pass round 2, the pistol kit (Whisper rebuilt from parts, 4 variants) and the
  live cloth cloak; real-server start 7.2s, 0 warnings, IntroKit cloak has 81 bones. Awaits Andy's look:
  docs/TESTING.md "Endeavor: the realistic pass, round 2".
- Endeavor v86 (2026-11-11): Metal Gear handling (stances, aim, sights, magazines, hold-up, throw, neck hold,
  carrying bodies, the wall); v85 the same day: playtest fixes (pistol every ride, third person, quiet screen, cloak,
  takedown alignment). Awaits Andy's play-through: docs/TESTING.md "Endeavor: Metal Gear handling". Andy reported
  "the right click broke" on v79; no fault was found beyond first person not turning the body (fixed); asked what failed.
- Front v40 (2026-11-12): weapon animation made by code for every gun in the view (slide and carrier cycle, brass,
  lock back, the reload with the hand on the magazine, rack, check, draw, selector). Real server: the G17, M4A1, AKM
  and Garand copies have their moving pieces, the action runs its travel and comes home (M4A1 0.32 studs, G17 0.22),
  the left hand stays within the arm's length through the reload; start 3.2s, 0 warnings. Unseen in game:
  all of it. Awaits Andy: docs/TESTING.md "Front: weapon animation made by code".
- Front v38 (2026-11-12): the gun floats in the view and kicks on springs, the round follows the bore, the arms
  reach for the gun, muzzle flash, both-eyes-open scopes. Real server (the module run there against all 8 guns on the real soldier): sights on the eye line, hands 1.3 to 2.1 from the shoulders (arm 2.26); start 3.3s, 0 warnings. Unseen in game: all of it (the arms and the
  position of the gun most of all). Awaits Andy: docs/TESTING.md "Front: the gun floats and kicks".
- Front v37 (2026-11-12; real server 0 warnings): the three actions named and shown; M16A1 semi only; the Mosin's selector reads SINGLE.
- Front v36 (2026-11-12): AK-74, M4A1, M1A; the M16A1's own receiver; rifles shrunk to body scale (0.55).
  Real server: start 4.4s, 0 warnings, all four assemble (M4A1 3.6 studs in the hand, M1A 4.6). Unseen in game: the new size in the hands. Awaits Andy: docs/TESTING.md "Front: one more gun in each family".
- Front v34 (2026-11-12): gun families, carried spare parts, changing parts in the field (hold Y, 1-4) and
  everything at the barracks. Real server: start 4.2s, 0 warnings, all 5 rifles assemble. Awaits Andy: docs/TESTING.md "Front: gun families and changing parts in
  the field". Next: more guns from Andy's list, family by family.
- Front v31 (2026-11-12): guns built from components (AK, AR, Garand/M14 with three barrel lengths, muzzle devices,
  scopes, foregrip), new AK-47, M1 Garand, Glock 17, service revolver. Real server: start 3.0s, 0 warnings, all 5 rifles assemble in every barrel with suppressor, scope and foregrip. Unseen in game: the grip of the new
  models in the hands and in first person. Awaits Andy: docs/TESTING.md "Front: guns built from parts".
- Front v26 (2026-11-11): clean screen, crouch/prone/dive/roll, lean and peek, quick and careful reload, binoculars
  with marking. Awaits Andy's play-through: docs/TESTING.md "Front: clean screen, stances, Metal Gear handling".
- Endeavor v80 + Front v25 published (2026-11-10, the story joined up) and starting cleanly on real servers
  (Endeavor 5.8-9.6s, Front 2.4s, 0 warnings; intro probe ok); a real-server probe found 12 freight lifts, 12
  consignments and no city geometry inside any cab or shaft. The unlink teleport itself is only testable in the live
  game (the mock and Open Cloud cannot teleport). Awaits Andy's play-through: docs/TESTING.md "The story joined up".
- Endeavor v79 published (2026-11-10, the arrival) and starting cleanly on a real server (startup 5.8s, 0 warnings);
  a real-server probe built the station (204 parts, 0.5s), loaded the car shell, the Sentry rig, the IntroKit props
  and the new animations, and read exposure 1.0 under a hall lamp and 0.05 in the dark tunnel. Train intro, stealth
  station, takedowns, UI kit. New assets: Whisper,
  IntroCloak, SubwayCar, Rig Sentry (`tools/models/station.py`), 14 animations (Crouch_*, Takedown_*, Downed, Intro_*),
  7 sounds (`tools/sounds/station.py`). Unseen in-game: awaiting Andy's look at the ride and the station.
- Front v22 published (2026-11-10, the open world) and starting cleanly on a real server: startup 1.8s (models
  loaded in parallel 1.0s, terrain 0.7s), 0 warnings, ~3,850 parts (3,780 MeshParts), ~1,650 props.
- Endeavor v78 published (2026-11-10, the megacity) and starting cleanly on a real server: startup 4.4s (was 52.6s
  before City.Init preloaded every model in parallel), 0 warnings, ~12,250 parts in the workspace, megacity 2,800
  parts + 112 kit models + 180 props, 60 lights, 63 emitters.
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
- The arrival (2026-11-10) awaits Andy's in-game look: cutscene timing and poses, cloak fit, seat height on the
  bench, guard sight and hearing balance (Config.Stealth), takedown alignment, the look of the new UI.
- Megacity (v78) awaits Andy's walk-through: look, frame rate across the ring, sludge damage and pocket healing.
  Ideas not built yet: a respirator item or Nose cybernetic that cuts sludge damage; an elevated rail line; station
  entrances to the train intro's subway; StreamingEnabled (still off; the map is ~3400 x 4000 studs now).
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
- Front first link (stasis tank, barracks, wireframe simulation; Front v24, 2026-11-10; real-server check 0 warnings) awaits Andy's play-through: docs/TESTING.md
  "Front: the first link". Next: the drop panel in the barracks (the blast door) for later deployments.
- Experience internal name is still "Conduit" (cosmetic; rename in Configurations → Basic Settings).
