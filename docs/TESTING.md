# Playtest checklist

Grows as features land. Tick what works, note what doesn't (an F9 → Client/Server tab screenshot is the most useful
report). Versions: Endeavor v69, Front v19.

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

## Endeavor: your body, swings and the look of the screens
- [ ] You spawn as the Conduit, rebuilt rounder (v2): hooded head with a wraparound visor band and a small respirator,
      long coat with a split skirt that moves with your hips, chest plate, layered shoulder plates, gloves with
      knuckle plates, knee guards and armoured boots. Not your Roblox avatar. It idles, walks, runs, jumps, falls and
      climbs; the coat and plates stay on the right limbs (shoulder plates on the arms, knee guards on the shins).
- [ ] Each life rolls its own jacket colour (gunmetal, olive, oxblood, navy, bone, black) and trim colour (cyan,
      magenta, amber, acid, red, white) on the seams, armband, stack port and visor. Dying gives you a new combination.
- [ ] Your own swings move your arms: windup and slash per weapon family, a block pose on F, a flinch when hit, and the
      lean into movement. Other players see them too.
- [ ] Worn armor, cybernetic implants and the weapon in your right hand sit on the new body correctly.
- [ ] Every panel (Tab inventory, L loadout, J attributes, O hideout, N recruit app, the computer, the market, F2 dev):
      rounded dark glass with a thin cyan edge, a wide sci-fi title face for section headers with a line under them,
      text that wraps instead of being cut off, uppercase buttons that brighten on hover.
- [ ] The HUD bars are rounded with a subtle shade; banners use the title face with an outline.
- [ ] Front: soldiers still hold the rifle in both hands, kick on shots and reach for the magazine on reload.

## Endeavor: movement (ported from Roblox's Platformer template)
- [ ] The body has weight: starting, stopping and turning ease in over a fraction of a second; jumps feel a little
      floatier (gravity 160, jump height 8) and the body leans into turns and runs.
- [ ] Space on the ground jumps, and still works for a moment after walking off a ledge. Space again in the air is a
      double jump (once per airtime, with a flip animation).
- [ ] Q on the ground is a roll in your move direction (backward with no input) that slows over its length; Q in the
      air is a short dash that holds your height, once per airtime. Both still cost stamina, give the dodge i-frames,
      and Enemy Step off a juggled enemy still hops you up (and gives the air dash and double jump back).
- [ ] Space right after a roll starts is a long jump; flying into a wall during it knocks you back and down for a beat.
- [ ] Landing refills the double jump and the dash. No stamina, no roll.
- [ ] In light gear (every worn piece Light, not overweight) Q works as above in every direction.
- [ ] Wearing any Medium or Heavy piece: Q toward where you face still rolls, but Q to the sides or back is a short,
      heavy step with its own animation (sinks, pushes off one leg, guard up) that loses speed quickly. More armour
      (Riot Plate + Plated Helm + Plated Greaves) makes it noticeably shorter and slower than one Medium piece, and it
      gives fewer i-frames (easier to get hit through it). No air dash at all while armoured.

## Endeavor: the body's own animations (keyframed in code, tools/anims)
- [ ] Standing still is a fighting stance (knees soft, left foot forward, guard hand up) with slow breathing, not
      Roblox's default idle. Walking and sprinting use the new walk/run cycle (arms pumping opposite the legs at a
      run); feet should not skate badly at walk or sprint speed.
- [ ] Every swing moves the whole body, not just the arm: it coils (torso turns away, weight on the back leg), then
      uncoils onto the front foot through the strike and holds the follow-through a moment. Overheads rise then drop
      the weight; thrusts lunge; uppercuts sink then drive up; jabs are short. The right arm still follows the
      weapon's actual arc. Light and heavy attacks keep their timing.
- [ ] Getting hit: the body reacts to where it was struck (right side folds left, left side folds right, a high hit
      snaps the head back, otherwise a recoil backwards). A guard break is a longer stumble with the arms out.
- [ ] Blocking (F) is a raised guard with a slight breathing sway; a parry or blocked hit jolts it. A clash or a
      wall glance throws you back into a short recoil.
- [ ] Enemies use the same swing and hit animations. Other players see your swings, hits and guard too.
- [ ] (v2 reactions) Hits read clearly: the body rocks back and steps to catch itself, held for as long as the
      hit-stun lasts (a baton's stun shows longer than a jab's). A heavy hit (20+ damage) throws the body back with two
      stumbling steps.
- [ ] The guard (F) with a weapon: the weapon is held across the front of the body and the other hand braces it. When
      an enemy winds up or swings, the guard turns toward that blade: across the head for a high blow, upright on the
      side it comes from. A parry sweeps the blade out and away; a blocked hit shoves the guard back into the chest.
      With fists: both forearms up in front of the face. Releasing F drops the arms.
- [ ] The Arc Pistol is aimed, not swung: shooting no longer winds the arm up and out to the right.
- [ ] Weapon tooltips (Tab, hover a weapon) show frame data: "light 7f startup 8f active 14f recovery" and the heavy.
- [ ] Light attacks have a little more recovery than before (a whiffed swing can be punished); pressing the next
      attack or heavy early still queues it.

## Endeavor: launchers and juggles
- [ ] A heavy on a staggered hostile launches it. It rises, then floats down slowly enough to land two more hits.
- [ ] Pipe Club (Medium) or Sledge (Heavy): the launcher throws up every hostile around the impact (about 6 / 10
      studs), not just the one struck. Blades, batons, spears and fists launch only their target.
- [ ] Q next to a floating enemy (Enemy Step) springs you up to its height, just in front of it, facing it, and
      holds you there briefly; it stays up a little longer too, so you can keep hitting it.
- [ ] Enemy mannequins (F2, Armory): arms hang at their sides and swing outward, not into the body; the weapon is in
      the right hand.

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
- [ ] Dodge (Q) has i-frames (longer when you dodge sideways); feint (Z) cancels a swing; sprint (Shift) drains stamina.
- [ ] Launcher: light, light, then heavy on a Raider sends it up ("LAUNCHED", a yellow streak); hits while it is
      airborne pop it back up ("AIR x2...") and hurt more; it lands stunned. A Brute cannot be launched mid-swing
      (hyperarmor); players are never launched. Does the rhythm read? Too floaty or too short?
- [ ] Enemy Step: dodge (Q) next to a launched hostile hops you up and refunds stamina ("ENEMY STEP").
- [ ] A hostile staggered during its wind-up loses that strike (the red glow ends with no hit).
- [ ] Equipping a weapon from Tab puts its model in your right hand; fists show nothing. Check each: pipe club,
      rebar blade, shock baton, scrap spear, sledge, arc pistol. Note any that point the wrong way or float.

### Traced blades (Mordhau-style swings)
- [ ] A swing only hurts where the weapon actually passes: stepping back out of the arc, or ducking under a high slash
      with a dodge, makes it miss. The body flinches away from the point the weapon touched (a hit on the right
      shoulder turns it left; a high hit snaps the head back), not straight back.
- [ ] A hit bites: the swing freezes for a split second at the contact, sparks fly from the contact point.
- [ ] Enemies' swings work the same way on you: their weapon arm follows a visible arc and you are pushed from where it
      landed.
- [ ] Two weapons meeting mid-air (you and an enemy swinging at each other at range) clang, spark, and both swings
      stop with a short recovery; neither lands. "CLASH" shows.
- [ ] Swinging into a wall stops the blade with a glance (sparks, short recovery). Swinging through a streetlight,
      crate or breach point still breaks it.
- [ ] Each weapon family swings its own arcs: blades right-left-right-diagonal, blunt/batons right-left-overhead,
      hammers right-overhead, spears thrust-thrust-slash-thrust, fists jabs then an uppercut. Heavies use the big arc.
- [ ] Blocking needs the guard in the way (F): an enemy's blow from the front or either side (up to about 100 degrees
      round) stops on your guard with a clang and the enemy's swing ends there. A blow from behind lands even with F
      held. With two enemies swinging at once, the guard turns to one and the other's blow gets round it. A parry
      (F pressed just before the blow) only works if the guard meets the blade too. Fists cover with the forearms.
      Say if a blow you could see coming went through a guard that looked like it was in the way.

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

## Endeavor: cybernetics (the whole body)
- [ ] Tab: a cybernetic in your pack has no Wear button in the field; the tooltip/row says it is ripped in at an Autonet.
- [ ] Hideout (O): build the Autonet module (6 sheet metal, 10 wire, 3 battery, 2 glass); a red-lit table appears.
      The arena has one beside the Cybernetics Bay (which now hands out two of each arm and leg piece).
- [ ] X on the table: "On the Autonet"; Tab now shows Rip in / Rip out on cybernetics. Arm and leg pieces show
      Rip in L and Rip in R. Walking away from the table (about 12 studs) takes the buttons away.
- [ ] Rip one in: a third of your max health goes at once, you are held in place about 4 s with the screen whiting
      at the edges and the camera shaking, "RIPPING" over you, then it is in. A swap costs and takes twice as much.
      Getting hurt during a rip cancels it (the cost stays). Fighting (recent combat) refuses the table.
- [ ] L loadout: eight slots (Eyes, Ears, Nose, Core, Left/Right arm, Left/Right leg), each "flesh" until filled,
      and "Body: N% metal". Two Servo Arms need two in the pack; the row says "in you (left arm, right arm)".
- [ ] Implants show on the body for everyone, using the generated implant meshes (a Servo Arm's upper arm,
      forearm and hand replace the flesh; optics, ear pods, nose pieces and cores sit on the head and chest).
      If a mesh fails to load, that piece falls back to a plain metal shell with a lit seam. Say which look wrong.
- [ ] Audio Pickup (ears): a moving raider behind you or behind a wall puts a pip on the ring around the screen
      centre pointing at it; it goes quiet when the raider stands still or you can see it.
- [ ] Chem Sniffer (nose): loot containers within ~45 studs get a green dot through walls. Blood Tracer: hurt a
      raider below half health and it gets a red dot too.
- [ ] Strider legs: faster walk. Piston legs: noticeably higher jump. Two Servo Arms: the heaviest debris lifts
      without the Strength requirement.
- [ ] Fill all eight slots: "Body: 100% metal", a lore line, and chat comes out flat and capitalised ("lol I'm sooooo
      done!!" becomes "I AM SO DONE.") in grey-blue with a terminal-style bubble. Rip one out: the voice returns.
- [ ] Old characters: an Optic implant is now in Eyes, an Arm implant in the Right arm.

## Endeavor: enemy spacing (ideas from KrugKrew's sword-fighting AI)
- [ ] Raiders, Shockers and Rival conduits read your swing: as you wind up, some of the time they slip sideways out of
      your reach after a short reaction (Rivals most often and fastest, Raiders least). A feint baits that step back.
- [ ] Your recovery after a swing (or a stagger) is their opening: they come straight in.
- [ ] While their own attack is on cooldown they circle you, facing you, instead of standing still, and switch
      direction now and then. A wall in the way makes them circle the other way.
- [ ] Hold a guard and they sometimes circle it for a moment instead of swinging into it.
- [ ] Charge a Shocker or a Rival and it gives ground with a sidestep.
- [ ] Badly wounded (under about a third of their health), they keep outside your reach and only come in on an opening.
- [ ] Brutes and Wardens don't back off at all: they walk through your swings (hyperarmor).
- [ ] Packs still take turns: only one swings at you at a time.

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
- [ ] Nothing is drawn through walls: no floating diamonds or distances. Walking up to a marked place (a Neural Net
      terminal, the Blackout Gate, a supply drop, a Warden, a dead drop, your salvage cache, the next route stop, a
      site) shows its name in the banner at the top of the screen for about 4 s.
- [ ] A place's banner (marked places, districts, frontier regions, sites) shows once, then not again for 5 minutes
      even if you walk out and back in; another place's name still shows.
- [ ] Nameplates only show within about 70 studs and not through walls.
- [ ] Supply drop: announced, a glowing crate lands; opening takes 3 s.
- [ ] Raider ambush: "Raiders have found you", 2 to 4 hostiles close in.
- [ ] Blackout: the city goes dark for a minute or two (neon stays), Shockers spawn; light returns afterwards.
- [ ] Warden patrol: announced by district; a Warden walks there and drops Supply loot.
- [ ] Salvage cache: intact props appear near you to break for salvage.
- [ ] Dead drop: a purple stash at a numbered hideout site, announced to everyone.
- [ ] Quests cycle through: scrap run, raiders, medkit, bounty, survey, brute, raid, wrecker (break 10), catcher,
      black flash, tap in (deploy to the Front), shockers. Completing one assigns the next.

## Endeavor: the Crossroads (the city's heart)
- [ ] The centre of the city is no longer the test arena: it is the Crossroads, where the four districts meet. A ring
      road, a 46-stud obelisk with a yellow seam lit from below, a collapsed interchange (one span up on pillars, one
      fallen at an angle, a stub), wrecks and rubble, two caches under the span, two spawn pads, and a standing pack.
- [ ] Walking into it banners "The Crossroads - danger: Medium"; it counts for the Survey quest.
- [ ] The Pit and the Test Armory still exist, 3000 studs east off the map on their own slab; F2 "Go to: Armory" gets
      there and back ("Go" on any district). Nobody spawns there any more.

## Endeavor: the megacity (the industrial ring, green pockets, smog)
- [ ] Walk out of the core city east, west or south: the ground goes on into seven new districts, each with its own
      banner as you cross in (map: docs/maps/world_map_megacity.png). Roads run along the core's sides and the
      south artery, with streetlights and wrecks.
- [ ] The Stacks (west, north half): smokestacks pouring dark smoke, tank farms with ladders you can climb, flare stacks
      burning, pipe racks with a walkway on top, one giant stack by the plaza with a red light on top.
- [ ] Slag Flats (west, south half): glowing green pools. Standing in one hurts and tints the screen green; stepping
      out clears it. Slag heaps, dead cranes, conveyors, a tipped giant ladle glowing orange by the plaza.
- [ ] Pylon Fields (east, north half): power lines on lattice pylons, fenced transformer yards (one sparks), cooling
      towers steaming, a blue coil spire by the plaza. Mostly Shockers here.
- [ ] The Hab Blocks (east, south half): huge apartment blocks on stilts with neon floors and signs; market stalls in
      the shade under them; low terrace blocks with a ladder up and skybridges between their roofs; a very tall
      spire block with a pink crown.
- [ ] Scrap Sea (south-west): junk mountains you can climb, walls of crushed cubes, magnet cranes with a car hanging.
- [ ] The Foundry (south): furnace halls you can walk through (molten channel down the middle, a catwalk with a
      ladder), blast furnaces with a glowing taphole, ore piles and rails; the mother furnace by the plaza. Brutes.
- [ ] The Sumps (south-east): islands between sunken canals of sludge, bridges between them. Fall in and it burns;
      a ramp in each stretch lets you climb out. Stilt shacks, pump houses, outfall pipes, a water tower by the plaza.
- [ ] Each new district has a Neural Net terminal by its plaza, caches that refill, a locked building with a breach
      door (the Foundry also a red Sealed one), and its own pack of hostiles.
- [ ] The edge: a wall of dark megablocks with lit windows closes the map. Past it the skyline goes on into the smog:
      huge dark towers and a few chimneys smoking far away. You cannot reach or touch them.
- [ ] The air: thicker, browner smog in the Stacks, Foundry and Scrap Sea; green-tinged over the Slag Flats and the
      Sumps; ash drifting in the air there; grey ash north of the wall. It blends, with no text.
- [ ] Green pockets (no banner text explains them): The Last Garden (a broken glass dome full of trees, flowers and
      a pond, between the Foundry and the Sumps), The Rootwork (one huge old tree in a ruined courtyard, glowing
      caps in its roots, between Scrap Sea and the Foundry), Fernwell (a spring with ferns and a shaft of light,
      inside the Hab Blocks). Inside one the air clears, pollen and fireflies drift, and after about 8 seconds
      without being hurt your health slowly comes back. No hostiles settle there (they can still follow you in).
- [ ] North of the wall the valley is mostly dead now: grey ground, dead trees, rusted tanks and toppled pylons;
      only rare glades and the meadows around Verdant Reach are still green.
- [ ] Performance: walk the whole ring and say if any district drops your frame rate.

## Endeavor: north of the wall (the frontier)
Maps: `docs/maps/world_map_seed7919.png` and `world_map_seed23757.png` (two rolls). The valley is a 9x8 grid of
200-stud chunks dealt by a seed each server: the Reach, the sites, the hairpins, the trail and the checkpoints all
move; the city and the scarp overlook stay put. The server's seed is printed in the F9 log ("[Frontier] seed ...").
- [ ] Two servers (or a server restart) give a different valley: the Reach somewhere else, sites in other cells.
- [ ] The route north is marked by place, not beacon: walking up to the next stop ("Route north 1/N: Rail Yard")
      banners its name; standing at it banners "Checkpoint 1/N" and the next stop takes over to the next one (Sprawl Market, Canal Bridge, Blackout Toll,
      North Gate, Scarp Overlook, Second Hairpin, Scarp Foot, then rolled valley stops such as Valley Ford, Fallen
      Bridge, Dead Crossing, Burnt Clearing, Stone Steps, then Reach Gate, Verdant Reach). It is never a straight line.
- [ ] Chunks read as places: forest (dense trees), glade (open middle, fallen logs, flowers), boulders (rock field on
      bumpy ground), ruin (two collapsed Sprawl buildings and a yard of breakable props), marsh (a pond in a hollow,
      dead trees), crater (a bowl ringed by scorched rocks with "Blast Remains" loot in the middle), meadow (flowers
      around the Reach). The border cells are the peaks.
- [ ] Each checkpoint has a numbered sign on a post with an orange light, a barricade of breakable props facing the
      way you come, and a pack behind it that gets nastier north of the Blackout Zone (Brutes, Shockers, scaled).
- [ ] The North Gate (x 120, past the Blackout Zone) leads to the Scarp Overlook: a railed deck and a "CITY LIMITS -
      VERDANT REACH 1.2 km" sign, with a view down over the valley. A boss Warden named Gatekeeper holds it.
- [ ] Banners: "The Scarp - danger: High" past the wall, "The Valley", "The Ridge - danger: Severe" in the mountains,
      "Verdant Reach - safe haven" inside the hedge.
- [ ] The switchback road zigzags down the cliff face: asphalt with a faded centre line, hazard lamps (half dead),
      wrecks on the verge, dead trees and boulders between the hairpins. The ground under it is flattened to the road.
      An ambush pack waits at the second hairpin, another at the foot.
- [ ] The valley is forest (trees you can walk between, rocks on the slopes) on smooth terrain; a dirt trail winds from
      the scarp foot to the Reach's south gate with Shockers at the ford and a pack at the gate.
- [ ] Verdant Reach: hedge ring with a gate where the trail arrives and one opposite, sand paths (cross + ring), glass greenhouse domes with pink
      grow light, solar towers, planter beds, trees, warm lamps. The green ring at the centre is the market.
- [ ] Inside the green ring nobody can hurt you and you cannot hit anyone (PvP and hostiles both). Leaving it, you can.
- [ ] Trader counter (X "Browse wares") opens the Verdant Market panel: prices in war credits (the Front's pay). Buying
      with too few credits warns; with enough it takes the credits and the item lands in the pack (overflow drops).
      Stock: Medkit, Ration, Arc Cells x5, Pipe Grenade, Breaching Charge, Rucksack, Frame Pack, Arc Pistol, Plated
      Helm, Servo Greaves, Reflex Optic, Audio Pickup.
- [ ] Reaching the Reach completes the "Northbound" quest when it is active.
- [ ] Ring sites, found by walking within 150 studs (banner; remembered even after permadeath): Ridge Watch
      and Logging Camp (encampments: tents, campfire, fence barricade, a stockpile crate), Hunter's Shack and Pump
      Station (concrete huts with a store crate), Signal Mast (70-stud mast with a red beacon on the mountain, relay
      vault), Crashed Dropship (hull, broken wing, fire, cargo + pilot's locker, a boss Warden "Pilot"), Old Mine
      (timbered tunnel into the mountain with lamps, vault at the end + a miner's cache).
- [ ] Relic sites' containers hold cybernetics, armor and weapons the city rarely drops (and one guaranteed: Echo Array,
      Conduit Harness, Overclock Core); emptied containers refill after 10 minutes.
- [ ] Site guards return to their posts 4 minutes after dying.
- [ ] Chunk encounters (most valley cells roll one; F9 log line "[Frontier] encounters rolled"): an **ambush** springs
      with an "Ambush!" banner when you walk into its cell, hostiles closing from behind and beside you, and does not
      spring again for 5 minutes; a **patrol** (2 to 3 bodies) walks a loop through its cell and the neighbours and only
      stands up once you are within 420 studs; a **nest** is three Shockers around a "Shocker Nest" stash; a **bounty**
      is a named, oversized Brute (Hollowjaw, The Culler, Ten-Ton Vey, Rebar Saint, Mother Gravel) that drops a
      "<name>'s Hoard" crate of relic-table loot and is announced to everyone when it falls.
- [ ] Encounters nobody is near for 90 s stand down (their bodies vanish) and wake again when someone returns.
- [ ] Dev panel (F2): "North" row (Scarp, Hairpin, Reach) and "Sites" row (Ridge, Mast, Mine, Ship) teleports.
- [ ] Nothing falls through the terrain: walk the switchbacks, the trail and a mountain slope.
- [ ] The valley is dressed with real models: low-poly pines and broadleaf trees of varied size, bare dead trees on
      the scarp and in marshes, faceted rocks, canvas ridge tents at the camps, glass geodesic domes with white ribs
      and a door in the Reach, solar towers with a tilted blue panel. Trees stand on the ground, not in it or above it.

## Endeavor: the hideout computer (contacts, contracts, rival crews)
- [ ] Three contacts stand in the world with a Talk prompt (X) and cannot be hurt: the Broker by the trader in the
      Verdant Market, the Fixer under the Crossroads span, the Dealer on the Scarp Overlook deck (the Gatekeeper's
      ground). Talking banners their line; the first time also "RAIDS/HOUSE/MARKET unlocked on your hideout computer".
- [ ] Hideout module "Computer" (4 Battery, 12 Wire, 3 Glass, 4 Sheet Metal): a terminal shell with a green screen in
      the compound; "Log in" (X, members only) opens the computer panel; locked apps read "locked: find the Broker".
- [ ] RAIDS: a contract per frontier site ("Clear Ridge Watch (Encampment)", needs every guard there), one per named
      bounty, and the Blackout raid; Accept (two held at most), Drop. Kills at the site count ("Clear ...: 3/5");
      the last one pays credits + items with a banner, and everyone sees "<you> completed a contract".
- [ ] HOUSE: material lots (scrap, sheet, wire, cells, powder, glass, cloth) delivered to the pack for credits.
- [ ] MARKET: cybernetics, riot plate, a sledge and breaching charges at black-market prices.
- [ ] Rival conduit crews (2 crews of 3, purple-grey raider rigs named Rival, rebar blades) walk between the frontier's
      sites and fight whoever they meet. Killing one drops rival loot and may put "Rival intel: <contract>" on your board
      even without RAIDS.
- [ ] The first log-in reads "> INIT 1/1 . . . STACK READ . . . RESIDENT" and the panel's second line "> STACK: RESIDENT".
      Nothing explains what that means.
- [ ] Before the upload, dying wipes what the computer knew (contacts met die with the body) and the death screen ends
      "> NO STACK . . . NO RECOVERY". After it, "> STACK RESIDENT . . . REBOOTING" and contacts, contracts and the archive
      survive. Tapping in to the Front shows "> LINK: RECRUIT STACK . . . OK". Meeting a contact: "> RAIDS: ONLINE".

## Endeavor: the cycle and the clues
- [ ] Every hour (10 minutes while Dev is on), with no countdown text: debris flickers for a minute, colour drains
      over the last 5 s, then a second of white: broken props, breaches and structures are back, loose remains and
      dropped gear nobody looted are gone, woken valley encounters are gone. Nothing announces it. You stay
      where you stand with what you carry; the hideout is untouched. F2 "Cycle: Run now" does it on demand.
- [ ] After a cycle the contacts have moved: the Broker to one of three spots in the Reach (by the trader, inside the
      gate, by a dome), the Fixer (under the span, Transit Hub plaza, Sprawl plaza), the Dealer (overlook deck, second
      hairpin, scarp foot). Their Talk line changes with the cycle; a few lines slip.
- [ ] Fragments lie at anomalies: a glitching cube, a flickering silhouette, a sign that reads wrong (they stutter
      in and out). "Read" (X) shows the text on screen for 12 s and files it in the ARCHIVE app on the computer.
      Hour Zero and Lamp Count every cycle; the Ledger, the Gatekeeper and the Dispatch on even cycles; Seed Packet
      and Uplink every third; The Door every fourth. A fragment whose prerequisites you have not read is invisible to
      you and "means nothing to you. Not yet." A nose implant scents fragments.
- [ ] The archive survives permadeath and lists fragments in the order read.

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
- [ ] Deploy from the locker with a kit; spawn on solid ground. Your faction's base (in the rear): a hollow concrete bunker
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

### Front open world (2026-11-10; map of one roll: docs/maps/front_world_map.png)
- [ ] The Front is a big terrain world now (about 2,000 x 1,200 studs inside the walls): 7 x 5 sectors of 200 studs
      between two rears, rolled fresh each server (F9 Server log: "[Front] world seed ...").
- [ ] Every sector has a crest: a pale mound of calcified clone bodies (helmets, reaching arms, rifles sticking out).
      The hill's yellow light column stands on the crest of the hot sector.
- [ ] The Spine: a long pale ridge of the dead runs north-south down the middle column, with low saddles to cross at.
      Shorter broken ridges stand between the other columns.
- [ ] Both outer columns are each faction's line: one long zigzag trench down the whole map, wire in front of it, a
      field gun behind it. Trench sectors in the middle have two trench lines either side of their crest.
- [ ] A sunken canal with brown standing water crosses west-east; three fords let you wade across.
- [ ] The old highway (dark asphalt) runs from base to base. Village sectors have 5-7 buildings, Works sectors have
      halls, ruined brick chimneys and a leaning pylon, Deadwood is a forest of dead trees and stumps, Craters is
      churned mud with flooded shell holes.
- [ ] Somewhere in the middle columns one sector is still green: grass and a living tree on its crest.
- [ ] The map ends in tall pale cliffs (the outer barrows); you cannot walk past them. Far beyond them, giant
      smokestacks smoke on the skyline.
- [ ] You deploy from a sandbagged dugout one sector behind the hill on your side (Union west, Pact east), facing the
      fight; when the hill is on your own line you deploy at the base.
- [ ] A recruit's body turns into a pale calcified figure where it fell about 45 s after death. Every 4 deaths in a
      sector the crest grows: dust breathes off it and the ground groans.
- [ ] Ash falls around you; guns flash on the horizon now and then, sometimes with a far boom. The light is a brown,
      drained overcast.
- [ ] Foxholes (F) dig into the terrain wherever you stand; sandbags (V) sit on the ground on slopes too.
- [ ] Frame rate with many players stays playable (report your FPS with Shift+F5 if it drops).

## Known / expected
- Weapon grip angles and sound levels are first guesses: say what feels off.
- Collapsed building stumps may collide as solid hulls (MeshPart collision can't be set from scripts).
- Studio's Play button cannot teleport between places.
