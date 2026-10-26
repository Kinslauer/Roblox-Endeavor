# Wardogs — the war world's perpetual battle

> **Status**: First implementation 2026-10-26 (`server/War.lua`), live-verified in Studio, owner playtest pending
> **Owner ask** (Phase 3 brief): a 3-sided, ticket-based, capture-the-moving-hill battle that never stops; recruits
> cloned on the war world (land/sea facilities, re-entry pods); rewards for the objective zone, revives and takedowns;
> money that comes home to the Conduit world. Death there costs the **deployment only** — never the Conduit.
> **Where it runs today**: the Range's arena, until the war world is its own place (build order 6).
> **Decided** (owner): three player factions from day one; everyone on the war world is a *recruit* — "they all know
> they're really just in hell. They've accepted it."

## 1. The shape of it

Three sides — Ashen Compact, Meridian Union, Hollow Court (`Config.War.Factions`) — each with a base, a cloning facility
and a ticket count. One **hill** (a ring and a beam) sits on one of `HillPoints`. Holding it alone for `CaptureSeconds`
flips it to your side; the side that owns the hill bleeds every other side one ticket every `HillDrainSeconds`. The hill
moves after a capture (`HillMoveOnCapture`, 3 s later) or on its own after `HillMoveSeconds`, so nobody can dig in.
Every death on the field — AI or player — costs that side `DeathTickets`. When any side hits 0, the **round** ends: the
side with the most tickets left "holds the field", its deployed players get `MoneyRoundWin`, all recruits are cleared,
tickets reset, the hill moves, and the next round starts at once. There is no lobby; the war is always on.

### Why these rules
- **Three sides, one hill** means the leader is always the one being shot at by two others — the natural brake on
  snowballing without any artificial catch-up.
- **The hill moves** so the fight is a march, not a siege; the owner's advantage is temporary by design.
- **Tickets, not kills**, keep the objective the point: a side that farms kills but never stands on the ring still loses
  to the drain.
- **Rounds end and restart themselves**: a player who deploys at any moment lands in a fight that is already happening.

## 2. Recruits

Everyone on the war world is a recruit. Players are recruits with a will; AI recruits (`Enemies.Defs.Recruit`: Arc Rifle,
90 HP, speed 16, aggro 120, leash 400, keep 18–40 studs, Poise 2) fill the sides out:

- **Re-entry pods**: every `PodIntervalSeconds` a side under `MaxRecruitsPerSide` gets a pod that drops from `PodHeight`
  above its base over `PodFallSeconds` (flame, "Pod" combat event), then opens into a `Squad` of recruits.
- **The cloning facility** at each base trickles one more recruit every `CloneIntervalSeconds` while under the cap.
- AI recruits hunt the nearest **other-side** combatant (player or AI, not downed), and when nobody is in range their
  home is **the hill** — so the hill is always contested, even on an empty server.
- No friendly fire between recruits of the same side, players included — but **only in the war zone**; in the city,
  conduits owe each other nothing (`Combat.FactionOf`, `atWar`).
- What a recruit spawns with depends on its side's **supply pool** (§6): basic, armed or plated.

## 3. The player's loop

1. **Deploy** from the hideout console (needs a side; `Range.Unlocked`). You arrive at your base facing the hill, in
   first person, with the basic kit, under `EntryProtection`. First deployment plays `Lore.FirstRift`.
2. **Fight for the hill**. Standing on the ring pays `MoneyPerZoneSecond`; killing an AI recruit of another side pays
   `MoneyPerTakedown`, a player `MoneyPerPlayerTakedown`.
3. **Going down**: a lethal hit on a deployed player **downs** them instead (`Combat.LethalHook` → `War.down`): 1 HP,
   prone, stunned, a "Revive" prompt (hold X `ReviveSeconds`) that any same-side recruit can use. A revive gives
   `ReviveHealthFraction` health and pays the reviver `MoneyPerRevive`. Nobody comes in `DownedSeconds` → you bleed out.
4. **Dying** (bleed-out): your side loses a ticket, the killer is paid, and you **redeploy** from your base after
   `RedeploySeconds` as a fresh body — Deployed, in the zone, first person, kit on. Nothing else changes: the Conduit,
   the stash, the wallet, the side are untouched. `Lifecycle.onDied` asks `War.HandleDeath` first; only when the war
   says no does permadeath get a look.
5. **Leaving**: the Return rift (or anything that fires `Range.OnLeave`) ends the deployment and puts you in the hideout
   with whatever money you made. The money is the thing that crosses between worlds.

### Why the deployment is the only thing at stake
The Conduit world is the permadeath game; the war world is the one you can lose for an evening and come back to. If
a war death wiped the Conduit, nobody would ever deploy. If a war death cost nothing, nobody would care about the
hill. A ticket, a redeploy timer and the money you did not bank is the middle.

## 4. Numbers (`Config.War`)

| Rule | Value | Note |
|---|---|---|
| Tickets per side / per death | 150 / 1 | a round is a few minutes with recruits dying constantly |
| Hill drain | 1 ticket per other side every 2 s | the owner's pressure |
| Hill radius / capture | 16 studs / 12 s uncontested | contested or empty: progress freezes, an empty hill keeps its owner |
| Hill moves | after capture (+3 s) or 90 s | `HillPoints`: 6 spots around the arena centre |
| Recruits | 3 per pod, cap 6 per side, pod every 25 s, clone every 18 s | pod falls 140 studs in 2.2 s |
| Downed / revive | 20 s bleed-out; hold X 2.5 s; 40 % health back | |
| Redeploy | 5 s | |
| Pay | 1/s on the hill, 15 revive, 10 takedown, 30 player takedown, 60 round win | money = `Wallet` |

## 5. What the client sees
- HUD war board while `Zone == "Range"`: hill line (owner / who is capturing / progress / position) and three ticket
  rows with the recruit counts, from workspace attributes (`War_Tickets_<Id>`, `War_Recruits_<Id>`, `War_HillOwner`,
  `War_Capturing`, `War_Progress`, `War_HillPos`, `War_Round`) — no remote traffic for the board.
- DOWNED overlay with the bleed-out countdown (`DownedUntil` attribute).
- Combat events: "Pod", "HillCaptured", "Downed", "Revive" fx; announcements for deploy / downed / died / round end.

## 6. Supply — how the Conduit world feeds the war (build order 3)

Owner's rule: *AI recruits draw from a basic kit or from a pool generated from conduit supplies; shipments go to your
own recruits; conduits supply the pool separately.* Two consoles on the hideout's back wall, next to the stash:

**Supply the War (the pool).** Donating your stash turns it into points for your side's pool by item type
(`Config.Supply.Value`: materials 1, consumables 3, armor 10, weapons 12, cybernetics 15). The pool is server-wide
per faction. Every AI recruit the side fields **draws** from it: `CostPerRecruit` points are spent and the recruit
spawns with the highest **tier** the pool still reaches (`Config.Supply.Tiers`):

| Tier | Pool ≥ | Health | Resist | Damage | Look |
|---|---|---|---|---|---|
| Basic | 0 | ×1 | +0 | ×1 | side colours |
| Armed | 60 | ×1.25 | +8 % | ×1.1 | steel helm |
| Plated | 200 | ×1.5 | +16 % | ×1.2 | steel helm + plated torso |

So a side its conduits keep feeding fields tougher recruits, and attrition (three recruits a pod, one every 18 s from
the facility) drains the pool back toward basic. A side nobody supplies is never locked out — it just fights with the
basic kit. The HUD's ticket rows show each side's current tier; a tier change is announced to everyone.

**Shipment (your own gear).** Sends up to `ShipmentMax` shippable items from the stash (weapons, armor, cybernetics,
consumables — never materials) to the front. `ShipmentSeconds` later (wall clock, saved in the profile so a rejoin
does not lose it) a **crate** drops at your base while you are deployed, with a hold-X prompt only you can use.
Opening it hands over the items as your **field kit**: a gun is equipped first (this is a shooting war), armor and
cybernetics are worn. The field kit follows Tarkov's one honest rule: **die and it stays where you fell** (dropped as
loot anyone can take, 3 minutes), **walk out alive and it goes back to the stash**. Logging off returns it too —
there is no combat-log stake in the war. One shipment at a time; the war board shows the countdown and "waiting at
your base".

Why two channels: the pool is the *collective* lever (your faction's war gets better because conduits feed it; nobody
owns the result) and the shipment is the *personal* one (your gear, your risk, your base). Separating them keeps a
donation from ever feeling like a loss and a shipment from ever feeling like charity.

## 7. Open questions and follow-ups
- The pool is in memory: a server restart resets it. Persist per faction in a DataStore (or MemoryStore shared
  across servers) once the war is its own place.
- Shipments arrive as one crate at the base; "shipments to your own recruits" (your squad spawning with your gear)
  needs squads first.
- Enhanced senses / cybernetics bought from the pool as war-only buffs; faction pool spending choices (buy a pod
  early, call a drone wing) for players who want to *direct* supply, not just donate it.
- ~~Recruit corpses drop Gunner loot~~ — now `Items.LootTables.Recruit` (a ration, a little scrap, often nothing).
- The Range's "Rift" practice entry bypasses deployment (you are in the zone but not deployed, so you cannot be downed
  and your kills pay nothing). Fine for the firing line; remove when the war gets its own place.
- Squad play: deploying with friends onto the same side, pods you can ride down in.
- Sea facilities and land facilities as different spawn flavours (landing craft vs. pod) — world-scale content.
- Enhanced senses / cybernetics as war-world-only buffs (Phase 3 brief), bought from the faction pool.
