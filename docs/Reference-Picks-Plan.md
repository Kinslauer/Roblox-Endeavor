# Reference picks: the build plan

Andy ticked all 56 rows of the pick page (https://claude.ai/artifact/3TmKX47RimLRJ6f1oE671V, saved 2026-11-12
18:47 to the page's db doc `picks/andy`). The rows came from Cursed Gear, Devil May Cry, Metal Gear and Escape from
Tarkov. They are ideas only: our own names, code and art. This file turns the picks into rounds. Each round is one
commit, the smoke tests, a real-server start check, a publish, and lines in docs/TESTING.md.

## Andy's notes on the rows (his words, 2026-11-12)

- Two weapons, swap mid-combo: "The weapons they equip should animate onto the character's rig, with specific
  points for each weapon. The kit should revolve around having body armor or plate carrier, or tactical vest and a
  belt for attaching a sidearm, or meds or other gear."
- Style grade: "This should be there, but not visible in the same way, just a combo count in the corner instead."
- Spend an arm for one huge blow: "A specific embeddable cybernetic intended for this as an attack."
- Earnings at risk until banked: "You must extract to keep what you find."
- Guards who radio in: "You can disable the radios on soldiers themselves with a whisper emp round that discharges
  if it hits the target, no immediate alert if it hits a plate, and aggro if it hits flesh as they feel the impact.
  These rounds are loaded lighter to prevent that but they still feel it on flesh."
- Pain, tremors and concussion: "Hits against armor bruise and inflict pain until it breaks."
- A small pouch that survives death: "data uploaded from the stack upon death is kept in an inventory slot, it only
  accepts data and valuable chips or information. Never materials."
- A free run as someone else: "Conduits can develop a humanoid drone, they can send this out on a raid in its stead.
  Only difference is these bots have less health, so they REQUIRE armor and are far less skilled in melee, they
  thrive in ranged combat as they have 120t weights and use 80b for combat." (The last clause is unclear: asked.)
- Party: "Correct." (names up close only, no markers through walls)
- Party runs: "Brainstorm 5 original tasks" (below).
- Player market: "Yes only items you found in raid."
- Day, night and weather: "Every hour the time of day swaps, sometimes it is a natural progression, dawn midday
  night, but it can go in any order."
- Take guards home: "You use the brain slave tech to trap an enemy and enslave them for your needs. They can be
  released and will remember, or they can be reprogrammed and sent to the front to fight for you, or break free and
  find you out in the world as an invader."
- A companion: "You can create a hybrid, drone or cyberdog, or natural dog."

## Rounds (in this order)

1. **Wounds** (both places): health per body part (head, chest, stomach, arms, legs; head or chest at zero kills; a
   dead limb slows or shakes aim), bleeding (light, heavy; bandage, tourniquet), broken bones (falls, heavy hits;
   splint), pain, tremors and concussion (blasts; painkillers), bruising under plate until the plate breaks, surgery
   kit (dead limb back at a lower maximum), healing at home over time (medbay), the doctor in Verdant Reach and lost
   limbs, scars that stay for the life, hunger (light).
2. **The kit and two weapons** (Endeavor first): mount points on the body for each weapon (back, hip, thigh, chest),
   a plate carrier or tactical vest and a belt that hold the sidearm, meds and magazines; swap between two weapons
   mid-combo; lock-on with direction moves; delay branches; moves out of a roll; a quiet combo count in the corner;
   shots keep a juggled body up; knocked, not dead (ally pick-up, finisher).
3. **Guns and ammo** (both): round types inside a calibre, the Whisper's light EMP .22 (kills radios, quiet on
   plate, felt on flesh), loading magazines by hand, plate that wears through and ricochets, barrels that overheat,
   kinds of jam, gun weight and tired arms, range marks, grabbing a dropped gun, tags from the dead.
4. **Stealth** (Endeavor): questioning a held guard, sleeping rounds, thrown distractions, hiding places, a second
   of slow time when seen (NPCs only), clothes that hide you, guards who adapt, radios on guards (round 3's EMP),
   shifts and sleep (with round 6's hour).
5. **Builds** (Endeavor): skill modifier chips, implant load and active implants, vows, a rolled trait per body, the
   empty body, grade trials, earnings carried until you extract to your bay, a hidden respec, skills that grow by
   doing, the stack slot (data and chips only) that survives death.
6. **World and money** (Endeavor): the hour picks a time of day (any order) and weather; party; party runs in the
   shelters; keys and locked rooms; timed crafting and fuel; contact loyalty and swaps; player market (found-in-run
   items only); calling in a drop to a bay.
7. **Things you make** (Endeavor, Front): the arm cybernetic built to be spent in one blow; the cable arm; trapping
   an enemy with slave tech (release, reprogram for the Front, or he escapes and invades you); companions (natural
   dog, cyberdog, drone, hybrid); the conduit's humanoid drone sent on a run in its place (less health, needs armour,
   weak in melee, good with guns).

## Five party-run tasks (Andy asked for five original ones; all in the shelters under the city)

1. **Drain the gallery**: a pump gallery floods with sludge; turn three valves in the order the gauges show while it
   rises. Overseers come down the stairs at each valve.
2. **Carry the crate**: one runner carries a heavy STACK HARDWARE crate (no weapon, slow) from a sorting floor to a
   freight cage; the rest clear and hold the route.
3. **Blind the counter**: a hall's OUTPUT counter runs on a fuse ring; shoot or cut its fuses within one timed
   window. Each fuse wakes the section around it.
4. **Copy the roll**: a console copies the HANDS roll only while someone stands at it in the light; noise anywhere
   pauses the copy and calls a patrol.
5. **Hold the cage**: a freight cage needs cells to climb; scavenge cells from the hall, load them, then hold the cage
   while it rises through two floors of contact.
