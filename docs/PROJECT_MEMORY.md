# Endeavor: project memory

The short, self-contained memory of the Endeavor project as of 2026-11-10, written to be added to the Endeavor
Project on claude.ai (Project knowledge). It is for chats that cannot see the code. The full working memory
for coding sessions is `CLAUDE.md` in the repository, and the playtest checklist is `docs/TESTING.md`.

## The game

Endeavor is a Roblox experience (universe 10773835758) with two places.

- **Endeavor** (the start place, 120490278050491): a permadeath, always-on PvP open world in a ruined cyberpunk
  megacity, with a valley north of the city wall (the frontier, rolled fresh each server from prebuilt chunks) and a
  hidden settlement, Verdant Reach. Melee combat draws on Cursed Gear (cursed-energy flicker and Black Flash timing,
  cybernetics, raids, devouring) and Deepwoken (posture, parry, feint, skills gated by stats). Players build hideouts
  that outlive death, raid compounds, salvage a destructible city, and live through an hourly "cycle" in which the
  city rematerializes.
- **Front** (81481823786216): a Cold War war world with simulated firearms, two factions (Union and Pact), a moving
  hill, ticket scales, recruits that die for good and drop damaged gear, digging in, and artillery.

Players are "conduits". The lore: people upload their consciousness "stack" through the hideout computer, so each
death is a reboot of the stack; on the Front the stack links to a recruit's; the rich uploaded and left the world
behind. The game never explains this in words (see "Show, don't tell").

## The owner and how they work

- The owner (Roblox name Kinslauer) calls themself "just a gamer". Claude builds everything: code, 3D models
  (Blender scripts), sounds, animations, uploads and publishing.
- They test in Roblox Studio (File, Open from Roblox) or the Roblox app, and report with screenshots. They cannot
  read logs easily: ask for F9, Server or Client tab, screenshots.
- They give direction in short messages, often mid-task, and expect work to continue autonomously.
- They tick features off a playtest checklist (`docs/TESTING.md`, plus an interactive checklist page).

## Decisions the owner made (do not reopen)

- **Show, don't tell.** No banner explains a system or the lore. Machine text is terse and in-world
  ("> STACK RESIDENT . . . REBOOTING"). The cycle shows itself (flicker, colour drain, white-out) with no countdown.
- No classes: the weapon is the moveset; skills unlock from stats and worn armour or cybernetic tags.
- Cursed Gear controls: E flicker, F block/parry, Q dodge, X interact, M devour/app, R/Y/V skills, Z feint,
  G grab/throw, H drop, Shift sprint, Tab inventory, L loadout, J attributes, O hideout, N recruit app.
- Movement comes from Roblox's Platformer template: momentum, double jump, coyote time, roll, air dash, long jump.
- Combat is Mordhau-style: a weapon only hurts along its real path while it is live; it hits where it touches and
  pushes the victim from that point; two weapons meeting mid-air cancel both swings; walls stop a swing.
- Every attack has defined startup, active and recovery frames (60 per second).
- Q depends on armour. In light gear it rolls or air-dashes any way. Wearing any Medium or Heavy piece, it rolls
  only forward; to the sides or back it is a heavy step that gets slower with more armour; no air dash.
- Launchers: launched enemies float long enough for two more hits; a Medium or Heavy weapon launches everyone
  around the impact; Enemy Step springs the player up in front of a floating enemy and holds them there.
- The guard holds the weapon across the front, braced by the off hand, and turns toward the incoming blade.
- No markers drawn through the world. A place shows its name in a banner when you enter it, at most once per
  5 minutes. Nameplates only up close.
- The player body is the game's own "Conduit" model (hood, visor, long coat), recoloured each life.
- Gore level Restricted: dismemberment, blood pools, corpses that stay.
- The hideout outlives permadeath; raids can strip it. A compound only stands while its owner is online.
- Front: realistic weapon handling; no rounds; recruits' gear drops damaged; foxholes and low sandbags only.
- The frontier map is procedural (prebuilt chunks), with a winding route north; the Reach need not be central.

## Current state (2026-11-10)

Endeavor v75 is published and starts cleanly on a real server. Front is at v19.

Recent rounds, newest first:

| Date | What landed |
|---|---|
| 2026-11-10 | A skill for writing Claude Fable 5.2 prompts (`.claude/skills/fable-prompt`) |
| 2026-11-04 | v75: frame data on every attack, group launches with hang time, Enemy Step hover, stronger hit reactions, the visible guard; the pistol no longer poses a sword wind-up; arena labels no longer show through walls |
| 2026-11-04 | v73: 21 keyframed animations (swings, hits, block, parry, idle, walk, run, armoured steps), armoured dodge, a fix for combat effects that errored |
| 2026-11-04 | v71-72: Mordhau-style traced blades, place banners instead of markers, sculpted Conduit body |
| 2026-11-04 | Conduit body, joints for Roblox's new avatar system, UI theme, enemy spacing AI |
| 2026-11-03 | Movement from the Platformer template; enemy rigs no longer mirrored |
| 2026-10-31 | The stack lore, hideout computer, the cycle and clues, the frontier, "show, don't tell" |

Nobody has seen the latest animations, the guard or the new reactions in-game yet. The test server cannot play
animations, so motion is checked only with stick-figure previews.

## Open items

- The owner's in-game look at v75: body, animations, guard, reactions, launches.
- Offered, not started: make blocking depend on the guard really being in the blade's path.
- Front: a 20-player frame-rate test and war-world art; vehicles are left out on purpose.
- The experience's internal name is still "Conduit" (rename in the Creator Dashboard).
- All balance numbers are first guesses until the owner's playtest.

## How Claude works on it

- Repository: github.com/Kinslauer/Roblox-Endeavor, branch `claude/roblox-permadeath-openworld-cj3jfk` (the only
  branch; one commit per round; no pull requests).
- Built with Rojo; code in Luau. Smoke tests run the real scripts against a mock of Roblox (215 game checks,
  28 client checks, 34 Front checks). A real-server check runs scripts on the published place through Open Cloud.
- Publishing uses an Open Cloud API key that the owner made. It is never stored in the repository, so a new session
  asks the owner for it. Publishing fails with 409 "server busy" while Studio has the place open: ask them to close it.
- Models are Blender scripts, animations are keyframes written in code, sounds are synthesized; all are uploaded
  through Open Cloud and wired in by asset id.
- Every feature that lands gets a line in `docs/TESTING.md`; every decision the owner makes goes in `CLAUDE.md`.
