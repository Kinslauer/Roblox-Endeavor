-- Input: keys -> intent remotes. The client only asks; the server decides (ADR-0001).
-- Layout (README "Controls"): LMB attack, RMB heavy, F block/parry, Q dodge, E flick, Z feint,
-- R/Y/V skills, J attributes, Tab inventory, L loadout. X is the server-side ProximityPrompt key.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Remotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"))
local Hud = require(script.Parent.Hud)

local player = Players.LocalPlayer

local Input = {}

local SKILL_KEYS = { [Enum.KeyCode.R] = 1, [Enum.KeyCode.Y] = 2, [Enum.KeyCode.V] = 3 }
local PANEL_KEYS = { [Enum.KeyCode.J] = "Stats", [Enum.KeyCode.Tab] = "Inventory", [Enum.KeyCode.L] = "Loadout" }

local function dodge()
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if hum and root then
		local dir = if hum.MoveDirection.Magnitude > 0.1 then hum.MoveDirection else -root.CFrame.LookVector -- backstep by default
		Remotes.Dodge:FireServer(dir)
	end
end

function Input.Init()
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		local key = input.KeyCode
		local mouse = input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.MouseButton2
		if mouse and Hud.MenuOpen() then
			return -- the cursor is free for the creator / a panel; a missed button click is not a swing
		end
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			Remotes.Attack:FireServer()
		elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
			Remotes.Heavy:FireServer()
		elseif key == Enum.KeyCode.F then
			Remotes.Block:FireServer(true)
		elseif key == Enum.KeyCode.E then
			Remotes.Flicker:FireServer() -- tap just before your swing connects
		elseif key == Enum.KeyCode.Z then
			Remotes.Feint:FireServer()
		elseif key == Enum.KeyCode.Q then
			dodge()
		elseif SKILL_KEYS[key] then
			Remotes.UseSkill:FireServer(SKILL_KEYS[key])
		elseif PANEL_KEYS[key] then
			local frame = Hud.Panels[PANEL_KEYS[key]]
			if frame then
				frame.Visible = not frame.Visible
			end
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if input.KeyCode == Enum.KeyCode.F then
			Remotes.Block:FireServer(false)
		end
	end)
end

return Input
