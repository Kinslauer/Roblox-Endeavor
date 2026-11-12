-- Weapons own the melee/ranged moveset: combo chain, heavy attack, timings and reach.
-- Skills and resistances come from stats + armor, never from the weapon.
--
-- Every attack is defined by its frame data (frames at 60 per second), fighting-game style:
--   Startup  - frames before the weapon is live (the wind-up; what you can react to)
--   Active   - frames the weapon is live (shared/Swings traces it; it hits whatever it passes)
--   Recovery - frames after, until you can act again (what you get punished in)
-- frames(damage, posture, startup, active, recovery, range, extra) stores those and derives the seconds the
-- combat code runs on: Windup = Startup/60, Active = Active/60, End = (Startup + Active + Recovery)/60.
-- Other fields (seconds / studs):
--   Range  - reach (ranged weapons: raycast length)
--   Arc    - min dot(look, toTarget); 0.3 ~ 145deg cone, 0.7 ~ narrow thrust (non-traced fallbacks)
--   Damage / Posture - raw values, scaled by stats at runtime
--   Knockback (studs/s push), Stun (hit-stun on target), Hyperarmor, Type ("Physical"|"Arc"), Ranged
-- Weapon Mass ("Light" | "Medium" | "Heavy"): how big it swings. A Medium or Heavy weapon's launcher throws up
-- everything around the impact (Config.Momentum.GroupLaunch).
local Weapons = {}

Weapons.FPS = 60

local function frames(damage, posture, startup, active, recovery, range, extra)
	local spec = {
		Damage = damage, Posture = posture, Range = range, Arc = 0.3, Stamina = math.floor(damage * 0.6 + 2),
		Startup = startup, ActiveFrames = active, Recovery = recovery,
		Windup = startup / Weapons.FPS, Active = active / Weapons.FPS, End = (startup + active + recovery) / Weapons.FPS,
	}
	for k, v in extra or {} do
		spec[k] = v
	end
	return spec
end
Weapons.Frames = frames

-- "8f / 7f / 18f": an attack's frame data as a line (inventory tooltip)
function Weapons.FrameLine(spec)
	return ("%df startup  %df active  %df recovery"):format(spec.Startup or 0, spec.ActiveFrames or 0, spec.Recovery or 0)
end

Weapons.Defs = {
	Fists = {
		Name = "Fists", Family = "Fists", ComboReset = 0.7, ComboCooldown = 0.35,
		Attacks = {
			frames(6, 3, 6, 7, 12, 6),
			frames(6, 3, 6, 7, 12, 6),
			frames(6, 3, 6, 7, 12, 6),
			frames(9, 6, 8, 8, 16, 6, { Knockback = 30 }),
		},
		Heavy = frames(12, 8, 18, 9, 21, 6, { Knockback = 35, Stamina = 14 }),
	},
	PipeClub = {
		Name = "Pipe Club", Family = "Blunt", Mass = "Medium", ComboReset = 0.7, ComboCooldown = 0.45,
		Attacks = {
			frames(12, 5, 10, 8, 16, 7),
			frames(12, 5, 10, 8, 16, 7),
			frames(18, 10, 13, 10, 19, 7, { Knockback = 35 }),
		},
		Heavy = frames(26, 14, 24, 10, 26, 7.5, { Knockback = 45, Stamina = 20 }),
	},
	RebarBlade = {
		Name = "Rebar Blade", Family = "Blade", ComboReset = 0.7, ComboCooldown = 0.45,
		Attacks = {
			frames(11, 4, 7, 8, 14, 8),
			frames(11, 4, 7, 8, 14, 8),
			frames(13, 5, 8, 8, 14, 9, { Arc = 0.2 }),
			frames(17, 9, 12, 10, 20, 9, { Knockback = 30 }),
		},
		Heavy = frames(24, 12, 21, 11, 25, 8.5, { Arc = 0.0, Stamina = 20 }),
	},
	ShockBaton = {
		Name = "Shock Baton", Family = "Baton", ComboReset = 0.7, ComboCooldown = 0.4, ChargeBonus = 6,
		Attacks = {
			frames(10, 4, 7, 7, 14, 7, { Type = "Arc" }),
			frames(10, 4, 7, 7, 14, 7, { Type = "Arc" }),
			frames(16, 10, 11, 8, 20, 7, { Type = "Arc", Knockback = 25, Stun = 0.6 }),
		},
		Heavy = frames(22, 12, 21, 10, 23, 7, { Type = "Arc", Stamina = 18, Stun = 0.7 }),
	},
	ScrapSpear = {
		Name = "Scrap Spear", Family = "Spear", ComboReset = 0.8, ComboCooldown = 0.45,
		Attacks = {
			frames(8, 3, 8, 7, 14, 11, { Arc = 0.6 }),
			frames(8, 3, 8, 7, 14, 11, { Arc = 0.6 }),
			frames(12, 6, 11, 8, 14, 12, { Arc = 0.6, Knockback = 25 }),
		},
		Heavy = frames(20, 10, 21, 10, 23, 13, { Arc = 0.7, Knockback = 30, Stamina = 18 }),
	},
	Sledge = {
		Name = "Sledge", Family = "Hammer", Mass = "Heavy", ComboReset = 0.9, ComboCooldown = 0.7,
		Attacks = {
			frames(24, 12, 18, 10, 17, 8, { Knockback = 40 }),
			frames(24, 12, 18, 10, 23, 8, { Knockback = 40 }),
		},
		Heavy = frames(44, 28, 36, 12, 36, 9, { Hyperarmor = true, Knockback = 60, Stamina = 30 }),
	},
	ArcPistol = {
		Name = "Arc Pistol", Family = "Sidearm", ComboReset = 0.5, ComboCooldown = 0.3, ChargeBonus = 3, Ammo = "ArcCell",
		Attacks = {
			frames(9, 3, 5, 3, 17, 90, { Type = "Arc", Ranged = true, Stamina = 8 }),
		},
		Heavy = frames(22, 10, 30, 3, 39, 110, { Type = "Arc", Ranged = true, Stamina = 22, Knockback = 20 }),
	},
	-- a suppressed .22 pistol: a small round that a guard two rooms off does not hear (Noise = the radius it
	-- carries, server/Stealth; anything without one is loud) and that only hurts where it finds flesh: any plate
	-- stops it. Made for putting lights out and for the one clean shot.
	Whisper = {
		Name = "Whisper", Family = "Sidearm", ComboReset = 0.5, ComboCooldown = 0.25, ChargeBonus = 1, Caliber = ".22", Noise = 7,
		MagSize = 7, ReloadSeconds = 1.5, Action = "Single", RackSeconds = 0.55, -- the slide is locked for quiet: racked by hand (T) after every round
		Attacks = {
			frames(12, 4, 6, 3, 19, 120, { Ranged = true, Stamina = 4 }),
		},
		Heavy = frames(12, 4, 6, 3, 19, 120, { Ranged = true, Stamina = 4 }),
	},
	-- station security's sidearm: 9mm, fifteen in the magazine, and everyone on the floor hears it
	DutyPistol = {
		Name = "Duty Pistol", Family = "Sidearm", ComboReset = 0.5, ComboCooldown = 0.2, ChargeBonus = 1, Caliber = "9mm", Noise = 75,
		MagSize = 15, ReloadSeconds = 1.8,
		Attacks = {
			frames(24, 8, 5, 3, 13, 150, { Ranged = true, Stamina = 5 }),
		},
		Heavy = frames(24, 8, 5, 3, 13, 150, { Ranged = true, Stamina = 5 }),
	},
	-- Long guns (owner, 2026-11-12: "a carbine firing 5.56 based off the exploded ar-15 model is next, then the ak-47
	-- firing 7.62x39. And the garand fires .308 or 7.62x51"). Family "Rifle" = held in two hands (client/Handling:
	-- Rifle_Ready, Aim_Rifle, Reload_Rifle). Action: see Weapons.ActionOf below. Model = how common/HeldWeapons
	-- builds it from the gun components (shared/GunParts): the gun there, its barrel, the size in the hands (the
	-- parts are modelled 0.19 studs to the inch, twice a body's scale) and the grip the two-handed animations expect.
	Carbine = {
		Name = "Carbine", Family = "Rifle", ComboReset = 0.3, ComboCooldown = 0, ChargeBonus = 1, Caliber = "5.56", Noise = 120,
		MagSize = 30, ReloadSeconds = 2.4, Model = { Gun = "M4A1", Scale = 0.5, Grip = "Shoulder" },
		Attacks = { frames(30, 8, 3, 2, 4, 260, { Ranged = true, Stamina = 2 }) },
		Heavy = frames(30, 8, 3, 2, 4, 260, { Ranged = true, Stamina = 2 }),
	},
	AK47 = {
		Name = "AK-47", Family = "Rifle", ComboReset = 0.3, ComboCooldown = 0, ChargeBonus = 1, Caliber = "7.62x39", Noise = 135,
		MagSize = 30, ReloadSeconds = 2.7, Action = "Auto", Model = { Gun = "AK47", Scale = 0.5, Grip = "Shoulder" },
		Attacks = { frames(38, 12, 3, 2, 6, 240, { Ranged = true, Stamina = 3 }) },
		Heavy = frames(38, 12, 3, 2, 6, 240, { Ranged = true, Stamina = 3 }),
	},
	-- eight rounds, one for each pull of the trigger, and the heaviest round of the three
	M1Garand = {
		Name = "M1 Garand", Family = "Rifle", ComboReset = 0.5, ComboCooldown = 0.1, ChargeBonus = 1, Caliber = "7.62x51", Noise = 150,
		MagSize = 8, ReloadSeconds = 2.2, Model = { Gun = "M1Garand", Scale = 0.5, Grip = "Shoulder" },
		Attacks = { frames(64, 20, 4, 2, 14, 380, { Ranged = true, Stamina = 5 }) },
		Heavy = frames(64, 20, 4, 2, 14, 380, { Ranged = true, Stamina = 5 }),
	},
}

-- Actions (owner, 2026-11-12): "Single" = one round per action, racked by hand before the next (the Whisper);
-- "Semi" = one round per pull of the trigger, the gun loads the next itself (the default: the Garand, the Carbine,
-- the Duty Pistol); "Auto" = rounds keep leaving while the trigger is held (the AK-47).
function Weapons.ActionOf(def)
	return def and def.Caliber and (def.Action or "Semi") or nil
end

-- A gun is aimed, not swung: RMB aims, R reloads, the body faces the camera (client/Handling, server/Stealth).
function Weapons.IsGun(def)
	return def ~= nil and (def.Family == "Sidearm" or def.Family == "Rifle")
end

-- What common/HeldWeapons needs to put weapon id in a hand: the model's id, its attachments, its options.
function Weapons.Held(id)
	local model = id and Weapons.Defs[id] and Weapons.Defs[id].Model
	if not model then
		return id
	end
	return model.Gun or id, model.Attachments, model
end

-- Calibres (owner, 2026-11-12: "a realistic ammunition system ... different weapons could be compatible with the
-- same caliber"). A gun names its Caliber; the cartridge is an item any gun of that calibre feeds on.
--   Item = the cartridge in the pack. Pen = the armour rating it defeats (a plate rated above it stops the round
--   dead: no damage, a ping). Head / Limb = damage multipliers where it finds flesh. Through = the share of damage
--   left after it has gone through armour it defeats.
-- Armour ratings are character attributes (server/NPCs sets them from NPCs.Types[t].Armor): HelmetCover (share of
-- the head's height the helmet covers, from the top), Helmet, Vest (upper torso), Bracers (lower arms), Shins.
Weapons.Calibers = {
	[".22"] = { Item = "Round22", Name = ".22 LR", Pen = 0, Head = 9, Limb = 0.6, Through = 1 },
	["9mm"] = { Item = "Round9", Name = "9mm", Pen = 1, Head = 5, Limb = 0.7, Through = 0.6 },
	["5.56"] = { Item = "Round556", Name = "5.56", Pen = 2, Head = 6, Limb = 0.8, Through = 0.75 },
	["7.62x39"] = { Item = "Round762x39", Name = "7.62x39", Pen = 2, Head = 6, Limb = 0.85, Through = 0.8 },
	["7.62x51"] = { Item = "Round762x51", Name = "7.62x51", Pen = 3, Head = 8, Limb = 0.9, Through = 0.9 }, -- .308: nothing a guard wears stops it
}
for _, def in Weapons.Defs do
	local cal = def.Caliber and Weapons.Calibers[def.Caliber]
	if cal then
		def.Ammo = cal.Item -- everything that counts or spends rounds reads Ammo
	end
end

-- Loads inside a calibre (round 3 of docs/Reference-Picks-Plan.md, after Tarkov's round types): each is its own
-- cartridge item. Pen adds to the calibre's Pen, Damage and Flesh scale what it does, Emp = the Whisper's light EMP
-- round (Andy, 2026-11-12: it discharges into what it hits and kills a guard's radio; on plate no alert, on flesh he
-- feels it; loaded lighter, so it hurts less). The calibre's own Item is the standard load.
Weapons.Loads = {
	Round22Emp = { Caliber = ".22", Name = ".22 EMP", Pen = 0, Damage = 0.45, Emp = true },
	Round9AP = { Caliber = "9mm", Name = "9mm AP", Pen = 1, Damage = 0.85, Flesh = 0.9 },
	Round9HP = { Caliber = "9mm", Name = "9mm HP", Pen = -1, Damage = 1, Flesh = 1.35 },
	Round556AP = { Caliber = "5.56", Name = "5.56 AP", Pen = 1, Damage = 0.9, Flesh = 0.9 },
	Round762x39AP = { Caliber = "7.62x39", Name = "7.62x39 AP", Pen = 1, Damage = 0.9, Flesh = 0.9 },
}
-- What a cartridge item does: the calibre's numbers with its load applied (nil if it is not a cartridge).
function Weapons.Round(itemId)
	local load = Weapons.Loads[itemId]
	local calName = load and load.Caliber
	if not calName then
		for name, c in Weapons.Calibers do
			if c.Item == itemId then
				calName = name
			end
		end
	end
	local cal = calName and Weapons.Calibers[calName]
	if not cal then
		return nil
	end
	local r = table.clone(cal)
	r.Caliber, r.ItemId = calName, itemId
	if load then
		r.Name, r.Pen = load.Name, cal.Pen + load.Pen
		r.Damage, r.Flesh, r.Emp = load.Damage, load.Flesh, load.Emp
	end
	r.Damage, r.Flesh = r.Damage or 1, r.Flesh or 1
	return r
end
-- Every cartridge item of a calibre, the standard load first.
function Weapons.LoadsOf(calName)
	local cal = Weapons.Calibers[calName]
	local out = { cal and cal.Item }
	for id, load in Weapons.Loads do
		if load.Caliber == calName then
			table.insert(out, id)
		end
	end
	table.sort(out, function(a, b)
		return (a == (cal and cal.Item)) or (b ~= (cal and cal.Item) and a < b)
	end)
	return out
end

-- Which weapons a cartridge fits (tooltips).
function Weapons.Chambered(itemId)
	local out = {}
	local round = Weapons.Round(itemId)
	for _, def in Weapons.Defs do
		if def.Caliber and round and def.Caliber == round.Caliber then
			table.insert(out, def.Name)
		end
	end
	table.sort(out)
	return out
end

return Weapons
