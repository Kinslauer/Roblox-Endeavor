# Design

## Pillars
1. **The reveal.** Prologue feels single-player; Emergence reveals everyone else.
2. **Everything is at stake.** Permadeath, always-on PvP, loot drops where you fall.
3. **Skill-based combat.** Timing (parry, dodge i-frames) and stamina management beat stat checking.
4. **A living ruin.** A cyberpunk megacity that is wrecked but inhabited; events keep it unpredictable.

## Core loop
Scavenge -> craft/upgrade -> take quests -> fight (NPCs, players, events) -> get stronger -> risk it all.

## Systems (implemented in this scaffold)
| System | Notes |
|---|---|
| Prologue/Emergence (`WorldPhase`) | Per-player private plots 1500 studs apart, no PvP. Timer starts on first join; at zero everyone is teleported to city spawns. Late joiners skip straight in. |
| Attributes (`Stats`) | Strength (damage), Fortitude (health), Agility (speed), Intelligence (Surge power), Willpower (stamina). XP -> level -> points. |
| Combat | M1 combo with 4th-hit finisher, block (stamina cost, guard break), parry window, dodge with i-frames, stun. All server-validated. |
| Conduit "Surge" | Hits build Charge; spend it on an unblockable AoE burst. Placeholder for the Cursed Gear-style conduit powers. |
| Permadeath | Death deletes the DataStore character, drops *all* items as lootable remains, credits the killer, records a legacy. Combat-logging counts as death. |
| Loot / stealing | Remains and crates are hold-to-loot prompts; hold time is the risk window. |
| Crafting | Recipe table in `Items.Recipes`. |
| Quests | Rotating collect/kill/craft/bounty quests with XP + item rewards. |
| Events (`Events`) | Weighted director: supply drops (announced to all, pulls PvP) and raider ambushes. |

## Roadmap
**Next (vertical slice)**
- Build the city: districts (slums, corp plaza, transit hub, blackout zone), tag `CitySpawn`s, lighting/atmosphere.
- Animations + hit effects + sounds (hook `CombatEvent` "Swing"/"Hit").
- Character creation + proper tutorial inside the prologue plot (teach combat vs. a scripted dummy).
- Safe-ish zones / spawn protection so new characters are not spawn-killed.

**Then**
- Deepwoken-style depth: weapon classes, talents/mantras unlocked by stat thresholds, posture bar, status effects.
- Conduit powers: multiple trees (arc, cinder, void...) with cooldown/charge costs.
- Pickpocketing on live players, lockpicking containers, bounty board, factions/territory.
- Gear: armour with resistances, rarity/affixes, durability, workbenches by district.
- More events: blackout zones, rogue drone swarms, faction wars, boss spawns.
- Anti-exploit pass (rate limits on remotes, sanity checks), DataStore session locking (swap in ProfileService), legacy cosmetics/leaderboards.
- Server size/matchmaking tuning for a shared open world.

## Open design questions
- How long should the prologue last, and should it end by timer, objective, or both?
- Does a dead player keep anything (a "legacy" perk), or is it a fully clean slate?
- Should low-level players be matchmade/protected for the first N minutes?
