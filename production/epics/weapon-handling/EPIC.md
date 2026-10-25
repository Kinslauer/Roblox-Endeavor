# Epic: Weapon Handling (post-brief, owner playtest round 1)

> **Status**: Stories 001–003 implemented (owner playtest pending) · **Layer**: Feature · **Rigor**: standard
> **Source**: owner playtest notes 2026-10-25 19:24–19:33 · **Foundation for**: Universe 2 (first-person shooter view)

## Overview
After signing off the brief's six items the owner asked for three handling changes: two-handed
weapons should be held with two hands, the pistol should stay on target between shots, and the
pistol's right click should aim down real iron sights in first person — "this is how the first
person shooter part of the game will operate as well". The sight picture is therefore built as
engine, not decoration: the weapon carries its own aim line, the view model puts the camera on it,
and the server fires along the camera direction it is sent (validated).

## Governing ADRs
ADR-0001 (the shot direction is client intent, validated inside `Config.Combat.AimCone` / `AimMaxPitch`;
the server still raycasts and applies damage), ADR-0004 (stances, hold time, sights, view-model
offsets and recoil are all slots in `Presentation`).

## Stories
| # | Story | Type | Status |
|---|---|---|---|
| 001 | Two-handed stances: `Presentation.Weapons[id].TwoHanded` + `Stance {Right, Left}`; `SwingAnimator` drives both shoulders (left mirrors yaw/roll), every tracked character holds its weapon's stance between swings, swings start from the current arm pose | Presentation | Implemented (`9772832`) |
| 002 | Pistol hold + ADS: `Swings.Families.Sidearm.*.HoldAfter = 2` (arm stays on the firing line, lowers over `HoldLower`); `Aim.SetADS` (first person, FOV 42) on right mouse for ranged weapons; specials on MMB / G; hitstop FOV base owned by Aim | Presentation + Input | Implemented (`9772832`) |
| 003 | Sight picture: iron sights on the procedural pistol (rear posts + notch, front post + bead, `Sight` attachment = aim line); `ViewModel` draws arm + weapon under the Camera in first person, hip pose vs. sights pose, sway, recoil; reticle hidden while on the sights; `Input` sends the camera look vector, `Combat.sanitizeAim` accepts it inside the cone and fires from eye height along it | Presentation + Logic | Implemented |
| 004 | Owner playtest: spear/sledge grips, pistol hold time, sight alignment on a target at 20–60 studs, hip-fire feel, recoil amount | Visual/Feel | Pending |

## Acceptance criteria
1. Spear and sledge: both hands on the shaft at rest and through the swing; one-handed weapons unchanged.
2. After a pistol shot the arm stays raised; it lowers 2 s after the last shot; a new shot does not drop it first.
3. Right mouse with a ranged weapon enters first person with a narrower FOV; release returns to the shoulder camera; melee right mouse is still the heavy. MMB / G fire the special.
4. In ADS the weapon's `Sight` line coincides with the camera axis: rear notch and front post top on the axis (x = y = 0 in camera space), so the front post is centred in the notch with tops level.
5. A ranged shot fired while aiming goes where the camera looks (pitch included); a direction outside the cone falls back to the body's facing.
6. The reticle disappears while on the sights and returns off them.

## Definition of Done
AC 1–6 verified (4 and 5 by instrument, below); owner sign-off on 004.

## Follow-ups
- Hip-fire view (first person without ADS) is wired but Universe 1 only enters first person through ADS; Universe 2 will set the camera first-person permanently and reuse `ViewModel` as is.
- Studio's `screen_capture` returns stale frames in Play mode; visual sign-off is the owner's.
