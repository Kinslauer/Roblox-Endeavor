# HUD v2 evidence — stories 001 + 002

**Date**: 2026-10-25 · **Build**: branch `claude/combat-feel`, Studio place `Conduit.rbxlx`
**Method**: Studio MCP. Patched Studio from the working tree (`tools/studio_patch.py`: Hud 4/4, Main 2/2,
Presentation 1/1, HudCombat written). Play; creator confirmed from the Client datamodel; damage applied
from the Client (`Remotes.Attack`) and from a server bridge `Script` calling `Combat.Damage` (the
assistant's Server datamodel cannot fire the game's remotes — its `require` builds a second `Remotes`
folder; see Notes). Studio was not rendering (owner away), so all checks read instances and attributes;
`DescendantAdded` listeners caught the short-lived billboards.

| AC | Result | Notes |
|---|---|---|
| 1. Labels + `value / max` | PASS | `barLabels=HEALTH,STAMINA,POSTURE,CHARGE`; `HEALTH:100 / 100 STAMINA:100 / 100 POSTURE:0 / 80 CHARGE:0 / 100` |
| 2. Custom health bar, core bar off | PASS | `GetCoreGuiEnabled(Health)=false`; label tracked `Humanoid.Health` 100 → `85 / 100` → `75` → `62 / 100` after three server hits |
| 3. Hit numbers | PASS | Own attack on an arena dummy: `12` (Hit colour `255,235,200`) over `Training Dummy.Head`; bridge heavy hit: `25` at TextSize **34** in the Heavy colour; bridge hit on me: `-10` over my Head |
| 3b. Black Flash re-tint | by construction | Server order confirmed in `Combat.lua` (Hit at `applyDamage`, then `blackFlash` → `fx("BlackFlash")`); handler recolours the last `DamageNumber` under the victim's Head. Not exercised live (needs a flicked 3-chain) — owner playtest |
| 4. Outcome words | PASS | `BLOCKED` (`150,170,255`), `PARRIED` (white), `DODGED` (`80,255,230`) spawned over my Head from blocked / parry-window / i-frame bridge hits |
| 5. Reticle + hit marker | PASS | `Reticle` with 5 children, `Visible=true` while Aim defaults on; tick colour **and** position changed during my hit (`reticle hit colour=true scale=true`). Aim-off hiding is one line (`Visible = Aim.Enabled`) — owner to confirm with LeftControl |
| 6. Damage flash | PASS | `DamageFlash.BackgroundTransparency` min **0.81** during a 10-damage hit (strength 0.35 → `1 − 0.55·0.35`); `ConduitCombat.DisplayOrder = -1` |
| 7. Cleanup / cap | PASS | `leftover after life=0`, `stillAlive=0` after every batch; `MaxLive=24` |
| 8. Tab conflict | PASS (unchanged) | `PlayerList` CoreGui disabled in `Hud.Init` |

**Smoke**: `tools/smoke` 35/35, 0 errors (server-side; the overlay is client-only).

### Notes
- Verification gotcha recorded for future sessions: in the Server datamodel, `require(Shared.Remotes)`
  from the assistant VM runs the server branch again and creates a **second** `ReplicatedStorage.Remotes`
  folder, so `FireAllClients` from that VM reaches nobody. Use a bridge `Script` (shares the game's
  module cache) and delete the stray folder.
- The dev-arena dummies no longer draw their own numbers; the client overlay covers them.

**Sign-off**: pending project owner playtest (story 003).
