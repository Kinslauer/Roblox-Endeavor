-- Wallet (Phase 3): the war world's pay. One number on the profile (Money), mirrored to a Money
-- attribute on the Player for the HUD. Survives permadeath (PlayerData.PERSIST): the hideout is the
-- account's, the body is not. Scrap stays an inventory item for the city loop.
local PlayerData = require(script.Parent.PlayerData)

local Wallet = {}

local function sync(player, profile)
	player:SetAttribute("Money", profile.Money or 0)
end

function Wallet.Get(player)
	local profile = PlayerData.Get(player)
	return profile and profile.Money or 0
end

function Wallet.Add(player, amount)
	local profile = PlayerData.Get(player)
	if not profile or type(amount) ~= "number" or amount <= 0 then
		return false
	end
	profile.Money = (profile.Money or 0) + math.floor(amount)
	sync(player, profile)
	return true
end

-- false when they cannot afford it; nothing is taken then.
function Wallet.Spend(player, amount)
	local profile = PlayerData.Get(player)
	if not profile or type(amount) ~= "number" or amount < 0 or (profile.Money or 0) < amount then
		return false
	end
	profile.Money = profile.Money - math.floor(amount)
	sync(player, profile)
	return true
end

function Wallet.Sync(player)
	local profile = PlayerData.Get(player)
	if profile then
		sync(player, profile)
	end
end

return Wallet
