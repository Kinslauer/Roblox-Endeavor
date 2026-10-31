-- Clues (ported from combat-feel; design: the world resets every hour and the conduits suspect it is a
-- simulation; the cycle carries what a conduit who pays attention can find):
--   Lines      each contact's pool for the cycle's line (server/Cycle.lua draws one per cycle); most are
--              ordinary, a few slip. { Text, Weight }.
--   Fragments  recovered pieces of the truth. Each lies at a rolled spot of its Where on the cycles its Rule
--              allows, marked by an anomaly; reading it adds it to the conduit's Knowledge (the ARCHIVE app
--              on the hideout computer). Rule: Every = n (cycle index multiple of n), Needs = { ids } (only a
--              conduit who has read these can see or take it). Anomaly: "Static" (a glitching cube), "Echo"
--              (a flickering silhouette), "Wrong" (a sign that reads wrong).
--   Where      "City" (a district plaza edge), "Crossroads", "Scarp" (a switchback), "Trail" (a trail point),
--              "Site" (beside a site), "Reach" (inside the hedge). server/Clues.lua resolves them per layout.
local Clues = {}

Clues.Lines = {
	Broker = {
		{ "Contracts. Sites, bounties, the Blackout. Pay on completion. Don't die in the middle of one.", 3 },
		{ "Quiet hour. The quiet ones pay best.", 2 },
		{ "Someone was asking about you. Didn't leave a name. Nobody does.", 2 },
		{ "You asked me that last hour. You won't remember.", 1 },
		{ "Do you ever count the lamps on the switchbacks? Count them twice.", 1 },
	},
	Fixer = {
		{ "Anything for the house, delivered. Credits up front. Don't ask where it comes from.", 3 },
		{ "Everything I sell comes back. That's not a complaint.", 2 },
		{ "Same crack in the overpass. Same wreck under it. Every time. Funny, that.", 1 },
		{ "Your hideout's the only thing out here that keeps. Ever wondered why?", 1 },
	},
	Dealer = {
		{ "Cores, arms, lenses. Pulled from people who no longer need them. Credits only.", 3 },
		{ "I've stood here before. Different spot. Same cliff.", 2 },
		{ "The Gatekeeper's been killed a hundred times. He doesn't know.", 1 },
		{ "Stock refreshes on the hour. So does everything.", 1 },
	},
}

Clues.Fragments = {
	HourZero = {
		Name = "Fragment: Hour Zero", Anomaly = "Static", Where = "City",
		Text = "A burned terminal log, one line still legible: 'RESET HOLDS. SUBJECTS UNAWARE. BEGIN AGAIN AT HOUR ZERO.'",
		Rule = {},
	},
	Ledger = {
		Name = "Fragment: The Ledger", Anomaly = "Echo", Where = "Crossroads",
		Text = "A ledger of conduit names, every one crossed out in the same hand. The last line is blank, and the ink beside it is still wet.",
		Rule = { Every = 2, Needs = { "HourZero" } },
	},
	LampCount = {
		Name = "Fragment: Lamp Count", Anomaly = "Wrong", Where = "Scarp",
		Text = "A road-crew note taped to a hazard lamp: 'Switchback rebuilt again. Lamp count drift: one extra. Nobody ordered an extra.'",
		Rule = {},
	},
	Gatekeeper = {
		Name = "Fragment: The Gatekeeper", Anomaly = "Echo", Where = "Scarp",
		Text = "Scratched into the overlook rail: 'He has died here more times than I can count. He always stands back up facing the city. He has never once looked at the valley.'",
		Rule = { Every = 2 },
	},
	SeedPacket = {
		Name = "Fragment: Seed Packet", Anomaly = "Static", Where = "Reach",
		Text = "A seed packet from a greenhouse. The strain name is a date. The date is tomorrow.",
		Rule = { Every = 3 },
	},
	Dispatch = {
		Name = "Fragment: Front Dispatch", Anomaly = "Wrong", Where = "Site",
		Text = "A Front dispatch stamped by both factions at once: 'Ticket scales reset to balance. Recruit losses: acceptable. Conduit retention: nominal.'",
		Rule = { Every = 2, Needs = { "LampCount" } },
	},
	Uplink = {
		Name = "Schematic: Uplink", Anomaly = "Static", Where = "Trail",
		Text = "A Neural Net schematic. The 'tap in' line does not run to the Front. It runs up, and the label at the top reads ARCHIVE.",
		Rule = { Every = 3, Needs = { "Ledger" } },
	},
	Departed = {
		Name = "Fragment: The Departed", Anomaly = "Wrong", Where = "City",
		Text = "A brokerage receipt, stamped PAID IN FULL: one consciousness stack, one upload, one exit. The signature is a name you have seen on a tower. Nobody by that name lives in the city.",
		Rule = { Every = 2 },
	},
	TheDoor = {
		Name = "Fragment: The Door", Anomaly = "Echo", Where = "Site",
		Text = "A photograph of a door that is nowhere in the city and nowhere in the valley. On the back, in pencil: 'outside the hour'.",
		Rule = { Every = 4, Needs = { "Dispatch", "Uplink" } },
	},
}

-- Draw a line index for a contact from its weighted pool.
function Clues.DrawLine(contactId, rng)
	local pool = Clues.Lines[contactId]
	if not pool then
		return nil
	end
	local total = 0
	for _, e in pool do
		total += e[2] or 1
	end
	local x = rng:NextNumber() * total
	for i, e in pool do
		x -= e[2] or 1
		if x <= 0 then
			return i
		end
	end
	return #pool
end

-- Whether a fragment's world rule holds this cycle (Needs is per conduit: Clues.CanSee).
function Clues.Allowed(def, index)
	local r = def.Rule or {}
	return not (r.Every and index % r.Every ~= 0)
end

-- Whether a conduit whose Knowledge.Fragments is `known` ([id] = order) can see / take a fragment.
function Clues.CanSee(def, known)
	for _, id in (def.Rule and def.Rule.Needs) or {} do
		if not (known and known[id]) then
			return false
		end
	end
	return true
end

return Clues
