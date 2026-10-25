-- One standardized R15 body for everybody. We never use the player's own Roblox avatar:
-- characters are built from a HumanoidDescription made out of the Appearance catalog, so
-- hitboxes, reach, animation joints and gear attachment points are identical for all players.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Appearance = require(ReplicatedStorage.Shared.Appearance)
local PlayerData = require(script.Parent.PlayerData)

local Rig = {}

-- The 15 R15 parts, used by gear visuals and limb loss.
Rig.PartNames = {
	"Head", "UpperTorso", "LowerTorso",
	"LeftUpperArm", "LeftLowerArm", "LeftHand",
	"RightUpperArm", "RightLowerArm", "RightHand",
	"LeftUpperLeg", "LeftLowerLeg", "LeftFoot",
	"RightUpperLeg", "RightLowerLeg", "RightFoot",
}

local function makeDescription(resolved)
	local d = Instance.new("HumanoidDescription")
	local body = resolved.BodyType
	d.HeightScale, d.WidthScale, d.DepthScale, d.HeadScale = body.Height, body.Width, body.Width, 1
	d.BodyTypeScale, d.ProportionScale = body.BodyType, body.Proportion
	local skin = resolved.SkinTone.Color
	d.HeadColor, d.TorsoColor = skin, skin
	d.LeftArmColor, d.RightArmColor, d.LeftLegColor, d.RightLegColor = skin, skin, skin, skin
	d.Face = resolved.Face.Id
	-- Deliberately no clothing / accessories / animation packs: the base body is a plain mannequin,
	-- and everything visible beyond it comes from gear (see Visuals).
	return d
end

-- Hair is procedural (no catalog ids). Each entry: size and offset relative to the head.
local function hairParts(style, head)
	local s = head.Size
	local W, H, D = s.X + 0.12, s.Y, s.Z + 0.12
	if style == "Buzz" then
		return { { Vector3.new(W, 0.18, D), CFrame.new(0, H / 2 - 0.02, 0) } }
	elseif style == "Crop" then
		return {
			{ Vector3.new(W, 0.38, D), CFrame.new(0, H / 2 + 0.05, 0) },
			{ Vector3.new(W, 0.3, 0.2), CFrame.new(0, H / 2 - 0.2, -D / 2 + 0.04) },
		}
	elseif style == "Mohawk" then
		return { { Vector3.new(0.28, 0.6, D), CFrame.new(0, H / 2 + 0.2, 0) } }
	elseif style == "Long" then
		return {
			{ Vector3.new(W, 0.38, D), CFrame.new(0, H / 2 + 0.05, 0) },
			{ Vector3.new(W, 1.6, 0.3), CFrame.new(0, -0.15, D / 2 - 0.05) },
			{ Vector3.new(0.28, 1.0, D * 0.7), CFrame.new(W / 2 - 0.04, 0, 0.1) },
			{ Vector3.new(0.28, 1.0, D * 0.7), CFrame.new(-W / 2 + 0.04, 0, 0.1) },
		}
	end
	return {}
end

local function applyHair(char, resolved)
	local head = char:FindFirstChild("Head")
	if not head then
		return
	end
	for _, child in char:GetChildren() do
		if child:GetAttribute("RigHair") then
			child:Destroy()
		end
	end
	local folder = Instance.new("Folder")
	folder.Name = "Hair"
	folder:SetAttribute("RigHair", true)
	for _, def in hairParts(resolved.Hair.Style, head) do
		local p = Instance.new("Part")
		p.Size, p.Color, p.Material = def[1], resolved.HairColor.Color, Enum.Material.SmoothPlastic
		p.CanCollide, p.CanTouch, p.CanQuery, p.Massless = false, false, false, true
		p.CFrame = head.CFrame * def[2]
		local weld = Instance.new("WeldConstraint")
		weld.Part0, weld.Part1 = head, p
		weld.Parent = p
		p.Parent = folder
	end
	folder.Parent = char
end

-- Builds a standalone R15 model (not parented). Yields.
function Rig.Build(appearance)
	local resolved = Appearance.Resolve(appearance)
	local model = Players:CreateHumanoidModelFromDescription(makeDescription(resolved), Enum.HumanoidRigType.R15)
	applyHair(model, resolved)
	-- Created server-side so animations played by the owning client replicate to everyone.
	local hum = model:FindFirstChildOfClass("Humanoid")
	if hum and not hum:FindFirstChildOfClass("Animator") then
		Instance.new("Animator").Parent = hum
	end
	return model, resolved
end

-- Re-skins an existing character (used by the creator for live preview). Yields.
function Rig.Apply(char, appearance)
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not hum or hum.Health <= 0 then
		return
	end
	local resolved = Appearance.Resolve(appearance)
	local ok, err = pcall(hum.ApplyDescription, hum, makeDescription(resolved))
	if not ok then
		warn("[Rig] ApplyDescription failed:", err)
		return
	end
	applyHair(char, resolved)
end

-- Replaces player.Character with a fresh standardized body. Yields. Returns the new character.
function Rig.Spawn(player)
	local data = PlayerData.Get(player)
	local model = Rig.Build(data and data.Appearance)
	model.Name = player.Name
	local old = player.Character
	-- Spawn out of the way; the caller PivotTo()s it into place straight afterwards.
	model:PivotTo(CFrame.new(0, 5000, 0))
	player.Character = model
	model.Parent = workspace
	if old then
		old:Destroy()
	end
	return model
end

return Rig
