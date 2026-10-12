-- Server creates the RemoteEvents, client waits for them. Same API on both sides.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local NAMES = {
	-- client -> server
	"Attack", "Heavy", "Feint", "Flicker", "Block", "Dodge", "UseSkill", "SetSkill", "Allocate", "UseItem", "EquipItem", "Unequip", "Craft",
	-- server -> client
	"CombatEvent", "StatsChanged", "InventoryChanged", "LoadoutChanged", "QuestChanged", "Announce", "PhaseChanged", "Died",
}

local folder
if RunService:IsServer() then
	folder = Instance.new("Folder")
	folder.Name = "Remotes"
	for _, name in NAMES do
		local remote = Instance.new("RemoteEvent")
		remote.Name = name
		remote.Parent = folder
	end
	folder.Parent = ReplicatedStorage
else
	folder = ReplicatedStorage:WaitForChild("Remotes")
end

local remotes = {}
for _, name in NAMES do
	remotes[name] = folder:WaitForChild(name)
end
return remotes
