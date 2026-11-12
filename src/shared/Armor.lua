-- Armor is the second half of a build. Each piece contributes resistances, posture, stat
-- bonuses and TAGS; skills unlock and scale off the stats + tags you are actually wearing.
local Armor = {}

Armor.Slots = { "Head", "Chest", "Legs", "Rig", "Belt", "Cloak" }
Armor.WeightScore = { Light = 0, Medium = 1, Heavy = 2 } -- heavier = more stamina cost, slower, sturdier block

-- Resist: 0-1 damage reduction per damage type. Posture: extra max posture.
-- Stats: bonuses to effective stats. Tags: counted for skill requirements/bonuses.
-- ChargeGain: extra conduit charge per hit (fraction). Speed: walk speed multiplier delta.
Armor.Pieces = {
	ScavHelm = { Name = "Scav Helm", Slot = "Head", Weight = "Light", Resist = { Physical = 0.03 }, Stats = { Agility = 1 }, Tags = { "Scav" } },
	PlatedHelm = { Name = "Plated Helm", Slot = "Head", Weight = "Heavy", Resist = { Physical = 0.08 }, Posture = 12, Tags = { "Plated" } },
	ArcHood = { Name = "Arc-Lined Hood", Slot = "Head", Weight = "Light", Resist = { Arc = 0.12 }, Stats = { Intelligence = 2 }, ChargeGain = 0.10, Tags = { "Conduit" } },

	ScrapVest = { Name = "Scrap Vest", Slot = "Chest", Weight = "Light", Resist = { Physical = 0.06 }, Stats = { Agility = 1 }, Tags = { "Scav" } },
	RiotPlate = { Name = "Riot Plate", Slot = "Chest", Weight = "Heavy", Resist = { Physical = 0.16 }, Posture = 25, Stats = { Fortitude = 2 }, Speed = -0.04, Tags = { "Plated" } },
	ConduitHarness = { Name = "Conduit Harness", Slot = "Chest", Weight = "Medium", Resist = { Physical = 0.06, Arc = 0.15 }, Stats = { Intelligence = 3 }, ChargeGain = 0.25, Tags = { "Conduit" } },

	ScrapGreaves = { Name = "Scrap Greaves", Slot = "Legs", Weight = "Light", Resist = { Physical = 0.04 }, Stats = { Agility = 1 }, Tags = { "Scav" } },
	ServoGreaves = { Name = "Servo Greaves", Slot = "Legs", Weight = "Medium", Resist = { Physical = 0.05, Arc = 0.05 }, Stats = { Agility = 2 }, Speed = 0.04, Tags = { "Conduit" } },
	PlatedGreaves = { Name = "Plated Greaves", Slot = "Legs", Weight = "Heavy", Resist = { Physical = 0.1 }, Posture = 12, Tags = { "Plated" } },

	-- the kit (round 2): worn over the clothes, it carries things. Holster = where a carried short weapon rides
	-- (server/Kit.lua draws it there); Mags = magazine pouches (faster reloads); Meds = med pouches (key 2 dresses
	-- the worst wound from them); Plate = a plate's rating over the chest (stops rounds of a lower calibre Pen)
	PlateCarrier = { Name = "Plate Carrier", Slot = "Rig", Weight = "Medium", Resist = { Physical = 0.05 }, Posture = 8,
		Plate = 2, Holster = "Chest", Mags = 3, Meds = 1, Tags = { "Plated" } },
	TacticalVest = { Name = "Tactical Vest", Slot = "Rig", Weight = "Light", Holster = "Chest", Mags = 4, Meds = 2, Tags = { "Scav" } },
	DutyBelt = { Name = "Duty Belt", Slot = "Belt", Weight = "Light", Holster = "Hip", Mags = 1, Meds = 1 },
	DropLegRig = { Name = "Drop-Leg Rig", Slot = "Belt", Weight = "Light", Holster = "Thigh", Mags = 2 },

	-- clothes for the dark (round 4, stealth): worn over the rig. Conceal takes that share off how lit you are
	-- (server/Stealth); a Disguise passes a guard's look from beyond Config.Stealth.Disguise.Close until he is wary
	SootPoncho = { Name = "Soot Poncho", Slot = "Cloak", Weight = "Light", Conceal = 0.3, Tags = { "Scav" } },
	SentryUniform = { Name = "Sentry Uniform", Slot = "Cloak", Weight = "Light", Disguise = true },
}

-- What a worn kit holds: { Holster = { mount = true }, Mags, Meds, Plate } (profile.Armor = { slot = id })
function Armor.Kit(worn)
	local kit = { Holster = {}, Mags = 0, Meds = 0, Plate = 0, Conceal = 0, Disguise = false }
	for _, id in worn or {} do
		local p = Armor.Pieces[id]
		if p then
			if p.Holster then
				kit.Holster[p.Holster] = true
			end
			kit.Mags += p.Mags or 0
			kit.Meds += p.Meds or 0
			kit.Plate = math.max(kit.Plate, p.Plate or 0)
			kit.Conceal = math.max(kit.Conceal, p.Conceal or 0)
			kit.Disguise = kit.Disguise or p.Disguise == true
		end
	end
	return kit
end

return Armor
