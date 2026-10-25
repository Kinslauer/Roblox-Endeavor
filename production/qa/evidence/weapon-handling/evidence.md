# Weapon handling evidence — stories 001–003

**Date**: 2026-10-25 · **Build**: `claude/combat-feel` after `9772832` + this commit · **Studio**: `Conduit.rbxlx`, all pushes byte-exact
**Method**: Studio MCP; Play; creator confirmed and tutorial skipped from the Client datamodel; pistol / spear / sledge
granted by a server bridge Script; ADS toggled through a runtime LocalScript that requires the game's own `Aim`
module (simulated mouse buttons release when the tool returns, and `screen_capture` returned stale frames, so
alignment is verified numerically).

| AC | Result | Notes |
|---|---|---|
| 1. Two-handed stances | by construction + smoke | Stance tables present; `SwingAnimator.step` writes both shoulders; smoke 46/46 unaffected. Visual: owner |
| 2. Pistol hold | by construction | `HoldAfter = 2` on both Sidearm entries; `poseTransform` holds `arm.swing` until `holdUntil`, then lowers over `HoldLower = 0.3`; new swings start from `motor.Transform` |
| 3. ADS / specials | PASS | Equip ArcPistol → RMB: `CameraMode = LockFirstPerson`, `FieldOfView = 42`; release: `Classic`, 70. Melee RMB path unchanged in `Input` |
| 4. Sight picture | **PASS (exact)** | With ADS on: `Sight` attachment relative to camera `pos = (0.00, -0.00, -0.90)`, `lookDot = 1.000`; **front post top relative to camera `(0.000, 0.000, -2.00)`** — both on the camera axis, i.e. front post centred in the rear notch with tops level; rear posts at x = ±0.11, y = −0.07 (their centres, tops at 0) |
| 5. Aimed shots | PASS (smoke) | `Attack` with aim 30° up → Bolt endpoint `Y > 30`; aim behind the body → endpoint along the body's facing (`Z < −50`). Live: `sanitizeAim` present in Studio's Combat |
| 6. Reticle | PASS | `Reticle.Visible = false` while ADS with the view model up; `true` after |

**Smoke**: 46/46 (3 new: pistol equip, aimed pitch, cone fallback).
**Sign-off**: pending owner playtest (story 004).
