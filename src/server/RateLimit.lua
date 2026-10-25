-- Per-player token buckets for RemoteEvents (TR-006). The client is never trusted to pace itself:
-- a handler wrapped here silently drops calls past `perSecond` (with a small burst allowance) and
-- warns once per player per remote so a flood shows up in the log without spamming it.
-- Usage: remote.OnServerEvent:Connect(RateLimit.Wrap("Attack", 8, Combat.Attack))
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local RateLimit = {}

local buckets = {} -- [player][name] = { tokens, last }
local warned = {} -- [player][name] = true

local function bucket(player, name, perSecond)
	local mine = buckets[player]
	if not mine then
		mine = {}
		buckets[player] = mine
	end
	local b = mine[name]
	if not b then
		b = { tokens = perSecond * Config.RateLimit.Burst, last = os.clock() }
		mine[name] = b
	end
	return b
end

-- Returns true when the call may proceed. Refills continuously; capacity = perSecond * Burst.
function RateLimit.Allow(player, name, perSecond)
	local b = bucket(player, name, perSecond)
	local now = os.clock()
	local cap = perSecond * Config.RateLimit.Burst
	b.tokens = math.min(cap, b.tokens + (now - b.last) * perSecond)
	b.last = now
	if b.tokens >= 1 then
		b.tokens -= 1
		return true
	end
	local w = warned[player]
	if not w then
		w = {}
		warned[player] = w
	end
	if not w[name] then
		w[name] = true
		warn(("[RateLimit] %s exceeded %s (%d/s)"):format(player.Name, name, perSecond))
	end
	return false
end

function RateLimit.Wrap(name, perSecond, fn)
	return function(player, ...)
		if typeof(player) == "Instance" and player:IsA("Player") and RateLimit.Allow(player, name, perSecond) then
			return fn(player, ...)
		end
		return nil
	end
end

Players.PlayerRemoving:Connect(function(player)
	buckets[player], warned[player] = nil, nil
end)

return RateLimit
