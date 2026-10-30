-- Remote middleware: every client -> server remote is registered here with a rate limit and an
-- argument shape. Exploiters fire remotes with nil/NaN/huge/wrong-type arguments thousands of
-- times a second; nothing reaches a system module unless it passes this.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes)

local Net = {}

local buckets = {} -- [player][remote] = { tokens, last }

local function allow(player, key, ratePerSec, burst)
	local now = os.clock()
	local mine = buckets[player]
	if not mine then
		mine = {}
		buckets[player] = mine
	end
	local b = mine[key]
	if not b then
		b = { tokens = burst, last = now }
		mine[key] = b
	end
	b.tokens = math.min(burst, b.tokens + (now - b.last) * ratePerSec)
	b.last = now
	if b.tokens < 1 then
		return false
	end
	b.tokens -= 1
	return true
end

-- Argument checkers. Each returns true when the value is acceptable.
local CHECK = {
	string = function(v) return type(v) == "string" and #v <= 64 end,
	boolean = function(v) return type(v) == "boolean" end,
	int = function(v) return type(v) == "number" and v == v and v % 1 == 0 and math.abs(v) < 1e6 end,
	vector = function(v)
		return typeof(v) == "Vector3" and v.X == v.X and v.Y == v.Y and v.Z == v.Z and v.Magnitude < 1e4
	end,
	instance = function(v) return typeof(v) == "Instance" end,
}
CHECK.table = function(v) return type(v) == "table" end
CHECK.number = function(v) return type(v) == "number" and v == v and math.abs(v) < 1e6 end
CHECK["string?"] = function(v) return v == nil or CHECK.string(v) end
CHECK["vector?"] = function(v) return v == nil or CHECK.vector(v) end
CHECK["int?"] = function(v) return v == nil or CHECK.int(v) end

-- spec: { rate = per-second refill, burst = bucket size, args = { "string", "int?", ... } }
function Net.On(name, spec, handler)
	local remote = Remotes[name]
	assert(remote, "unknown remote " .. tostring(name))
	local args = spec.args or {}
	remote.OnServerEvent:Connect(function(player, ...)
		if not allow(player, name, spec.rate, spec.burst or spec.rate * 2) then
			return
		end
		local n = select("#", ...)
		if n > #args then
			return
		end
		for i, kind in args do
			if not CHECK[kind]((select(i, ...))) then
				return
			end
		end
		handler(player, ...)
	end)
end

function Net.Init()
	Players.PlayerRemoving:Connect(function(player)
		buckets[player] = nil
	end)
end

return Net
