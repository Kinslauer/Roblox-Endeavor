-- Weapon animation made by code (owner, 2026-11-12: "made with fable, meaning no hand drawn animations. We need
-- this ... Start with a pistol and carbine"). Nothing here is a recorded animation: every move is a few key poses
-- on a timeline, joined by easing curves, with overshoot where a real hand or spring would overshoot. The module is
-- pure (no instances): it is told the gun's shape and what is happening, and each step it answers where the gun's
-- moving pieces are, where the off hand is, how the whole gun is turned, and what just happened (a case thrown).
-- war/client/ViewGun.lua applies the answer to the copy in the view.
--
-- All points and moves are in the gun's own frame: barrel along +Z, up +Y, the gun's left +X.
local GunMotion = {}
GunMotion.__index = GunMotion

-- ===== curves =====
local function seg(t, a, b) -- 0 before a, 1 after b
	if b <= a then
		return if t >= b then 1 else 0
	end
	return math.clamp((t - a) / (b - a), 0, 1)
end
local function smooth(u)
	return u * u * (3 - 2 * u)
end
local function outBack(u) -- runs past the end and comes back: a hand arriving, a magazine seating
	local c = 1.70158
	local v = u - 1
	return 1 + (c + 1) * v * v * v + c * v * v
end
local function outCubic(u)
	local v = 1 - u
	return 1 - v * v * v
end
local function bump(u) -- 0 -> 1 -> 0
	return math.sin(math.clamp(u, 0, 1) * math.pi)
end
GunMotion.Curves = { seg = seg, smooth = smooth, outBack = outBack, outCubic = outCubic, bump = bump }

-- shape: { Long, Action = "Slide" | "Carrier" | nil, ActionLength, Charging = bool, GripAt, LeftRest, Mag = centre of
-- the magazine, MagSize = its size, Lo, Hi, Port = where cases leave, Handle = where the hand takes the slide or the
-- charging handle, TopFed = loaded with a clip from above }. T = Config.WarMovement.GunMotion.
function GunMotion.New(shape, T)
	local self = setmetatable({}, GunMotion)
	self.Shape, self.T = shape, T
	self.Kind = if shape.Long then T.Rifle else T.Pistol
	self.Travel = (shape.ActionLength or 0) * self.Kind.Travel
	self.Clock = 0
	self.ShotAt, self.ClickAt = -10, -10
	self.Seq = {} -- name -> { At, Seconds, ... }
	self.Check = 0
	self.Open = 0 -- how far the action is held back (locked open on an empty magazine)
	self.Brass = false
	return self
end

function GunMotion:Shot()
	self.ShotAt = self.Clock
	self.Released = false
	self.Brass = true
end
function GunMotion:Click()
	self.ClickAt = self.Clock
end
-- name: "Reload" { Eject, Insert, Rack = seconds or nil }, "Rack" { Seconds }, "Draw", "Selector"
function GunMotion:Start(name, opts)
	local s = opts or {}
	s.At = self.Clock
	if name == "Reload" then
		s.Seconds = (s.Eject or 0.6) + (s.Insert or 0.9) + (s.Rack or 0)
	else
		s.Seconds = s.Seconds or self.T.Seconds[name] or 0.4
	end
	self.Seq[name] = s
	if name == "Reload" then
		self.Seq.Rack = nil
	end
end
function GunMotion:Stop(name)
	local s = self.Seq[name]
	if s and not s.EndAt then
		s.EndAt = self.Clock -- finished early or late: ease out from wherever it is
	end
end
function GunMotion:Playing(name)
	return self.Seq[name] ~= nil
end

local ZERO = Vector3.zero

-- state: { BoltOpen, Checking, Tired (0..1) }
-- returns { Parts = { name = Vector3 move }, Left = Vector3 or nil (nil: the rest point), LeftWeight (0..1 toward
-- Left), Pos (the whole gun, studs, in the gun's own frame), Rot (degrees: pitch up, yaw left, roll),
-- Brass = true once per shot }
function GunMotion:Step(dt, state)
	self.Clock += dt
	local now, S, K, T = self.Clock, self.Shape, self.Kind, self.T
	local parts = {}
	local pos, rot = ZERO, ZERO
	local left, leftWeight = nil, 0
	local back = Vector3.new(0, 0, -1)

	-- the action on a shot: thrown back fast, pushed home slower
	local since = now - self.ShotAt
	local cyc = 0
	if since < K.CycleSeconds then
		local u = since / K.CycleSeconds
		cyc = if u < K.CycleBack then outCubic(u / K.CycleBack) else 1 - smooth((u - K.CycleBack) / (1 - K.CycleBack))
	end
	-- locked open on an empty magazine: it goes back with the last shot and stays
	-- (once the hand has let it go it stays shut until the gun itself reports the lock off and on again)
	if not state.BoltOpen then
		self.Released = false
	end
	local held = state.BoltOpen and not self.Released
	self.Open += ((if held then 1 else 0) - self.Open) * math.min(1, dt * (if held then 60 else 26))
	local action = math.max(cyc, self.Open)
	local handle = 0 -- the charging handle, moved only by the hand

	-- the trigger: squeezed on a shot or a dry click
	local pull = math.max(bump(seg(now - self.ShotAt, 0, T.TriggerSeconds)), bump(seg(now - self.ClickAt, 0, T.TriggerSeconds)))
	if pull > 0 then
		parts.Trigger = back * (T.TriggerPull * pull)
	end
	local click = bump(seg(now - self.ClickAt, 0, 0.12))
	if click > 0 then
		rot += Vector3.new(-0.5, 0, 0.6) * click
	end

	-- drawing the gun: up from below, arriving a little past its place
	local draw = self.Seq.Draw
	if draw then
		local u = seg(now, draw.At, draw.At + draw.Seconds)
		local away = 1 - outBack(u)
		pos += T.Draw.Position * away
		rot += T.Draw.Rotation * away
		if u >= 1 then
			self.Seq.Draw = nil
		end
	end

	-- the selector: a flick of the thumb rocks the gun
	local sel = self.Seq.Selector
	if sel then
		local u = seg(now, sel.At, sel.At + sel.Seconds)
		rot += T.Selector * bump(u)
		if u >= 1 then
			self.Seq.Selector = nil
		end
	end

	-- tired arms (round 3, the server's w.Fatigue while aiming): the gun wanders in a slow figure, more as they tire
	local tired = state.Tired or 0
	if tired > 0.02 then
		local amp = (K.Sway or 1.2) * tired
		rot += Vector3.new(math.sin(now * 1.3) * amp * 0.6, math.sin(now * 0.9 + 1) * amp, 0)
		pos += Vector3.new(0, math.sin(now * 2.1) * 0.006 * tired, 0)
	end

	-- checking the weapon: turned to show its side while the key is held
	self.Check += ((if state.Checking then 1 else 0) - self.Check) * math.min(1, dt * 8)
	if self.Check > 0.001 then
		local c = smooth(self.Check)
		pos += K.Check.Position * c
		rot += K.Check.Rotation * c
	end

	-- the hand working the action: to the handle, back with it, let go (the action flies home), hand away
	local function rackMove(u)
		-- u 0..1 over the whole move; returns hand weight, pull 0..1
		local reach = smooth(seg(u, 0, 0.3))
		local drawn = if u < 0.62 then smooth(seg(u, 0.3, 0.62)) else 1 - outCubic(seg(u, 0.62, 0.72))
		local leave = 1 - smooth(seg(u, 0.72, 1))
		return math.min(reach, leave), drawn
	end
	local function applyRack(u, weight)
		local w, drawn = rackMove(u)
		local travel = self.Travel * drawn
		if S.Charging then
			handle = math.max(handle, drawn)
		end
		action = math.max(action * (1 - seg(u, 0.3, 0.62)), drawn) -- the hand takes the action over from the lock
		left = S.Handle + back * travel + K.HandleGrip
		leftWeight = math.max(leftWeight, w * weight)
		rot += K.RackRotation * (bump(seg(u, 0.05, 0.95)) * weight)
		pos += back * (T.RackTug * bump(seg(u, 0.3, 0.7)) * weight)
		if u > 0.62 then
			self.Open = 0 -- let go: the lock is off
			self.Released = true
		end
	end

	local rack = self.Seq.Rack
	if rack then
		local u = seg(now, rack.At, rack.At + rack.Seconds)
		applyRack(u, 1)
		if u >= 1 then
			self.Seq.Rack = nil
		end
	end

	-- the reload: tip the gun, hand to the magazine, magazine out and away, a fresh one up and in, rack if empty
	local re = self.Seq.Reload
	if re then
		local t = now - re.At
		local tEject, tInsert, tRack = re.Eject or 0.6, re.Insert or 0.9, re.Rack or 0
		local out = 1 -- how much of the reload pose is on
		if re.EndAt then
			out = 1 - smooth(seg(now, re.EndAt, re.EndAt + T.ReloadEase))
			if out <= 0 then
				self.Seq.Reload = nil
			end
		elseif t >= re.Seconds then
			re.EndAt = now -- done: the gun comes back up
		end
		local tilt = smooth(seg(t, 0, tEject * 0.45)) * out
		pos += K.Reload.Position * tilt
		rot += K.Reload.Rotation * tilt

		local well = if S.TopFed then Vector3.new(0, 1, 0) else K.Well -- the way a magazine (or a clip, from the top) leaves the gun
		local magBottom = S.Mag + Vector3.new(0, -S.MagSize.Y * 0.5, 0)
		local pouch = K.Pouch
		local drop = math.max(S.MagSize.Y * 1.15, 0.25)
		local move, hand, weight
		if t < tEject then
			-- hand arrives (first 45%), strips the magazine (to 80%), carries it off (to 100%)
			local arrive = outBack(seg(t, 0, tEject * 0.45))
			local strip = smooth(seg(t, tEject * 0.45, tEject * 0.8))
			local away = smooth(seg(t, tEject * 0.8, tEject))
			move = well * (drop * strip) + (pouch - magBottom) * away
			hand = magBottom + move + K.MagGrip
			weight = arrive
			pos += well * (T.StripTug * bump(seg(t, tEject * 0.45, tEject * 0.7)))
		elseif t < tEject + tInsert then
			-- the fresh magazine: up from the pouch to under the well (55%), straight in with a bump (to 85%), hand off
			local v = t - tEject
			local rise = smooth(seg(v, 0, tInsert * 0.55))
			local seat = seg(v, tInsert * 0.55, tInsert * 0.8)
			local under = well * drop
			local from = pouch - magBottom
			move = from:Lerp(under, rise):Lerp(ZERO, outBack(seat))
			hand = magBottom + move + K.MagGrip
			weight = if tRack > 0 then 1 else 1 - smooth(seg(v, tInsert * 0.85, tInsert))
			pos += -well * (T.SeatBump * bump(seg(v, tInsert * 0.72, tInsert * 0.9)))
			rot += Vector3.new(T.SeatKick, 0, 0) * bump(seg(v, tInsert * 0.74, tInsert * 0.92))
		else
			move = ZERO
			if tRack > 0 and t < re.Seconds then
				applyRack((t - tEject - tInsert) / tRack, out)
			end
		end
		if move and move.Magnitude > 1e-4 then
			parts.Magazine = move * out
		end
		if hand then
			left = hand
			leftWeight = math.max(leftWeight, weight * out)
		end
	end

	if action > 0.001 and S.Action then
		parts[S.Action] = back * (self.Travel * action)
	end
	if handle > 0.001 then
		parts.Charging = back * (self.Travel * handle)
	end
	local brass = self.Brass and S.Action ~= nil
	self.Brass = false
	return { Parts = parts, Left = left, LeftWeight = leftWeight, Pos = pos, Rot = rot, Brass = brass, Action = action }
end

return GunMotion
