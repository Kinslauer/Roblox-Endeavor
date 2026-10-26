# Epic: Hideout + extraction + wallet (Phase 3, build order 1)

> **Status**: Stories 001–004 implemented (owner playtest pending) · **Layer**: Core loop · **Rigor**: standard
> **Brief**: `design/phase-3-brief.md` item 1 · **Replaces**: the Rift as the way between worlds (the Rift stays as a dev shortcut)

## Overview
The swap between the two worlds happens at the hideout, after extracting. A station in every district (hold X,
`Config.Hideout.ExtractSeconds`, refused mid-fight) takes you to a private room that is a safe zone: deploy to the
war (the Range stands in until Wardogs), take the train back to the city, stash what you are not wearing (the stash,
your money and your side survive permadeath — the hideout is the account's, the body is not), and pick one of the
three factions. Leaving the war brings you home, not to the plaza. A character that logs off in the hideout wakes there.

## Stories
| # | Story | Type | Status |
|---|---|---|---|
| 001 | `server/Hideout.lua`: room at `Config.Hideout.Origin` (floor, walls, lamps, cot, workbench placeholder, SafeZone "Hideout"), consoles Deploy / Return / Stash Deposit / Stash Withdraw / one per faction; `Hideout.Enter/Leave/Extract/Deploy`; `Range.OnLeave` hook → home; `Hideout.SpawnCFrame` for rejoin | Logic + Content | Implemented — live: hideout built, extract → zone Hideout at (0, 5, −1390), Location Hideout; deploy → Range + first person; leave → Hideout |
| 002 | Extraction hubs: one `Station` per district (`ExtractHub` tag, street line `Hubs.Line`, `FromEdge` from the south edge; platform, posts, roof, neon sign, rails, hold-X prompt); refused while `Combat.InCombat` | Content | Implemented — live: 2 hubs; smoke: station inside District 1, refusal mid-fight |
| 003 | Wallet: `server/Wallet.lua` (Get/Add/Spend/Sync → `Money` player attribute), `profile.Money`; Range waves pay `WaveRewardMoney`; HUD "Side · MONEY n" under the quest line; `PlayerData.PERSIST` = Money, Stash, Faction survive a wipe (Location does not) | Logic + HUD | Implemented — live: HUD "Hollow Court · MONEY 77"; smoke: wipe keeps 70 / stash / Meridian, Location City |
| 004 | Stash v1 (deposit everything not worn, keep one copy of each worn item; withdraw all; `StashCount` attribute) and faction choice (`Hideout.SetFaction`, `Config.War.Factions`, switching costs `SwitchCost`; deploy refused without a side) | Logic | Implemented — live: stashed 4; smoke: deposit / withdraw / switch cost |
| 005 | Owner playtest: find the station from the plaza; does the hideout feel like yours; is the deposit-all stash enough until the stash UI | Visual/Feel | Pending |

## Acceptance criteria
1. Every district has a station; holding X on it while not in combat puts you in the hideout with travel protection; mid-fight it refuses with a message.
2. The hideout is a safe zone (`SAFE ZONE · Hideout` on the HUD); nothing can be hurt there.
3. Deploy needs a faction and enters the war zone (first person, loadout); leaving the war returns to the hideout.
4. Deposit moves everything not worn into the stash; a permadeath keeps Money, Stash and Faction and resets Location to City.
5. Changing sides costs `Config.War.SwitchCost`; the HUD shows side and money.
6. Smoke covers 1–5 (16 checks: 111/111).

## Follow-ups
- Stash UI (per-item moves) in the inventory panel while in the hideout.
- Shipments + the faction pool (build order 3); the weapon bench on the workbench (build order 4).
- A train you actually ride (today: a short protection window and a teleport).
