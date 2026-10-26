-- Weapon parts (design/gdd/gunplay.md §4, Phase 3 build order 4): the bench strips a gun to its frame
-- and rebuilds it from parts. A BUILD is { [slot] = partId } stored per weapon id in the profile
-- (PlayerData.Builds); Attachments.Apply folds the fitted parts into a weapon definition so the
-- server (Combat) and the client (Aim recoil, HUD) read one effective spec. Every part is also an
-- item (Items.Defs, Type "Part"), so it drops, stashes, ships and donates like anything else.
--
-- Part fields (all optional): Slot (required), Families { "Sidearm" | "Rifle" } limits what it fits,
--   Gun = { MagazineAdd, ReloadAdd, SpreadMult, HipSpreadMult, ADSSpreadMult, RecoilMult, RecoverMult, SettleMult }
--   Attack = { DamageMult, RangeAdd }     Light = range (a torch on the gun)     Laser = true (a hip-fire aid)
local Attachments = {}

Attachments.Slots = { "Barrel", "Action", "Optic", "Muzzle", "Rail", "Magazine" }

Attachments.Parts = {
	-- barrels: reach vs. handling
	LongBarrel = { Name = "Long Barrel", Slot = "Barrel", Gun = { SpreadMult = 0.8, RecoilMult = 1.1 }, Attack = { RangeAdd = 30 } },
	CompBarrel = { Name = "Compensated Barrel", Slot = "Barrel", Gun = { RecoilMult = 0.8 } },
	-- actions: slide (sidearm) / bolt (rifle)
	MatchSlide = { Name = "Match Slide", Slot = "Action", Families = { "Sidearm" }, Gun = { RecoverMult = 1.3, SettleMult = 0.7 } },
	LightBolt = { Name = "Light Bolt Carrier", Slot = "Action", Families = { "Rifle" }, Gun = { RecoverMult = 1.25, ReloadAdd = -0.3 } },
	-- optics: what the sights give you
	DotSight = { Name = "Dot Sight", Slot = "Optic", Gun = { ADSSpreadMult = 0.6, SettleMult = 0.8 } },
	Scope4x = { Name = "4x Scope", Slot = "Optic", Families = { "Rifle" }, Gun = { ADSSpreadMult = 0.35, HipSpreadMult = 1.4, SettleMult = 1.5 } },
	-- muzzles
	Suppressor = { Name = "Suppressor", Slot = "Muzzle", Gun = { RecoilMult = 0.85 }, Attack = { DamageMult = 0.92 }, Quiet = true },
	Brake = { Name = "Muzzle Brake", Slot = "Muzzle", Gun = { RecoilMult = 0.7, HipSpreadMult = 1.15 } },
	-- rail: lights and lasers
	TacLight = { Name = "Tactical Light", Slot = "Rail", Light = 60 },
	LaserSight = { Name = "Laser Sight", Slot = "Rail", Gun = { HipSpreadMult = 0.7 }, Laser = true },
	-- magazines
	ExtMag = { Name = "Extended Magazine", Slot = "Magazine", Gun = { MagazineAdd = 6, ReloadAdd = 0.2 } },
}

-- Does this part go on this weapon? (a gun, a known slot, the right family)
function Attachments.Fits(partId, weaponDef)
	local part = Attachments.Parts[partId]
	if not (part and weaponDef and weaponDef.Attacks and weaponDef.Attacks[1] and weaponDef.Attacks[1].Ranged) then
		return false
	end
	if part.Families then
		return table.find(part.Families, weaponDef.Family) ~= nil
	end
	return true
end

local function clone(t)
	local out = {}
	for k, v in t do
		out[k] = if type(v) == "table" then clone(v) else v
	end
	return out
end

-- The weapon definition with a build folded in. Returns the definition itself for an empty build.
function Attachments.Apply(def, build)
	if not (def and build and next(build)) then
		return def
	end
	local out = clone(def)
	out.Gun = out.Gun or {}
	local gun = out.Gun
	gun.Spread = gun.Spread or {}
	gun.Recoil = gun.Recoil or {}
	out.Parts, out.Light, out.Laser, out.Quiet = {}, nil, nil, nil
	for slot, partId in build do
		local part = Attachments.Parts[partId]
		if part and part.Slot == slot then
			out.Parts[slot] = partId
			local g = part.Gun or {}
			if g.MagazineAdd and gun.Magazine then
				gun.Magazine = math.max(1, gun.Magazine + g.MagazineAdd)
			end
			if g.ReloadAdd and gun.Reload then
				gun.Reload = math.max(0.3, gun.Reload + g.ReloadAdd)
			end
			local hip = (g.SpreadMult or 1) * (g.HipSpreadMult or 1)
			local ads = (g.SpreadMult or 1) * (g.ADSSpreadMult or 1)
			if gun.Spread.Hip then
				gun.Spread.Hip *= hip
			end
			if gun.Spread.ADS then
				gun.Spread.ADS *= ads
			end
			if g.RecoilMult then
				if gun.Recoil.Pitch then
					gun.Recoil.Pitch *= g.RecoilMult
				end
				if gun.Recoil.Yaw then
					gun.Recoil.Yaw *= g.RecoilMult
				end
				if gun.Recoil.Pattern then
					for _, kick in gun.Recoil.Pattern do
						kick[1] *= g.RecoilMult
						kick[2] *= g.RecoilMult
					end
				end
			end
			if g.RecoverMult and gun.Recoil.Recover then
				gun.Recoil.Recover *= g.RecoverMult
			end
			if g.SettleMult then
				gun.SettleMult = (gun.SettleMult or 1) * g.SettleMult -- Combat multiplies Config.Gunplay.Spread.ADSSettle
			end
			local a = part.Attack or {}
			if a.DamageMult or a.RangeAdd then
				local specs = { out.Heavy }
				for _, spec in out.Attacks do
					table.insert(specs, spec)
				end
				for _, spec in specs do
					if spec and spec.Damage then
						spec.Damage = spec.Damage * (a.DamageMult or 1)
						spec.Range = (spec.Range or 0) + (a.RangeAdd or 0)
					end
				end
			end
			if part.Light then
				out.Light = part.Light
			end
			if part.Laser then
				out.Laser = true
			end
			if part.Quiet then
				out.Quiet = true
			end
		end
	end
	return out
end

-- One line per fitted slot, for the HUD / announcements.
function Attachments.Describe(build)
	local lines = {}
	for _, slot in Attachments.Slots do
		local partId = build and build[slot]
		local part = partId and Attachments.Parts[partId]
		table.insert(lines, ("%s: %s"):format(slot, part and part.Name or "-"))
	end
	return lines
end

return Attachments
