-- Skills are not tied to a weapon or class. They unlock from EFFECTIVE stats (base + armor
-- bonuses) and worn armor TAGS, and their power scales with those same stats and tags.
-- That means swapping a chest piece can unlock - or lock - an ability.
local Skills = {}

Skills.SlotCount = 3
Skills.Order = { "Surge", "ShatterStrike", "PhaseStep", "SecondWind", "IronBastion", "Overload", "Overclock" }

-- Kind: Burst | Strike | Dash | Buff | Recover (handled by server/SkillRunner.lua)
-- Req.Stats: minimum effective stats.  Req.Tags: minimum worn pieces carrying that tag.
-- Scaling: +fraction of power per stat point.  TagBonus: +fraction per worn piece with tag.
Skills.Defs = {
	Surge = {
		Name = "Surge", Kind = "Burst", Desc = "Release stored charge as an unblockable shockwave.",
		Req = { Stats = { Intelligence = 3 } }, ChargeCost = 50, Cooldown = 1,
		Damage = 28, Posture = 15, Radius = 14, Knockback = 70, Type = "Arc",
		Scaling = { Intelligence = 0.04 }, TagBonus = { Conduit = 0.08 },
	},
	ShatterStrike = {
		Name = "Shatter Strike", Kind = "Strike", Desc = "A hyperarmored overhead blow that wrecks posture.",
		Req = { Stats = { Strength = 8 } }, Stamina = 25, Cooldown = 8,
		Damage = 34, Posture = 30, Windup = 0.45, Active = 0.15, End = 0.9, Knockback = 55, Hyperarmor = true,
		Scaling = { Strength = 0.035 }, TagBonus = { Plated = 0.06 },
	},
	PhaseStep = {
		Name = "Phase Step", Kind = "Dash", Desc = "Blink forward with i-frames and strike on arrival.",
		Req = { Stats = { Agility = 8 } }, Stamina = 20, Cooldown = 9,
		Speed = 90, Duration = 0.25, Damage = 18, Posture = 8, Range = 7,
		Scaling = { Agility = 0.03 }, TagBonus = { Scav = 0.05 },
	},
	SecondWind = {
		Name = "Second Wind", Kind = "Recover", Desc = "Catch your breath: restore stamina and shed posture.",
		Req = { Stats = { Willpower = 10 } }, Cooldown = 40, Stamina = 60, Posture = 60,
		Scaling = { Willpower = 0.02 }, TagBonus = {},
	},
	IronBastion = {
		Name = "Iron Bastion", Kind = "Buff", Desc = "Hyperarmor and heavy damage reduction. Needs plated armor.",
		Req = { Stats = { Fortitude = 10 }, Tags = { Plated = 1 } }, Stamina = 20, Cooldown = 25,
		Duration = 4, DamageTaken = 0.6, Hyperarmor = true,
		Scaling = { Fortitude = 0.01 }, TagBonus = { Plated = 0.1 },
	},
	Overload = {
		Name = "Overload", Kind = "Buff", Desc = "Your hits arc extra damage and generate double charge. Needs conduit gear.",
		Req = { Stats = { Intelligence = 12 }, Tags = { Conduit = 2 } }, ChargeCost = 30, Cooldown = 30,
		Duration = 8, ArcBonus = 6,
		Scaling = { Intelligence = 0.04 }, TagBonus = { Conduit = 0.1 },
	},
	Overclock = {
		Name = "Overclock", Kind = "Flicker", Desc = "Prime your flicker chain to II: one well-timed flick away from a Black Flash. Needs two implants.",
		Req = { Stats = { Intelligence = 8 }, Tags = { Cyber = 2 } }, ChargeCost = 20, Cooldown = 20, Level = 2, Hold = 8,
		Scaling = {}, TagBonus = {},
	},
}

-- Returns unlocked (bool) and a human-readable reason when locked.
function Skills.Unlocked(def, stats, tags)
	for stat, need in def.Req.Stats or {} do
		if (stats[stat] or 0) < need then
			return false, ("%s %d"):format(stat, need)
		end
	end
	for tag, need in def.Req.Tags or {} do
		if (tags[tag] or 0) < need then
			return false, ("%dx %s armor"):format(need, tag)
		end
	end
	return true
end

-- Multiplier applied to the skill's numbers.
function Skills.Power(def, stats, tags)
	local power = 1
	for stat, per in def.Scaling or {} do
		power += (stats[stat] or 0) * per
	end
	for tag, per in def.TagBonus or {} do
		power += (tags[tag] or 0) * per
	end
	return power
end

return Skills
