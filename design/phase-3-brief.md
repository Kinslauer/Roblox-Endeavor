# Phase 3 Brief: Endeavor — the two worlds and the hideout between them

<!-- Written 2026-10-26 morning from the owner's description of the full game. Their words are kept
     where they carry design weight. "Assumed" lines are mine and are the first things to confirm or
     overrule; the questions at the end are the ones that change what gets built. -->

## The shape of the game (owner, 2026-10-26)

Two worlds, one character, one wallet.

**The Conduit world** — the "real world": a post-apocalyptic / solarpunk wasteland scavenged by
conduits, surviving on what little old retro-futuristic technology (phones, computers, television)
and cybernetics is left, overrun by brutes, bandits and **warmongers** — powerful figures like
conduits who use the same advancements purely to advance negative outcomes. A fairly large open
world (comparable to Deepwoken's Layer 1), crossed by trains, planes and cars as they become
available; every transport has to be reached and accessed once before it can be used. Different
areas offer different **weapon attachments, cybernetics and armor**, usable in either world.

**The war world** — an actual conflict on another world, where war is all that happens. Constant
infantry, either incubated in cloning facilities on land or sea bases, or dropped in like strategic
missiles in individual pods built for rapid atmospheric re-entry. Every soldier has enhanced senses,
customizable cybernetics and high-tier military weaponry. The combat loop is **Wardogs**: a
perpetual three-sided battle, a ticket-based *capture the moving hill*. Players are rewarded for
being inside the objective zone, reviving others and takedowns, and earn **money transferable back
to the Conduits**.

**The hideout** — the swap between worlds happens here, after **extracting**. Findings from the
Conduit world fund the war; gear found in the wasteland can be sent to the war world in
**shipment-style timed deliveries** for your recruits.

**Gunplay** (both worlds; Tarkov-influenced) — in-depth weapon breakdown and rebuild: strip a pistol
down to its frame and internals, swap slides and barrels, add lights, lasers and optics as you
collect them and see fit.

"This gives either playstyle a home and a reason to be played."

## What this changes in what is built

| Built (Phase 1–2) | Now | Change |
|---|---|---|
| Rift in Relay Plaza → the Range, Rift back | Extract → **hideout** → choose a world | The Rift becomes the dev shortcut; travel is extraction → hideout → deployment. `Range.Enter/Leave` already carry the zone/first-person/loadout plumbing; they move behind the hideout. |
| The Range: target lane + PvE waves | **War world prototype**: 3-sided moving hill with tickets | The Range arena becomes the first battlefield; targets stay as the hideout's practice lane. |
| Gunners / Drones as the ranged enemies | **Infantry** from pods and cloning facilities, in three factions | Enemy v3: faction-aware targeting (NPCs fight each other), pod-drop spawn, squads that hold the hill. |
| Two generated districts + gate street | **Open world** with regions and transport hubs | The district generator becomes the region generator; the gate street becomes the first "line" (a train). Districts stay as the city regions. |
| `Weapons.Gun` block (magazine, spread, recoil) | **Weapon bench**: components → stats | The Gun block is derived from parts (frame, slide/receiver, barrel, optic, light, laser, magazine). Attachments are items; the bench lives in the hideout. |
| Scrap as the only currency | **Money** (war world) + scrap (Conduit world) | One wallet on the profile; money moves at the hideout; shipments are timed item transfers. |
| Lore: "the Range is the city remembering guns" | The war is a real place funded by what conduits find | Lore lines rewrite (Lore.lua is data). |

## Assumed (say the word and I change them)
- **Permadeath stays in the Conduit world only.** Dying in the war world costs the deployment (you come back as a fresh
  clone from the next pod; your team loses tickets) — not the Conduit character. Gear *shipped* to the war world is at
  risk there; gear left in the hideout stash is safe. Otherwise nobody would ever ship anything.
- **Extraction** = reaching a transport hub (train station, airstrip, garage) and holding X; a short timer; nobody can
  hurt you once you are on the train. The hideout is private and persistent (stash, bench, world select). Extracting
  is the only way out of a Conduit run; dying is the other.
- **Recruits** = the player's war-world bodies and NPC squadmates on their faction; shipments equip them.
- **Three sides** = three factions the player can deploy for; at first, the player's faction vs two NPC factions,
  all three fighting each other. Player-vs-player across factions comes with the place split.
- The war world is **first person** (the sight picture is the whole point); the Conduit world keeps the third-person /
  C-toggle.
- Build in-place first (offset zones, like the arena and the Range), split into places (TeleportService, shared
  DataStore) only once each loop is fun — the Phase-2 rule.

## Build order (each an epic with evidence, as before)
1. **Hideout + extraction** — a private offset zone with a stash, a world-select console, the practice lane and the
   weapon bench placeholder; extraction hubs in District 1 and 2 (hold X, timer, protection); `Rift` kept for dev.
   The wallet: `Money` on the profile, shown in the HUD. *Small; everything else hangs off it.*
2. **War world v1 (Wardogs)** — in the Range arena: three factions, a moving hill (zone moves on capture or on a
   timer), tickets per side, pods that re-enter and open into infantry squads, a cloning facility that trickles
   reinforcements, revive (hold X on a downed ally), score for zone time / revives / takedowns → money. Deployment
   from the hideout; death = redeploy from the next pod. Faction-aware NPC AI.
3. **Shipments** — send stash items to the war world on a timer (`Config.Shipments.Minutes`), delivered to your
   deployment loadout / recruits; money back the other way is instant at the hideout.
4. **Weapon bench v1** — gun = frame + parts; parts as items with stat deltas (recoil, spread, magazine, reload,
   ADS speed, light/laser/optic behaviour); strip and rebuild UI at the bench; the Gun block becomes the computed
   result. Regional attachment loot tables.
5. **Open world v1** — the region generator (wasteland, solarpunk enclave, ruined city as palettes/layouts), transport
   hubs that unlock on first visit, a train line between regions; warmongers as the elite enemy (conduit-like skills).
6. **Multi-place split** — hideout, Conduit world, war world as places; profile + wallet in the shared DataStore.

## Out of scope (still)
Hand-made meshes/animations/audio (slots exist), monetisation, matchmaking, leaderboards, the full Deepwoken-scale
map in one go (regions come one at a time), vehicles you drive (transport is a ride, not a vehicle sim).

## Done when
A player extracts from District 1 with scrap and an attachment, stands in their hideout, ships the attachment to
the war, deploys, fights one full moving-hill rotation on the Range battlefield, comes back with money, buys /
fits a part at the bench, and takes the train to a second region — every step readable, every number data.

## Questions for the owner (the ones that change the build)
1. Permadeath: Conduit world only (assumed), or does a war-world death also end the Conduit character?
2. Recruits: your own clone bodies + NPC squadmates (assumed), or do you command a squad directly?
3. War world sides: player + two NPC factions first (assumed), or three player factions from day one?
4. First region after the city: solarpunk enclave (safe-ish trade hub) or more wasteland (harder, better loot)?
