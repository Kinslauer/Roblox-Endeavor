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
| Flickering cursed energy | Timing-based Black Flash: tap flick just before impact, chain 3 flicked hits -> x2.5 guard-breaking Black Flash + the Zone. Counters: parry, dodge, or stun them out of it. |
| Feint | Cancel a swing during its windup for most of the stamina back (Deepwoken). Heavies are criticals that crush blocks. |
| Tutorial | 15 data-driven steps in the private prologue room teach the real systems against a dummy that strikes with a telegraph; completion (or skip) marks the player ready and can open the world early. |
| Armor | Head/Chest/Legs. Resistances (Physical/Arc), posture, stat bonuses, weight, and tags (Scav/Plated/Conduit). |
| Cybernetics | Optic/Arm/Core implants: stats + tags (Cyber/Conduit) plus flick window and Black Flash bonuses; strong ones cost max health. |
| Skills | No class lock. Unlock from effective stats + worn armor tags; power scales with both. 3 slots; Surge, Shatter Strike, Phase Step, Second Wind, Iron Bastion (needs Plated), Overload (needs 2 Conduit pieces), Overclock (needs 2 implants; primes the flick chain). |
| Permadeath | Death resets the ProfileService character (session-locked saves), drops *all* items as lootable remains, credits the killer, records a legacy. Combat-logging counts as death. |
| Loot / stealing | Remains and crates are hold-to-loot prompts; hold time is the risk window. |
| Crafting | Recipe table in `Items.Recipes`. |
| Quests | Rotating collect/kill/craft/bounty quests with XP + item rewards. |
| Events (`Events`) | Weighted director: supply drops (announced to all, pulls PvP) and mixed ambushes (Raider/Shocker/Brute). |
| City (`City`) | Four generated districts with danger tiers, verticality, refilling caches, district banners and an explore quest. |
| Raids (`Raids`) | Blackout Gate -> sealed arena -> 4 waves -> Warden boss -> vault with a guaranteed implant. Scales with party size. Permadeath applies. |
| Devour | Consume remains for xp/charge/heal instead of looting them (Cursed Gear's devour). |
| Helmetcam | First-person with visible body (TTK-style), toggled with P. |
| Destruction & salvage | Breakable props -> salvage + grabbable chunks; grab/throw with parry deflect; shared explosions; tiered breach points on locked buildings; hourly dematerialization. Stories 1-7 of the design doc; 8 (stress test) and 9-10 (war world, gore) remain. |

## Roadmap
**Immediately after friend testing**
- Tune Flicker/Black Flash timing (`Config.Flicker`), plus weapon numbers; add a flick-timing cue (windup glow).
- Tutorial v2: scripted animations/voiceover, a lore beat before Emergence, and a flick-timing cue (windup glow).

**Next (vertical slice)**
- Build the city: districts (slums, corp plaza, transit hub, blackout zone), tag `CitySpawn`s, lighting/atmosphere.
- Animations + hit effects + sounds (hook `CombatEvent` "Swing"/"Hit").
- Safe-ish zones / spawn protection so new characters are not spawn-killed.

**Then**
- Hand-built district art replacing the generator; a proper Blackout interior for raids; more raid gates with different bosses.
- Cold War-style war world: faction fronts, artillery, sector resets, no vehicles (see the destruction doc).
- Destruction & salvage: breach points, destructible props, salvage crafting, grab-and-throw debris, explosions; war-world destruction at scale. See [systems/destruction-and-salvage.md](systems/destruction-and-salvage.md).
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
