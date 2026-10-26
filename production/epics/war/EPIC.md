# Epic: Wardogs — the perpetual war (Phase 3, build order 2)

> **Status**: Stories 001–006 implemented (owner playtest pending) · **Layer**: Core loop (war world) · **Rigor**: standard
> **Brief**: `design/phase-3-brief.md` item 2 · **GDD**: `design/gdd/war.md` · **Runs in**: the Range's arena until the war world is its own place

## Overview
Three sides (Ashen Compact, Meridian Union, Hollow Court) fight a ticket battle over one moving hill that never stops.
AI recruits re-enter by pod and trickle from each base's cloning facility; players deploy from the hideout as recruits
of their side. Standing on the hill, reviving and takedowns pay money that goes home to the Conduit world. A lethal hit
downs a deployed player (an ally can revive); bleeding out costs the side a ticket and the player a redeploy timer —
**never** the Conduit, the stash, the wallet or the side.

## Stories
| # | Story | Type | Status |
|---|---|---|---|
| 001 | `Config.War` (tickets, hill, pods, downed, pay); `Enemies.Defs.Recruit`; `server/War.lua` builds three bases (pad, facility, flag) and the hill (ring + beam) around `Range.ArenaCenter`; `publish()` → workspace attrs `War_*` | Logic + Content | Implemented — live: 3 bases, hill beam, attrs updating |
| 002 | Recruits: `dropPod` (tweened pod from `PodHeight`, flame, "Pod" event, opens into `Squad`), facility trickle, `MaxRecruitsPerSide`; `NPCs`: faction-aware `nearestTarget` (skips own side and downed, hunts other-side combatants), dynamic `Home` = the hill, `NPCs.Killed` event, opts.Faction/Name/Cloth on the rig | Logic | Implemented — live: pods opened into 6/5/4 recruits, all sides fighting on the hill |
| 003 | The hill: presence per side, `CaptureSeconds` uncontested flips the owner, drain every `HillDrainSeconds`, moves on capture (+3 s) and every `HillMoveSeconds`, round ends when a side hits 0 (winner's players paid, recruits cleared, tickets reset, hill moves) | Logic | Implemented — live: Hollow capturing 34 %, tickets draining; smoke: capture, drain |
| 004 | Deploy / leave: `Hideout.Deploy` → `War.Deploy` (needs a side + `Range.Unlocked`; basic kit, zone Range, first person, base pivot, entry protection, `Lore.FirstRift`); `Range.OnLeave` wrapped to un-deploy; `Combat.FactionOf`, friendly-fire refusal scoped to the war zone | Logic | Implemented — live + smoke |
| 005 | Downed / revive / redeploy: `Combat.LethalHook` → `War.down` (1 HP, prone, stunned, Revive prompt hold X, bleed-out), `War.Revive` (`ReviveHealthFraction`, pays reviver), `War.HandleDeath` (ticket, killer pay, `task.spawn` Lifecycle.Spawn and poll for the new body, then `War.Deploy`); `Lifecycle.onDied` asks the war first; tutorial skipped for a redeploying recruit | Logic | Implemented — live: downed → bled out 19.9 s → redeployed 5.1 s later at the base, Deployed/Range/first person; smoke: down, revive, ticket, redeploy |
| 006 | Pay + HUD: `MoneyPerZoneSecond` (fractional accumulator), `MoneyPerRevive`, `MoneyPerTakedown` via `NPCs.Killed`, `MoneyPerPlayerTakedown`, `MoneyRoundWin`; HUD war board (hill line + three ticket rows) while in the zone, DOWNED overlay with countdown | Logic + HUD | Implemented — live: board visible, money rising on the hill |
| 007 | Owner playtest: does a round have a shape (push, hold, lose the hill, chase it)? Is 20 s downed too long alone? Do pods read as reinforcements? Recruit loot clutter | Visual/Feel | Pending |

## Acceptance criteria
1. Deploying puts you at your side's base, in first person, with the kit; your side's recruits never hurt you and you never hurt them; other sides do.
2. One side alone on the hill for `CaptureSeconds` owns it; owning it drains the other sides; the hill moves after a capture and on a timer.
3. A lethal hit downs you; an ally's hold-X revive brings you back at 40 %; nobody coming means bleed-out → one ticket → redeploy at your base after 5 s with a fresh body, your Conduit untouched.
4. Any side at 0 tickets ends the round: announcement, winners paid, field reset, next round immediately.
5. Hill time, revives and takedowns pay into the wallet; the HUD shows the board in the zone.
6. Smoke covers 1–5 (13 checks: 124/124).

## Follow-ups
- Recruit corpses drop full Gunner loot — clutter; make recruits drop supply only.
- The Rift practice entry puts you in the zone undeployed (cannot be downed, no pay) — remove when the war has its own place.
- Build order 3: shipments to your own recruits + the faction pool for AI kits.
- Squads (deploy with friends, ride the pod), sea/land facility flavours, enhanced senses / cybernetics as war-world buffs.
