# Phase 2 Brief: Endeavor after the vertical slice

<!-- Written 2026-10-25 evening, after the owner signed off the Phase-1 brief's six items (1–6) and
     round-1 playtest fixes. The owner said "start everything else"; the assumptions below are mine
     and are the first things to confirm or overrule. -->

**Where we are:** Universe 1 (Conduit) plays end to end: creator → tutorial → Emergence into District 1 →
telegraphed enemies, HUD, safe zone, aim stance, iron sights on the pistol. Everything is procedural
placeholders behind `Presentation` slots. 46/46 smoke checks, Studio place in sync with `claude/combat-feel`.

## Goal of Phase 2
Turn the slice into a **game with a shape**: two universes you can travel between, a reason to go out
and come back, and a second district so the city is bigger than one screen. Keep the rule from
Phase 1: server decides, client draws, every number is data.

## Build order (each item ships as an epic with evidence, like Phase 1)
1. **First-person mode in Universe 1** — a camera toggle (first person locked, hip-fire view model,
   same combat) so the sight view is usable anywhere, not only while aiming. Small; also the base of 2.
2. **Universe 2 prototype: "the Range"** — built *inside this place* first (an offset zone like the
   arena) so it is testable through Studio today; split into its own place once it is fun.
   - Entry: a **Rift** in Relay Plaza (hold X). Exit: a Rift back. Travelling is not death.
   - Rules in the zone: first person locked, FPS move speed, no melee; weapons are hitscan
     (`Ranged`) and fire along the validated camera direction.
   - Weapons: Arc Pistol (exists) + **Arc Rifle** (new: semi-auto, longer range, 2-shot stagger,
     ADS with the same `Sight` system) + a **Lance** heavy (charged shot). Data only, in `Weapons.lua`.
   - Enemies: Gunner (exists, retuned for range) + **Drone** (flies, weak, strafes) via `NPCs`.
   - Content: a shooting range with pop-up targets and distance markers, then a wave arena.
   - Progression hook: Rift unlocks after the first District-1 kill (`Awakened` + 1 kill) — the
     "seems single-player until it isn't" beat gets a second reveal.
3. **Tutorial v2 lore** — one line at each beat (creator, first swing, Emergence, first Rift) from a
   `Lore.lua` table; no new systems.
4. **District 2** — the generator with a second seed and palette at an offset, joined to District 1
   by a gate street; its own plaza safe zone; `CitySpawn`s split by `Awakened`. Supply drops and
   ambushes already follow `PlayableArea`.
5. **Multi-place split** — `Universe2` as a separate place in the same experience: Rojo project per
   place, `TeleportService` with the profile in the shared DataStore. Only after 2 is signed off.

## Owner decisions I am assuming (say the word and I change them)
- Universe 2 is the shooter; Conduit stays the melee universe. Travel is free once unlocked.
- Permadeath applies in both universes; your remains drop where you die.
- The Range is PvE first (targets, waves); PvP in Universe 2 comes with the place split.
- Default keys stay: LMB fire, RMB sights, MMB/G special, **C** toggles first person in Universe 1.

## Out of scope (still)
- Hand-made meshes, animations, audio (slots exist), factions, talent trees, matchmaking, monetisation.

## Done when
A new player can: finish the tutorial, win a District-1 fight, take the Rift, clear a Range wave in
first person with the rifle, come back through the Rift with the loot, and walk into District 2 —
with every step readable on the HUD and every number tunable in `Config` / `Weapons` / `Enemies` /
`Presentation`.
