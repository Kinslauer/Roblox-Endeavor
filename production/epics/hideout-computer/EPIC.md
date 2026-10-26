# Epic: The hideout computer — raids, contacts, house, black market, rival crews (Phase 3, build order 6)

> **Status**: Stories 001–007 implemented (owner playtest pending) · **Layer**: Core loop (Conduit world) · **Rigor**: standard
> **Brief**: `design/phase-3-brief.md` item 6 + the 2026-10-26 addendum · **GDD**: `design/gdd/raids.md`

## Overview
The computer in the hideout is where a conduit learns what there is to do. RAIDS (contracts with kill / reach / hold
steps that end in an extraction or continue through a lead), HOUSE (furnishings, drawn for their owner), MARKET (the
black market) — each locked until its contact is found in the world. Rival conduit crews walk the same ground
unannounced and drop intel that puts contracts on the board. Every enemy now drops everything it carries.

## Stories
| # | Story | Type | Status |
|---|---|---|---|
| 001 | `shared/Raids.lua`: points, six templates, contacts, house, market, crews, lead chance/bonus, board size, `StepText`; Intel item; Rival def + loot; lore lines; profile fields (Contacts, Board, House persist; Raid dies with the body) | Data | Implemented |
| 002 | `server/Raids.lua`: board fill / intel insert, Accept (contact or intel), Abandon, kill / reach / hold progress with a per-player beacon, leads (offer + follow with bonus), `OnExtract` pays the chain; `RaidLine` attribute; hooks in `Hideout.Extract` and `Transport.Ride` | Logic | Implemented — live: 4 kills → extract step with a lead, lead followed (chain 2 ×1.5), extraction paid 158 |
| 003 | `server/Terminal.lua`: one state table, Meet (unlock + lines + first-contact lore), Open / Close (walking out closes), Order (house, once), Buy (black market), rate-limited `Remotes.Terminal`; the hideout's "Computer" console | Logic | Implemented — live: locked → unlocked per contact, rug ordered, suppressor bought |
| 004 | `server/Contacts.lua`: three standing bodies (Rig.Build, anchored, ForceField, Talk prompt) at the broker / fixer / dealer spots | Content | Implemented — live: 3 placed |
| 005 | `server/Rivals.lua`: two crews on routes between raid points, linger / move on, Home follows the crew, respawn after a wipe; `Enemies.Defs.Rival` with a short Dash | Logic | Implemented — live: 4 rivals, 2 crews |
| 006 | Client: `Hud` Terminal panel (three apps, Take / Drop / Order / Buy / Close), raid line under the wallet; `HouseView.lua` draws owned furnishings in the hideout | HUD | Implemented — live: panel rows + buttons, HouseView 2 parts for the rug |
| 007 | Everything drops: `NPCs.packCarry` at spawn (weapon + kit armour + one roll), dropped in full at death; held weapons removed from roll tables; kill credit tagged before damage | Logic | Implemented — live: grunt carried PipeClub + ration + scrap, all on the ground |
| 008 | Owner playtest: find the broker without being told; does a lead feel like a choice; are rival crews a surprise or a nuisance; does "everything drops" make corpses worth checking | Feel | Pending |
| 009 | The Autonet (`dematerialization.md` §6): schematic as knowledge (`Autonet` fragment), knowledge-gated recipe (`Recipes[id].Needs`), kit -> installed in the hideout for its owner (persists), cybernetic fit / swap / strip only at the Autonet, each rip a ~4 s channel that costs health (never lethal); field equips refused with a line; existing fits kept | Logic + HUD + Content | Not started (after 010 and destruction 002 / 011) |
| 010 | Knowledge on the computer: `profile.Knowledge`, the ARCHIVE app (with destruction epic story 011) | Data | Not started |
| 011 | Acquire the computer (`dematerialization.md` §6): empty desk until installed; `HomeComputer` item found (rare loot, rivals, breached interiors, anomaly spots) or built (salvage recipe); install = upload (`profile.Computer`); PERSIST split into hideout-kept (Money, Stash, Faction, Shipment, Hubs, Autonet) and computer-kept (Knowledge, Contacts, Board, House, only once uploaded); existing profiles grandfathered | Logic + Content | Implemented (smoke: 5 checks; Studio push pending) |

## Acceptance criteria
1. The computer shows three locked apps; meeting each contact unlocks its app with the contact's line.
2. A contract taken from the board puts its line on the HUD and a beacon at its point; kills / reaching / holding advance it.
3. Finishing the objectives either tells you to extract or offers a lead; following the lead chains the pay ×1.5; extracting at a station or train pays the chain and clears the raid.
4. Intel (from rivals or the market) puts a takeable contract on the board; HOUSE orders show up in your hideout; MARKET sells for money.
5. Rival crews walk their routes with no announcement and drop what they carry; every enemy drops its weapon and everything else it had.
6. Smoke covers 1–5 (17 checks: 174/174).

## Follow-ups
- Racing crews, place-based contracts, rival barks at aggro range, a tabbed terminal UI, functional furnishings (see the GDD).
