-- Builds (round 5 of docs/Reference-Picks-Plan.md; ideas from Cursed Gear and Tarkov, nothing copied): how a conduit
-- grows inside one life and what carries over. Pure rules; server/Builds.lua applies them, Gear reads them in compute.
--   Lineage  each body is a Line 9 batch and rolls a small bonus to one attribute; a rare batch is strong, and about
--            one in a hundred is empty (no flicker, no skills, a harder body)
--   Load     every implant costs load; the core sets the limit; pieces past it give nothing
--   Actives  some implants fire on K for a short effect (Quicken: half cooldowns; Spike: the next skill hits twice as hard)
--   Chips    fitted at the hideout bench to one skill each; they change what the skill does, not only its numbers
--   Vows     sworn at the hideout computer for one life: a handicap for a reward
--   Grades   the Broker's trials raise a conduit from GRADE 4 to SPECIAL; better contracts and the Blackout gate need one
--   Practice what the body does, it gets better at (running, reloading, searching)
--   Carried  xp and credits earned out in the city ride with the body until it is home at its bay
--   Stack    one small slot of data and chips that the stack keeps through a reboot (never materials)
local Config = require(script.Parent.Config)

local Builds = {}
local B = Config.Builds

-- ===== lineage =====
-- r is a number in [0, 1); pick is a function(n) -> 1..n. Returns { Batch, Stat, Bonus, Second?, Rare?, Empty? }.
function Builds.RollLineage(r, pick, names)
	names = names or Config.Stats.Names
	local L = B.Lineage
	local batch = pick(9999)
	if r < L.Empty then
		return { Batch = batch, Empty = true }
	end
	local stat = names[pick(#names)]
	if r < L.Empty + L.Rare then
		local second = names[pick(#names)]
		if second == stat then
			second = names[(table.find(names, stat) % #names) + 1]
		end
		return { Batch = batch, Stat = stat, Bonus = L.RareBonus, Second = second, SecondBonus = L.RareSecond, Rare = true }
	end
	return { Batch = batch, Stat = stat, Bonus = if r < L.Empty + L.Rare + L.Good then L.GoodBonus else L.Bonus }
end

-- The stat points a lineage adds: { [stat] = n }.
function Builds.LineageStats(lin)
	local out = {}
	if type(lin) ~= "table" or lin.Empty then
		return out
	end
	if lin.Stat then
		out[lin.Stat] = (out[lin.Stat] or 0) + (lin.Bonus or 0)
	end
	if lin.Second then
		out[lin.Second] = (out[lin.Second] or 0) + (lin.SecondBonus or 0)
	end
	return out
end

-- "LINE 9 . BATCH 0417"
function Builds.BatchName(lin)
	return ("LINE 9 . BATCH %04d"):format(type(lin) == "table" and lin.Batch or 0)
end

-- ===== implant load =====
function Builds.LoadOf(piece)
	if not piece then
		return 0
	end
	return piece.Load or B.Load.ByKind[piece.Slot] or 1
end

-- Limit from the core in the body (pieces = Cybernetics.Pieces, cyber = { [slot] = id }).
function Builds.LoadMax(cyber, pieces)
	local core = cyber and cyber.Core and pieces[cyber.Core]
	return B.Load.Base + (core and core.LoadCap or 0)
end

-- Walks the slots in order; returns total load, max, and { [slot] = true } for pieces past the limit.
function Builds.Load(cyber, pieces, slots)
	local max, total, over = Builds.LoadMax(cyber, pieces), 0, {}
	for _, slot in slots do
		local id = cyber[slot]
		local piece = id and pieces[id]
		if piece then
			local cost = Builds.LoadOf(piece)
			if total + cost > max then
				over[slot] = true
			else
				total += cost
			end
		end
	end
	return total, max, over
end

-- ===== chips =====
-- One chip per skill. A chip only works on the skill it names.
Builds.Chips = {
	FocusChip = { Skill = "Surge", Name = "Focus chip" }, -- the ring becomes a long cone ahead
	HookChip = { Skill = "ShatterStrike", Name = "Hook chip" }, -- the blow drags the body in and holds it
	TrailChip = { Skill = "PhaseStep", Name = "Trail chip" }, -- the blink leaves a live line on the ground behind it
	BreathChip = { Skill = "SecondWind", Name = "Breath chip" }, -- the breath also closes light bleeds and dulls pain
	MirrorChip = { Skill = "IronBastion", Name = "Mirror chip" }, -- blows on the bastion break the striker's posture
	ArcChip = { Skill = "Overload", Name = "Arc chip" }, -- each charged hit jumps to the next body near
}
function Builds.ChipFor(skillId)
	for id, c in Builds.Chips do
		if c.Skill == skillId then
			return id
		end
	end
	return nil
end

-- ===== vows =====
Builds.Vows = {
	OpenBook = { Name = "OPEN BOOK" }, -- everyone sees your stamina; you see the stamina and posture of whoever you fight
	LightHand = { Name = "LIGHT HAND" }, -- weaker hits, more xp
	ThinSkin = { Name = "THIN SKIN" }, -- less health, more charge
}
Builds.VowOrder = { "OpenBook", "LightHand", "ThinSkin" }

-- ===== grades =====
-- 4 is where every conduit starts; 0 is SPECIAL.
function Builds.GradeName(g)
	g = g or B.Grades.Start
	return if g <= 0 then "SPECIAL" else ("GRADE %d"):format(g)
end

-- ===== practice =====
-- points needed for level n: Per * n * (n + 1) / 2
function Builds.PracticeLevel(kind, points)
	local def = B.Practice[kind]
	if not def then
		return 0
	end
	local n, p = 0, points or 0
	while n < def.Max and p >= def.Per * (n + 1) * (n + 2) / 2 do
		n += 1
	end
	return n
end

-- ===== the stack slot =====
function Builds.StackOk(def)
	return def ~= nil and def.Data == true
end

return Builds
