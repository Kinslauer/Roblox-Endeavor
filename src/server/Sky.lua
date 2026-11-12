-- The hour picks the sky (round 6 of docs/Reference-Picks-Plan.md; Andy, 2026-11-12: "Every hour the time of day swaps,
-- sometimes it is a natural progression, dawn midday night, but it can go in any order"). Cycle.Run calls Sky.Roll:
-- a time of day (Config.World.Sky.Natural = the chance it moves on to the next one, else any other) and a weather
-- (Clear, Rain, Fog). The server sets the Lighting (it replicates) and the workspace attributes TimeOfDay and Weather;
-- client/Air.lua thickens the haze for fog and draws the rain. NPCs see less at night, in rain and in fog
-- (Sky.SightMult, NPCs' aggro range). Nothing announces it.
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local W = Config.World.Sky

local Sky = {}
local time, weather = W.Start, "Clear"

function Sky.Pick(rng, current)
	local order = W.Order
	local i = table.find(order, current) or #order
	if rng:NextNumber() < W.Natural then
		return order[i % #order + 1]
	end
	local others = {}
	for _, name in order do
		if name ~= current then
			table.insert(others, name)
		end
	end
	return others[rng:NextInteger(1, #others)]
end

function Sky.PickWeather(rng)
	local total = 0
	for _, w in W.Weather do
		total += w
	end
	local at = rng:NextNumber() * total
	for _, name in { "Clear", "Rain", "Fog" } do
		at -= W.Weather[name] or 0
		if at <= 0 then
			return name
		end
	end
	return "Clear"
end

function Sky.Apply(t, w)
	local def = W.Times[t] or W.Times.Night
	time, weather = t, w
	Lighting.ClockTime = def.Clock
	Lighting.Brightness = def.Brightness
	Lighting.Ambient, Lighting.OutdoorAmbient = def.Ambient, def.Outdoor
	Lighting.FogColor = def.Fog
	Lighting.FogEnd = if w == "Fog" then def.FogEnd * 0.45 else def.FogEnd
	workspace:SetAttribute("TimeOfDay", t)
	workspace:SetAttribute("Weather", w)
end

function Sky.Roll(rng)
	rng = rng or Random.new()
	Sky.Apply(Sky.Pick(rng, time), Sky.PickWeather(rng))
	return time, weather
end

-- the sky before the first hour (Main, round 6): the start time, clear
function Sky.Init()
	Sky.Apply(time, weather)
end

function Sky.Now()
	return time, weather
end

-- How far NPCs see in the city right now.
function Sky.SightMult()
	local m = (W.Times[time] or W.Times.Night).Sight or 1
	if weather == "Rain" then
		m *= W.Rain.Sight
	elseif weather == "Fog" then
		m *= W.Fog.Sight
	end
	return m
end

-- Rain covers noise out in the open (not underground).
function Sky.NoiseMult(position)
	if weather == "Rain" and (not position or position.Y > -100) then
		return W.Rain.Noise
	end
	return 1
end

return Sky
