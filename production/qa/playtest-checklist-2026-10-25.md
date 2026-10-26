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
- [ ] Launcher: light, light (stagger), then **heavy** on a Grunt → it flies up ("LAUNCHED"), hits while it is airborne pop it ("AIR x2…") and hurt more; it lands stunned. Does the rhythm read? Too floaty / too short?
- [ ] Enemy Step: dodge (Q) while a Grunt is in the air next to you → you hop up and get stamina back ("ENEMY STEP").
- [ ] Gunplay (Range): ammo counter bottom right (18 / 18 rifle). Shots kick the camera up and drift right then left — can you learn to pull against it? T reloads; an empty click reloads on its own.
- [ ] Hip fire while moving scatters; stop and hold RMB and the cone tightens after a beat. Sprinting drops the sights.
- [ ] Headshots on Gunners/Targets read "HEADSHOT" and hit twice as hard. Does the rifle still feel fair at 100 studs?

## 9. Round 4 — the hideout (Phase 3, build order 1), added 2026-10-26
- [ ] Find the station: south edge of each district, street line 2 (west of the plaza column), green "STATION · EXTRACT" sign. Hold X for 4 s. Try it right after hitting someone: it should refuse.
- [ ] The hideout: a warm private room, "SAFE ZONE · Hideout". Right side: Deploy / Return. Back: Stash deposit / withdraw. Left: the three faction consoles. Does the room read as *yours*?
- [ ] Pick a side; the HUD shows "Side · MONEY n". Deploy (needs a side) → the Range in first person; the Rift/Return there now brings you back to the hideout, not the plaza. Waves pay money.
- [ ] Stash: deposit, then die in the city — the stash, money and side survive; you wake in District 1 as a fresh character. Withdraw at the hideout afterwards.
- [ ] Log off in the hideout, rejoin: you wake in the hideout.

## 10. Round 5 — Wardogs (Phase 3, build order 2), added 2026-10-26
- [ ] Pick a side in the hideout and **Deploy**. You should land at your side's base pad (flag in your colour) facing the hill's beam, in first person, rifle in hand. Does the base read as a camp, not a spawn point?
- [ ] Watch the sky over a base for ~25 s: a pod should fall and open into three recruits in that side's colours. Do pods read as reinforcements arriving?
- [ ] The HUD war board (top): hill owner / who is capturing / progress, and three ticket rows with recruit counts. Is it readable mid-fight?
- [ ] Walk onto the hill ring alone: "capturing" fills over ~12 s, the ring recolours to your side, 3 s later the hill moves. Money ticks up while you stand there.
- [ ] Shoot your own recruits: nothing. Shoot another side's: normal damage, "+10 money" on the kill.
- [ ] Get downed (let a recruit finish you): screen says DOWNED with a countdown, you are prone and cannot act. Stand near a downed friendly recruit... (solo: you will bleed out at 20 s). Is 20 s too long alone?
- [ ] After bleeding out: "You died. Redeploying from your base in 5 s" → you are back at your base, fresh body, kit on; your money/stash/side unchanged. Check the Conduit is untouched (level, inventory) when you Return.
- [ ] Let a round finish (a side at 0 tickets): announcement "Round n: the X hold the field", +60 if it was yours, recruits cleared, hill moves, next round starts straight away.
- [ ] Clutter: recruits now drop only a ration / some scrap, often nothing. Still too much?

## 11. Round 5b — supply (Phase 3, build order 3), added 2026-10-26
- [ ] Hideout back wall, two new magenta consoles beside the stash: **Supply the War** (left) and **Shipment** (right). Stash some scrap and a weapon, then Supply: the message names the points and your side's kit tier; with 60+ the HUD rows should read "… · Armed" for your side on the next deploy.
- [ ] Deploy and look at your recruits: Armed ones wear a steel helm (Plated: plated torso too) and take a few more rifle rounds to drop. Does the upgrade read at a glance?
- [ ] Stash a gun or armour, press Shipment: "lands at your base in 45 s". Deploy; the war board shows the countdown; at 0 a crate in your colour falls at the base. Hold X: the gun is in your hands (ammo counter), armour worn.
- [ ] Die with the kit: "Your field kit stays where you fell" — a loot pile where you went down. Return alive with a kit instead: it is back in the stash. Does the risk feel right, or should some of it come home on death?

## 12. Round 5c — the weapon bench (Phase 3, build order 4), added 2026-10-26
- [ ] In the hideout holding the Arc Pistol, open Tab: a pink "Workbench: Arc Pistol (mag 9, spread 2.4/0.5, kick 1.6)" header and six slot rows. Craft an Extended Magazine and a Tactical Light from scrap + wire (crafting list, bottom), then press **Fit** on each. The header numbers change; the gun in your hand shows a torch beam.
- [ ] Deploy / go to the Range with the Dot Sight or a Brake fitted (loot them off Gunners, or `Supply` crates in the city): does the pistol feel different — tighter when aimed, less kick? Is the difference big enough to chase parts for?
- [ ] Fit a Laser Sight: a red beam from the gun in third and first person. Does it help hip fire read?
- [ ] Strip one slot, then "Frame": parts return to the inventory, the ammo counter clamps back to 9. Try the bench outside the hideout: refused.
- [ ] Rifle parts (4x Scope, Light Bolt from Drones) refuse the pistol; fit them to the Arc Rifle instead when you have one.
