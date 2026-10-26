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

## Decided (owner, 2026-10-26 — answers to the questions below)
- **Permadeath stays in the Conduit world only.** Dying in the war world costs the deployment: you come back as a fresh
  clone from the next pod and your side loses tickets. Gear *shipped* to the war world is at risk there; the Conduit
  character and the hideout stash are safe.
- **Recruits** are what soldiers on the war world are called — players included. "They all know they're really just in
  hell. They've accepted it." AI soldiers populate every team and draw their kit from either a **basic gear kit** or a
  **faction pool** generated from conduit supplies. **Shipments go to their respective recruits** (your own
  deployments); AI recruits draw from the pool; conduits supply the pool separately. Two supply paths, then: personal
  shipments → your loadout; pool donations → what your side's AI shows up wearing.
- **Three player factions from day one.** You pick a side at the hideout; NPC infantry fills the gaps on all three
  sides, and all three fight each other.
- **First region** after the city: the **solarpunk enclave** — greener, safer, a trade hub with the first attachments.

## Assumed (say the word and I change them)
- **Extraction** = reaching a transport hub (train station, airstrip, garage) and holding X; a short timer; nobody can
  hurt you once you are on the train. The hideout is private and persistent (stash, bench, world select, faction
  choice). Extracting is the only way out of a Conduit run; dying is the other.
- The war world is **first person** (the sight picture is the whole point); the Conduit world keeps the third-person /
  C-toggle.
- Faction choice is sticky per character (switching costs money and a cooldown) so sides stay populated.
- Build in-place first (offset zones, like the arena and the Range), split into places (TeleportService, shared
  DataStore) only once each loop is fun — the Phase-2 rule.

## Build order (each an epic with evidence, as before)
1. **Hideout + extraction** — a private offset zone with a stash, a world-select console, the practice lane and the
   weapon bench placeholder; extraction hubs in District 1 and 2 (hold X, timer, protection); `Rift` kept for dev.
   The wallet: `Money` on the profile, shown in the HUD. *Small; everything else hangs off it.*
2. **War world v1 (Wardogs)** — in the Range arena: three player factions chosen at the hideout, a moving hill (zone
   moves on capture or on a timer), tickets per side, pods that re-enter and open into AI recruit squads, a cloning
   facility that trickles reinforcements, revive (hold X on a downed ally), score for zone time / revives / takedowns
   → money. Deployment from the hideout; death = redeploy from the next pod. Faction-aware AI (every side fights the
   other two; players are targets for the other two sides).
3. **Shipments + the pool** — send stash items to the war world on a timer (`Config.Shipments.Minutes`): personal
   shipments land in your deployment loadout; pool donations raise the kit your side's AI recruits draw from. Money
   back the other way is instant at the hideout.
4. **Weapon bench v1** — gun = frame + parts; parts as items with stat deltas (recoil, spread, magazine, reload,
   ADS speed, light/laser/optic behaviour); strip and rebuild UI at the bench; the Gun block becomes the computed
   result. Regional attachment loot tables.
5. **Open world v1** — the region generator (wasteland, solarpunk enclave, ruined city as palettes/layouts), transport
   hubs that unlock on first visit, a train line between regions; warmongers as the elite enemy (conduit-like skills).
6. **The hideout computer** (owner, 2026-10-26) — the terminal in the hideout is where a conduit learns what there is
   to do: a **RAIDS** app (contracts with varied objectives that end in an extraction *or* a continuation — a new lead
   picked up on the way, your choice to follow it or go home), a **HOUSE** app (order furnishings for the hideout),
   a **MARKET** app (the black market: gear for money). Every app is **locked until you find its contact** out in the
   open world — the broker, the fixer, the dealer — so the computer grows with what you have seen. **Rival conduit
   crews** run the same raids on the same ground: unannounced until you see or hear each other, and they drop
   **raid intel** that puts a contract on your board. The rule under all of it: immersive and emergent — nothing is
   announced that you would not have noticed yourself.
7. **Multi-place split** — hideout, Conduit world, war world as places; profile + wallet in the shared DataStore.

## Out of scope (still)
Hand-made meshes/animations/audio (slots exist), monetisation, matchmaking, leaderboards, the full Deepwoken-scale
map in one go (regions come one at a time), vehicles you drive (transport is a ride, not a vehicle sim).

## Done when
A player extracts from District 1 with scrap and an attachment, stands in their hideout, ships the attachment to
the war, deploys, fights one full moving-hill rotation on the Range battlefield, comes back with money, buys /
fits a part at the bench, and takes the train to a second region — every step readable, every number data.

## Questions asked 2026-10-26 (answered above, kept for the record)
1. Permadeath: Conduit world only, or does a war-world death also end the Conduit character? → *deployment only*
2. Recruits: your own clone bodies + NPC squadmates, or a squad you command? → *all soldiers are recruits; AI draw
   from a basic kit or the faction pool; shipments go to your own*
3. War world sides: player + two NPC factions first, or three player factions from day one? → *three player factions*
4. First region after the city: solarpunk enclave or deeper wasteland? → *solarpunk enclave*

## Added 2026-10-26 09:46 (owner): the hideout computer, raids, contacts, rival crews
Verbatim intent: raids come from the computer in the hideout, which also orders anything for the house and gear off
the black-market shop; all apps unlocked through gameplay by finding the proper contacts out in the open world; raids
have varying objectives and end with an extraction or a continuation (travel on your own, or pick up a new quest on
the way); raid contracts can also drop from enemy conduits doing the same thing, met unannounced until you physically
see or hear each other; all of the gameplay should feel immersive and emergent like this. → build order item 6.
Assumptions (say the word): a raid lives on the body (dying ends it; the board on the computer persists); three
contacts to start (broker = raids, fixer = house, dealer = market), placed where the risk matches the reward; house
furnishings are shown only to their owner (the hideout room is shared geometry for now).

## Added 2026-10-26 17:30–17:37 (owner): destruction, consistent weapons, the cycle
- Grab key for destruction's grab-and-throw: **G**.
- "All weapons are consistent. Conduits are just stronger and more modified." → Arc Cells (reload reserve) apply in
  both worlds; no weapon rule differs between conduits and recruits.
- Verbatim intent: "The world may be simulated, or at least that is what the conduits think, and why they look for
  knowledge and try to escape. That's why it always resets, everything in the world: terrain, POI, etc. The only
  variables are player and enemy NPC spawns, encounters with vendor NPCs and loot." → `design/gdd/dematerialization.md`.
  Assumption (say the word): "encounters with vendor NPCs" = contacts and the trader stand at one of several authored
  spots, re-drawn each cycle.
- Dead players' remains clear at the cycle reset like any other unlooted ground loot: "it's fair, it encourages leaving
  raids with what you have as conduits, and there is always more loot on the war world."

