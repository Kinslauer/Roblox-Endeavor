-- Firearm simulation. A gun is a mechanism, not a damage number: it has a chamber, a magazine
-- with rounds, a bolt, a safety and a selector, and five parts that wear. The client only
-- presses buttons; every state change and every bullet is resolved here.
--
-- Weapon state: { Id, Def, Parts = {Receiver..}, Attachments = {Optic..}, Mag = n or nil (no mag),
--   Spare = { n, n, ... } magazines carried, Chamber = bool, BoltOpen = bool, Mode = "Safe"|..,
--   Jammed = bool, LastShot = t, Busy until t }
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Firearms = require(Shared.Firearms)
local Remotes = require(Shared.Remotes)

local Guns = {}
Guns.Hit = Instance.new("BindableEvent") -- (shooterPlayer, victimModel, zone, damage, killed)

local GRAVITY = 196.2 * 0.5 -- studs/s^2 (half gravity: Roblox scale makes real drop feel like a mortar)
local rng = Random.new()

-- ===== building a weapon from a kit entry =====
function Guns.Make(id, condition, attachments)
	local def = Firearms.Defs[id]
	if not def then
		return nil
	end
	local parts = {}
	for _, name in Firearms.Parts do
		parts[name] = condition or 100
	end
	local w = {
		Id = id, Def = def, Parts = parts, Attachments = {}, Mag = def.MagSize - 1, Spare = {}, Chamber = true, BoltOpen = false, Reloading = false,
		Mode = def.Modes[1], Jammed = false, LastShot = 0, Busy = 0, Aiming = false,
		-- round 3: the load in its magazines, loose rounds to thumb in, the barrel's heat, the kind of jam
		Load = "Ammo", Loose = 0, Heat = 0, HeatAt = 0, JamKind = nil,
	}
	for slot, att in attachments or {} do
		if table.find(def.Slots, slot) and Firearms.Attachments[att.Id] and Firearms.Attachments[att.Id].Slot == slot then
			w.Attachments[slot] = { Id = att.Id, Condition = att.Condition or 100 }
		end
	end
	return w
end

function Guns.AddMagazines(w, count)
	for _ = 1, count do
		table.insert(w.Spare, w.Def.MagSize)
	end
end

-- The barrel's heat now (Config.Guns.Heat: per shot by kind of gun, cooling per second).
local G = Config.Guns
function Guns.Heat(w)
	return math.max(0, (w.Heat or 0) - (os.clock() - (w.HeatAt or 0)) * G.Heat.Cool)
end

-- What the client is allowed to know (Tarkov-style: it sees the mechanism, not a hit scan).
function Guns.Snapshot(w)
	if not w then
		return nil
	end
	return { Id = w.Id, Name = w.Def.Name, Mode = w.Mode, Chamber = w.Chamber, BoltOpen = w.BoltOpen, Jammed = w.Jammed, Reloading = w.Reloading, Mag = w.Mag,
		MagSize = w.Def.MagSize, Spare = #w.Spare, Parts = w.Parts, Attachments = w.Attachments, Busy = math.max(0, w.Busy - os.clock()),
		Zoom = (w.Attachments.Optic and Firearms.Attachments[w.Attachments.Optic.Id] and Firearms.Attachments[w.Attachments.Optic.Id].Zoom) or 1,
		Load = Firearms.LoadOf(w.Load).Name, Loose = w.Loose or 0, Heat = math.floor(Guns.Heat(w) * 100 + 0.5) / 100, JamKind = w.JamKind,
		Fatigue = w.Fatigue }
end

local function attMult(w, key)
	local m = 1
	for _, att in w.Attachments do
		local def = Firearms.Attachments[att.Id]
		if def and def[key] then
			m *= def[key]
		end
	end
	return m
end

Guns.AttMult = attMult

local function busy(w, seconds)
	w.Busy = math.max(w.Busy, os.clock()) + seconds
end

local function isBusy(w)
	return os.clock() < w.Busy
end

-- ===== the mechanism =====
function Guns.CycleMode(w)
	if isBusy(w) then
		return
	end
	local i = table.find(w.Def.Modes, w.Mode) or 1
	w.Mode = w.Def.Modes[i % #w.Def.Modes + 1]
end

-- Pull the bolt: ejects whatever is chambered (live or dud) and chambers the next round.
-- A jam is cleared with Unjam, which takes longer; racking a jammed gun does nothing.
local function rack(w)
	busy(w, w.Def.Reload.Rack)
	w.Chamber = false
	w.BoltOpen = false
	if w.Mag and w.Mag > 0 then
		w.Mag -= 1
		w.Chamber = true
	else
		w.BoltOpen = true -- bolt locks back on an empty mag (or no mag)
	end
end

function Guns.Rack(w)
	if isBusy(w) or w.Reloading then
		return
	end
	if w.Jammed then
		if w.JamKind == "Stovepipe" then
			Guns.Unjam(w) -- the caught case goes out with the rack
		end
		return
	end
	rack(w)
end

-- Reload in stages: drop the magazine, seat a fresh one, and if the chamber is empty, rack. A mint
-- gun does this fast; a worn one is slower. `keep` is the careful reload: the half-used magazine
-- goes back in the pouch, which takes longer. The quick one lets it fall, rounds and all.
function Guns.Reload(w, keep, quickMult, carefulMult)
	if isBusy(w) or w.Reloading then
		return false
	end
	if #w.Spare == 0 then
		return Guns.HandLoad(w)
	end
	w.Reloading = true
	local r = w.Def.Reload
	local wear = 1 + (1 - (w.Parts.Magazine or 100) / 100) * 0.5
	local partial = w.Mag and w.Mag > 0
	if partial then
		wear *= if keep then carefulMult or 1.35 else quickMult or 0.8
	end
	-- pick the fullest spare
	table.sort(w.Spare, function(a, b) return a > b end)
	local fresh = table.remove(w.Spare, 1)
	if partial and keep then
		table.insert(w.Spare, w.Mag) -- back in the pouch
	end
	w.Dropped = if partial and not keep then w.Mag else nil -- rounds left on the ground (tests read it)
	w.Mag = nil
	busy(w, r.EjectMag * wear)
	task.delay(r.EjectMag * wear, function()
		w.Mag = fresh
		busy(w, r.InsertMag * wear)
		task.delay(r.InsertMag * wear, function()
			if w.Jammed then
				w.Jammed, w.JamKind, w.Chamber = false, nil, false -- the magazine out clears any jam
			end
			if not w.Chamber then
				rack(w) -- the stage sequence owns the gun; it never gets stuck on a busy check
			end
			w.Reloading = false
		end)
	end)
	return true
end

-- No magazine left in the pouch: the one in the gun comes out, loose rounds go into it one by one
-- (Config.Guns.PerRound each), back in, rack if empty. Returns false with nothing to load.
function Guns.HandLoad(w)
	local room = w.Def.MagSize - (w.Mag or 0)
	local count = math.min(room, w.Loose or 0)
	if isBusy(w) or w.Reloading or count <= 0 then
		return false
	end
	w.Reloading = true
	w.HandLoading = true
	local r = w.Def.Reload
	local before = w.Mag or 0
	w.Mag = nil
	local thumb = count * G.PerRound
	busy(w, r.EjectMag + thumb)
	task.delay(r.EjectMag + thumb, function()
		w.Loose -= count
		w.Mag = before + count
		busy(w, r.InsertMag)
		task.delay(r.InsertMag, function()
			if w.Jammed then
				w.Jammed, w.JamKind, w.Chamber = false, nil, false
			end
			if not w.Chamber then
				rack(w)
			end
			w.Reloading = false
			w.HandLoading = nil
		end)
	end)
	return true
end

function Guns.Unjam(w)
	if not w.Jammed or isBusy(w) then
		return
	end
	-- each kind takes its own time (a double feed strips the magazine and puts it back)
	local seconds = (Firearms.JamSeconds[w.JamKind or "Feed"] or 1.2) + (1 - (w.Parts.Receiver or 100) / 100) * 1.5
	busy(w, seconds)
	task.delay(seconds, function()
		w.Jammed, w.JamKind = false, nil
		rack(w)
	end)
end

local function jamKind()
	local total = 0
	for _, k in Firearms.JamKinds do
		total += k[2]
	end
	local at = rng:NextNumber() * total
	for _, k in Firearms.JamKinds do
		at -= k[2]
		if at <= 0 then
			return k[1]
		end
	end
	return "Feed"
end
Guns.JamKind = jamKind

-- One trigger pull. Returns "fired" | "dry" | "safe" | "jam" | "busy" | "dud".
function Guns.Trigger(w)
	if isBusy(w) then
		return "busy"
	end
	if w.Mode == "Safe" then
		return "safe"
	end
	if w.Jammed then
		return "jam"
	end
	local interval = 60 / w.Def.RPM
	if os.clock() - w.LastShot < interval then
		return "busy"
	end
	if not w.Chamber then
		return "dry"
	end
	-- a cooked barrel: no more until it has cooled under Hot
	local h = Guns.Heat(w)
	if w.Cooked and h <= G.Heat.Hot then
		w.Cooked = nil
	end
	if w.Cooked or h >= 1 then
		w.Cooked = true
		return "hot"
	end
	w.LastShot = os.clock()
	w.Chamber = false
	local add = if table.find(w.Def.Modes, "Auto") then G.Heat.Auto elseif w.Def.Class == "Pistol" then G.Heat.Pistol else G.Heat.Rifle
	w.Heat, w.HeatAt = math.min(1, h + add), os.clock()
	-- wear: every shot takes a little off the barrel and bolt; dirtier = worse
	w.Parts.Barrel = math.max(0, w.Parts.Barrel - 0.08)
	w.Parts.Bolt = math.max(0, w.Parts.Bolt - 0.05)
	if rng:NextNumber() < Firearms.MalfunctionChance(w.Parts) + G.Jam.Heat * h * h then -- worn parts, a hot action
		w.Jammed = true
		w.JamKind = jamKind()
		return "jam" -- the round is lost, the action is fouled
	end
	-- self-loading guns chamber the next round; bolt actions wait for the rack
	if not w.Def.BoltAction then
		if w.Mag and w.Mag > 0 then
			w.Mag -= 1
			w.Chamber = true
		else
			w.BoltOpen = true
		end
	end
	return "fired"
end

-- ===== ballistics =====
local function zoneOf(partName)
	if partName == "Head" then
		return "Head"
	elseif partName == "Torso" or partName == "UpperTorso" or partName == "LowerTorso" or partName == "HumanoidRootPart" then
		return "Torso"
	end
	return "Limb"
end

-- Fires a simulated round from `origin` along `dir` (unit). Steps the projectile with gravity,
-- raycasting each segment, until it hits something or runs out of range.
function Guns.Shoot(shooter, w, origin, dir, onHit)
	local ammo = Firearms.Ammo[w.Def.Ammo]
	local load = Firearms.LoadOf(w.Load)
	local h = Guns.Heat(w)
	local hot = if h > G.Heat.Hot then 1 + (h - G.Heat.Hot) / (1 - G.Heat.Hot) * G.FrontHeatSpread else 1
	local spreadDeg = (if w.Aiming then w.Def.AdsSpread else w.Def.Spread) * Firearms.SpreadMult(w.Parts) * (w.Steady or 1) * attMult(w, "Spread") * hot
	local spread = math.rad(spreadDeg)
	local yaw, pitch = rng:NextNumber(-spread, spread), rng:NextNumber(-spread, spread)
	dir = (CFrame.lookAt(Vector3.zero, dir) * CFrame.Angles(pitch, yaw, 0)).LookVector
	local speed = ammo.Velocity * attMult(w, "Velocity")
	local vel = dir * speed
	local pos = origin
	local travelled = 0
	local ray = RaycastParams.new()
	ray.FilterType = Enum.RaycastFilterType.Exclude
	ray.FilterDescendantsInstances = { shooter.Character }
	local maxRange = ammo.Range * 2.5
	Remotes.Weapon:FireAllClients("Shot", shooter.Character, origin, dir, attMult(w, "Loudness"))
	local force = load.Damage -- a glance off plate keeps going with less (Config.Guns.Ricochet)
	local glanced = false
	task.spawn(function()
		local dt = 1 / 60
		while travelled < maxRange do
			local nextPos = pos + vel * dt
			local hit = workspace:Raycast(pos, nextPos - pos, ray)
			if hit then
				local model = hit.Instance:FindFirstAncestorOfClass("Model")
				local hum = model and model:FindFirstChildOfClass("Humanoid")
				if hum and hum.Health > 0 then
					local falloff = 1 - math.clamp(travelled / ammo.Range, 0, 1) * (1 - ammo.Falloff)
					local zone = zoneOf(hit.Instance.Name)
					local damage = ammo.Damage * falloff * Firearms.Zones[zone] * force
					local stopped = onHit(model, zone, damage, math.clamp(ammo.Pen + load.Pen, 0, 0.95), hit.Position)
					local u = vel.Unit
					if stopped and not glanced and math.abs(u:Dot(hit.Normal)) < G.Ricochet.Dot then
						-- off the plate at a glance: on along the mirror line, slower and weaker, never through him again
						glanced = true
						force *= G.Ricochet.Damage
						vel = (u - 2 * u:Dot(hit.Normal) * hit.Normal) * vel.Magnitude * G.FrontRicochetSpeed
						pos = hit.Position + hit.Normal * 0.05
						local list = ray.FilterDescendantsInstances
						table.insert(list, model)
						ray.FilterDescendantsInstances = list
						Remotes.Weapon:FireAllClients("Ricochet", hit.Position, vel.Unit)
						continue
					end
				else
					Remotes.Weapon:FireAllClients("Impact", hit.Position, hit.Normal)
					if Guns.OnSurface then -- the simulation's blocks break under fire (Simulation.lua)
						Guns.OnSurface(hit.Instance, hit.Position, ammo.Damage, shooter)
					end
				end
				return
			end
			travelled += (nextPos - pos).Magnitude
			pos = nextPos
			vel = vel - Vector3.new(0, GRAVITY * dt, 0)
			if travelled > 400 then
				RunService.Heartbeat:Wait() -- long shots take real time to arrive
			end
		end
	end)
end

return Guns
