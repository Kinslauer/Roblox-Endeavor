# Cybernetics: the whole body

> **Status**: Implemented (Studio push + owner playtest pending)
> **Author**: Claude, from the owner's direction 2026-10-27
> **Last Updated**: 2026-10-28
> **Last Verified**: 2026-10-27 against `src/shared/Cybernetics.lua`, `src/server/Gear.lua`, `src/server/Autonet.lua`, `src/client/Implants.lua`, `src/client/Senses.lua`, `src/shared/Voice.lua`, `src/client/Speech.lua`
> **Implements Pillar**: 2 — builds you assemble; conduits are "just stronger and more modified" (owner, 2026-10-26)

## Summary

Every part of a conduit's body can be ripped out and replaced with metal at the Autonet. That covers the eyes,
ears, nose, core, both arms and both legs. The owner's words: "the cybernetics are intended to be completely
usable, you could make someone 100% metal if you wanted. so everything must be rippable. arms legs eyes ears nose.
they all have benefits." Each kind of slot does something no other slot does. Paired limbs take a piece each.
What is in a body shows on that body, for everyone.

> **Quick reference** — Layer: `Progression` · Priority: `Phase 3+` · Key deps: `Gear (derived numbers)`, `Autonet (the only place to rip)`, `Grab (Lift)`, `Stats.Apply (jump)`, `Loot / Clues (Scent tag)`

## 1. Slots

| Slot | Takes | What it does (and nothing else does) |
|---|---|---|
| Eyes | Eyes | **Timing**: `FlickerRate` (a wider flick window and cheaper flicks), `ParryBonus` (a wider parry window) |
| Ears | Ears | **Hearing**: any moving body inside the radius that you can't see puts a pip on your screen, pointing at it. This works through walls and behind you. |
| Nose | Nose | **Scent**: loot and fragments inside the radius are marked through walls. With `Track`, wounded bodies are marked as well. |
| Core | Core | **The engine**: stamina, posture, charge and resist. The strongest cores cost max health. |
| Left arm, Right arm | Arm | **Force**: Strength, `FlashBonus`, `ChargeGain`. `Lift` lets the arms pick up heavier debris: one lifting arm for Medium, two for Heavy. |
| Left leg, Right leg | Leg | **Movement**: `Speed` (a share of walk speed), `Jump` (a share of jump height), `DodgeBonus` (dodge i-frames) |

- An arm piece fits either arm and a leg piece fits either leg. To fill both arms with Servo Arms you need two
  Servo Arms (`Cybernetics.Fitted`, `Gear.CyberSlot`).
- Lose a copy (theft, crafting, a drop) and the extra comes out. The left side keeps the one that's left (`Gear.Validate`).
- The loadout panel shows **Body: N% metal**. That is the number of fitted slots out of 8 (`Gear` `Conversion`).

## 2. Pieces (v1)

| Piece | Slot | Benefit | Cost |
|---|---|---|---|
| Reflex Optic | Eyes | Agility +2, flick window +0.15 | — |
| Targeting Lens | Eyes | Intelligence +2, parry window +0.05 s | — |
| Audio Pickup | Ears | Willpower +1, hearing 60 studs | — |
| Echo Array | Ears | hearing 100 studs, parry window +0.03 s | max health −5 |
| Chem Sniffer | Nose | Intelligence +1, scent 45 studs | — |
| Blood Tracer | Nose | scent 35 studs, tracks wounded bodies | — |
| Neural Core | Core | Willpower +3, flick window +0.25 | — |
| Overclock Core | Core | Agility +2, Strength +2, Black Flash +0.6, flick +0.15 | max health −20 |
| Plated Core | Core | Fortitude +3, posture +20, physical resist +6% | walk speed −3% |
| Servo Arm | Arm | Strength +3, Black Flash +0.3, Lift 1 | — |
| Arc Gauntlet | Arm | Intelligence +2, arc resist +10%, charge gain +0.2 | — |
| Strider Leg | Leg | Agility +1, walk speed +5% | — |
| Piston Leg | Leg | jump height +20%, dodge i-frames +0.03 s | — |

Where they come from:

| Source | Pieces |
|---|---|
| Supply drops | eyes, Audio Pickup, Chem Sniffer, Strider Leg |
| Raiders | Chem Sniffer |
| Brutes | Plated Core, Piston Leg |
| Drones | eyes, ears |
| Warmongers | Blood Tracer, Echo Array, Piston Leg, Servo Arm, cores |
| Black market | Reflex Optic, Servo Arm, Strider Leg, Audio Pickup |

The Arena's bay gives one of each piece, and two of each arm and leg piece.

## 3. Ripping (unchanged rules, per slot)

Rips happen at the Autonet and nowhere else (dematerialization.md §6). The rules are the same for every slot:

- Each rip costs `Config.Cyber.RipHealthCost` of max health, paid up front. It never takes you below 1 HP.
- You are held in place for `RipSeconds`. A swap counts as two rips.

Fitting yourself out from flesh to all metal takes eight rips. That is eight times a third of your health, each time
on the table, so going all metal is something you work toward over several visits. The inventory row shows where each piece sits in you, for example
"in you (left arm, right arm)". At the table, arm and leg pieces show **Rip in L / Rip in R** and **Rip out L / Rip
out R**. The remote is `Autonet "In", itemId, slot?`. With no slot named, the piece goes in the first empty slot of its kind.

Older saves: Optic → Eyes, Arm → Right arm; Core stays Core (`PlayerData.Migrate`).

## 4. Senses (client/Senses.lua)

The server sets `Hearing`, `Scent` and `Track` as player attributes. The client draws what it already has replicated,
so the radius is the only gate.

- **Hearing**: a body counts only while it moves faster than 6 studs/s. Standing still is silent, so a conduit with ears hears you
  move but not wait. It must also be off screen or behind a wall: you don't get pips for what you can see.
- **Scent**: loot (`server/Loot.lua`) and fragment pickups (`server/Clues.lua`) carry the `Scent` tag. Fragments you
  can't see yet (clue rules) stay hidden from the nose too.

## 5. Visible implants (client/Implants.lua) and art

- `Gear.Push` sets `Cyber_<slot>` on each character, and every client draws it on every R15 body (players and `Combatant`s).
- **Limbs**: a metal shell, a copy of the body part 4% larger so it covers clothing, plus a lit seam at the elbow
  or knee.
- **Eyes, ears, nose, core**: small metal parts with an accent glow on the head and chest.
- The accent colour is set per piece.
- **Art drop-in**: give a piece `Mesh = { MeshId, TextureId, Scale, Offset }` in `Presentation.Implants.Pieces` and
  it replaces the placeholder. The visuals are the "scavenger conduit" look (owner, 2026-10-27): salvage metal,
  exposed actuators and brass fasteners, not fantasy armour. The prompts are in
  `design/art/cybernetics-asset-prompts.md`.

## 6. Full conversion: the voice goes

Owner, 2026-10-28, on what 100% metal does by itself: "you lose your humanity, you no longer speak the way you did."

- With all eight slots metal, the server flags the player (`Machine`, `Gear.Push`).
- Every client, the player's own included, renders that player's chat through `Voice.Machine`:
  - all capitals, and every sentence ends in a full stop (no ! or ?, no ~, an ellipsis is one stop)
  - contractions spelled out: DON'T becomes DO NOT, I'M becomes I AM
  - no laughter (lol, lmao, haha), no emoticons, no emoji, no stretched words (sooooo becomes SO)
  - a message that was nothing but laughter comes out as "..."
- The name and text go a cold grey-blue in the chat window, and the bubble turns terminal-style (`Presentation.Voice`).
- The moment the last flesh goes, a lore line plays at the Autonet (`Lore.FullConversion`).
- Rip any one piece back out and the voice comes back, with a line saying so. Conversion is a choice you can undo
  at the table, like every other rip.
- Display only: the words were already filtered by Roblox; this only reshapes them. It needs the TextChatService
  chat (the default for new places).
- There is no stat cost. Losing your voice is the cost.

## 7. Open questions

- Should enemies carry cybernetics (a warmonger with a servo arm you can rip off its body)? `Implants` already draws
  on Combatants that carry `Cyber_*` attributes.
- Should anyone react to a fully converted conduit (contacts greeting it differently, say)? Today only its own
  voice changes.
