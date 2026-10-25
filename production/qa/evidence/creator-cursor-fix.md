# Fix evidence — creator unusable under the aim stance (owner report, 2026-10-25 16:40)

**Report**: "the character creator isn't functional yet, I tried clicking and it only did a swing with my loaded character."

**Cause**: `Aim` (fair-arrival build-order 2) locks the mouse to the screen centre every rendered frame
while the stance is on, and it is on by default. The creator opens while the character is already
loaded (it previews on your real body), so the cursor could never reach its buttons and every click
went to `Input` as an attack. The same lock would have blocked the tutorial's Skip button and the
inventory / stats / loadout panels.

**Fix** (`src/client/Hud.lua`, `Aim.lua`, `Input.lua`, `HudCombat.lua`, `Creator.client.lua`, `Presentation.lua`):
- `Hud.MenuOpen()` — true while the creator is open (`CreatorOpen` attribute set by the creator
  client) or any HUD panel is visible.
- `Aim.Active()` = stance on **and** no menu open **and** `Presentation.Aim.FreeCursorKey` (LeftAlt)
  not held. `lockMouse` sets `Default` instead of `LockCenter` while inactive; body tracking and the
  reticle follow `Active()`.
- `Input` ignores mouse buttons while a menu is open, so a missed button click is not a swing.
- Side fix seen in the same screenshot: the prologue plot's cyan floor light (brightness 2, 4 studs
  from the spawn) blew the character out to a glowing silhouette under bloom; replaced by a warm
  0.9-brightness ceiling lamp (`WorldPhase.buildPlot`).

**Verified live** (Studio rendering, 37 frames / 0.6 s): creator open → `CreatorOpen=true`,
`MouseBehavior=Default`, reticle hidden; screenshot shows the panel with a readable skin-tone body.
Owner to confirm by clicking through the creator (left in Play mode with the creator open).
