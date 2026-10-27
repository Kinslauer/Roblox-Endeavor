-- Implants: the third gear category alongside weapon and armor. The whole body is rippable (owner,
-- 2026-10-27: "you could make someone 100% metal if you wanted ... arms legs eyes ears nose. they all have
-- benefits"). Every slot is ripped in or out at the Autonet only (server/Autonet.lua), and each kind of
-- slot does something the others can't:
--   Eyes  - timing: FlickerRate (wider flick window, cheaper flicks), ParryBonus (wider parry window, s)
--   Ears  - Hearing: radius (studs) in which moving or fighting bodies ping on your screen, walls or not
--   Nose  - Scent: radius (studs) in which loot and fragments are marked; Track also marks wounded bodies
--   Core  - the engine: stamina, posture, charge, resist; the strongest carry HealthPenalty (max health lost)
--   Arm   - (left and right) Strength, FlashBonus (extra Black Flash multiplier), ChargeGain; Lift lets the
--           arms pick up heavier debris (Config.Destruction.Grab.Classes[*].Lift)
--   Leg   - (left and right) Speed (walk speed share), Jump (jump height share), DodgeBonus (i-frames, s)
-- Paired slots take any piece of their kind; two of the same piece need two in the inventory.
local Cybernetics = {}

Cybernetics.Slots = { "Eyes", "Ears", "Nose", "Core", "LeftArm", "RightArm", "LeftLeg", "RightLeg" }

-- slot -> the kind of piece it takes (Pieces[*].Slot)
Cybernetics.KindOf = {
	Eyes = "Eyes", Ears = "Ears", Nose = "Nose", Core = "Core",
	LeftArm = "Arm", RightArm = "Arm", LeftLeg = "Leg", RightLeg = "Leg",
}

Cybernetics.Label = {
	Eyes = "Eyes", Ears = "Ears", Nose = "Nose", Core = "Core",
	LeftArm = "Left arm", RightArm = "Right arm", LeftLeg = "Left leg", RightLeg = "Right leg",
}

-- Saves from before the full body (Optic / Arm / Core) land here (PlayerData.Load).
Cybernetics.Renamed = { Optic = "Eyes", Arm = "RightArm" }

Cybernetics.Pieces = {
	-- Eyes
	ReflexOptic = { Name = "Reflex Optic", Slot = "Eyes", Stats = { Agility = 2 }, FlickerRate = 0.15, Tags = { "Cyber" } },
	TargetingLens = { Name = "Targeting Lens", Slot = "Eyes", Stats = { Intelligence = 2 }, ParryBonus = 0.05, Tags = { "Cyber" } },
	-- Ears
	AudioPickup = { Name = "Audio Pickup", Slot = "Ears", Stats = { Willpower = 1 }, Hearing = 60, Tags = { "Cyber" } },
	EchoArray = { Name = "Echo Array", Slot = "Ears", Hearing = 100, ParryBonus = 0.03, HealthPenalty = 5, Tags = { "Cyber" } },
	-- Nose
	ChemSniffer = { Name = "Chem Sniffer", Slot = "Nose", Stats = { Intelligence = 1 }, Scent = 45, Tags = { "Cyber" } },
	BloodTracer = { Name = "Blood Tracer", Slot = "Nose", Scent = 35, Track = true, Tags = { "Cyber" } },
	-- Core
	NeuralCore = { Name = "Neural Core", Slot = "Core", Stats = { Willpower = 3 }, FlickerRate = 0.25, Tags = { "Cyber" } },
	OverclockCore = { Name = "Overclock Core", Slot = "Core", Stats = { Agility = 2, Strength = 2 }, FlashBonus = 0.6, FlickerRate = 0.15, HealthPenalty = 20, Tags = { "Cyber", "Conduit" } },
	PlatedCore = { Name = "Plated Core", Slot = "Core", Stats = { Fortitude = 3 }, Posture = 20, Resist = { Physical = 0.06 }, Speed = -0.03, Tags = { "Cyber" } },
	-- Arms
	ServoArm = { Name = "Servo Arm", Slot = "Arm", Stats = { Strength = 3 }, FlashBonus = 0.3, Lift = 1, Tags = { "Cyber" } },
	ArcGauntlet = { Name = "Arc Gauntlet", Slot = "Arm", Stats = { Intelligence = 2 }, Resist = { Arc = 0.1 }, ChargeGain = 0.2, Tags = { "Cyber", "Conduit" } },
	-- Legs
	StriderLeg = { Name = "Strider Leg", Slot = "Leg", Stats = { Agility = 1 }, Speed = 0.05, Tags = { "Cyber" } },
	PistonLeg = { Name = "Piston Leg", Slot = "Leg", Jump = 0.2, DodgeBonus = 0.03, Tags = { "Cyber" } },
}

function Cybernetics.Fits(piece, slot)
	return piece ~= nil and Cybernetics.KindOf[slot] ~= nil and Cybernetics.KindOf[slot] == piece.Slot
end

-- The slots a piece can go in, in order (left first).
function Cybernetics.SlotsFor(piece)
	local out = {}
	for _, slot in Cybernetics.Slots do
		if Cybernetics.Fits(piece, slot) then
			table.insert(out, slot)
		end
	end
	return out
end

-- How many copies of an item are in the body right now.
function Cybernetics.Fitted(cyber, itemId)
	local n = 0
	for _, id in cyber do
		if id == itemId then
			n += 1
		end
	end
	return n
end

return Cybernetics
