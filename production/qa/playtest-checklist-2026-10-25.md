# Owner playtest checklist — 2026-10-25

Everything in the brief's build order (1–6) is implemented and verified by instrument; these are the
by-eye checks only you can do. Press **Play** in Studio (the place already has every script; if you
use Rojo instead, `git pull` in your clone first or Rojo will overwrite Studio with old files).

Keys: **LMB** attack · **RMB** heavy · **E** flick · **F** block/parry · **Q**+dir dodge · **G** feint ·
**R/Y/V** skills · **J** stats · **Tab** inventory · **L** loadout · **LeftControl** toggle aim stance ·
**LeftShift** sprint · **C** first person · **X** use consoles/loot · **hold LeftAlt** to free the mouse for buttons (the creator and HUD panels free it on their own). Skip the tutorial with its Skip button if you have seen it.

## 1. Combat feel (epic `combat-feel`, stories 003–005)
- [ ] Swing: the arm winds back, the hand glows and the glow snaps to red right before impact — is the flick cue readable at the moment you should press E?
- [ ] Hit: sparks + a tiny camera punch; heavy hits shake more. Too much / too little?
- [ ] Parry: white ring + white flash; guard break: orange shards. Can you tell them apart without reading the word?
- [ ] Weapons sit in the right hand and point the right way (club, blade, baton, spear, sledge, pistol — take all from the arena Weapons Rack).
- [ ] Sounds: swing / hit / parry / guard-break / dodge are audible and not grating (placeholders).

## 2. Aiming (epic `fair-arrival`, Aim)
- [ ] The body turns to where the camera looks while standing still; the camera sits over the right shoulder; the mouse is locked to the centre.
- [ ] LeftControl toggles back to the classic camera and the reticle disappears.
- [ ] Swings and the arc pistol go where the reticle points.

## 3. Enemy v2 (epic `enemy-v2`, story 003)
- [ ] Find an ambush (walk the streets; a banner announces them). Grunt: can you parry it by reading its windup? Dodge through it?
- [ ] Brute: slow overhead; you can't stagger it mid-swing (hyperarmor). Does the fight feel fair?
- [ ] Gunner: keeps 18–30 studs away and shoots; closing on it should feel possible.
- [ ] Damage tuning: how many Grunt hits kill you at 100 HP? Note the number.

## 4. HUD v2 (epic `hud-v2`, story 003)
- [ ] Bars read HEALTH / STAMINA / POSTURE / CHARGE with numbers; the Roblox health bar is gone.
- [ ] Numbers float over whatever you hit; red "-N" over you when you are hit; BLOCKED / PARRIED / GUARD BREAK / DODGED words.
- [ ] Reticle blinks when a hit lands; the screen edges flash red when you take damage. Blinding or fine?
- [ ] Land a Black Flash (3 flicked hits in a row): the number over the victim should turn red with "!".

## 5. Fair arrival
- [ ] After Emergence you have a glowing ForceField for 8 s; it drops the moment you attack.
- [ ] Supply drops / ambushes land on streets, never in the plaza or outside the wall.

## 6. District 1 (epic `district-blockout`, story 004)
- [ ] From your spawn pad, can you see the Relay Plaza beacon and find it?
- [ ] Walk the ring: the "SAFE ZONE · Relay Plaza" label and banner appear; nothing can hit you inside, you can't hit out.
- [ ] Silhouettes and cover: enough corners to fight around? Too many lamps (frame rate)?
- [ ] The arena is south of the wall (0, 2, 820) — jump over / walk around to reach the armory. If you'd rather spawn there for testing, set `Config.Dev.SpawnInArena = true`.

Write what felt wrong in one line each; I'll turn them into tuning stories.

## 7. Round 2 (Phase 2) — added 2026-10-25 evening
- [ ] Creator → Skip: you should see "AWAITING EMERGENCE" with a countdown (or "waiting for others"), then "EMERGENCE" fading to black, then the city. No idle time in the room.
- [ ] LeftShift sprints (faster, stamina drains, slight FOV push); blocking cancels it.
- [ ] C: first person; C again returns to the exact zoom you had.
- [ ] Lore lines (italic, lavender) at: creator, wake-up, first swing, flicker step, first kill, first Rift.
- [ ] Rift in Relay Plaza → the Range: rifle sights, targets fall and score, Wave Console, Rift back. Melee refused inside.
- [ ] Spear thrust / slash, hammer swipe / slam, torso lean: do hits read now?

## 8. Round 3 — District 2 + Drone, added 2026-10-26
- [ ] From Relay Plaza walk the street just north of the plaza east: a magenta arch in the wall with "→ District 2". The gate street has lamps and kerbs; nothing blocks it.
- [ ] District 2 (Ferrite Court): rust/brown buildings, orange-red neon, warm lamps, more rubble. Does it read as a different place at a glance?
- [ ] Its plaza shows "SAFE ZONE · Ferrite Court" and refuses damage like Relay Plaza.
- [ ] Ambushes in D2 are bigger (3–5) with more Brutes. Fair, or too much?
- [ ] Spawn test: die in the city (permadeath wipe) → you wake in District 1. Rejoin alive → District 2.
- [ ] Range: Wave Console, wave 2 → 2 Gunners + 2 Drones. Drones hover ~9 studs up and circle you, flipping direction; their eye glows red before a shot. Can you hit them with the rifle? Does a hit visibly knock them off their line?
- [ ] Drone spoils land on the ground under where it died.
