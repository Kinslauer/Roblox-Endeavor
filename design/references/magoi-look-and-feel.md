# Reference: Magoi (Roblox) — the look and feel to aim for

> **Owner, 2026-10-26 10:31**: "ultimately I want a look and feel like this; it's a game called Magoi on Roblox and
> it closer captures the middle ground of Cursed Gear and Deepwoken I'm trying to achieve." Kept for combat polish.
> **Source**: an 83 s clip (1330×720, 60 fps) of a staff user in an open dirt arena, a dozen players around.
> Observations only — nothing of Magoi's is copied; this is the target *feel*, expressed as things we can build.

## What the clip shows (and what it means for Conduit)

| Seen in the clip | Why it reads well | Conduit today | Polish item |
|---|---|---|---|
| **Third person, camera far and a little high**, character small in frame, lots of ground visible | you read spacing and footwork, not a shoulder | our Aim stance sits over the right shoulder, closer | add a "far" camera preset (distance ~14–16, slight pitch) as the default for melee; keep the close one for ADS / guns |
| **Weapon trails**: a thin white arc that hangs for a few frames on every swing, wide on heavies | the swing is readable from any angle, including yours | we have a SwingAnimator + CombatFX, no persistent arc | a Trail (two attachments on the weapon handle) that lights only during the active frames, longer life on heavies |
| **Dust**: a low tan dust puff under the feet on dodge and landing; a big dust cloud on a heavy / slam | movement has weight; the ground answers you | Impacts does hit sparks; dodges are silent | ground-coloured particle puffs on dodge, Enemy Step landing, launcher land, and under heavies; a big cloud on Buster / Sledge heavies |
| **Short, snappy animations with held poses**: wind-ups are a pose you can see, recoveries are a settle, idle is low and ready | the parry / dodge window is *visible* | our telegraphs are timed but the body language is placeholder | pose-driven windups (an actual held frame at Windup start), weapon low in idle, a crouch-settle on landing |
| **Readable hitstop**: a frame or two of freeze on contact, more on heavies | hits feel like they land | CameraShake.Hitstop exists | tune it up on heavies and parries; freeze the attacker's animation too |
| **Muted palette**: dirt, slate, grey-blue cliffs, dark cloth; colour is reserved for effects and hair | effects pop because the world does not compete | our districts are neon-on-dark; the enclave is already muted | keep the enclave direction; dim District neon by ~30 %; let hit effects carry the colour |
| **Minimal HUD**: one long bar bottom-centre (health left, stamina/other right, a crest in the middle), a 9-slot hotbar under it, nothing else | eyes stay on the fight | our bars are top-left, panels around the edges | move health/stamina/posture into one bottom-centre bar; hotbar under it (we have 3 skills + weapon); ammo and raid line stay small at the edges |
| **Interaction prompts are tiny letter badges** floating at the thing (D / I / R in a ring) | no billboards shouting | our ProximityPrompts are stock Roblox | custom ProximityPrompt style: small dark circle with the key letter, label on hover only |
| **Nameplates are small, lower-left of the body**, not over the head | people read as bodies first | Roblox default over-head names | custom small nameplate at hip height, fades with distance |
| **Crowds**: a dozen players in the open, fights breaking out unannounced | the world is social and dangerous | rival crews + barks (built today) | more of this: no "ambush" announcement at all once barks are tuned |

## Where it sits between Cursed Gear and Deepwoken
Cursed Gear's **cleanness** (one clear silhouette, a trail per swing, a dust puff per step, a tight hitstop) with
Deepwoken's **openness** (wide ground, far camera, people everywhere, nothing marked). Conduit already has the rules
side of that (timing core, posture, flicker, momentum); the gap is *presentation*: camera distance, trails, dust, pose
discipline, HUD placement, palette restraint. None of it is systems work.

## Proposed polish order (when combat polish comes up)
1. ~~Far camera preset + bottom-centre bar + hotbar~~ — **done 2026-10-26** (`Presentation.Aim.Melee / Ranged`, `Hud.lua`).
2. ~~Weapon trails on active frames + dust on dodge / land / heavy~~ — **done 2026-10-26** (`WeaponView.AddTrail`, `WorldFX.Dust`).
3. Held wind-up poses — **done 2026-10-26** as keyframed per-step combos (`Presentation.Swings` Keys, story 006);
   idle stance per family and hitstop tuning still open.
4. Palette pass on the districts; custom prompt and nameplate styles.
