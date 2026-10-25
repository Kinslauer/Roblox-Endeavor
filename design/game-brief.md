# Game Brief: Endeavor — Universe 1: Conduit

<!-- DRAFT for review. One-page brief in the Claude-Code-Game-Studios `minimal` format.
     This is the whole design doc for the vertical slice; it replaces GDDs. -->

**One-sentence pitch:** A Roblox action game that feels single-player until the city wakes up around you: a permadeath, always-on-PvP cyberpunk ruin where timing (parry, dodge, and the Black Flash flick) beats stat-checking.

## Core loop
- Scavenge and craft in the ruin → equip weapons, armor and cybernetics that change your moveset and unlock skills.
- Take quests and chase events (supply drops, ambushes) → fight NPCs and other players with timing-based combat.
- Win fights → XP, loot, and the Black Flash high. Lose one → your character is gone and your gear is on the floor for someone else.

## Player goal & fail state — what "working" looks like
- A new player finishes the tutorial, emerges into the shared city, wins a fight against a telegraphed enemy by reading its windup, lands a Black Flash, and loots a supply drop before another player can. A session feels complete after one risky trip out and back.
- Fail state: death. The character is wiped, everything carried drops as remains, and a fresh character starts over.

## MVP — what must exist to be the game
The server logic for all of these already exists in `src/`. The MVP is making them *readable* and *felt*:
1. Combat you can see: weapon in hand, a windup you can read (with the flick-timing cue), a swing, hit sparks, hitstop and sound slots for every CombatEvent.
2. Combat you can aim: the character faces the camera/mouse while fighting, so melee cones and the arc pistol go where you look.
3. An enemy worth fighting: a real rig, pathfinding, a telegraphed attack you can parry or dodge, and 2–3 variants.
4. A HUD that explains itself: labeled bars, a custom health bar, damage numbers on every target, hit markers, no key conflicts.
5. A fair arrival: spawn protection after Emergence, events that spawn inside the playable area, remote rate limits.
6. A first district: a generated blockout (streets, buildings, cover, `CitySpawn`s, one safe zone) that replaces the dev arena until hand-built districts exist.

## Out of scope — not building this
- Universe 2 (the first-person shooter world). Same account, different place, built after this slice proves the loop.
- Hand-built art: custom meshes, bespoke animations, and audio assets are the player's job in Studio. Code ships with procedural placeholders and ID slots for them.
- Factions, territory, pickpocketing, lockpicking, bounty board, talent tree, status effects, Conduit power trees, legacy cosmetics, leaderboards.
- Matchmaking and server-size tuning.
- Renaming data stores (would wipe saves).

## Build order
1. **Combat feel** — procedural weapon models + procedural swing/windup animation via Motor6D (with animation-ID slots), windup glow flick cue, hit sparks, hitstop, camera shake, sound slots. Risky and core-fun; prove it first.
2. **Aiming** — mouse-facing while in combat.
3. **Enemy v2** — R15 raider rig, PathfindingService, telegraphed attacks with parry/dodge windows, Grunt / Brute / Gunner variants, fixes for stuck-on-wall spawning.
4. **HUD v2** — labels, custom health bar, damage numbers, hit markers, Tab conflict fix, dodge feedback bug. *(implemented 2026-10-25, owner playtest pending)*
5. **Fair arrival** — spawn protection, in-bounds events, rate limits, stale-comment cleanup.
6. **District blockout** — generated first district + safe zone; dev arena kept behind `Config.Dev`.

---
**Who it's for / what they feel:** Roblox combat-game players (Deepwoken / Cursed Gear fans) who want the tension of having everything on the line and the rush of a perfectly timed hit.

**Art & audio direction:** Wrecked neon megacity at night; heavy, readable silhouettes; combat audio that snaps (short, punchy hits, a bass-drop Black Flash).

**Reference game:** Deepwoken — the timing-based melee, posture and permadeath; none of its talent cards, factions or ocean yet. Cursed Gear — the flick/Black Flash chain as the skill ceiling.
