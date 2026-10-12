# Class Combat System (Roblox / Luau)

**Built:** 2021 – 2022 · Solo project

> Written in Roblox Studio between 2021 and 2022. Roblox saves projects as binary place files, so in 2026 I used Claude to extract the scripts into plain `.lua` files for GitHub. The code itself is unchanged, apart from replacing friends' Roblox usernames with placeholders.

The combat and game systems for a class-based fighting game on Roblox. Players pick a class, fight in rounds on voted maps, and can practise against training NPCs.

## Highlights

- **Melee combat:** light-attack combos, heavy attacks, and class skills, each driven by per-attack frame data (`ServerScriptService/CombatManager.server.lua`).
- **Defence:** blocking, a timed parry window, and a posture meter that leads to a guard break when it fills.
- **Dodge with i-frames:** a short invulnerability window with a cooldown.
- **Hit stun and attack stun:** states that stop players acting out of turn and make combos possible.
- **Lag compensation:** hit timing is adjusted for the delay between client and server (`getClientDelay`).
- **Physics knockback:** knockback paths are raycast each step so players stop at walls instead of clipping through them.
- **Data-driven classes:** 5 classes defined as data (stats, attacks, skills) and loaded at runtime (`ServerStorage/Modules/ClassData.lua`, `ClassLoader.lua`, `SkillData.lua`).
- **Hitboxes and projectiles:** a custom hitbox module and a projectile module.
- **Training NPCs:** dummies that attack, block, parry or use heavies so players can practise each mechanic.
- **Game loop:** map voting, rounds, a shop and rewards HUD, collision groups, and saved player data.

## Layout

The code was written in Roblox Studio and extracted from the place file. Folders under `src/` mirror the Roblox Explorer tree. File suffixes follow the Rojo convention:

- `.server.lua`: server `Script`
- `.client.lua`: `LocalScript`
- `.lua`: `ModuleScript`

Only my own code is included. ProfileService (used for saving) and Roblox's default scripts were left out, as were models, animations and effects assets, so the code won't run on its own.
