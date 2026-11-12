-- Make (Endeavor client, round 7 of docs/Reference-Picks-Plan.md): what the things you make show and do here.
--   K held        the arm's active (Remote "Arm" with the camera's aim); client/Build keeps the tap for the core
--   World "Cable" the cable pulls this body to a point (the client owns its body's physics)
--   CombatEvent "Cable" the line itself, for everyone
--   World "Sniff" a dog's nose: containers near you glow for a moment
--   Rows(panel, addRow)          the loadout panel (L): your companion (Dismiss) and whether you are in the drone
--   TerminalRows(panel, addRow, t, send)   the computer: the holding frame (Release, Front) and invaders out there
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local MK = Config.Make
local player = Players.LocalPlayer
local Make = {}

local GOLD = Color3.fromRGB(255, 210, 120)
local GREEN = Color3.fromRGB(120, 220, 150)

function Make.Companion()
	for _, m in workspace:GetChildren() do
		if m:IsA("Model") and m:GetAttribute("Owner") == player.UserId and m:GetAttribute("Companion") then
			return m
		end
	end
	return nil
end

function Make.Rows(panel, addRow)
	local n = 0
	local c = Make.Companion()
	if c then
		local hum = c:FindFirstChildOfClass("Humanoid")
		n += 1
		addRow(panel, ("COMPANION . %s . %s%s"):format(string.upper(c:GetAttribute("Companion") or ""), c:GetAttribute("CompanionName") or "",
			if hum then ("  %d/%d"):format(math.floor(hum.Health), math.floor(hum.MaxHealth)) else ""), { { text = "Dismiss", color = Color3.fromRGB(110, 60, 40), fn = function()
			Remotes.Companion:FireServer("Dismiss")
		end } }, GREEN)
	end
	if player:GetAttribute("Proxy") then
		n += 1
		addRow(panel, "> PROXY . LINKED", {}, GOLD)
	end
	return n
end

function Make.TerminalRows(panel, addRow, t, send)
	local n = 0
	if t.Thralls and #t.Thralls > 0 then
		n += 1
		addRow(panel, ("HOLDING FRAME  -  %d kept"):format(#t.Thralls), {}, GREEN)
		for _, th in t.Thralls do
			n += 1
			addRow(panel, ("  %s . %s"):format(th.Name, string.upper(th.Type or "")), {
				{ text = "Release", color = Color3.fromRGB(50, 110, 70), fn = send("Release", tostring(th.Index)) },
				{ text = "Front", color = Color3.fromRGB(110, 60, 40), fn = send("Reprogram", tostring(th.Index)) },
			}, nil)
		end
	end
	if (t.Invaders or 0) > 0 then
		n += 1
		addRow(panel, ("> HOLDING FRAME . %d OUT"):format(t.Invaders), {}, Color3.fromRGB(255, 120, 100))
	end
	return n
end

-- the cable's pull on this body
local pull -- { To, Until }
function Make.Pull(to)
	pull = { To = to, Until = os.clock() + MK.Cable.PullSeconds + 0.6 }
end

local function line(from, to)
	local p = Instance.new("Part")
	p.Name = "CableLine"
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch = true, false, false, false
	p.Material, p.Color = Enum.Material.Neon, Color3.fromRGB(230, 230, 120)
	local d = (to - from).Magnitude
	p.Size = Vector3.new(0.08, 0.08, math.max(0.1, d))
	p.CFrame = CFrame.lookAt(from:Lerp(to, 0.5), to)
	p.Parent = workspace
	task.delay(0.35, function()
		p:Destroy()
	end)
	return p
end
Make.Line = line

function Make.Start()
	local Build = require(script.Parent:WaitForChild("Build"))
	RunService.Heartbeat:Connect(function()
		-- K held past the threshold: the arm, once per press
		if Build.KDown and not Build.ArmFired and os.clock() - Build.KDown >= MK.Arm.Hold then
			Build.ArmFired = true
			local cam = workspace.CurrentCamera
			Remotes.Arm:FireServer(cam and cam.CFrame.LookVector or nil)
		end
		if pull then
			local char = player.Character
			local root = char and char:FindFirstChild("HumanoidRootPart")
			if not root or os.clock() > pull.Until then
				pull = nil
				return
			end
			local to = pull.To - root.Position
			if to.Magnitude < 3 then
				pull = nil
				root.AssemblyLinearVelocity = root.AssemblyLinearVelocity * 0.3
				return
			end
			root.AssemblyLinearVelocity = to.Unit * MK.Cable.Speed
		end
	end)
	Remotes.World.OnClientEvent:Connect(function(kind, a)
		if kind == "Cable" and typeof(a) == "Vector3" then
			Make.Pull(a)
		elseif kind == "Sniff" and type(a) == "table" then
			for _, p in a do
				if typeof(p) == "Instance" and p.Parent then
					local h = Instance.new("Highlight")
					h.FillColor, h.OutlineColor, h.FillTransparency = Color3.fromRGB(255, 200, 120), Color3.fromRGB(255, 220, 160), 0.8
					h.Parent = p
					task.delay(3, function()
						h:Destroy()
					end)
				end
			end
		end
	end)
	Remotes.CombatEvent.OnClientEvent:Connect(function(kind, char, point)
		if kind == "Cable" and typeof(char) == "Instance" and typeof(point) == "Vector3" then
			local root = char:FindFirstChild("HumanoidRootPart")
			if root then
				line(root.Position + Vector3.new(0, 1.2, 0), point)
			end
		end
	end)
end

return Make
