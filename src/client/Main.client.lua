-- Client composition root (ADR-0003 / ADR-0004). Each module is presentation or input only; the
-- server owns every gameplay outcome. Order matters: Hud first (others use its banner/labels),
-- then the CombatEvent dispatcher, then the modules that register handlers on it, then input.
local Hud = require(script.Parent.Hud)
local CombatFX = require(script.Parent.CombatFX)
local CameraShake = require(script.Parent.CameraShake)
local Impacts = require(script.Parent.Impacts)
local FlickerAura = require(script.Parent.FlickerAura)
local WeaponView = require(script.Parent.WeaponView)
local SwingAnimator = require(script.Parent.SwingAnimator)
local Input = require(script.Parent.Input)

Hud.Init()
CombatFX.Init()
CameraShake.Init()
Impacts.Init()
FlickerAura.Init()
WeaponView.Init()
SwingAnimator.Init()
Input.Init()
