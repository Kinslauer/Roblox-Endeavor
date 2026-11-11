-- Live cloth for a skinned cloak (tools/models/train.py build_cloak, Andy 2026-11-11: "There should be a cloth physics
-- simulation on the cloak. that way it conforms over the character and what he carries").
--
-- The cloak is one skinned MeshPart with a grid of Bones named "R<row>C<col>". Row 0 rings the neck and stays where
-- the mesh puts it (the mesh is welded to the torso). Every other bone is a cloth particle: verlet motion under
-- gravity, held to its neighbours (down the column exactly, round the row with slack), tethered to its neck point,
-- pulled gently back toward the shape the cloak was draped in, and pushed out of every box it would pass into: the
-- character's limbs, what the character carries (opts.Extra: models such as a holstered pistol) and the solid world
-- nearby (benches, floor, walls). Each frame the bones' Transforms are set from the particles.
--
--   local handle = Cloth.Attach(model, character, { Extra = { holster, back } })
--   handle:Stop()            -- also stops on its own once the model leaves the game
--
-- Everything is local to this client (the intro's cloak is a local copy), so it costs no network.
local RunService = game:GetService("RunService")

local Cloth = {}

Cloth.Tuning = {
	Gravity = 0.45, -- share of workspace.Gravity (160 here is a game-feel gravity, too fast for cloth)
	Damping = 0.97, -- velocity kept per step
	Iterations = 4,
	Shape = 2.5, -- per second: how fast a particle drifts back toward the draped shape
	Margin = 0.14, -- studs of cloth thickness kept off every box
	Stretch = 1.05, -- round a row the cloth may stretch this much ...
	Squash = 0.3, -- ... and bunch down to this share of its rest length
	Step = 1 / 60,
	MaxSteps = 3,
	WorldRadius = 9, -- studs round the cloak searched for solid world parts
	WorldEvery = 0.5, -- seconds between those searches
}

local function boxesOf(model, into, skip)
	if not model or not model.Parent then
		return
	end
	local list = model:IsA("BasePart") and { model } or model:GetDescendants()
	for _, p in list do
		if p:IsA("BasePart") and not skip[p] and p.Name ~= "HumanoidRootPart" then
			table.insert(into, p)
		end
	end
end

function Cloth.Attach(model, char, opts)
	opts = opts or {}
	local K = Cloth.Tuning
	local mesh
	for _, d in model:GetDescendants() do
		if d:IsA("MeshPart") and d:FindFirstChildWhichIsA("Bone", true) then
			mesh = d
			break
		end
	end
	if not mesh then
		return nil
	end
	-- the particle grid from the bone names
	local grid, rows, cols = {}, 0, 0
	for _, b in mesh:GetDescendants() do
		if b:IsA("Bone") then
			local r, c = string.match(b.Name, "^R(%d+)C(%d+)$")
			if r then
				r, c = tonumber(r), tonumber(c)
				rows, cols = math.max(rows, r + 1), math.max(cols, c + 1)
				grid[r * 1000 + c] = b
			end
		end
	end
	if rows < 2 or cols < 3 then
		return nil
	end
	local mcf = mesh.CFrame
	local P, Prev, Rest, Bones, BoneCF = {}, {}, {}, {}, {}
	for r = 0, rows - 1 do
		for c = 0, cols - 1 do
			local b = grid[r * 1000 + c]
			if not b then
				return nil
			end
			local i = r * cols + c + 1
			Bones[i] = b
			BoneCF[i] = b.CFrame
			Rest[i] = mcf:PointToObjectSpace(b.WorldPosition)
			P[i] = b.WorldPosition
			Prev[i] = P[i]
		end
	end
	local function idx(r, c)
		return r * cols + (c % cols) + 1
	end
	-- links: down each column (exact), round each row and across the diagonals (slack), and the tether to the neck
	local down, round, tether = {}, {}, {}
	for c = 0, cols - 1 do
		local along = 0
		for r = 1, rows - 1 do
			local a, b = idx(r - 1, c), idx(r, c)
			local len = (Rest[a] - Rest[b]).Magnitude
			along += len
			table.insert(down, { a, b, len })
			table.insert(tether, { idx(0, c), b, along * 1.03 })
			local n = idx(r, c + 1)
			table.insert(round, { b, n, (Rest[b] - Rest[n]).Magnitude })
			local d = idx(r - 1, c + 1)
			table.insert(round, { b, d, (Rest[b] - Rest[d]).Magnitude })
		end
	end

	-- what the cloth lies on
	local own = {}
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			own[d] = true
		end
	end
	local bodyParts, worldParts = {}, {}
	local function refreshBody()
		table.clear(bodyParts)
		boxesOf(char, bodyParts, own)
		for _, m in opts.Extra or {} do
			boxesOf(m, bodyParts, own)
		end
	end
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local function refreshWorld()
		local exclude = { char, model }
		for _, m in opts.Extra or {} do
			if m and m.Parent then
				table.insert(exclude, m)
			end
		end
		params.FilterDescendantsInstances = exclude
		table.clear(worldParts)
		local ok, found = pcall(function()
			return workspace:GetPartBoundsInRadius(mesh.Position, K.WorldRadius, params)
		end)
		if ok then
			for _, p in found do
				-- plain blocks only: a mesh's box is its bounds, and a car shell's bounds hold the whole rider
				local block = p:IsA("Part") and p.Shape == Enum.PartType.Block
				local holds = block and (function()
					local l = p.CFrame:PointToObjectSpace(mesh.Position)
					local h = p.Size * 0.5
					return math.abs(l.X) < h.X and math.abs(l.Y) < h.Y and math.abs(l.Z) < h.Z
				end)()
				if block and p.CanCollide and p.Anchored and not holds then
					table.insert(worldParts, p)
				end
			end
		end
	end
	refreshBody()
	refreshWorld()

	local boxes = {}
	local function gatherBoxes()
		table.clear(boxes)
		local centre, reach = mesh.Position, mesh.Size.Magnitude * 0.6 + K.Margin
		for _, list in { bodyParts, worldParts } do
			for _, p in list do
				if p.Parent then
					local cf, half = p.CFrame, p.Size * 0.5
					local radius = half.Magnitude + K.Margin
					if (cf.Position - centre).Magnitude < reach + radius then
						table.insert(boxes, { cf, half + Vector3.new(K.Margin, K.Margin, K.Margin), radius })
					end
				end
			end
		end
	end

	local function collide(p)
		for _, box in boxes do
			local cf, h = box[1], box[2]
			if (p - cf.Position).Magnitude < box[3] then
				local l = cf:PointToObjectSpace(p)
				local dx, dy, dz = h.X - math.abs(l.X), h.Y - math.abs(l.Y), h.Z - math.abs(l.Z)
				if dx > 0 and dy > 0 and dz > 0 then
					if dx <= dy and dx <= dz then
						l = Vector3.new(l.X >= 0 and h.X or -h.X, l.Y, l.Z)
					elseif dy <= dz then
						l = Vector3.new(l.X, l.Y >= 0 and h.Y or -h.Y, l.Z)
					else
						l = Vector3.new(l.X, l.Y, l.Z >= 0 and h.Z or -h.Z)
					end
					p = cf:PointToWorldSpace(l)
				end
			end
		end
		return p
	end

	local pinned = cols -- particles 1..cols are row 0
	local function step(dt)
		mcf = mesh.CFrame
		local g = Vector3.new(0, -workspace.Gravity * K.Gravity * dt * dt, 0)
		local pull = math.min(1, K.Shape * dt)
		for i = 1, #P do
			if i <= pinned then
				P[i] = mcf:PointToWorldSpace(Rest[i])
				Prev[i] = P[i]
			else
				local p = P[i]
				local v = (p - Prev[i]) * K.Damping
				Prev[i] = p
				p = p + v + g
				P[i] = p + (mcf:PointToWorldSpace(Rest[i]) - p) * pull
			end
		end
		for _ = 1, K.Iterations do
			for _, l in down do
				local a, b, len = l[1], l[2], l[3]
				local d = P[b] - P[a]
				local m = d.Magnitude
				if m > 1e-4 then
					local fix = d * ((m - len) / m)
					if a <= pinned then
						P[b] -= fix
					else
						P[a] += fix * 0.5
						P[b] -= fix * 0.5
					end
				end
			end
			for _, l in round do
				local a, b, len = l[1], l[2], l[3]
				local d = P[b] - P[a]
				local m = d.Magnitude
				local want = m > len * K.Stretch and len * K.Stretch or (m < len * K.Squash and len * K.Squash or nil)
				if want and m > 1e-4 then
					local fix = d * ((m - want) / m) * 0.5
					if a > pinned then
						P[a] += fix
					end
					P[b] -= fix
				end
			end
			for _, l in tether do
				local d = P[l[2]] - P[l[1]]
				local m = d.Magnitude
				if m > l[3] then
					P[l[2]] = P[l[1]] + d * (l[3] / m)
				end
			end
			for i = pinned + 1, #P do
				P[i] = collide(P[i])
			end
		end
	end

	local function write()
		for i = pinned + 1, #P do
			local local_ = mcf:PointToObjectSpace(P[i])
			Bones[i].Transform = CFrame.new(BoneCF[i]:PointToObjectSpace(local_))
		end
	end

	-- settle into place before the first frame is seen (the drape was made on a standing body)
	gatherBoxes()
	for _ = 1, 40 do
		step(K.Step)
	end
	write()

	local handle = {}
	local acc, sinceWorld, sinceBody = 0, 0, 0
	local conn
	local function frame(dt)
		if not mesh.Parent or not model.Parent then
			if conn then
				conn:Disconnect()
			end
			return
		end
		sinceWorld += dt
		sinceBody += dt
		if sinceWorld >= K.WorldEvery then
			sinceWorld = 0
			refreshWorld()
		end
		if sinceBody >= 1 then
			sinceBody = 0
			refreshBody()
		end
		gatherBoxes()
		acc = math.min(acc + dt, K.Step * K.MaxSteps)
		while acc >= K.Step do
			acc -= K.Step
			step(K.Step)
		end
		write()
	end
	handle.Frame = frame -- opts.Manual: the caller steps it (tests on a server, where RenderStepped never fires)
	if not opts.Manual then
		conn = RunService.RenderStepped:Connect(frame)
	end
	function handle:Stop()
		if conn then
			conn:Disconnect()
		end
	end
	handle.Particles = P -- for tests
	return handle
end

return Cloth
