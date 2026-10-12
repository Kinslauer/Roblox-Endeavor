local ProfileService = require(game.ServerStorage.Modules.ProfileService)
local ProfileTemplate = {
	["Banned"] = false,
	["Level"] = 1,
	["Exp"] = 0,
	["Coins"] = 0,
	["Inventory"] = table.create(50, {""}),
	["Classes"] = {
		["Brawler"] = {
			["Level"] = 1,
			["Skins"] = {}
		},
		["Sword"] = {
			["Level"] = 1,
			["Skins"] = {}
		},
		["Spear"] = {
			["Level"] = 1,
			["Skins"] = {}
		},
		["Blasters"] = {
			["Level"] = 1,
			["Skins"] = {}
		},
		["Knight"] = {
			["Level"] = 1,
			["Skins"] = {}
		},
		["Hammer"] = {
			["Level"] = 1,
			["Skins"] = {}
		},
	},
	["Skills"] = {
		--"Thrust Combo"
	},
	["Keybinds"] = {
		["One"] = 1,
		["Two"] = 2,
		["Three"] = 3,
		["Four"] = 4,
		["Five"] = 5,
		["Six"] = 6,
		["Seven"] = 7,
		["Eight"] = 8,
		["F"] = "Block",
		["Q"] = "Dodge",
	},
}

local ProfileStore = ProfileService.GetProfileStore("PlayerData",ProfileTemplate).Mock
_G.Profiles = {}

local function PlayerDataLoaded(player)
	--print(player)
end

local function PlayerAdded(player)
	local profile = ProfileStore:LoadProfileAsync(tostring(player.UserId),"ForceLoad")

	if profile ~= nil then
		profile:Reconcile()
		profile:ListenToRelease(function()
			_G.Profiles[player.Name] = nil
			player:Kick("Your profile has been loaded remotely, please rejoin.")
		end)

		if player:IsDescendantOf(game.Players) then
			_G.Profiles[player.Name] = profile.Data
			PlayerDataLoaded(player)
		else
			profile:Release()
		end
	else
		player:Kick("Failed to load saved data, please rejoin.")
	end
end

for _,player in ipairs(game.Players:GetPlayers()) do
	coroutine.wrap(PlayerAdded)(player)
end

game.Players.PlayerAdded:Connect(PlayerAdded)
game.Players.PlayerRemoving:Connect(function(player)
	local profile = _G.Profiles[player.Name]

	if profile ~= nil then
		profile:Release()
	end
end)

