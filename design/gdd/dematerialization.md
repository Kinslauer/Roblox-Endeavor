# The cycle: dematerialization and rematerialization (Conduit world)

> **Status**: The cycle itself implemented 2026-10-26 (`server/Cycle.lua`, client FX in `client/WorldFX.lua`; smoke 9
> checks; Studio push pending — Studio was offline). Clues (§5) and the computer (§6) are designed, not built · **World**: Conduit (Universe 1) · **Epic**: `production/epics/destruction`
> (story 007) · **Depends on / depended on by**: `design/gdd/destruction.md` §4.8
> **Owner (2026-10-26 17:37)**: "The world may be simulated, or at least that is what the conduits think, and why
> they look for knowledge and try to escape. That's why it always resets, everything in the world: terrain, POI,
> etc. The only variables are player and enemy NPC spawns, encounters with vendor NPCs and loot."

## 1. Fiction
The conduits suspect the world is a simulation, and the reset is the evidence: every hour the world comes apart and
puts itself back exactly as it was. That suspicion is why conduits hunt for knowledge (intel, contacts, lore) and why
they want out. The cycle is the world's heartbeat and the game's central mystery; nothing in the UI explains it.

## 2. The rule
**Everything authored is restored exactly. Only four things vary from cycle to cycle:**

| Varies | What changes each cycle | Today in code |
|---|---|---|
| **Player spawns** | which spawn pad a fresh / respawning body wakes on | `CitySpawn` pads, picked by `WorldPhase.GetSpawnCFrame` |
| **Enemy NPC spawns** | where guards, ambushes, warmongers and rival crews start; where on its route each crew starts | built: road guard posts move up to `Config.Cycle.GuardJitter` of the road (`Regions.SpawnGuards`), crews restart at a drawn waypoint (`Rivals.Reset`); ambushes are random events already |
| **Vendor encounters** | where each contact stands this cycle (one of 3–4 authored spots) | built: `Raids.Contacts[id].Spots`, `Contacts.Place` |
| **Loot** | every container, body and salvage roll | already random per roll |

**Restored exactly**: terrain, buildings, POIs, roads, props, breach points, lamps, signs, raid points, transport
hubs — anything authored. Destruction (`destruction.md`) is undone; nothing a player broke survives the cycle.

**Not part of the world** (never reset): the player's profile, inventory, money, raid in progress, contacts met,
board, house, builds. The hideout is the conduit's own space and is untouched. The war world keeps its own per-sector
rebuild (`destruction.md` §4.7).

### Reading of "encounters with vendor NPCs" (say the word if wrong)
Contacts don't stand in the same place every hour: each has 3–4 authored spots in its region and the
cycle picks one. Finding the Broker once unlocks RAIDS for good, but meeting them again means looking again. This
keeps "you have to find the proper contacts" true after the first find.

The enclave **trader** is a counter in Verdant Market, not a body: the market is a POI, so it stays where it is. Only the
contacts move.

## 3. What players see
1. **T − 60 s**: broken things start flickering; a low hum rises everywhere in the Conduit world (diegetic only — no
   HUD timer, in keeping with "nothing announced you wouldn't notice yourself").
2. **T − 5 s**: the hum peaks; the whole world flickers; colour drains (a client ColorCorrection ramp).
3. **T**: **dematerialize**. A second of white-out for everyone in the Conduit world. During it, server-side:
   - every enemy NPC and rival crew is removed (no deaths, no drops);
   - everything on the ground nobody looted is cleared: salvage remains, enemy drops, **and dead players' remains**
     (owner, 17:48: fair — it pushes conduits to leave a raid with what they have, and the war world always has more
     loot);
   - anything held in hand (grabbed debris) dissolves out of it;
   - every broken prop, breach point, structure and terrain change is restored (§4).
4. **T + 1 s**: **rematerialize**. Colour returns. The new cycle's draw places enemies, crews and contacts;
   fresh loot is rolled where containers have it.
- **Players stay where they stand**, with their bodies, gear and state. A player inside a resealing breach is not
  moved: that point waits until the space is clear (`destruction.md` §4.8).
- **Fights in progress end**: the enemy you were fighting is gone. A raid in progress continues; its kill targets are
  whatever the new draw puts out there; its points (fixed POIs) are where they were.

## 4. Implementation (built 2026-10-26)
- `server/Cycle.lua`: a server clock started when the world opens (`WorldPhase` → Open; emergence is the first
  materialization). `Config.Cycle = { Seconds = 3600, WarningSeconds = 60, FlickerSeconds = 5, WhiteoutSeconds = 1 }`.
- Signals: `Cycle.Warning(secondsLeft)`, `Cycle.Dematerialize()`, `Cycle.Rematerialized(index, rng)`. Each cycle gets
  a seed; systems draw their variables from the cycle's `Random`, so a cycle is reproducible in tests.
- Replicated: `workspace` attributes `Cycle_Index`, `Cycle_At` (when the next one hits) for the client FX
  (`client/WorldFX.lua`: hum, flicker, colour drain, white-out).
- Subscribers: `NPCs` / `Regions` guards / District ambushes / `Rivals` (despawn, respawn from the draw), `Contacts`
  (pick a spot from `Raids.Contacts[id].Spots`), `Loot` (clear unlooted ground loot), destruction
  (restore props / breaches; `workspace.Terrain` snapshot via `CopyRegion` at boot, `PasteRegion` on reset).
- **Multi-place**: once the Conduit world is its own place (`Config.Places`), each server keeps its own cycle.
- Smoke: advance the mock clock past `Seconds`; check enemies re-spawned from a different draw, contacts moved to a
  listed spot, ground loot cleared, a broken prop restored, the player's inventory and raid untouched.

## 5. Clues (owner, 17:48: "yes yes this")
The cycle carries the mystery. Each cycle's draw also decides a few **clues** — small things that are only true this
hour — so paying attention to the world across cycles is how a conduit learns what it is. Three kinds, all diegetic:

| Kind | What it is | How it's found |
|---|---|---|
| **Cycle lines** | Each contact has a pool of lines; the cycle picks one. Most are ordinary; a few slip ("You asked me that last hour. You won't remember."). | Talk to the contact (they've moved; §2) |
| **Fragments** | A new item type (`Type = "Fragment"`): a recovered log, a corrupted photo, a note in someone's handwriting. Each has text and an id. | Spawn only on some cycles, at authored **anomaly spots**; a fragment can also be on a rival conduit (they're looking too) |
| **Anomalies** | Something that doesn't come back right this cycle: a sign with the wrong words, a building that flickers on its own, a lamp that stays dark, a door that's open. Purely visual. | Seen — it marks where this cycle's fragment is, without a marker |

- **Knowledge** is the set of fragment ids a conduit has read (`profile.Knowledge`). Reading a fragment (Tab → Read)
  adds it and keeps the text; the item itself is consumed. The first one unlocks a fourth computer app, **ARCHIVE**,
  listing everything read in the order found — the same "apps unlocked through gameplay" rule as the others.
- **Gating**: a fragment's spawn rule names its condition — a cycle index (`every 4th`), a precondition (`needs
  fragment X read`), a place (`only while the Dealer stands at spot 3`). Chains of fragments are the story arc.
- **Content is the owner's**: the system holds the slots (`shared/Clues.lua`: `Lines[contact]`, `Fragments[id] =
  { Text, Spots, Rule }`, `Anomalies[id] = { Spot, Kind }`). What the truth is and how escape works is a writing job;
  the first build ships a handful of placeholder fragments clearly marked as such.
- **Smoke**: a fragment spawns on a cycle its rule allows and not otherwise; reading it adds to Knowledge and unlocks
  ARCHIVE; a chained fragment stays absent until its precondition is read; a cycle line is drawn from the pool.

**As built (2026-10-26)**: `shared/Clues.lua` (lines, fragments, rules: Every / Needs / While / OnRival, Anomaly kind,
Teaches) and `server/Clues.lua` (draw on every rematerialize and at boot; pickups "Fragment" + an "Anomaly" part per
fragment out; one conduit takes it per cycle; reading via Tab -> Read turns it into Knowledge, pushes ARCHIVE and
unlocks recipes it Teaches). Contacts you've met say the cycle's drawn line (`CycleLine_<id>` workspace attributes);
the first meeting is always the introduction. Client (`WorldFX`): anomalies glitch (Static jitters, Echo flickers in
colour, Wrong barely moves) and both they and their fragment are hidden from a conduit who lacks the Needs
(`Knowledge` player attribute). Five fragments ship, all **placeholder** text: Hour Zero (every cycle, District 1
streets — the way in), A List of Names (every 2nd, needs Hour Zero, Ferrite Court), Maintenance Log 7 (only while the
Dealer stands at spot 3), Schematic: Autonet (every 3rd, half the time on a rival conduit; teaches the Autonet), The
Door (every 4th, needs the List and the Log).

## 6. The home computer: why knowledge carries (owner, 17:53; table 18:02; acquiring it 18:03)
"Yes it carries. Conduits have their consciousness uploaded to their home computer; that's why it's so vital they
acquire one early. That is also how they mix and match cybernetics."

- **The computer is the conduit's backup.** A conduit's mind lives on the computer in their hideout, not in the body
  they wear. A body can die for good (permadeath wipes what it carried); what's on the computer comes back in the
  next one. This is the fiction behind what already persists across permadeath (`PlayerData` PERSIST: money, stash,
  side, shipment, hubs, contacts met, board, house) and it now covers **Knowledge** too (`profile.Knowledge` joins
  PERSIST; ARCHIVE survives every death).
- **Cybernetics are "ripped in" at an Autonet you build** (owner, 18:02: "cybernetics are 'ripped in', and need a
  specific table for doing so. It can be crafted after acquiring the knowledge and building it in your hideout").
  The upload is what makes a body re-wireable; the **Autonet** (owner's name, 18:10) is where it's done. The chain:
  1. **Learn it**: the Autonet's schematic is a piece of **knowledge** (a fragment, `Clues.Fragments.Autonet`, §5) —
     found like any other, so it carries across permadeath once read.
  2. **Craft it**: with the schematic known, its recipe appears (salvage materials, `destruction.md` §4.4: e.g.
     SheetMetal, Pipe, Battery, Wire; tuning later). A recipe gated by knowledge is new: `Items.Recipes[id].Needs =
     "Autonet"`.
  3. **Build it**: crafting gives a kit; using it in the hideout installs **the Autonet** for that conduit (stored with
     the hideout, `profile.House`-style, so it persists across deaths like the rest of the hideout). Shown and usable
     only by its owner while the hideout is shared geometry.
  4. **Rip in**: at the Autonet, fit, swap or strip cybernetics in the three slots (Optic / Arm / Core). Nowhere else: a
     conduit without an Autonet can carry cybernetics but can't put them in.
  - Today `Gear.EquipGear` fits a cybernetic anywhere; this moves it behind the Autonet. Cybernetics already fitted when
    the change ships stay fitted. Armour and weapons still change anywhere. A permadeath loses the cybernetics that
    were in the body (they were the body's), never the Autonet or the schematic.
  - **It hurts** (owner, 18:10). Every rip — in or out — is a channel on the Autonet (`Config.Cyber.RipSeconds`,
    ~4 s): the body is locked in place, the screen whites at the edges, and it comes off at reduced health
    (`RipHealthCost`, a share of max health, e.g. 35 %; never below 1 HP — the Autonet doesn't kill). A swap is two
    rips (out, then in), so it costs twice. Taking damage or leaving cancels the channel with nothing changed and the
    cost paid. Recovering is ordinary healing (rations, medkits), so ripping in right before a raid is a real choice.
  (`production/epics/hideout-computer` story 009.)
  **As built (2026-10-26)**: `server/Autonet.lua`, `Config.Cyber` (RipSeconds 4, RipHealthCost 0.35, Range 12),
  `Remotes.Autonet`. The schematic is `Clues.Fragments.AutonetSchematic` (Teaches "Autonet"); the kit recipe is
  Sheet Metal 4 + Pipe 3 + Battery 2 + Wire 8 (`Needs = "Autonet"`). The bay stands at the front of the hideout by the
  cot, drawn per player ("Empty bay" / "Install" until built, HouseView). Use it when built and you are on the table
  (`AtAutonet`, cleared when you step away); the inventory's cybernetic rows then show Rip in / Rip out. Each rip
  costs health up front, anchors the body for the channel, whites the screen edges and shakes the camera; a swap is
  two rips. `Inventory.Equip` and `Remotes.Unequip` refuse cybernetics everywhere; war shipments no longer put them in.
- **The computer is acquired, and life is hard until it is** (owner, 18:03: "it should be hard before they build or
  find a computer"). A fresh conduit has a hideout with an empty desk where the computer goes; no Computer console, no
  apps. Two ways to get one:
  - **Find it**: a working machine (`Items.Defs.HomeComputer`) is rare loot — on rival conduits, in breached interiors,
    at anomaly spots on some cycles, or salvaged whole from a terminal prop (`destruction.md` §4.2) with luck.
  - **Build it**: a basic recipe from salvage (e.g. Battery, Glass, Wire, SheetMetal; tuning later). No knowledge
    needed — otherwise the first step would need the thing it unlocks.
  Using it in the hideout **installs and uploads**: the Computer console appears, contacts already met light up their
  apps, and from that moment the conduit is backed up (`profile.Computer = true`).
- **What a death costs before the upload.** Two kinds of persistence, split by the fiction:

  | Kept by | What | Before a computer | After |
  |---|---|---|---|
  | **The hideout** (physical) | Money, Stash, Faction, Shipment, Hubs (routes you've unlocked), the Autonet | kept | kept |
  | **The computer** (the mind) | Knowledge, Contacts met, Board, House | **lost** — they were in the body's head | kept |

  So a fresh conduit's first deaths cost every fragment read and every contact met. The fastest way to stop losing
  them is the computer. (Assumption, say the word: money and the stash are physical and survive either way; if the
  early game should be harsher, they move to the right-hand column.)
- **Existing profiles** when this ships: anyone who has met a contact or ordered for the house already counts as
  having a computer (`Computer = true` on load), so no one loses what they have.
- **As built (2026-10-26)**: `Items.Defs.HomeComputer` (Type `Device`); recipe Battery 2 + Glass 2 + Sheet Metal 2 +
  Wire 6; rare in supply drops (2 %), on rival conduits (5 %) and warmongers (10 %). The hideout's Computer console is
  drawn per player (`client/HouseView.lua`, the `Computer` attribute): a dark screen labelled "Empty desk" (prompt
  "Install") until installed. Using it with a computer in your bag installs it (`Terminal.Install`: the upload line,
  then any apps whose contacts you already met). Without one: the empty-desk lore line once, then a hint. Meeting a
  contact before the upload says you only remember the way. `PlayerData` HIDEOUT_KEPT / MIND_KEPT implement the
  table above; `Knowledge` is in the profile, ready for the clues. Anomaly-spot finds and terminal-prop salvage come
  with clues and destruction.

## 7. Open questions
- None open right now.

## 8. As built (2026-10-26)
- `server/Cycle.lua`: Stable → Warning (T−60) → Flicker (T−5) → Whiteout (T) → Stable (T+1), 4 Hz tick on
  `os.clock`. Starts when the world opens. `Cycle.Schedule(seconds)` forces the next one (dev / tests).
  Signals `Cycle.Warning`, `Cycle.Dematerialized`, `Cycle.Rematerialized` for later systems (destruction, clues).
- Clear: every body with an `EnemyType` and no `Faction` outside `Config.Cycle.Exclude` (hideout, war / range,
  prologue plots) is removed with `NPCs.Remove` (no loot, no credit); every `Lootable` on the ground outside the
  exclusions is destroyed. Redraw from `Random.new(Seed + index)`: road guards, rival crews, contacts.
- Client (`WorldFX`): the hum (built-in bass, looped, pitch and volume rising), lights within 170 studs flickering
  more and more, a colour drain with a slight tremble, a white-out frame; none of it in the hideout or the war.
  Tunables in `Presentation.Cycle`.
- Not yet: player spawn pads are already a random pick per spawn (no per-cycle subset); destruction and clues will
  subscribe to the signals when they exist.
