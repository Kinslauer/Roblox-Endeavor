-- Bay (Endeavor client, round 6 of docs/Reference-Picks-Plan.md): what the world and the money show.
--   Start(gui)            the party list (upper left: each member's name and health; names only, no markers), the
--                         invite card (Y join, N decline), the work-order clock while a run is on, the unlock flash,
--                         and the bay's lights flickering while its generator is dry (bay model attribute Dark)
--   Rows(panel, addRow)   the loadout panel (L): conduits standing with you (Invite), your party (Leave)
--   TerminalRows(panel, addRow, t, send)   the computer: trust with each contact, swaps, the exchange, the drop
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local P = Config.World.Party
local player = Players.LocalPlayer
local Bay = {}

local DIM = Color3.fromRGB(150, 156, 166)
local GOLD = Color3.fromRGB(255, 210, 120)
local GREEN = Color3.fromRGB(120, 220, 150)

Bay.Party = {} -- member userIds (the server's list)
Bay.Leader = nil
Bay.Invite = nil -- { From, Name, At }
Bay.Run = nil -- { Task, EndsAt }

local function text(parent, props)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency, l.Font, l.TextColor3, l.TextSize = 1, Enum.Font.RobotoMono, Color3.fromRGB(220, 226, 232), 14
	l.TextXAlignment = Enum.TextXAlignment.Left
	for k, v in props do
		l[k] = v
	end
	l.Parent = parent
	return l
end

-- ===== the loadout panel =====
function Bay.Rows(panel, addRow)
	local n = 0
	local function row(t, buttons, color)
		n += 1
		addRow(panel, t, buttons or {}, color)
	end
	row("-- PARTY --")
	if Bay.Invite then
		local from = Bay.Invite.From
		row(("%s asks you to join"):format(Bay.Invite.Name or "?"), { { text = "Join", color = Color3.fromRGB(50, 110, 70), fn = function()
			Remotes.Party:FireServer("Accept", tostring(from))
			Bay.Invite = nil
			if Bay.Elements then
				Bay.Elements.Invite.Visible = false
			end
		end }, { text = "No", color = Color3.fromRGB(110, 60, 40), fn = function()
			Remotes.Party:FireServer("Decline")
			Bay.Invite = nil
			if Bay.Elements then
				Bay.Elements.Invite.Visible = false
			end
		end } }, GOLD)
	end
	local me = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if #Bay.Party > 0 then
		for _, id in Bay.Party do
			local p = Players:GetPlayerByUserId(id)
			row(("%s%s"):format(p and p.DisplayName or "?", if id == Bay.Leader then "  . LEAD" else ""), {}, if id == player.UserId then GOLD else nil)
		end
		row("", { { text = "Leave", color = Color3.fromRGB(110, 60, 40), fn = function()
			Remotes.Party:FireServer("Leave")
		end } }, DIM)
	end
	local inParty = #Bay.Party > 0
	if not inParty or Bay.Leader == player.UserId then
		for _, p in Players:GetPlayers() do
			local root = p ~= player and p.Character and p.Character:FindFirstChild("HumanoidRootPart")
			if root and me and (root.Position - me.Position).Magnitude <= P.InviteReach and not table.find(Bay.Party, p.UserId) then
				row(p.DisplayName, { { text = "Invite", fn = function()
					Remotes.Party:FireServer("Invite", tostring(p.UserId))
				end } }, DIM)
			end
		end
	end
	return n
end

-- ===== the computer =====
function Bay.TerminalRows(panel, addRow, t, send)
	local e = t and t.Economy
	if not e then
		return 0
	end
	local n = 0
	local function row(s, buttons, color)
		n += 1
		addRow(panel, s, buttons or {}, color)
	end
	local trust = {}
	for _, id in { "Broker", "Fixer", "Dealer" } do
		if e.Loyalty[id] then
			table.insert(trust, ("%s %d"):format(string.upper(id), e.Loyalty[id]))
		end
	end
	row("TRUST  -  " .. table.concat(trust, " . "), {}, DIM)
	-- swaps: goods for goods with a contact you have met
	row("SWAPS", {}, GREEN)
	for _, s in e.Swaps do
		if t.Apps[({ Broker = "RAIDS", Fixer = "HOUSE", Dealer = "MARKET" })[s.Contact]] then
			if s.Lock then
				row(("  %s  -  > TRUST %d"):format(s.Text, s.Lock), {}, DIM)
			else
				row("  " .. s.Text, { { text = "Swap", fn = send("Swap", s.Id) } })
			end
		end
	end
	-- the exchange: other conduits' listings (online sellers only), your own, and what you may list
	row(("EXCHANGE  -  %d/%d slots . rep %d . fee %d%%"):format(#e.Mine, e.Slots, e.Rep, math.floor(e.Fee * 100 + 0.5)), {}, GREEN)
	for _, l in e.Board do
		row(("  %s x%d  -  %d cr  -  %s"):format(l.Name, l.Count, l.Price, l.Seller), { { text = "Buy", color = Color3.fromRGB(50, 110, 70), fn = send("Take", l.Key) } },
			if l.Price > (t.Credits or 0) then DIM else nil)
	end
	for _, l in e.Mine do
		row(("  yours: %s x%d  -  %d cr"):format(l.Name, l.Count, l.Price), { { text = "Pull", color = Color3.fromRGB(110, 60, 40), fn = send("Unlist", tostring(l.Index)) } }, GOLD)
	end
	for _, f in e.Found do
		local buttons = {}
		for step, mult in e.Mults do
			table.insert(buttons, { text = tostring(math.ceil(f.Value * mult) * f.Count), fn = send("List", ("%s:%d:%d"):format(f.Id, f.Count, step)) })
		end
		row(("  found: %s x%d"):format(f.Name, f.Count), buttons, DIM)
	end
	-- the drop
	if t.Apps.HOUSE then
		local d = e.Drop
		if d.Wait < 0 then
			row("LINE 9 DROP  -  on its way", {}, GOLD)
		elseif d.Wait > 0 then
			row(("LINE 9 DROP  -  line busy %d s"):format(d.Wait), {}, DIM)
		else
			row(("LINE 9 DROP  -  a consignment to your bay's lift . %d cr"):format(d.Price), { { text = "Call", fn = send("Drop", "") } })
		end
	end
	return n
end

-- ===== the screen =====
function Bay.Start(gui)
	local frame = Instance.new("Frame")
	frame.Name = "Party"
	frame.BackgroundTransparency, frame.Size, frame.Position = 1, UDim2.fromOffset(220, 120), UDim2.fromOffset(16, 120)
	frame.Parent = gui
	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0, 2)
	list.Parent = frame
	local card = text(gui, { Name = "PartyInvite", Size = UDim2.fromOffset(360, 26), Position = UDim2.new(0.5, -180, 0, 92), TextXAlignment = Enum.TextXAlignment.Center,
		TextColor3 = GOLD, Visible = false, Font = Enum.Font.GothamBold })
	local clock = text(gui, { Name = "RunClock", Size = UDim2.fromOffset(360, 22), Position = UDim2.new(0.5, -180, 0, 64), TextXAlignment = Enum.TextXAlignment.Center,
		TextColor3 = Color3.fromRGB(216, 166, 26), Visible = false })
	Bay.Elements = { Party = frame, Invite = card, Clock = clock }

	local rows = {}
	local function drawParty()
		for _, r in rows do
			r:Destroy()
		end
		table.clear(rows)
		for _, id in Bay.Party do
			if id ~= player.UserId then
				local p = Players:GetPlayerByUserId(id)
				local r = text(frame, { Size = UDim2.fromOffset(220, 18), Text = p and p.DisplayName or "?" })
				r:SetAttribute("UserId", id)
				table.insert(rows, r)
			end
		end
	end

	Remotes.World.OnClientEvent:Connect(function(kind, a, b)
		if kind == "Party" then
			Bay.Party, Bay.Leader = a or {}, b
			drawParty()
		elseif kind == "PartyInvite" then
			Bay.Invite = { From = a, Name = b, At = os.clock() }
			card.Text = ("> PARTY . %s . [L]"):format(string.upper(tostring(b)))
			card.Visible = true
		elseif kind == "Run" then
			Bay.Run = if a then { Task = a, EndsAt = os.clock() + (b or 0) } else nil
			clock.Visible = Bay.Run ~= nil
		elseif kind == "Unlocked" and typeof(a) == "Instance" then
			local flash = Instance.new("PointLight")
			flash.Color, flash.Range, flash.Brightness = Color3.fromRGB(120, 255, 160), 10, 3
			flash.Parent = a
			task.delay(0.4, function()
				flash:Destroy()
			end)
		end
	end)

	-- health on the party rows, the run clock, the invite running out, the dark bays
	local acc, flick = 0, 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		flick += dt
		if Bay.Run then
			local left = math.max(0, Bay.Run.EndsAt - os.clock())
			clock.Text = ("> WORK ORDER . %s . %d:%02d"):format(string.upper(Bay.Run.Task), math.floor(left / 60), math.floor(left % 60))
		end
		if acc < 0.25 then
			return
		end
		acc = 0
		if Bay.Invite and os.clock() - Bay.Invite.At > P.InviteSeconds then
			Bay.Invite = nil
			card.Visible = false
		end
		for _, r in rows do
			local p = Players:GetPlayerByUserId(r:GetAttribute("UserId"))
			local hum = p and p.Character and p.Character:FindFirstChildOfClass("Humanoid")
			if hum then
				local share = math.clamp(hum.Health / math.max(1, hum.MaxHealth), 0, 1)
				r.Text = ("%s  %s"):format(p.DisplayName, string.rep("|", math.ceil(share * 10)))
				r.TextColor3 = if share < 0.35 then Color3.fromRGB(255, 110, 90) else Color3.fromRGB(220, 226, 232)
			end
		end
		-- a dry generator: the bay's lights stutter
		local bays = workspace:FindFirstChild("Hideouts")
		if bays and flick > 0.12 then
			flick = 0
			for _, model in bays:GetChildren() do
				local dark = model:GetAttribute("Dark") == true
				if dark or model:GetAttribute("WasDark") then
					model:SetAttribute("WasDark", dark or nil)
					for _, light in model:GetDescendants() do
						if light:IsA("PointLight") then
							light.Enabled = not dark or math.random() < 0.25
						end
					end
				end
			end
		end
	end)
end

return Bay
