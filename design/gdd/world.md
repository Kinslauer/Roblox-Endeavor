# The open world — regions, transport, warmongers

> **Status**: v1 implemented 2026-10-26 (`shared/Regions.lua`, `server/Regions.lua`, `server/Transport.lua`), live-verified, owner playtest pending
> **Brief**: `design/phase-3-brief.md` item 5 · **Decided**: first region = the **solarpunk enclave**
> **Scale target**: Deepwoken Layer 1 — regions come one at a time; the city (two districts) is the first two.

## 1. Shape
The Conduit world is the city plus **regions**, each its own generator with its own palette, layout and loot, joined by
roads you walk once and **transport hubs** you ride afterwards. "North" is +Z (the districts' wall names). District 1
now has a north gap on the gate street line; the **wasteland road** leaves through it, and 420 studs on the
**solarpunk enclave** begins. The dev arena moved south (−Z, between the city and the hideout) to leave the north free.

| Place | Where | What it is |
|---|---|---|
| The road (`Regions.Road`) | x = gate line, z 224 → 644 | a broken highway on a wasteland apron: cracked centre line, 9 wrecks/rubble, 24 dead trees, sparse lamps (half dead); `PlayableArea` tagged so ambushes can land; fixed **guards** (3 Grunts at 30 %, a Brute + 2 Grunts at 55–58 %, a **Warmonger** at 85 %) that never despawn and hold their ground |
| Verdant Reach (`Regions.Enclave`) | round terrace r = 190 at the road's end | mossy ground, a sand path cross + ring, 9 greenhouse domes with grow-lamps, 6 solar towers, 28 planter beds, 46 trees, 20 warm lamps, a hedge wall with the road gap and a neon-arched gate carrying the name. **Not** `PlayableArea`: no ambushes — greener and safer, as decided |
| Verdant Market | the enclave's centre, r = 48 | a covered round plaza (posts + glass roof), five stalls, a **trader** counter; a **SafeZone** ("Verdant Market") with the green ring |
| Relay Terminal / Verdant Station (`Regions.Hubs`) | inside District 1 by the north gate / just inside the enclave | the transport hubs (§3) |

## 2. The trader (the first parts)
Standing in the market sets the player's `Market` attribute (server watch, 1 Hz); the inventory panel (Tab) then grows a
**Trader** section listing `Regions.Enclave.Stock` with Buy buttons (`Remotes.Buy` → `Regions.Buy`: market only, `Wallet.Spend`
first, then `Inventory.Add`). Stock v1: Dot Sight 40, Extended Magazine 35, Muzzle Brake 60, Tactical Light 25, Laser Sight 55,
Match Slide 90, Compensated Barrel 70, Arc Pistol 140, Medkit 20. Money comes from the war (and later, from raids): the
enclave is where the war world's pay turns into the Conduit world's parts. Prices are tuning.

## 3. Transport
Every hub is a platform with rails, a roof, a station sign and one console per **line** out of it. Rules:
- **Unlock by standing there** (`Config.Transport.UnlockRadius`, 1 Hz watch): `profile.Hubs[id] = true`, announced once,
  `HubsKnown` attribute. Hubs persist through permadeath (`PlayerData.PERSIST`) — the hideout's knowledge, not the body's.
- **A ride needs both ends unlocked**: hold X on "Train to X" → refused with *"You have never been to X. Reach it once on
  foot, then the line is yours"* until you have. Refused mid-fight (`Combat.InCombat`).
- **Boarding**: `BoardSeconds` protected wait on the platform (`Boarding` attribute), then the far platform with
  `Protection` seconds of ForceField and an "Arrived" line. The train is implied — transport is a ride, not a vehicle.
- Lines v1: Relay Terminal ⇄ Verdant Station. New regions add a hub and a line entry; nothing else.

## 4. Warmongers
`Enemies.Defs.Warmonger`: a conduit gone wrong. 340 HP, Sledge heavy (34 dmg, hyperarmor, knockback 55), posture 220,
poise 5 hits, and a **Dash** (`{ MinRange 12, Range 45, Duration 0.22, Stop 5, Cooldown 5 }`): with line of sight and
a target between 12 and 45 studs, it flicker-steps to 5 studs short of you over 0.22 s (busy during, `Dash` combat event),
and the heavy follows immediately. Read it like a player's Flicker: the step is the tell, the swing is the punish window.
Drops `Items.LootTables.Warmonger`: scrap, wire, medkits, a real chance at cybernetics (Neural Core, Overclock Core,
Conduit Harness), a pistol, and the good rifle/sidearm parts. XP 260. One holds the road to the enclave.

## 5. Acceptance (smoke: 14 checks)
1. The road is playable ground with its region attribute; the market is a safe zone; all seven guards stand; the warmonger is on the road.
2. `Regions.At` / `InMarket` answer correctly for the enclave, the road, the city.
3. Two hubs; standing on one unlocks it; riding to an unvisited hub is refused; reaching it on foot unlocks it; boarding is protected; the ride lands you on the far platform.
4. Buying outside the market is refused; inside it costs the price; no money, no part.
5. A warmonger 36 studs away closes to within reach in under a second.

## 6. Next regions and follow-ups
- Deeper wasteland (a second road out of the enclave), the ruined city (District 3 as a region with a different layout),
  the coast (sea facilities for the war's recruits). Each: palette, generator, hub, guards, a trader or a contact.
- Planes and cars as lines with their own hub look (airstrip, garage) — same `Transport` rules.
- Ambushes on the road use the default city tables; a `Regions.Ambush` override per region.
- A Dash FX on the client (trail + whoosh) and a short camera shake when it lands near you.
- The **hideout computer** (owner, 2026-10-26): raids board, house orders, black-market shop, apps unlocked by finding
  contacts in the world; rival conduit crews on the same raids, met unannounced. → `design/phase-3-brief.md` item 7.
