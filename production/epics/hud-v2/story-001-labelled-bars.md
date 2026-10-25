# Story 001 — Labelled bars and a custom health bar

**Epic**: HUD v2 · **Type**: UI · **Status**: Implemented (owner playtest pending)

## Change
- `src/client/Hud.lua`: `bar(y, color, name)` now draws a name (left) and a `value / max` label
  (right) over the fill; `bindBar(fill, valueLabel, char, attr, maxAttr)` updates both on the
  attribute-changed signals; new `bindHealth(fill, valueLabel, char)` binds `Humanoid.HealthChanged`
  and `MaxHealth`. Bars are stacked HEALTH / STAMINA / POSTURE / CHARGE from the bottom-left; the
  level and flicker labels moved up to make room. The core `Health` CoreGui is disabled (our bar
  replaces it); `PlayerList` stays disabled (Tab is the inventory key). `Hud.Gui` is exposed.

## Acceptance
AC 1, 2, 8 — see `production/qa/evidence/hud-v2/hud-v2-evidence.md`.
