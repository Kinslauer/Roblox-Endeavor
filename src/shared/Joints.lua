-- Joints: procedural pose offsets that work on both joint systems a character can have.
--   * Motor6D (our Blender rigs, the Conduit StarterCharacter, older avatars): the offset goes on C0.
--   * AnimationConstraint (Roblox's newer avatar joints, which build every R15 avatar since the
--     "Avatar Joint Upgrade"; verified live 2026-11-04): the offset goes on Attachment0's CFrame, the
--     parent-side rig attachment, which plays the same role as C0.
-- Either way the Animator keeps writing Transform underneath, so idle/walk still play through a pose.
-- Used by both clients (swing/block/flinch poses, the Front's rifle hold) and client/Movement (lean).
local TweenService = game:GetService("TweenService")

local Joints = {}

local base = setmetatable({}, { __mode = "k" }) -- joint -> its rest offset
local tweens = setmetatable({}, { __mode = "k" })

-- The joint named `name` under `char` (Motor6D or AnimationConstraint), or nil.
function Joints.Find(char, name)
	local j = typeof(char) == "Instance" and char:FindFirstChild(name, true)
	if j and (j:IsA("Motor6D") or j:IsA("AnimationConstraint")) then
		return j
	end
	return nil
end

-- What to tween and which property, plus the rest offset (captured the first time a joint is posed).
local function target(j)
	if j:IsA("Motor6D") then
		if base[j] == nil then
			base[j] = j.C0
		end
		return j, "C0", base[j]
	end
	local a = j.Attachment0
	if not a then
		return nil
	end
	if base[j] == nil then
		base[j] = a.CFrame
	end
	return a, "CFrame", base[j]
end

-- Tweens the joint to rest * offset over `seconds`.
function Joints.Pose(char, name, offset, seconds, style)
	local j = Joints.Find(char, name)
	if not j then
		return false
	end
	local inst, prop, rest = target(j)
	if not inst then
		return false
	end
	local old = tweens[j]
	if old then
		old:Cancel()
	end
	local tw = TweenService:Create(inst, TweenInfo.new(seconds or 0.2, style or Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { [prop] = rest * offset })
	tweens[j] = tw
	tw:Play()
	return true
end

-- True when `j` is a joint whose Transform the Animator drives (both kinds have one).
function Joints.IsJoint(j)
	return j ~= nil and (j:IsA("Motor6D") or j:IsA("AnimationConstraint"))
end

return Joints
