# Playtest checklist

Grows as features land. Tick what works, note what doesn't (an F9 → Client/Server tab screenshot is the most useful
report). Versions: Endeavor v28, Front v15.

## Endeavor: first minutes
- [ ] Spawn in the starting room on solid floor (no falling through, no black room). Returning players see
      "Welcome back, conduit" and the world opens at once.
- [ ] Tutorial steps advance as you do them (move, sprint with Shift, swing, block, dodge, flicker).
- [ ] F1 shows the controls card. Tab inventory, L loadout, J attributes, O hideout, N recruit app all open and close.
- [ ] City hum and wind are audible from the start (ambient loops).

## Endeavor: combat
- [ ] Light swing (LMB) and heavy swing (RMB/hold) show an arc and make a whoosh (heavy is deeper).
- [ ] Swings animate: the arm winds up and back, the torso twists, then the arm snaps down through the arc.
      Heavy swings wind up higher and slower. Other conduits' swings animate too.
- [ ] Each weapon family swings differently: fists jab, blades/batons/clubs cut across, the sledge comes overhead,
      the spear thrusts, the arc pistol aims and kicks. Brutes (sledge) and Wardens (blade) use theirs too.
- [ ] Blocking (F) raises both arms into a guard (yours and other players'); a blocked or parried hit jolts the guard.
- [ ] Getting hit flinches head and torso; a guard break staggers harder.
- [ ] Your own hits float a damage number off the target (yellow normal, orange big, grey blocked, cyan arc) with a
      small camera nudge; nobody else sees your numbers.
- [ ] Hostiles raise their arm for the whole telegraph (red glow) and slash when it lands; dodge/parry on the slash.
- [ ] Hitting a dummy or hostile thuds and flashes it red; parry (F just before impact) clangs and flashes white.
- [ ] Guard break (blocking too long) plays the deep crack; posture bar empties.
- [ ] Flicker (E just before your hit lands) ticks; three chained = BLACK FLASH banner, red shockwave, boom.
- [ ] Dodge (Q) has i-frames; feint (Z) cancels a swing; sprint (Shift) drains stamina.
- [ ] Equipping a weapon from Tab puts its model in your right hand; fists show nothing. Check each: pipe club,
      rebar blade, shock baton, scrap spear, sledge, arc pistol. Note any that point the wrong way or float.

## Endeavor: enemies and rigs
- [ ] Mannequins on the magenta pads by the test armory: Raider, Brute, Shocker, Warden. Limbs in the right place
      (left arm on the character's left), idle animation playing, weapon in the right hand.
- [ ] Live hostiles walk with moving legs, telegraph attacks, and die with gore (dismemberment, pools, corpse stays).
- [ ] Corpses can be looted; your own corpse after death cannot be looted by you for 60 s.

## Endeavor: destruction and salvage
- [ ] Props break (barrels, crates, signs, terminals, vending machines, window panes) with the right crunch
      (glass, wood, metal) and drop salvage chunks.
- [ ] Grab a chunk (G), charge and throw; a thrown chunk can be caught with G within 0.25 s of impact ("CAUGHT").
- [ ] Explosions (grenades, barrels) boom, push, and breach lockup doors by tier.
- [ ] Buildings come from the kits (five district styles, intact and collapsed variants); props show A/B/C wear.
- [ ] After a dematerialize cycle the world returns in a different condition.

## Endeavor: random events (every 1 to 2.5 minutes once the world is open)
- [ ] Supply drop: announced, a glowing crate lands; opening takes 3 s.
- [ ] Raider ambush: "Raiders have found you", 2 to 4 hostiles close in.
- [ ] Blackout: the city goes dark for a minute or two (neon stays), Shockers spawn; light returns afterwards.
- [ ] Warden patrol: announced by district; a Warden walks there and drops Supply loot.
- [ ] Salvage cache: intact props appear near you to break for salvage.
- [ ] Dead drop: a purple stash at a numbered hideout site, announced to everyone.
- [ ] Quests cycle through: scrap run, raiders, medkit, bounty, survey, brute, raid, wrecker (break 10), catcher,
      black flash, tap in (deploy to the Front), shockers. Completing one assigns the next.

## Endeavor: hideouts and raids
- [ ] Claim a site, open the bench (X). Bench model matches the tier (Tinkerer planks, Workshop steel, Foundry chrome).
- [ ] Build Vault, Walls, Bunks, Generator, Turret, Forge, Medbay: each shows its model; prompts still work on them.
- [ ] Walls are scrap panels with a hazard stripe and razor coil, the gate has a frame with a lamp; the gate panel
      still breaches by tier; vault can be stripped by a raider.
- [ ] Blackout Gate is a dark arch with red seams; the raid arena has ribbed concrete walls and red-banded pillars.
- [ ] Raid arena: waves spawn, rewards at the vault, extraction works.

## Endeavor → Front
- [ ] Neural Net terminal (X) plays the uplink sequence and teleports to the Front (needs the Roblox app or
      "Open from Roblox", not Studio Play).

## Front
- [ ] Deploy from the locker with a kit; spawn on solid ground, at your faction's base: a hollow concrete bunker
      with its door toward the front line, a flag in your faction's colour, and a locker terminal (X opens the app).
- [ ] Your rifle or pistol shows in your right hand (AKM, M16A1, SKS, M14, Mosin, Makarov, M1911); switching (1/2)
      swaps the model; other soldiers' guns are visible too. Note if the barrel points the wrong way or the gun floats.
- [ ] Soldiers hold their rifle with both hands (not arms hanging); each shot kicks the arms; reloading (R) drops the
      left hand to the magazine and brings it back.
- [ ] Sectors have farmhouse/hall buildings, sandbag nests, trucks, tank traps, ammo crates. No floating or sunken props.
- [ ] Explosives degrade buildings through four stages (intact → damaged → ruined → rubble).
- [ ] Shots crack nearby, roll in the distance; dry click on empty; rack (T) clicks; impacts puff dirt or blood.
- [ ] Dig (F) makes a foxhole with a thump; sandbags (V) stack a low wall with the mesh on it.
- [ ] Artillery (K): warning, then whistle about two seconds before the shells land.
- [ ] Wind with distant guns is audible as ambience.
- [ ] Hill moves, tickets tip the scales HUD, income only while deployed.
- [ ] Recruit death drops damaged gear that anyone can loot; conscript bodies give nothing.

## Known / expected
- Weapon grip angles and sound levels are first guesses: say what feels off.
- Collapsed building stumps may collide as solid hulls (MeshPart collision can't be set from scripts).
- Studio's Play button cannot teleport between places.
