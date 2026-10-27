-- Raids (Phase 3, build order 6; design/gdd/raids.md): contracts a conduit takes from the hideout
-- computer and runs in the open world. A raid is a chain of STEPS; the last real step is always to
-- get home - extract at any station, or follow a LEAD into the next contract instead (the
-- continuation). Dying ends the raid; the board on the computer remembers nothing about it.
--
-- Step kinds: kill { Target = QuestTag or EnemyType, Count } · reach { Point, Radius } ·
--             hold { Point, Radius, Seconds } · extract (added by the server)
-- Points are names from Raids.Points (world positions, built from the regions).
local District = require(script.Parent.District)
local Regions = require(script.Parent.Regions)

local Raids = {}

local Rd, E = Regions.Road, Regions.Enclave
local D2 = District.Districts[2]

Raids.Points = {
	RoadWrecks = Vector3.new(Rd.X + 12, 0, Rd.Z0 + Rd.Length * 0.45),
	RoadEnd = Vector3.new(Rd.X, 0, Rd.Z0 + Rd.Length - 20),
	EnclaveGate = Vector3.new(Rd.X, 0, E.Origin.Z - E.Radius + 14),
	EnclaveEast = E.Origin + Vector3.new(E.Radius * 0.6, 0, 0),
	FerriteEdge = D2.Origin + Vector3.new(0, 0, -District.Extent() / 2 + 30),
	RelayNorth = District.Districts[1].Origin + Vector3.new(0, 0, District.Extent() / 2 - 30),
}

Raids.Templates = {
	{
		Id = "highway_cull", Name = "Clear the Highway", Contact = "Broker",
		Text = "Raiders are taxing the road north. Put four of them down.",
		Steps = { { Kind = "kill", Target = "Raider", Count = 4, Text = "Put down %d raiders on the road" } },
		Reward = { Money = 60, Xp = 120 },
	},
	{
		Id = "dead_drop", Name = "Dead Drop", Contact = "Broker",
		Text = "Something was left by the wrecks halfway up the road. Go and stand on it.",
		Steps = { { Kind = "reach", Point = "RoadWrecks", Radius = 10, Text = "Reach the dead drop by the wrecks" } },
		Reward = { Money = 45, Xp = 80, Items = { Wire = 4 } },
	},
	{
		Id = "hold_the_gate", Name = "Hold the Gate", Contact = "Broker",
		Text = "Stand at the enclave's gate long enough for the hedge-watch to count you a friend.",
		Steps = { { Kind = "hold", Point = "EnclaveGate", Radius = 14, Seconds = 25, Text = "Hold the enclave gate for %d s" } },
		Reward = { Money = 70, Xp = 140, Items = { Medkit = 1 } },
	},
	{
		Id = "warmonger_head", Name = "A Warmonger's Head", Contact = "Broker",
		Text = "The one holding the road to the enclave. Bring proof.",
		Steps = { { Kind = "kill", Target = "Warmonger", Count = 1, Text = "Kill the warmonger on the road" } },
		Reward = { Money = 150, Xp = 300, Items = { ArcPistol = 1 } },
	},
	{
		Id = "rival_crew", Name = "Competition", Contact = "Broker",
		Text = "Another crew is working our contracts. Make the road ours again.",
		Steps = { { Kind = "kill", Target = "Rival", Count = 2, Text = "Put down %d rival conduits" } },
		Reward = { Money = 110, Xp = 220 },
	},
	{
		Id = "ferrite_sweep", Name = "Ferrite Sweep", Contact = "Broker",
		Text = "Ferrite Court's south edge, then anything that moves on the way.",
		Steps = {
			{ Kind = "reach", Point = "FerriteEdge", Radius = 14, Text = "Reach Ferrite Court's south edge" },
			{ Kind = "kill", Target = "Raider", Count = 3, Text = "Put down %d raiders" },
		},
		Reward = { Money = 90, Xp = 180, Items = { Scrap = 6 } },
	},
}

Raids.ById = {}
for _, t in Raids.Templates do
	Raids.ById[t.Id] = t
end

-- The three contacts and where they stand (server/Contacts.lua builds them). An app on the computer
-- opens when its contact has been met once. Spots: where they may stand this cycle (the cycle draws one;
-- design/gdd/dematerialization.md §2); Position is the first spot, where they stand before any cycle.
Raids.Contacts = {
	Broker = { Name = "the Broker", App = "RAIDS", Line = "Contracts. Read them on your computer. I don't do the work; I know who needs it done.",
		Spots = { -- between the market stalls (stalls ring the market at r22; the trader's counter is at (0, -10))
			E.Origin + Vector3.new(16, 0, 14), E.Origin + Vector3.new(-12, 0, 17), E.Origin + Vector3.new(-20, 0, -6), E.Origin + Vector3.new(20, 0, -7),
		} },
	Fixer = { Name = "the Fixer", App = "HOUSE", Line = "A room is not a home until someone sells you the difference. Ask the computer.",
		Spots = { -- Ferrite Court's plaza corners (the pylon is at the centre)
			D2.Origin + Vector3.new(-14, 0, 12), D2.Origin + Vector3.new(15, 0, -14), D2.Origin + Vector3.new(17, 0, 16), D2.Origin + Vector3.new(-16, 0, -15),
		} },
	Dealer = { Name = "the Dealer", App = "MARKET", Line = "You found me. The shop's on your computer now. Don't ask where any of it comes from.",
		Spots = { -- off the verge, always near a guard post (the risk is the price)
			Vector3.new(Rd.X + 22, 0, Rd.Z0 + Rd.Length * 0.47), Vector3.new(Rd.X - 24, 0, Rd.Z0 + Rd.Length * 0.25), Vector3.new(Rd.X + 23, 0, Rd.Z0 + Rd.Length * 0.7),
		} },
}
for _, c in Raids.Contacts do
	c.Position = c.Spots[1]
end

-- House furnishings (the HOUSE app): client-rendered in the hideout for their owner. Offsets from the room's origin.
Raids.House = {
	{ Id = "Rug", Name = "Woven Rug", Price = 30 },
	{ Id = "Lamp", Name = "Floor Lamp", Price = 20 },
	{ Id = "Shelf", Name = "Scrap Shelf", Price = 40 },
	{ Id = "Plant", Name = "Enclave Fern", Price = 25 },
	{ Id = "Poster", Name = "Pre-War Poster", Price = 15 },
	{ Id = "Couch", Name = "Salvaged Couch", Price = 60 },
}

-- The black market (the MARKET app): the things the enclave's trader does not carry.
Raids.Market = {
	{ Id = "Powder", Price = 30 },
	{ Id = "Battery", Price = 20 },
	{ Id = "Suppressor", Price = 110 },
	{ Id = "Scope4x", Price = 130 },
	{ Id = "LightBolt", Price = 100 },
	{ Id = "LongBarrel", Price = 95 },
	{ Id = "ReflexOptic", Price = 120 },
	{ Id = "ServoArm", Price = 150 },
	{ Id = "StriderLeg", Price = 140 },
	{ Id = "AudioPickup", Price = 110 },
	{ Id = "ArcRifle", Price = 260 },
	{ Id = "Intel", Price = 50 },
}

-- Rival crews (server/Rivals.lua): where they walk, how many, how soon a wiped crew is replaced.
Raids.Crews = {
	{ Id = "RoadCrew", Route = { "RoadWrecks", "RoadEnd", "EnclaveGate" }, Size = 2 },
	{ Id = "CityCrew", Route = { "FerriteEdge", "RelayNorth" }, Size = 2 },
}
Raids.CrewRespawnSeconds = 180
Raids.CrewLingerSeconds = 10 -- how long a crew works a point before moving on

Raids.LeadChance = 0.6 -- finishing the objectives: chance a new lead is offered instead of a plain extraction
Raids.LeadBonus = 1.5 -- money multiplier on a raid finished through a lead
Raids.BoardSize = 3

function Raids.StepText(step)
	if step.Kind == "extract" then
		return if step.Lead then ("Extract at any station - or follow the lead: %s"):format(Raids.ById[step.Lead].Name) else "Extract at any station"
	end
	local n = step.Count or step.Seconds
	return if step.Text and step.Text:find("%%d") then step.Text:format(n) else (step.Text or step.Kind)
end

return Raids
