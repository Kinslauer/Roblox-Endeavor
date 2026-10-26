# Epic: Weapon bench — parts, builds, strip and rebuild (Phase 3, build order 4)

> **Status**: Stories 001–004 implemented (owner playtest pending) · **Layer**: Feature (gunplay) · **Rigor**: standard
> **Brief**: `design/phase-3-brief.md` item 4 · **GDD**: `design/gdd/gunplay.md` §4 · **Owner ask**: strip a pistol to the frame, swap slides/barrels, lights/lasers/optics

## Overview
A gun is a frame plus parts. Eleven parts across six slots (`shared/Attachments.lua`) fold into the weapon definition
both sides read, so a fitted part is a real change to spread, recoil, magazine, reload, settle time, damage and reach.
The bench lives in the hideout: fit, strip, or strip to the frame from the inventory panel's Workbench section. Parts
drop by region, three are craftable, and a build rides into the war with the gun.

## Stories
| # | Story | Type | Status |
|---|---|---|---|
| 001 | `shared/Attachments.lua`: slots, 11 parts (families, Gun / Attack mods, Light / Laser / Quiet flags), `Fits`, `Apply` (deep clone + fold), `Describe`; parts registered as items (Type "Part"); recipes TacLight / ExtMag / CompBarrel; regional loot entries | Data | Implemented — smoke: Apply numbers |
| 002 | `server/Bench.lua`: `Fit` / `Strip` / `StripAll` (hideout only, ownership + family checks, old part handed back), `Publish` (JSON `Builds` player attribute), `Remotes.Bench` rate-limited; `profile.Builds`; `Combat.WeaponDefOf` + `weaponOf` fold the build; ammo clamp; `SettleMult` on ADS settle | Logic | Implemented — live: fit mag/dot/light, scope refused on a sidearm, strip-all returns all, MaxAmmo 9→15→9 |
| 003 | Client: `Aim` kicks by the built recoil; HUD inventory panel Workbench section (effective numbers, slot rows + Strip, Frame, Fit buttons on fitting parts) re-rendering on Builds / Zone / inventory changes | HUD | Implemented — live: panel rows and 3 Fit buttons in the hideout |
| 004 | Visible parts: `WeaponView.AddPartViews` (SpotLight torch, red Beam laser) on the hand model and the first-person ViewModel; redraw when Builds changes | Visual | Implemented — live: torch appears on Fit, swaps to beam, gone on strip-all |
| 005 | Owner playtest: does a Dot Sight + Brake pistol *feel* different at the Range? Is the Workbench section readable or does it need its own panel? Which parts should be visible on the gun? | Feel | Pending |

## Acceptance criteria
1. In the hideout with a gun held, Tab shows the Workbench with the gun's effective numbers; parts that fit show Fit; fitted slots show Strip; Frame strips everything.
2. A fitted part changes the server's shot (spread / recoil / magazine / reload) and the camera kick; the ammo counter follows the magazine with no free rounds.
3. Rifle parts refuse sidearms and vice versa; outside the hideout the bench refuses.
4. Torch and laser parts are visible on the gun in third and first person.
5. Smoke covers 1–3 (8 checks: 143/143).

## Follow-ups
- Builds are per weapon *type*: two Arc Pistols share one build. Per-instance weapons need an inventory model change.
- A bench prop to stand at; a dedicated bench panel with slot art once the inventory panel gets crowded.
- Part models on the gun (barrel length, scope), durability / jams, ammo types.
