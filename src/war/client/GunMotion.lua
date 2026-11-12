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
	self.Bare = 0 -- how much the gun shows its empty well (no magazine in it)
	self.HasMag = nil -- whether the magazine is in the gun, as the hands left it (nil: not known yet)
	self.SeqEnd = -10
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
-- name: "MagOut" { Seconds, Keep }, "MagIn" { Seconds }, "Rack" { Seconds }, "Release" (the slide let go by the
-- thumb), "Draw", "Selector"
function GunMotion:Start(name, opts)
	local s = opts or {}
	s.At = self.Clock
	s.Seconds = s.Seconds or self.T.Seconds[name] or 0.4
	s.Done = {} -- the marks on its timeline that have been passed
	self.Seq[name] = s
	if name == "MagOut" then
		self.Seq.MagIn, self.Seq.Rack = nil, nil
	elseif name == "MagIn" then
		self.Seq.MagOut, self.Seq.Rack = nil, nil
	end
end
function GunMotion:Stop(name)
	self.Seq[name] = nil
end
function GunMotion:Playing(name)
	return self.Seq[name] ~= nil
end

local ZERO = Vector3.zero

-- state: { BoltOpen, NoMag (the server's word that no magazine is in the gun), Checking, Aim (0..1), Tired (0..1) }
-- returns { Parts = { name = Vector3 move }, Hide = { name = true } (a piece that is not on the gun now), Left =
-- Vector3 or nil (nil: the rest point), LeftWeight (0..1 toward Left), Pos (the whole gun, studs, in the gun's own
-- frame), Rot (degrees: pitch up, yaw left, roll), Kick = { Rot, Pos } or nil (a jolt for the gun's springs: speed),
-- Brass = true once per shot, DropMag = true once when a magazine is let fall }
function GunMotion:Step(dt, state)
	self.Clock += dt
	local now, S, K, T = self.Clock, self.Shape, self.Kind, self.T
	local parts, hide = {}, {}
	local pos, rot = ZERO, ZERO
	local left, leftWeight = nil, 0
	local back = Vector3.new(0, 0, -1)
	local kickRot, kickPos = ZERO, ZERO
	local dropMag = false
	local grip = nil -- what the off hand is on: "Mag", "Handle", "Pouch" (reaching, empty), nil = its rest on the gun
	-- a mark on a timeline: true the one step it is passed; its jolt goes to the gun's springs
	local function mark(seq, name, u, at)
		if u >= at and not seq.Done[name] then
			seq.Done[name] = true
			local j = T.Jolt[name]
			if j then
				kickRot += j.Rot
				kickPos += j.Pos
			end
			return true
		end
		return false
	end

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

	-- tired arms (the server's w.Fatigue while aiming): the gun wanders in a slow figure, more as they tire
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
	local rack = self.Seq.Rack
	if rack then
		local u = seg(now, rack.At, rack.At + rack.Seconds)
		local reach = smooth(seg(u, 0, 0.3))
		local drawn = if u < 0.62 then smooth(seg(u, 0.3, 0.62)) else 1 - outCubic(seg(u, 0.62, 0.72))
		local leave = 1 - smooth(seg(u, 0.72, 1))
		if S.Charging then
			handle = math.max(handle, drawn)
		end
		action = math.max(action * (1 - seg(u, 0.3, 0.62)), drawn) -- the hand takes the action over from the lock
		left = S.Handle + back * (self.Travel * drawn) + K.HandleGrip
		grip = "Handle"
		leftWeight = math.max(leftWeight, math.min(reach, leave))
		rot += K.RackRotation * bump(seg(u, 0.05, 0.95))
		mark(rack, "Back", u, 0.6) -- the action hits its stop
		if u > 0.62 then
			self.Open = 0 -- let go: the lock is off
			self.Released = true
		end
		mark(rack, "Home", u, 0.72) -- and slams shut
		if u >= 1 then
			self.Seq.Rack = nil
			self.SeqEnd = now
		end
	end
	-- the slide let go by the thumb: no hand leaves the gun, the slide just runs home
	local rel = self.Seq.Release
	if rel then
		local u = seg(now, rel.At, rel.At + rel.Seconds)
		if u > 0.35 then
			self.Open = 0
			self.Released = true
		end
		mark(rel, "Home", u, 0.55)
		if u >= 1 then
			self.Seq.Release = nil
		end
	end

	-- the magazine. What the hands last did decides whether it is in the gun; with no move under way the server's
	-- word is taken (a moment after a move ends, so a late message does not undo it).
	local out, into = self.Seq.MagOut, self.Seq.MagIn
	if self.HasMag == nil or (not out and not into and now - self.SeqEnd > 0.6) then
		self.HasMag = not state.NoMag
	end
	local well = if S.TopFed then Vector3.new(0, 1, 0) else K.Well -- the way a magazine (or a clip, from above) leaves
	local magFoot = S.Mag + well * (S.MagSize.Y * 0.5)
	local drop = math.max(S.MagSize.Y * 1.15, 0.25)
	local pouch = K.Pouch
	local tilt = 0 -- how much of the magazine-change pose is on
	if out then
		local u = seg(now, out.At, out.At + out.Seconds)
		tilt = smooth(seg(u, 0, 0.3))
		if out.Keep then
			-- the hand arrives, strips the magazine down the well and carries it to the pouch
			local arrive = outBack(seg(u, 0, 0.38))
			local strip = smooth(seg(u, 0.42, 0.72))
			local away = smooth(seg(u, 0.72, 1))
			local move = well * (drop * strip) + (pouch - magFoot - well * drop) * away
			mark(out, "Strip", u, 0.42)
			if move.Magnitude > 1e-4 then
				parts.Magazine = move
			end
			left, leftWeight = magFoot + move + K.MagGrip, arrive
			grip = "Mag"
		else
			-- the catch is pressed and the magazine falls free; the off hand is already going for the next one
			if mark(out, "Strip", u, 0.3) then
				dropMag = true
				out.Fell = true
			end
			if out.Fell then
				hide.Magazine = true
			end
			left, leftWeight = pouch, smooth(seg(u, 0.2, 0.85))
			grip = "Pouch"
		end
		if u >= 1 then
			self.Seq.MagOut = nil
			self.HasMag = false
			self.SeqEnd = now
			self.HandAtPouch = now
		end
	elseif into then
		-- a magazine comes up from the pouch, stops short under the well, backs off a touch, is driven home; the
		-- hand rebounds off it, tugs it to feel that it holds, and goes back to the gun
		local u = seg(now, into.At, into.At + into.Seconds)
		local short, wind = drop * T.Seat.Short, drop * T.Seat.WindUp
		local along -- how far down the well the magazine is
		local rise = smooth(seg(u, 0.05, 0.5))
		if u < 0.5 then
			along = nil
		elseif u < 0.6 then
			along = short + wind * smooth(seg(u, 0.5, 0.6))
		else
			local v = seg(u, 0.6, 0.7)
			along = (short + wind) * (1 - v * v)
		end
		local move
		if along == nil then
			move = (pouch - magFoot):Lerp(well * short, rise)
			if u < 0.05 then
				hide.Magazine = true
			end
		else
			move = well * along
		end
		local seated = mark(into, "Seat", u, 0.7)
		if seated then
			self.HasMag = true
		end
		local hand = magFoot + move + K.MagGrip
		if u >= 0.7 then
			move = ZERO
			local rebound = bump(seg(u, 0.7, 0.8)) * drop * T.Seat.Rebound
			local tug = bump(seg(u, 0.8, 0.9)) * drop * T.Seat.Tug
			hand = magFoot + K.MagGrip + well * (rebound + tug)
			mark(into, "Tug", u, 0.85)
		end
		if move.Magnitude > 1e-4 then
			parts.Magazine = move
		end
		left, leftWeight = hand, 1 - smooth(seg(u, 0.9, 1))
		grip = "Mag"
		tilt = 1 - smooth(seg(u, 0.78, 1))
		if u >= 1 then
			self.Seq.MagIn = nil
			self.HasMag = true
			self.SeqEnd = now
		end
	elseif not self.HasMag then
		hide.Magazine = true
	end
	-- with no magazine in it the gun stays tipped a little, showing its empty well (less so at the sights)
	local bare = if self.HasMag or into then 0 else T.Bare * (1 - (state.Aim or 0))
	self.Bare += (bare - self.Bare) * math.min(1, dt * 7)
	tilt = math.max(tilt, self.Bare)
	if tilt > 0.001 then
		pos += K.Reload.Position * tilt
		rot += K.Reload.Rotation * tilt
	end

	if action > 0.001 and S.Action then
		parts[S.Action] = back * (self.Travel * action)
	end
	if handle > 0.001 then
		parts.Charging = back * (self.Travel * handle)
	end
	local brass = self.Brass and S.Action ~= nil
	self.Brass = false
	return {
		Parts = parts, Hide = hide, Left = left, LeftWeight = leftWeight, Pos = pos, Rot = rot, Brass = brass, Action = action,
		Kick = if kickRot ~= ZERO or kickPos ~= ZERO then { Rot = kickRot, Pos = kickPos } else nil, DropMag = dropMag, Grip = grip,
	}
end

return GunMotion
