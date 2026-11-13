-- Skin: makes a character's one-piece body follow its limbs (Andy, 2026-11-12: "the ones right now look too blocky
-- and disjointed"). Client side; both the player's own body and every other skinned body in view.
--
-- A skinned body (server/Rigs.lua attachSkin, models from tools/models/figure.py) is a Model named "Skin", tagged
-- "Skin", inside the character: a holder part with 15 Bones and the skinned MeshParts. The character's own limbs are
-- still there, invisible, jointed and animated exactly as before. Each bone carries the limb it belongs to (attribute
-- Limb) and where it sat on that limb at rest (attribute Rest). Every frame, just before rendering, each bone is put
-- where its limb now is. The mesh blends between bones across every joint, so an elbow folds instead of gapping.
-- Nothing here knows about animations: whatever moves the limbs (Animator, joint poses, physics) moves the skin.
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local Skin = {}

Skin.Tuning = {
	Near = 140, -- studs: closer than this, every frame
	Far = 420, -- beyond Near, every third frame; beyond Far, never (too small on screen to tell)
}

local bodies = {} -- skin Model -> { Holder, Rig, Bones = { { bone, inverse, rest, limbName, limb } } }
local frame = 0

local function bind(skin)
	if bodies[skin] or not skin:IsA("Model") then
		return
	end
	local holder
	local list = {}
	for _, d in skin:GetDescendants() do
		if d:IsA("Bone") then
			local limbName, rest = d:GetAttribute("Limb"), d:GetAttribute("Rest")
			if limbName and rest and d.Parent:IsA("BasePart") then
				holder = holder or d.Parent
				table.insert(list, { d, d.CFrame:Inverse(), rest, limbName, nil })
			end
		end
	end
	if holder and #list > 0 then
		bodies[skin] = { Holder = holder, Bones = list }
	end
end

local function update(body, rig)
	local inverse = body.Holder.CFrame:Inverse()
	for _, b in body.Bones do
		local limb = b[5]
		if not limb or limb.Parent ~= rig then
			limb = rig:FindFirstChild(b[4])
			b[5] = limb
		end
		if limb then
			b[1].Transform = b[2] * (inverse * limb.CFrame) * b[3]
		end
	end
end

-- Puts every bone of one skinned character where its limbs are now (tests, and one-off poses outside the loop).
function Skin.Update(character)
	local any = false
	for _, skin in (character and character:GetChildren()) or {} do
		if skin:IsA("Model") and (skin.Name == "Skin" or skin:GetAttribute("Kind")) then -- the body and its layers
			bind(skin)
			if bodies[skin] then
				update(bodies[skin], character)
				any = true
			end
		end
	end
	return any
end

function Skin.Count()
	local n = 0
	for _ in bodies do
		n += 1
	end
	return n
end

local started = false
function Skin.Start()
	if started then
		return
	end
	started = true
	for _, skin in CollectionService:GetTagged("Skin") do
		task.spawn(bind, skin)
	end
	CollectionService:GetInstanceAddedSignal("Skin"):Connect(function(skin)
		-- the bones and their attributes can arrive a moment after the model does
		task.defer(function()
			for _ = 1, 20 do
				bind(skin)
				if bodies[skin] or not skin.Parent then
					return
				end
				task.wait(0.25)
			end
		end)
	end)
	CollectionService:GetInstanceRemovedSignal("Skin"):Connect(function(skin)
		bodies[skin] = nil
	end)
	local K = Skin.Tuning
	-- last in the render step, so the limbs have been posed by everything else first
	-- The bones are named after the limbs (the mesh finds its bones by name, so they cannot be renamed), and the
	-- character's Animator also drives anything named like a limb: it wrote each playing animation's joint turn
	-- straight into these bones after the render step, so the body sat in a half-folded pose and never followed
	-- its limbs (Andy, 2026-11-12: "the model had no animations, so he was crouching the entire time"). The
	-- animation step runs before Stepped, so the bones are also set there, after the Animator has written.
	RunService.Stepped:Connect(function()
		local camera = workspace.CurrentCamera
		local eye = camera and camera.CFrame.Position
		for skin, body in bodies do
			local rig = skin.Parent
			if rig and skin:IsDescendantOf(workspace) and (not eye or (body.Holder.Position - eye).Magnitude < K.Far) then
				update(body, rig)
			end
		end
	end)
	RunService:BindToRenderStep("SkinFollow", 2005, function() -- Enum.RenderPriority.Last is 2000
		frame += 1
		local camera = workspace.CurrentCamera
		local eye = camera and camera.CFrame.Position
		for skin, body in bodies do
			local rig = skin.Parent
			if not rig or not skin:IsDescendantOf(workspace) then
				if not skin.Parent then
					bodies[skin] = nil
				end
				continue
			end
			local d = if eye then (body.Holder.Position - eye).Magnitude else 0
			if d < K.Near or (d < K.Far and (frame + #body.Bones) % 3 == 0) then
				update(body, rig)
			end
		end
	end)
end

return Skin
