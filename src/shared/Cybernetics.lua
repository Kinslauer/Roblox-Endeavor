-- Implants: a third gear category alongside weapon and armor. Each piece adds stats and tags
-- like armor does, plus flicker-specific perks. Stronger implants carry a health penalty.
--   FlickerRate - wider flick timing window and cheaper flicks   FlashBonus - extra Black Flash damage multiplier
--   ParryBonus  - wider parry window (s)   HealthPenalty - max health lost
local Cybernetics = {}

Cybernetics.Slots = { "Optic", "Arm", "Core" }

Cybernetics.Pieces = {
	ReflexOptic = { Name = "Reflex Optic", Slot = "Optic", Stats = { Agility = 2 }, FlickerRate = 0.15, Tags = { "Cyber" } },
	TargetingLens = { Name = "Targeting Lens", Slot = "Optic", Stats = { Intelligence = 2 }, ParryBonus = 0.05, Tags = { "Cyber" } },
	ServoArm = { Name = "Servo Arm", Slot = "Arm", Stats = { Strength = 3 }, FlashBonus = 0.3, Tags = { "Cyber" } },
	ArcGauntlet = { Name = "Arc Gauntlet", Slot = "Arm", Stats = { Intelligence = 2 }, Resist = { Arc = 0.1 }, ChargeGain = 0.2, Tags = { "Cyber", "Conduit" } },
	NeuralCore = { Name = "Neural Core", Slot = "Core", Stats = { Willpower = 3 }, FlickerRate = 0.25, Tags = { "Cyber" } },
	OverclockCore = { Name = "Overclock Core", Slot = "Core", Stats = { Agility = 2, Strength = 2 }, FlashBonus = 0.6, FlickerRate = 0.15, HealthPenalty = 20, Tags = { "Cyber", "Conduit" } },
}

return Cybernetics
