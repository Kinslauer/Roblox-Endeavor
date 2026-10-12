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
| Attributes (`Stats`, `Gear`) | Strength (damage/posture damage), Fortitude (health, physical resist), Agility (speed, i-frames), Intelligence (skill power, charge gain), Willpower (stamina, posture). XP -> level -> points. `Gear` derives the effective numbers from stats + armor. |
| Weapons | Weapon = moveset: per-weapon combo chain, heavy, frame data (windup/active/end), reach and arc. Fists, club, blade, baton, spear, sledge, arc pistol (hitscan). |
| Combat | Server-authoritative. Hit stun cancels swings, posture meter + guard break, parry, i-frame dodge (shortened by heavy armor), wall-aware knockback, hyperarmor. |
| Armor | Head/Chest/Legs. Resistances (Physical/Arc), posture, stat bonuses, weight, and tags (Scav/Plated/Conduit). |
| Skills | No class lock. Unlock from effective stats + worn armor tags; power scales with both. 3 slots; Surge, Shatter Strike, Phase Step, Second Wind, Iron Bastion (needs Plated), Overload (needs 2 Conduit pieces). |
| Permadeath | Death resets the ProfileService character (session-locked saves), drops *all* items as lootable remains, credits the killer, records a legacy. Combat-logging counts as death. |
| Loot / stealing | Remains and crates are hold-to-loot prompts; hold time is the risk window. |
| Crafting | Recipe table in `Items.Recipes`. |
| Quests | Rotating collect/kill/craft/bounty quests with XP + item rewards. |
| Events (`Events`) | Weighted director: supply drops (announced to all, pulls PvP) and raider ambushes. |

## Roadmap
**Next (vertical slice)**
- Build the city: districts (slums, corp plaza, transit hub, blackout zone), tag `CitySpawn`s, lighting/atmosphere.
- Animations + hit effects + sounds (hook `CombatEvent` "Swing"/"Hit").
- Character creation + tutorial inside the prologue plot (re-use the reference repo's training NPCs: attack/block/parry/heavy dummies).
- Safe-ish zones / spawn protection so new characters are not spawn-killed.

**Then**
- Deepwoken-style depth: talent tree and more skills gated by stat thresholds and armor sets, status effects (bleed, burn, shock), armor set bonuses, weapon-specific hit effects.
- Conduit powers: multiple trees (arc, cinder, void...) with cooldown/charge costs.
- Pickpocketing on live players, lockpicking containers, bounty board, factions/territory.
- Gear: armour with resistances, rarity/affixes, durability, workbenches by district.
- More events: blackout zones, rogue drone swarms, faction wars, boss spawns.
- Anti-exploit pass (rate limits on remotes, sanity checks), legacy cosmetics/leaderboards.
- Server size/matchmaking tuning for a shared open world.

## Open design questions
- How long should the prologue last, and should it end by timer, objective, or both?
- Does a dead player keep anything (a "legacy" perk), or is it a fully clean slate?
- Should low-level players be matchmade/protected for the first N minutes?
