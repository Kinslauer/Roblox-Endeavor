-- Clues (design/gdd/dematerialization.md §5): what each cycle carries for a conduit who pays attention.
--   Lines      each contact's pool for the cycle's line (server/Clues.lua draws one per cycle); most are
--              ordinary, a few slip. Weight: an entry may be { Text, Weight } (default 1).
--   Fragments  recovered pieces of the truth. Each is an item (Type "Fragment") that only appears on some
--              cycles at one of its Spots, marked by an anomaly; reading it adds it to the conduit's Knowledge
--              (profile.Knowledge, the ARCHIVE app). Rule fields (all optional, all must hold):
--                Every = n          the cycle index is a multiple of n
--                Needs = { ids }    only a conduit who has read these can see or take it
--                While = { Contact = id, Spot = i }   only while that contact stands at that spot this cycle
--                OnRival = true     it may be carried by a rival conduit instead of lying at a spot
--              Anomaly = what marks it: "Static" (a glitching cube), "Echo" (a flickering silhouette),
--              "Wrong" (a sign that reads wrong).
-- CONTENT IS THE OWNER'S: everything marked Placeholder = true is stand-in writing for the system to run on.
local District = require(script.Parent.District)
local Regions = require(script.Parent.Regions)

local Clues = {}

local D1, D2 = District.Districts[1].Origin, District.Districts[2].Origin
local function street(origin, i, j) -- a street intersection of a district (never inside a building)
	return origin + Vector3.new(District.StreetLine(i), 0, District.StreetLine(j))
end
local Rd, E = Regions.Road, Regions.Enclave
local function road(at, side)
	return Vector3.new(Rd.X + side * (Rd.Width / 2 + 6), 0, Rd.Z0 + Rd.Length * at)
end
local function enclave(angle, r)
	return E.Origin + Vector3.new(math.cos(math.rad(angle)) * r, 0, math.sin(math.rad(angle)) * r)
end

Clues.Lines = {
	Broker = {
		{ "Contracts. Read them on your computer. I don't do the work; I know who needs it done.", 3 },
		{ "Quiet hour. The quiet ones pay best.", 2 },
		{ "Someone was asking about you. Didn't leave a name. Nobody does.", 2 },
		{ "You asked me that last hour. You won't remember.", 1 },
		{ "Do you ever count the lamps on the road? Count them twice.", 1 },
	},
	Fixer = {
		{ "A room is not a home until someone sells you the difference. Ask the computer.", 3 },
		{ "Everything I sell comes back. That's not a complaint.", 2 },
		{ "Same chair, same scratch on the leg. Every time. Funny, that.", 1 },
		{ "Your hideout's the only thing out here that keeps. Ever wondered why?", 1 },
	},
	Dealer = {
		{ "You found me. The shop's on your computer now. Don't ask where any of it comes from.", 3 },
		{ "I've stood here before. Different spot. Same road.", 2 },
		{ "The warmonger at the gate - he's been killed a hundred times. He doesn't know.", 1 },
		{ "Stock refreshes on the hour. So does everything.", 1 },
	},
}

Clues.Fragments = {
	HourZero = {
		Name = "Fragment: Hour Zero", Placeholder = true, Anomaly = "Static",
		Text = "[placeholder] A burned log, one line legible: 'Reset holds. Subjects unaware. Begin again at hour zero.'",
		Spots = { street(D1, 1, 1), street(D1, 4, 1), street(D1, 1, 4), street(D1, 4, 4) },
		Rule = {}, -- every cycle: the way in
	},
	ListOfNames = {
		Name = "Fragment: A List of Names", Placeholder = true, Anomaly = "Echo",
		Text = "[placeholder] A page of names, every one crossed out. The last one isn't. It's yours.",
		Spots = { street(D2, 1, 1), street(D2, 4, 4), street(D2, 1, 4) },
		Rule = { Every = 2, Needs = { "HourZero" } },
	},
	MaintenanceLog = {
		Name = "Fragment: Maintenance Log 7", Placeholder = true, Anomaly = "Wrong",
		Text = "[placeholder] 'Road segment rebuilt again. Lamp count drift: one extra. Flag for review.'",
		Spots = { road(0.72, 1), road(0.74, -1) },
		Rule = { While = { Contact = "Dealer", Spot = 3 } },
	},
	AutonetSchematic = {
		Name = "Schematic: Autonet", Placeholder = true, Anomaly = "Static", OnRival = true,
		Text = "[placeholder] A wiring diagram for a table that opens a body and closes it again. The margins say: it hurts.",
		Spots = { enclave(110, 70), enclave(250, 80), road(0.4, 1) },
		Rule = { Every = 3 },
		Teaches = "Autonet", -- knowledge that unlocks a recipe (Items.Recipes[*].Needs)
	},
	TheDoor = {
		Name = "Fragment: The Door", Placeholder = true, Anomaly = "Echo",
		Text = "[placeholder] A photograph of a door that isn't anywhere in the city. On the back: 'outside the hour'.",
		Spots = { enclave(20, 95), street(D1, 0, 5), road(0.9, -1) },
		Rule = { Every = 4, Needs = { "ListOfNames", "MaintenanceLog" } },
	},
}

-- Draw a line for a contact from its weighted pool.
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

-- Whether a fragment's world rule holds this cycle (Needs is per conduit; see Clues.CanSee).
function Clues.Allowed(def, index, contactSpots)
	local r = def.Rule or {}
	if r.Every and index % r.Every ~= 0 then
		return false
	end
	if r.While and (contactSpots or {})[r.While.Contact] ~= r.While.Spot then
		return false
	end
	return true
end

-- Whether a conduit who knows `knowledge` ([id] = order) can see / take a fragment.
function Clues.CanSee(def, knowledge)
	for _, id in (def.Rule and def.Rule.Needs) or {} do
		if not (knowledge and knowledge[id]) then
			return false
		end
	end
	return true
end

-- Whether `knowledge` holds a fragment that Teaches `what` (recipes gated by knowledge: Items.Recipes[*].Needs).
function Clues.Knows(knowledge, what)
	for id in knowledge or {} do
		local def = Clues.Fragments[id]
		if def and def.Teaches == what then
			return true
		end
	end
	return false
end

return Clues
