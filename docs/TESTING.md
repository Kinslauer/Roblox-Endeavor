# Playtest checklist

Grows as features land. Tick what works, note what doesn't (an F9 → Client/Server tab screenshot is the most useful
report). Versions: Endeavor v47, Front v19.

## Endeavor: first minutes
- [ ] The starting room is a pod: dark panelled walls with cyan seams, diamond-plate floor, the console in a terminal
      cabinet, the supply locker a crate.
- [ ] Spawn in the starting room on solid floor (no falling through, no black room). Returning players see
      "Welcome back, conduit" and the world opens at once.
- [ ] Tutorial steps advance as you do them (move, sprint with Shift, swing, block, dodge, flicker). The locker step
      completes once the locker's grid is emptied.
- [ ] F2 opens the dev panel (test build only): Heal, Mats, Die, Open world, Go to armory/gate/districts/terminals/
      hideout sites, Spawn each hostile, fire each event. Use it to reach anything on this list quickly.
- [ ] HUD v2: one composite at the bottom centre - a thin charge strip, HEALTH | STAMINA with numbers, a thin posture
      strip, the R/Y/V skill slots under it; level and FLICKER text above it. The Roblox health bar and player list
      are gone. Anything you miss from the old top-left stack?
- [ ] A small reticle sits at the screen centre while the stance is on; it flares orange when your hit lands.
- [ ] Taking damage: a red "-N" floats off you and the screen edges flash red (stronger for bigger hits). Over
      whoever is hit the words BLOCKED / PARRIED / GUARD BREAK / DODGED float up.
- [ ] Nameplates: no Roblox name or health bar over anyone; a small plate at hip height, lower-left (white for
      players, red for hostiles), fading out past about 30 studs. Do bodies read first?
- [ ] F1 shows the controls card. Tab inventory, L loadout, J attributes, O hideout, N recruit app all open and close.
- [ ] City hum and wind are audible from the start (ambient loops).
- [ ] The city reads as late night: purple haze, neon bloom, cold grade; you can still see where you're going.

## Endeavor: combat
- [ ] Combat stance (on by default): the body turns to where the camera looks even standing still, the camera sits
      over the right shoulder (far and high with a melee weapon, closer with the arc pistol) and the mouse is locked.
      LeftControl toggles the classic camera; with a panel open LeftControl closes the panels instead. Hold LeftAlt to
      free the mouse without leaving the stance; any panel (Tab, O, J, L, N, F2) frees it on its own.
- [ ] Swings and arc pistol bolts go where the reticle/centre of the screen points.
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
- [ ] Input queue: click light, light, then heavy at a natural pace; no press is dropped, the heavy plays as soon as
      the second light ends. A dodge, a block or getting staggered cancels a queued press.
- [ ] Impact feel: hits spark orange and punch the FOV for a frame, heavies shake harder; blocks spark blue; a parry
      throws a white ring and freezes the frame; a guard break scatters orange shards; a dodge leaves a cyan
      after-image; explosions shake by distance. Too much or too little? (Config.Impacts)
- [ ] Hitting a dummy or hostile thuds and flashes it red; parry (F just before impact) clangs and flashes white.
- [ ] Guard break (blocking too long) plays the deep crack; posture bar empties.
- [ ] Flicker (E just before your hit lands) ticks; three chained = BLACK FLASH banner, red shockwave, boom.
- [ ] Dodge (Q) has i-frames; feint (Z) cancels a swing; sprint (Shift) drains stamina.
- [ ] Equipping a weapon from Tab puts its model in your right hand; fists show nothing. Check each: pipe club,
      rebar blade, shock baton, scrap spear, sledge, arc pistol. Note any that point the wrong way or float.

## Endeavor: inventory (Tab)
- [ ] Tab shows a grid (pockets 6x4 without a pack). Items are coloured blocks sized by footprint: materials 1x1 stacking
      to 20, a pipe club 1x3, a sledge 2x4, vests 3x3, sheet metal 2x1, a satchel 2x2. Stacks show their count, gear its
      condition %. Worn/held items have a green bar.
- [ ] Blocks show the item as a small 3D model (scrap pile, wire coil, medkit, the actual weapon or armor piece);
      stacks of 2+ show two copies, 10+ three. Icons may take a few seconds after joining to appear.
- [ ] Drag a block to move it; press R while dragging to rotate; drop onto a same-item stack to merge; a drop that
      overlaps or leaves the grid snaps back. Dropping outside the grid drops the stack at your feet ("Dropped gear").
- [ ] Hovering a block shows a tooltip: name, count, footprint, weight each, condition, and a pack's grid and carry.
- [ ] While dragging, the cells under the ghost tint green where the stack would fit and red where it would not
      (overlap, outside the grid, or an illegal move such as container to vault).
- [ ] Click a block for actions (Use / Equip / Wear / Drop / Drop 1) and its size and weight.
- [ ] Looting is a search: X on a crate, stash, corpse or salvage opens its own grid beside your pack. Drag items into
      your pack, double-click to quick-move, or Take all. The container closes and vanishes when empty; what does not
      fit stays in it ("No room in your pack for the rest"). You must stay within reach to take.
- [ ] Searching takes time: blocks start as dark "?" shapes and reveal one by one (big items slower, about half a
      second each plus a bit per cell); walking away stops the search where it was and reopening resumes it. The
      header shows "searching n/m", then the container's total weight once everything is found. Hidden items
      cannot be taken, by drag or Take all.
- [ ] Crafting into a full grid drops the result at your feet.
- [ ] Double-click moves a stack between your pack and the vault when the hideout panel is open.
- [ ] Craft a Satchel (4 cloth, 1 scrap), click it, Wear: the grid becomes 7x5 and the satchel leaves the grid. Rucksack
      9x6 and Frame Pack 11x7 likewise. "Take off" shrinks the grid; anything that no longer fits spills at your feet.
- [ ] Sort (Tab header) repacks the grid biggest-first without losing anything.
- [ ] At the bench (O) the worn pack has a +1/+2/+3 row: each upgrade adds a row to the grid and 5 carry
      (+1: 4 cloth 4 scrap; +2 needs a Forge like other gear).
- [ ] Weight shows as "Weight x / carry"; over the carry limit (15 pockets, 25/40/60 packs) you walk at 60% speed and
      stamina costs more; the row turns red and says OVERWEIGHT.
- [ ] Hideout vault (O) is a grid too: 6x4 at Tinkerer, 8x6 Workshop, 10x8 Foundry. Drag a stack from your pack onto
      the vault grid to store it, from the vault onto your pack to take it, within the vault to rearrange (R rotates).
      The server places stored items; a full vault refuses and says so.
- [ ] Build Shelving (20 scrap, 6 sheet metal) up to three times; each level adds two rows to the vault grid.

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
- [ ] Groups take turns: with three raiders on you only one winds up at a time; the others hold a ring a few studs
      out, circling and spreading apart, and step in when it is their turn. Can you fight a pack now?
- [ ] Hostiles path around walls and props instead of pushing into them, jump when stuck, and walk back to their
      post if you lead them too far (about 110 studs).
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
