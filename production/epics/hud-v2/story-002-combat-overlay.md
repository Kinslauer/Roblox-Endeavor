# Story 002 — Combat overlay: damage numbers, reticle, hit marker, damage flash

**Epic**: HUD v2 · **Type**: UI · **Status**: Implemented (owner playtest pending)

## Change
- New `src/client/HudCombat.lua` (registered on `CombatFX`, init after `Audio`, before `Aim`):
  - `HudCombat.Number(char, text, color, big)` — `BillboardGui` on the victim's Head, random
    sideways scatter, rises `Rise` studs over `Life` seconds and fades; capped at `MaxLive`.
  - `Hit` → amount over the victim (`-N` in the Taken colour + `DamageFlash` for the local player;
    heavy size/colour at/above `HeavyAmount`); `HitMarker()` if the local player is the attacker.
  - `Block` / `Parry` / `GuardBreak` / `Dodged` → BLOCKED / PARRIED / GUARD BREAK / DODGED.
  - `BlackFlash` → re-tints the number `Hit` just spawned (the server sends Hit, then BlackFlash)
    red, heavy size, with `!`.
  - Reticle: four ticks + dot at screen centre, `Visible = Aim.Enabled` each Heartbeat; hit marker
    scales to `HitScale` in `HitColor` and eases back over `HitSeconds`.
  - `DamageFlash(strength)` — full-screen frame with a vignette `UIGradient`, tweened back to clear.
  - ScreenGui `ConduitCombat` has `DisplayOrder = -1` so it draws under `ConduitHUD`.
- `src/shared/Presentation.lua`: `Presentation.Hud = { DamageNumbers, Reticle, DamageFlash }` slots.
- `src/server/Arena.lua`: server-drawn dummy damage numbers removed (every client draws them now).
- `src/client/Main.client.lua`: requires and inits `HudCombat`.

## Acceptance
AC 3–7 — see `production/qa/evidence/hud-v2/hud-v2-evidence.md`.
