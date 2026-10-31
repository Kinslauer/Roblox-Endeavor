# Playtest checklist

Grows as features land. Tick what works, note what doesn't (an F9 → Client/Server tab screenshot is the most useful
report). Versions: Endeavor v35, Front v18.

## Endeavor: first minutes
- [ ] The starting room is a pod: dark panelled walls with cyan seams, diamond-plate floor, the console in a terminal
      cabinet, the supply locker a crate.
- [ ] Spawn in the starting room on solid floor (no falling through, no black room). Returning players see
      "Welcome back, conduit" and the world opens at once.
- [ ] Tutorial steps advance as you do them (move, sprint with Shift, swing, block, dodge, flicker).
- [ ] F2 opens the dev panel (test build only): Heal, Mats, Die, Open world, Go to armory/gate/districts/terminals/
      hideout sites, Spawn each hostile, fire each event. Use it to reach anything on this list quickly.
- [ ] F1 shows the controls card. Tab inventory, L loadout, J attributes, O hideout, N recruit app all open and close.
- [ ] City hum and wind are audible from the start (ambient loops).
- [ ] The city reads as late night: purple haze, neon bloom, cold grade; you can still see where you're going.

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

## Endeavor: worn gear
- [ ] Wearing armor from Tab shows it on your body: helms on the head (Scav cap with goggles, Plated with a red slit,
      Arc hood with cyan lines), vests on the chest (Scrap plates, Riot plate with collar, Conduit harness with a glowing
      core), greaves on both thighs. Unequipping removes it. Other players' gear is visible too.
- [ ] Cybernetics show: optics on the face, Servo Arm / Arc Gauntlet on the left forearm, cores on the upper back.
- [ ] Nothing floats off the body or clips badly through the head; say which piece if one does.

## Endeavor: enemies and rigs
- [ ] The city has standing hostiles: Raider packs in the Transit Hub, mixed packs (Shockers, Brutes) in Corp Plaza and
      the Sprawl, tougher packs and sometimes a Warden in the Blackout Zone. They wander near where they spawned,
      chase on sight and come back a couple of minutes after dying.
- [ ] Mannequins on the magenta pads by the test armory: Raider, Brute, Shocker, Warden. Limbs in the right place
      (left arm on the character's left), idle animation playing, weapon in the right hand.
- [ ] Hostiles bark: a shout when they first spot you, another on each attack windup, a death cry. Raiders shout,
      Brutes roar low, Shockers crackle, the Warden sounds a horn.
- [ ] Live hostiles walk with moving legs, telegraph attacks, and die with gore (dismemberment, pools, corpse stays).
- [ ] Loot looks right: caches and supply drops are olive crates with a hazard stripe, vault caches dark with a cyan
      lock, remains/spoils/salvage a canvas stash bag; the prompt still works on each.
- [ ] Corpses can be looted; your own corpse after death cannot be looted by you for 60 s.

## Endeavor: destruction and salvage
- [ ] Props break (barrels, crates, signs, terminals, vending machines, window panes) with the right crunch
      (glass, wood, metal) and drop salvage chunks.
- [ ] Grab a chunk (G), charge and throw; a thrown chunk can be caught with G within 0.25 s of impact ("CAUGHT").
- [ ] Explosions (grenades, barrels) boom, push, and breach lockup doors by tier.
- [ ] Buildings come from the kits (five district styles, intact and collapsed variants); props show A/B/C wear.
- [ ] After a dematerialize cycle the world returns in a different condition.

## Endeavor: random events (every 1 to 2.5 minutes once the world is open)
- [ ] Landmarks are marked once the world opens: every Neural Net terminal (purple), the Blackout Gate (red) and the
      Test Armory (magenta), with distance. They stay; they come back after a respawn.
- [ ] Events put a marker in the world: a pulsing diamond with a label and distance in metres, visible through walls
      (supply drop yellow, Warden red, dead drop purple, your salvage cache green). It disappears when the event ends.
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
- [ ] Neural Net terminals are dark cabinets with a cyan pulse either side of the purple screen.
- [ ] Neural Net terminal (X) plays the uplink sequence and teleports to the Front (needs the Roblox app or
      "Open from Roblox", not Studio Play).

## Front
- [ ] Deploy from the locker with a kit; spawn on solid ground, at your faction's base: a hollow concrete bunker
      with its door toward the front line, a flag in your faction's colour, and a locker terminal (X opens the app).
- [ ] Your rifle or pistol shows in your right hand (AKM, M16A1, SKS, M14, Mosin, Makarov, M1911); switching (1/2)
      swaps the model; other soldiers' guns are visible too. Note if the barrel points the wrong way or the gun floats.
- [ ] Flak vest / steel plate carrier show on the torso and the steel helmet on the head of anyone wearing them.
- [ ] Soldiers hold their rifle with both hands (not arms hanging); each shot kicks the arms; reloading (R) drops the
      left hand to the magazine and brings it back.
- [ ] Sectors have farmhouse/hall buildings, sandbag nests, trucks, tank traps, ammo crates. No floating or sunken props.
- [ ] Explosives degrade buildings through four stages (intact → damaged → ruined → rubble).
- [ ] Shots crack nearby, roll in the distance; dry click on empty; rack (T) clicks; impacts puff dirt or blood.
- [ ] Dig (F) makes a foxhole with a thump; sandbags (V) stack a low wall with the mesh on it.
- [ ] Artillery (K): warning, then whistle about two seconds before the shells land.
- [ ] Wind with distant guns is audible as ambience.
- [ ] The hill is marked by a column of yellow light from ground to sky with the beacon on top; it moves with the hill.
- [ ] Hill moves, tickets tip the scales HUD, income only while deployed.
- [ ] Kills show in a feed at the top right (last five, fading after 7 s); your own death still banners.
- [ ] Recruit death drops damaged gear that anyone can loot; conscript bodies give nothing.

## Known / expected
- Weapon grip angles and sound levels are first guesses: say what feels off.
- Collapsed building stumps may collide as solid hulls (MeshPart collision can't be set from scripts).
- Studio's Play button cannot teleport between places.
