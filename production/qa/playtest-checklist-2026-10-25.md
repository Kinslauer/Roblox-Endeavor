# Owner playtest checklist — 2026-10-25

Everything in the brief's build order (1–6) is implemented and verified by instrument; these are the
by-eye checks only you can do. Press **Play** in Studio (the place already has every script; if you
use Rojo instead, `git pull` in your clone first or Rojo will overwrite Studio with old files).

Keys: **LMB** attack · **RMB** heavy · **E** flick · **F** block/parry · **Q**+dir dodge · **G** feint ·
**T/Y/V** skills · **R** reload · **J** stats · **Tab** inventory · **L** loadout · **LeftControl** toggle aim stance ·
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
- [ ] Gunplay (Range): ammo counter bottom right (18 / 18 rifle). Shots kick the camera up and drift right then left — can you learn to pull against it? R reloads; an empty click reloads on its own.
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

## 13. Round 6 — the open world (Phase 3, build order 5), added 2026-10-26
- [ ] District 1 now has a north gap (gate street line, the side away from the dev arena). Walk out: a broken highway with wrecks, dead trees and dark lamps. Does it feel like leaving the city?
- [ ] Three Grunts at a third of the way, then a Brute with two Grunts. Fight or run past: can you?
- [ ] Near the end a **Warmonger** (red-black, Sledge). From ~30 studs it flicker-steps to you and swings a heavy. Is the step readable enough to dodge? Does it drop something worth the fight?
- [ ] Through the green arch: **Verdant Reach**. Domes, solar towers, planted beds, warm lamps. Does it read as a relief after the city? The covered market is a safe zone; open Tab inside it for the **Trader** and buy a part with war money.
- [ ] Stand on **Verdant Station** (platform by the south edge): "unlocked". Hold X on "Train to Relay Terminal": refused until you have also stood on the city's platform (by the north gate). Then ride: a 3 s protected wait, arrive on the other platform.
- [ ] Try the train while someone is hitting you: refused.

## 14. Round 7 — the computer, raids, contacts, rival crews (Phase 3, build order 6), added 2026-10-26
- [ ] Hideout, back-left corner: the **Computer** console (cyan). Use it: three apps, all locked, each naming who to find. Walk away: it closes.
- [ ] Verdant Market: a person by the stalls with a name over them — **the Broker**. Talk (hold X). Back at the computer, RAIDS lists three contracts with pay and step count. Take one. The HUD shows "RAID · ..." under your money, and a tall yellow beacon stands at the point if it has one.
- [ ] Run "Clear the Highway": four raiders on the road. When the fourth drops, either "Get to a station and extract" or a **lead** is offered. Try both across two raids: extract at a station (paid) vs. doing the lead's first objective (the raid continues; the final pay stacks ×1.5). Does the lead feel like a real choice?
- [ ] Rival crews: two conduits in teal walking the road between the wrecks, the road's end and the enclave gate — no warning when you meet. Kill one: it drops its baton and, often, **Raid Intel**. Use the intel (Tab): a new contract on your board, takeable with no contact.
- [ ] Ferrite Court plaza: **the Fixer** → HOUSE. Order the rug (30): it appears on your hideout floor. Only you see it.
- [ ] The road, past the brute by the wrecks: **the Dealer** → MARKET. Buy a Suppressor (110) or Intel (50).
- [ ] Every enemy now drops its weapon plus whatever it carried (Carrying count on the model). Loot a brute: a Sledge every time. Does that make corpses worth checking, or is the ground too busy?
- [ ] Tells: the first time any enemy sees you it says a line in a bubble over its head (within ~90 studs). Is that enough warning for rivals, or do you want a sound too?
- [ ] Hold the Gate while a rival crew is on the point: the timer stops and the line reads "contested" until they are dead or gone.
- [ ] A warmonger's / rival's dash leaves a streak (red / teal) and shakes the camera when it lands next to you. Pods and crates shake when they land nearby.

## 15. Round 8 — attack animations + the Magoi polish pass (combat feel), added 2026-10-26
- [ ] Equip the **Scrap Spear** (craft or loot). Click three times: thrust, low thrust (the body dips), then a wide swipe right-to-left. Does each read as a different move? Does the third feel like the end of a chain?
- [ ] Spear heavy (right mouse): a lunge — the body drops and leans in. Can you see it coming in time to dodge it from another client?
- [ ] Rebar Blade: four cuts (diagonal, rising backhand, flat, overhead finisher). Pipe Club: swing, backhand, overhead. Sledge: sweep, overhead; heavy = the slam with a big dust cloud. Fists: jab, cross (left hand), hook, uppercut.
- [ ] Every melee swing leaves a thin white trail from hand to tip for the active frames; heavies leave an amber one that hangs longer. Readable from behind an enemy?
- [ ] Dust: a low tan puff under your feet on a dodge, under an Enemy Step, where a launched body lands, and under heavies. Too much? Too little?
- [ ] Camera: with a melee weapon the camera sits farther back and higher (you can still scroll); draw a gun and it comes in over the shoulder. Does the far view make a two-enemy fight readable without losing the parry timing?
- [ ] HUD: one bar bottom-centre — health left, stamina right, a thin posture strip under it and a thin charge strip above; the T / Y / V skill slots sit right under it. Anything you miss from the old top-left stack?
- [ ] Enemies use the same combos (a raider's club, a rival's baton, a brute's sledge): does their body language give you the parry window?
- [ ] Idle: with a club / blade / baton the weapon hangs low and a little forward, off hand half up; bare hands keep a loose guard. Does the stance read as "ready" without blocking the view?
- [ ] Jump and land: the body dips and rises. Hit something: the swing freezes for a few frames on contact (longer on a heavy; a parry freezes both of you). Does the hit feel like it lands, or does the freeze read as lag?
- [ ] District neon is 30 % dimmer (signs, lamps, gate beams); the safe ring is untouched. Do hit sparks and trails now carry the colour?
- [ ] Prompts: every console / crate / contact shows a small dark badge with the key letter and faint text beside it; holding fills the badge amber. Readable at a glance? Try one on touch if you can.
- [ ] Nameplates: no names over heads; a small plate at hip height, lower-left (white players, red enemies, cyan contacts), fading out past ~30 studs. Do bodies read first?

## 16. Round 9 — the cycle (dematerialization), added 2026-10-26
To see one without waiting an hour, run this in the Studio command bar during Play (Server view):
`require(game.ServerScriptService.Server.Cycle).Schedule(70)`
- [ ] T−60 s: a low hum starts and rises; the lights around you start to fail, a few at a time, then more. Is it unsettling without telling you anything? Could you miss it?
- [ ] T−5 s: the colour drains out and the camera trembles. T: the screen goes white for a second, then the world is back.
- [ ] After: the road guards are at different posts, the rival crews are somewhere else on their routes, and the Broker / Fixer / Dealer are standing somewhere new (each has 3–4 spots). Any you couldn't find again?
- [ ] Anything left on the ground (enemy spoils, a dead conduit's remains) is gone. Your inventory, money and position are untouched; a raid you were running is still running.
- [ ] Stand in the hideout during one: nothing happens to you. Same deployed in the war.
- [ ] Any contact standing inside a wall, a stall or a wreck at one of its spots? Note which.

## 17. Round 10 — salvage materials and Arc Cells, added 2026-10-26
- [ ] With an arc pistol or rifle, the ammo counter has a cell count under it. Empty the magazine: R reloads and the count drops by one. With no cells, R says "No cells." and nothing happens.
- [ ] Deploy to the war: your cells are topped up to 4. Run dry in a long fight — does that feel like pressure or like a chore?
- [ ] Raider gunners and war recruits run out too: after a while one shouts "I'm out!", puts the gun away and comes at you with its fists. Kill it: the gun and any cells it had left are on the ground.
- [ ] New materials turn up in loot: Glass, Sheet Metal, Pipe, Battery, Black Powder. Craft Arc Cells (Battery + 2 Wire = 6 cells). The trader sells single cells (8); the black market sells Battery and Powder.

