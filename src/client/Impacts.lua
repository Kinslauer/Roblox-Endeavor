-- Impacts (story 003, ADR-0004): what a hit looks like. Registers handlers on CombatFX for every
-- impact kind: sparks, rings, shards, after-images, muzzle flash, plus camera shake and hitstop
-- when the local player is the attacker or the victim. All sizes, colours and durations come from
-- Presentation.Impacts; every instance is parented under workspace.FX and auto-destroyed.
-- Presentation only: never touches Humanoid, attributes, or another character's gameplay state.
local Debris = game:GetService("Debris")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Presentation = require(Shared:WaitForChild("Presentation"))
local CameraShake = require(script.Parent.CameraShake)
local SwingAnimator = require(script.Parent.SwingAnimator)
local CombatFX = require(script.Parent.CombatFX)
local Quality = require(script.Parent.Quality)
local Hud = require(script.Parent.Hud)

local player = Players.LocalPlayer
local I = Presentation.Impacts

local Impacts = {}

local function rootOf(char)
	return typeof(char) == "Instance" and char:FindFirstChild("HumanoidRootPart")
end

local function torsoOf(char)
	return typeof(char) == "Instance" and (char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso") or char:FindFirstChild("HumanoidRootPart"))
end

local function involvesMe(a, b)
	local me = player.Character
	return me ~= nil and (a == me or b == me)
end

local function neonPart(shape, size, color, cframe)
	local part = Instance.new("Part")
	part.Shape = shape
	part.Size = size
	part.Color = color
	part.Material = Enum.Material.Neon
	part.CFrame = cframe
	part.Anchored, part.CanCollide, part.CanQuery, part.CanTouch = true, false, false, false
	return part
end

-- A short burst of particles at a position. ParticleEmitter with the default texture is the
-- placeholder; a Texture id in the spec swaps it.
local function sparks(position, spec)
	if not spec then
		return
	end
	local anchor = neonPart(Enum.PartType.Ball, Vector3.new(0.2, 0.2, 0.2), spec.Color, CFrame.new(position))
	anchor.Transparency = 1
	local emitter = Instance.new("ParticleEmitter")
	if spec.Texture and spec.Texture ~= "" then
		emitter.Texture = spec.Texture
	end
	emitter.Color = ColorSequence.new(spec.Color)
	emitter.LightEmission = 1
	emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, spec.Size), NumberSequenceKeypoint.new(1, 0) })
	emitter.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) })
	emitter.Lifetime = NumberRange.new(spec.Life * 0.6, spec.Life)
	emitter.Speed = NumberRange.new(spec.Speed * 0.5, spec.Speed)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Drag = 4
	emitter.Rate = 0
	emitter.Enabled = false
	emitter.Parent = anchor
	if CombatFX.Spawn(anchor, spec.Life + 0.1) then
		emitter:Emit(Quality.Count("Particles", spec.Count, 3))
	end
end

-- Flat expanding ring (parry).
local function ring(position, spec)
	if not spec then
		return
	end
	local part = neonPart(Enum.PartType.Cylinder, Vector3.new(0.15, 1, 1), spec.Color, CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90)))
	if CombatFX.Spawn(part, spec.Life + 0.05) then
		TweenService:Create(part, TweenInfo.new(spec.Life, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Size = Vector3.new(0.15, spec.Size, spec.Size), Transparency = 1,
		}):Play()
	end
end

-- Physical shards thrown outward (guard break). Unanchored so they tumble.
local function shards(position, spec)
	if not spec then
		return
	end
	for _ = 1, Quality.Count("Shards", spec.Count, 4) do
		local shard = neonPart(Enum.PartType.Block, Vector3.new(spec.Size, spec.Size * 0.4, spec.Size * 0.6), spec.Color, CFrame.new(position) * CFrame.Angles(math.random() * 6, math.random() * 6, 0))
		shard.Anchored = false
		shard.Massless = true
		if CombatFX.Spawn(shard, spec.Life) then
			local dir = Vector3.new(math.random() - 0.5, math.random() * 0.8 + 0.2, math.random() - 0.5).Unit
			shard.AssemblyLinearVelocity = dir * spec.Speed
			TweenService:Create(shard, TweenInfo.new(spec.Life), { Transparency = 1 }):Play()
		end
	end
end

-- Frozen translucent copy of the character's visible parts that fades out (dodge after-image).
local function ghost(char, seconds, color)
	if typeof(char) ~= "Instance" or not seconds or seconds <= 0 or Quality.Scale("Ghost") <= 0 then
		return
	end
	local folder = CombatFX.Folder()
	local count = 0
	for _, part in char:GetChildren() do
		if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" and part.Transparency < 1 then
			count += 1
			if #folder:GetChildren() + count > I.MaxInstances * Quality.Scale("Instances") then
				break
			end
			local copy = Instance.new("Part")
			copy.Size = part.Size
			copy.CFrame = part.CFrame
			copy.Color = color
			copy.Material = Enum.Material.ForceField
			copy.Transparency = 0.4
			copy.Anchored, copy.CanCollide, copy.CanQuery, copy.CanTouch = true, false, false, false
			copy.Parent = folder
			Debris:AddItem(copy, seconds)
			TweenService:Create(copy, TweenInfo.new(seconds), { Transparency = 1 }):Play()
		end
	end
end

local function feel(spec, a, b, heavy)
	-- the bodies freeze for everyone watching (Presentation.Impacts[kind].Freeze); the camera only for mine
	local freeze = (spec.Freeze or 0) * (if heavy then I.HeavyFreezeMult or 1 else 1)
	if freeze > 0 then
		SwingAnimator.Freeze(a, freeze)
		SwingAnimator.Freeze(b, freeze)
	end
	if not involvesMe(a, b) then
		return
	end
	CameraShake.Add(spec.Shake * (if heavy then I.HeavyShakeMult else 1))
	CameraShake.Hitstop(spec.Hitstop * (if heavy then I.HeavyHitstopMult or 1 else 1))
end

-- ===== Handlers =====

local function onHit(victim, info)
	local spec = I.Hit
	local attacker = type(info) == "table" and info.attacker or nil
	local amount = type(info) == "table" and tonumber(info.amount) or 0
	local torso = torsoOf(victim)
	if torso then
		sparks(torso.Position, spec.Sparks)
	end
	feel(spec, victim, attacker, amount >= spec.HeavyAmount)
end

local function onBlock(victim, attacker)
	local spec = I.Block
	local torso = torsoOf(victim)
	if torso then
		-- in front of the blocker, where the guard would be
		sparks(torso.Position + torso.CFrame.LookVector * 1.5, spec.Sparks)
	end
	feel(spec, victim, attacker)
end

local function onParry(victim, attacker)
	local spec = I.Parry
	local torso = torsoOf(victim)
	if torso then
		local at = torso.Position + torso.CFrame.LookVector * 1.5
		sparks(at, spec.Sparks)
		ring(at, spec.Ring)
	end
	feel(spec, victim, attacker)
end

local function onGuardBreak(victim, attacker)
	local spec = I.GuardBreak
	local torso = torsoOf(victim)
	if torso then
		shards(torso.Position + torso.CFrame.LookVector * 1.2, spec.Shards)
	end
	feel(spec, victim, attacker)
end

local function onDodged(victim, attacker)
	local spec = I.Dodged
	ghost(victim, spec.Ghost, spec.Color)
	feel(spec, victim, attacker)
end

local function onBlackFlash(attacker, victim)
	local spec = I.BlackFlash
	local vroot = rootOf(victim)
	if vroot then
		local spark = neonPart(Enum.PartType.Ball, Vector3.new(2, 2, 2), spec.Color, CFrame.new(vroot.Position))
		if CombatFX.Spawn(spark, spec.Flash + 0.05) then
			TweenService:Create(spark, TweenInfo.new(spec.Flash), { Size = Vector3.new(12, 12, 12), Transparency = 1 }):Play()
		end
	end
	SwingAnimator.Freeze(attacker, spec.Freeze)
	SwingAnimator.Freeze(victim, spec.Freeze)
	if involvesMe(attacker, victim) then
		local cc = Instance.new("ColorCorrectionEffect")
		cc.Brightness, cc.Contrast, cc.Saturation, cc.TintColor = -0.35, 0.6, -1, Color3.fromRGB(255, 120, 120)
		cc.Parent = Lighting
		TweenService:Create(cc, TweenInfo.new(0.4), { Brightness = 0, Contrast = 0, Saturation = 0, TintColor = Color3.new(1, 1, 1) }):Play()
		Debris:AddItem(cc, 0.5)
		Hud.Banner(("BLACK FLASH  x%.1f"):format(Config.Flicker.BlackFlashMult), spec.Color, spec.BannerSeconds)
		CameraShake.Add(spec.Shake)
		CameraShake.Hitstop(spec.Hitstop)
	end
end

local function onBolt(char, hitPos)
	local spec = I.Bolt
	local from = rootOf(char)
	if not from or typeof(hitPos) ~= "Vector3" then
		return
	end
	-- from the gun's muzzle when there is one (owner s2-3: "closer to the origin"), else the hand
	local hand = char:FindFirstChild("RightHand") or char:FindFirstChild("Right Arm") or from
	local view = char:FindFirstChild("WeaponView")
	local muzzleAt = view and view:FindFirstChild("Muzzle", true)
	local origin = if muzzleAt and muzzleAt:IsA("BasePart") then muzzleAt.Position else hand.Position
	local length = (hitPos - origin).Magnitude
	local beam = neonPart(Enum.PartType.Block, Vector3.new(0.2, 0.2, length), spec.Color, CFrame.lookAt(origin, hitPos) * CFrame.new(0, 0, -length / 2))
	CombatFX.Spawn(beam, spec.Flash)
	local muzzle = neonPart(Enum.PartType.Ball, Vector3.new(spec.Muzzle.Size, spec.Muzzle.Size, spec.Muzzle.Size), spec.Color, CFrame.new(origin))
	CombatFX.Spawn(muzzle, spec.Muzzle.Life)
	sparks(hitPos, spec.Sparks)
	if char == player.Character then
		CameraShake.Add(I.Burst.Shake)
	end
end

-- Snatch: a hook beam from the user's hand to the target (nil target = a whiff: short stub).
local function onSnatch(char, target)
	local spec = I.Snatch
	local hand = char:FindFirstChild("RightHand") or rootOf(char)
	if not hand then
		return
	end
	local origin = hand.Position
	local targetRoot = typeof(target) == "Instance" and rootOf(target)
	local to = targetRoot and targetRoot.Position or (origin + hand.CFrame.LookVector * 6)
	local length = (to - origin).Magnitude
	local beam = neonPart(Enum.PartType.Block, Vector3.new(spec.Beam.Width, spec.Beam.Width, length), spec.Color, CFrame.lookAt(origin, to) * CFrame.new(0, 0, -length / 2))
	CombatFX.Spawn(beam, spec.Beam.Life)
	if targetRoot then
		CombatFX.Flash(target, spec.Color, spec.Flash)
	end
	if char == player.Character then
		CameraShake.Add(spec.Shake)
	end
end

-- Buster: gold flash + heavy shake on a throw; a plain flash on a shove.
local function onBuster(char, data)
	local spec = I.Buster
	local target = typeof(data) == "table" and data.target or nil
	local throw = typeof(data) == "table" and data.throw == true
	if typeof(target) == "Instance" then
		CombatFX.Flash(target, spec.Color, if throw then spec.Flash else spec.Flash * 0.5)
	end
	if throw and (char == player.Character or target == player.Character) then
		CameraShake.Add(spec.Shake)
		CameraShake.Hitstop(spec.Hitstop)
	end
end

-- Launch: a vertical streak under the body on the way up, shake for the attacker.
local function onLaunch(victim, attacker)
	local spec = I.Launch
	local root = rootOf(victim)
	if not root then
		return
	end
	local S = spec.Streak
	local streak = neonPart(Enum.PartType.Block, Vector3.new(S.Width, S.Height, S.Width), spec.Color, root.CFrame * CFrame.new(0, -S.Height / 2 - 1, 0))
	CombatFX.Spawn(streak, S.Life)
	if streak then
		TweenService:Create(streak, TweenInfo.new(S.Life), { Transparency = 1, Size = Vector3.new(S.Width * 0.2, S.Height * 1.6, S.Width * 0.2) }):Play()
	end
	if attacker == player.Character then
		CameraShake.Add(spec.Shake)
		CameraShake.Hitstop(spec.Hitstop)
	end
end

-- Juggle: a short hitstop per pop for the one doing the juggling.
local function onJuggle(victim)
	local spec = I.Juggle
	local root = rootOf(victim)
	if root and (root.Position - (rootOf(player.Character) and rootOf(player.Character).Position or root.Position)).Magnitude < 14 then
		CameraShake.Add(spec.Shake)
		CameraShake.Hitstop(spec.Hitstop)
	end
end

function Impacts.Init()
	CombatFX.On("Hit", onHit)
	CombatFX.On("Launch", onLaunch)
	CombatFX.On("Juggle", onJuggle)
	CombatFX.On("Block", onBlock)
	CombatFX.On("Parry", onParry)
	CombatFX.On("GuardBreak", onGuardBreak)
	CombatFX.On("Dodged", onDodged)
	CombatFX.On("BlackFlash", onBlackFlash)
	CombatFX.On("Bolt", onBolt)
	CombatFX.On("Snatch", onSnatch)
	CombatFX.On("Buster", onBuster)
end

return Impacts
