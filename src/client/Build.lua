-- Build (Endeavor client, round 5 of docs/Reference-Picks-Plan.md): what the server's builds snapshot shows, and the
-- two things the body does with it.
--   Rows(panel, addRow, loadout)  the loadout panel (L): the body's batch, grade, vow, implant load, practice, what is
--                                 carried and not yet banked, the chip on each skill, and the stack slot
--   K                             fires the core's active implant (server/Builds.Active)
--   Open book                     a conduit under the vow shows a stamina line over its head to everyone; the one who
--                                 swore it sees the stamina and posture of whoever it faces
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Items = require(Shared:WaitForChild("Items"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Rules = require(Shared:WaitForChild("Builds"))
local Skills = require(Shared:WaitForChild("Skills"))

local B = Config.Builds
local player = Players.LocalPlayer
local Build = {}

local DIM = Color3.fromRGB(150, 156, 166)
local GOLD = Color3.fromRGB(255, 210, 120)
local CYAN = Color3.fromRGB(150, 220, 255)

-- Rows for the loadout panel. Returns how many rows were added (tests read it).
function Build.Rows(panel, addRow, loadout)
	local b = loadout and loadout.Build
	if not b then
		return 0
	end
	local n = 0
	local function row(text, buttons, color)
		n += 1
		addRow(panel, text, buttons or {}, color)
	end
	row("-- STACK --")
	local lin = b.Lineage or {}
	local trait = if lin.Empty then "EMPTY" elseif lin.Stat then ("%s +%d%s"):format(string.upper(lin.Stat), lin.Bonus or 0,
		if lin.Second then (" . %s +%d"):format(string.upper(lin.Second), lin.SecondBonus or 0) else "") else ""
	row(("%s . %s"):format(b.Batch or "", trait), {}, if lin.Empty or lin.Rare then GOLD else nil)
	row(("%s%s"):format(b.Grade or "", if b.Vow then "   VOW . " .. b.Vow else ""), {}, DIM)
	row(("LOAD %d/%d%s"):format(b.Load or 0, b.LoadMax or 0, if b.Active then ("   K . %s"):format(string.upper(b.Active)) else ""), {}, if (b.Load or 0) >= (b.LoadMax or 1) then GOLD else DIM)
	local parts = {}
	for _, kind in { "Endurance", "Reload", "Search" } do
		table.insert(parts, ("%s %d"):format(string.upper(kind), b.Practice and b.Practice[kind] or 0))
	end
	row(table.concat(parts, " . "), {}, DIM)
	local c = b.Carried or {}
	if (c.Xp or 0) > 0 or (c.Credits or 0) > 0 then
		row(("CARRIED . %d XP . %d CR"):format(c.Xp or 0, c.Credits or 0), {}, GOLD)
	end
	-- chips on skills
	for skillId, chipId in b.Chips or {} do
		local def, item = Skills.Defs[skillId], Items.Defs[chipId]
		if def and item then
			row(("%s . %s"):format(string.upper(def.Name), string.upper(item.Name)), { { text = "Remove", fn = function()
				Remotes.Build:FireServer("Unfit", skillId)
			end } }, CYAN)
		end
	end
	-- the stack slot
	local stack = b.Stack or {}
	for i = 1, b.StackSlots or B.Stack.Slots do
		local e = stack[i]
		if e then
			local item = Items.Defs[e.Id]
			row(("[%d] %s%s"):format(i, item and item.Name or e.Id, if e.Count > 1 then (" x%d"):format(e.Count) else ""), { { text = "Take", fn = function()
				Remotes.Build:FireServer("Unstore", tostring(i))
			end } }, CYAN)
		else
			row(("[%d] -"):format(i), {}, DIM)
		end
	end
	-- what in the pack could go in
	for id, count in Build.Pack or {} do
		local def = Items.Defs[id]
		if count > 0 and Rules.StackOk(def) then
			local buttons = { { text = "Stack", fn = function()
				Remotes.Build:FireServer("Store", id)
			end } }
			if def.Type == "Chip" then
				table.insert(buttons, 1, { text = "Fit", fn = function()
					Remotes.Build:FireServer("Fit", id)
				end })
			end
			row(("%s x%d"):format(def.Name, count), buttons)
		end
	end
	return n
end

-- ===== open book =====
local readGui, readStam, readPost
local worn = setmetatable({}, { __mode = "k" }) -- model -> billboard (others under the vow)

local function bar(parent, y, color)
	local back = Instance.new("Frame")
	back.Size, back.Position, back.BackgroundColor3, back.BackgroundTransparency, back.BorderSizePixel = UDim2.new(1, 0, 0, 3), UDim2.new(0, 0, 0, y), Color3.new(0, 0, 0), 0.4, 0
	back.Parent = parent
	local fill = Instance.new("Frame")
	fill.Size, fill.BackgroundColor3, fill.BorderSizePixel = UDim2.fromScale(1, 1), color, 0
	fill.Parent = back
	return fill
end

local function board(model, two)
	local head = model:FindFirstChild("Head") or model:FindFirstChild("HumanoidRootPart")
	if not head then
		return nil
	end
	local gui = Instance.new("BillboardGui")
	gui.Name = "OpenBook"
	gui.Size, gui.StudsOffset, gui.AlwaysOnTop, gui.MaxDistance, gui.LightInfluence = UDim2.fromOffset(46, if two then 10 else 5), Vector3.new(0, 2.4, 0), false, B.Vows.OpenReach, 0
	gui.Adornee = head
	local stam = bar(gui, 0, Color3.fromRGB(120, 220, 140))
	local post = two and bar(gui, 5, Color3.fromRGB(255, 190, 80)) or nil
	gui.Parent = head
	return gui, stam, post
end

local function share(model, attr, maxAttr)
	local v, m = model:GetAttribute(attr), model:GetAttribute(maxAttr)
	if type(v) ~= "number" or type(m) ~= "number" or m <= 0 then
		return nil
	end
	return math.clamp(v / m, 0, 1)
end

local function faced()
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	local cam = workspace.CurrentCamera
	if not (root and cam) then
		return nil
	end
	local best, bestDot = nil, 0.85
	for _, model in workspace:GetChildren() do
		local hum = model:IsA("Model") and model ~= char and model:FindFirstChildOfClass("Humanoid")
		local r = hum and hum.Health > 0 and model:FindFirstChild("HumanoidRootPart")
		if r then
			local to = r.Position - root.Position
			if to.Magnitude < B.Vows.OpenReach and to.Magnitude > 0.1 then
				local dot = to.Unit:Dot(cam.CFrame.LookVector)
				if dot > bestDot then
					best, bestDot = model, dot
				end
			end
		end
	end
	return best
end

local acc = 0
function Build.Step(dt)
	acc += dt
	if acc < 0.15 then
		return
	end
	acc = 0
	local me = player.Character
	-- others under the vow: their stamina shows to everyone
	for _, p in Players:GetPlayers() do
		local c = p.Character
		if c and c ~= me then
			local on = c:GetAttribute("Vow") == "OpenBook"
			local gui = worn[c]
			if on and not gui then
				local g, stam = board(c, false)
				if g then
					worn[c] = { gui = g, stam = stam }
				end
			elseif not on and gui then
				gui.gui:Destroy()
				worn[c] = nil
			end
			if on and worn[c] then
				worn[c].stam.Size = UDim2.fromScale(share(c, "Stamina", "MaxStamina") or 1, 1)
			end
		end
	end
	-- mine: the one I face reads open
	local reading = me and me:GetAttribute("Vow") == "OpenBook"
	local target = reading and faced() or nil
	if readGui and (not target or readGui.Adornee == nil or not readGui.Adornee:IsDescendantOf(target)) then
		readGui:Destroy()
		readGui = nil
	end
	if target and not readGui then
		readGui, readStam, readPost = board(target, true)
	end
	if readGui then
		readStam.Size = UDim2.fromScale(share(target, "Stamina", "MaxStamina") or 1, 1)
		readPost.Size = UDim2.fromScale(share(target, "Posture", "MaxPosture") or 0, 1)
	end
end
Build.Reading = function()
	return readGui
end

function Build.Start()
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		if input.KeyCode == Enum.KeyCode.K then
			Build.KDown = os.clock() -- round 7 (client/Make): a tap fires the core, a hold the arm
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if input.KeyCode == Enum.KeyCode.K and Build.KDown then
			local held = os.clock() - Build.KDown
			Build.KDown = nil
			if held < Config.Make.Arm.Hold and not Build.ArmFired then
				Remotes.Active:FireServer()
			end
			Build.ArmFired = nil
		end
	end)
	RunService.Heartbeat:Connect(Build.Step)
	Remotes.World.OnClientEvent:Connect(function(kind, stone, result)
		if kind == "Stone" and typeof(stone) == "Instance" and stone:IsA("BasePart") then
			-- the stone answers: a soft glow for a step, a long one when it is solved, nothing for a wrong one
			local light = Instance.new("PointLight")
			light.Color = if result == "solved" then Color3.fromRGB(140, 255, 220) else Color3.fromRGB(120, 200, 180)
			light.Range, light.Brightness = if result == "solved" then 18 else 8, if result == "reset" then 0 else 1.2
			light.Parent = stone
			task.delay(if result == "solved" then 6 else 1.2, function()
				light:Destroy()
			end)
		end
	end)
end

return Build
