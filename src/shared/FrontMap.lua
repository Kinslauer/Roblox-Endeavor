-- The Front's open world: the layout and the ground height, shared so the server (terrain, props) and the
-- map tools agree. `FrontMap.Generate(seed)` rolls a layout; `FrontMap.Sample(x, z)` returns the ground
-- height there, what shaped it (a tag for the terrain material) and the water level (or nil).
--
-- The picture (Andy, 2026-11-10: "endlessly war torn, the bodies of clones solidifying into hills along the
-- battlefields"): a Cols x Rows grid of sectors between the two faction rears. Every sector is held around
-- its crest, a barrow of calcified clone bodies; the moving hill walks from crest to crest. Long barrow
-- ridges run north-south where old front lines stood (the Spine down the middle is the oldest), the
-- faction lines are trench networks in the outer columns, and the world is ringed by the outer barrows,
-- cliffs of the dead too old to have shape. A sunken canal crosses east-west with three fords, the old
-- highway runs between the bases, and one sector still holds a pocket of green.
--
-- Sector types: Line (a faction's trench line, outer columns), Barrows (the Spine column), and rolled:
-- Village, Trenches, Craters, Deadwood, Works; one interior sector is the Glade.
local Config = require(script.Parent.Config)

local FrontMap = {}
local L -- the current layout

local function cfg()
	return Config.War.World
end

local function smooth(t)
	t = math.clamp(t, 0, 1)
	return t * t * (3 - 2 * t)
end

-- 1 at t = 0, 0 at t >= 1, smooth both ends
local function bell(t)
	if t >= 1 then
		return 0
	end
	local u = 1 - t * t
	return u * u
end

local function segDist(ax, az, bx, bz, x, z)
	local abx, abz = bx - ax, bz - az
	local len2 = abx * abx + abz * abz
	local t = if len2 > 0 then math.clamp(((x - ax) * abx + (z - az) * abz) / len2, 0, 1) else 0
	local dx, dz = x - ax - abx * t, z - az - abz * t
	return math.sqrt(dx * dx + dz * dz), t
end

-- ===== the bucket grid: features are registered in every cell their influence reaches =====
local CELL = 64
local function cellKey(cx, cz)
	return cx * 4096 + cz
end

local function register(f, x0, z0, x1, z1)
	for cx = math.floor(x0 / CELL), math.floor(x1 / CELL) do
		for cz = math.floor(z0 / CELL), math.floor(z1 / CELL) do
			local key = cellKey(cx, cz)
			local list = L.Buckets[key]
			if not list then
				list = {}
				L.Buckets[key] = list
			end
			table.insert(list, f)
		end
	end
end

local function addMound(x, z, r, h, kind)
	local f = { Kind = "Mound", X = x, Z = z, R = r, H = h, Tag = kind or "Barrow" }
	register(f, x - r, z - r, x + r, z + r)
	return f
end

-- a polyline feature (ridge, trench, canal, road): each segment is registered on its own
local function addLine(kind, points, width, props)
	for i = 1, #points - 1 do
		local a, b = points[i], points[i + 1]
		local f = { Kind = kind, AX = a.X, AZ = a.Y, BX = b.X, BZ = b.Y, W = width }
		for k, v in props or {} do
			f[k] = if type(v) == "table" then v[i] else v
		end
		if kind == "Ridge" then
			f.H0, f.H1 = props.Heights[i], props.Heights[i + 1]
		end
		local reach = width + 8
		register(f, math.min(a.X, b.X) - reach, math.min(a.Y, b.Y) - reach, math.max(a.X, b.X) + reach, math.max(a.Y, b.Y) + reach)
	end
end

local function addCrater(x, z, r, depth, water)
	local f = { Kind = "Crater", X = x, Z = z, R = r, D = depth, Water = water }
	local reach = r * 1.45
	register(f, x - reach, z - reach, x + reach, z + reach)
	return f
end

local function addPad(x, z, r, y)
	local f = { Kind = "Pad", X = x, Z = z, R = r, Y = y }
	register(f, x - r - 12, z - r - 12, x + r + 12, z + r + 12)
	return f
end

-- ===== the height =====
local function base(x, z)
	local s = L.Seed % 97 + 0.37
	return cfg().GroundLevel + 5 * math.noise(x / 260, z / 260, s) + 1.6 * math.noise(x / 48, z / 48, s + 3.1)
end
FrontMap.Base = function(x, z)
	return base(x, z)
end

-- Ground height at (x, z), the tag of what shaped it, and the water surface (nil = no water).
function FrontMap.Sample(x, z)
	local h = base(x, z)
	local tag = "Ground"
	local list = L.Buckets[cellKey(math.floor(x / CELL), math.floor(z / CELL))]
	local water
	if list then
		-- barrows and ridges: the highest one wins (they do not stack into spikes)
		local barrow = 0
		for _, f in list do
			if f.Kind == "Mound" then
				local dx, dz = x - f.X, z - f.Z
				local d = math.sqrt(dx * dx + dz * dz)
				if d < f.R then
					barrow = math.max(barrow, f.H * bell(d / f.R))
				end
			elseif f.Kind == "Ridge" then
				local d, t = segDist(f.AX, f.AZ, f.BX, f.BZ, x, z)
				if d < f.W then
					barrow = math.max(barrow, (f.H0 + (f.H1 - f.H0) * t) * bell(d / f.W))
				end
			end
		end
		if barrow > 0 then
			-- the fused bodies make the surface lumpy
			h += barrow + math.min(1, barrow / 4) * 0.9 * math.noise(x / 7, z / 7, 9.9)
			if barrow > 1.5 then
				tag = "Barrow"
			end
		end
		-- building pads flatten the ground to the pad's height
		for _, f in list do
			if f.Kind == "Pad" then
				local dx, dz = x - f.X, z - f.Z
				local d = math.sqrt(dx * dx + dz * dz)
				if d < f.R + 12 then
					local w = 1 - smooth((d - f.R) / 12)
					h += (f.Y - h) * w
					if w > 0.5 then
						tag = "Pad"
					end
				end
			end
		end
		-- trenches: a cut with a spoil bank either side
		for _, f in list do
			if f.Kind == "Trench" then
				local d = segDist(f.AX, f.AZ, f.BX, f.BZ, x, z)
				if d < f.W + 7 then
					local cut = 1 - smooth((d - (f.W - 1.5)) / 2.5)
					h -= f.Depth * cut
					h += 1.4 * bell(math.abs(d - (f.W + 3.5)) / 3.5)
					if cut > 0.5 then
						tag = "Trench"
					end
				end
			elseif f.Kind == "Road" then
				local d = segDist(f.AX, f.AZ, f.BX, f.BZ, x, z)
				if d < f.W and tag == "Ground" then
					tag = "Road"
				end
			end
		end
		-- the canal: banks, a muddy bed, standing water; fords where it shallows
		for _, f in list do
			if f.Kind == "Canal" then
				local d = segDist(f.AX, f.AZ, f.BX, f.BZ, x, z)
				if d < f.W then
					local shallow = 1
					for _, ford in L.Fords do
						local fx, fz = x - ford.X, z - ford.Y
						shallow = math.min(shallow, 1 - 0.85 * bell(math.sqrt(fx * fx + fz * fz) / 22))
					end
					local pre = h
					h -= f.Depth * shallow * bell((d / f.W) ^ 2.5)
					if shallow > 0.6 then
						water = math.max(water or -math.huge, pre - f.Depth + f.WaterDepth)
					end
					tag = if d < f.W * 0.7 then "Canal" else tag
				end
			end
		end
		-- shell craters: a bowl with a thrown-up rim, some holding water
		for _, f in list do
			if f.Kind == "Crater" then
				local dx, dz = x - f.X, z - f.Z
				local d = math.sqrt(dx * dx + dz * dz)
				if d < f.R * 1.45 then
					local pre = h
					if d < f.R then
						h -= f.D * (1 - (d / f.R) ^ 2)
						if tag ~= "Barrow" then
							tag = "Crater"
						end
						if f.Water then
							water = math.max(water or -math.huge, pre - f.D * 0.45)
						end
					end
					h += f.D * 0.3 * bell(math.abs(d - f.R * 1.05) / (f.R * 0.4))
				end
			end
		end
	end
	-- the outer barrows: the world ends in cliffs of the oldest dead
	local ex = math.abs(x) - L.PlayX
	local ez = math.abs(z) - L.PlayZ
	local e = math.max(ex, ez)
	if e > -30 then
		h += cfg().EdgeHeight * smooth((e + 30) / 160) + 8 * smooth((e + 30) / 60) * math.noise(x / 26, z / 26, 5.5)
		if e > -10 then
			tag = "Edge"
		end
	end
	if L.Glade then
		local g = L.Glade
		local dx, dz = x - g.X, z - g.Z
		if dx * dx + dz * dz < g.R * g.R and tag ~= "Crater" and tag ~= "Trench" then
			tag = "Glade"
		end
	end
	if water and water <= h then
		water = nil
	end
	return h, tag, water
end

function FrontMap.Height(x, z)
	return (FrontMap.Sample(x, z))
end

-- ===== the grid =====
function FrontMap.SectorCenter(index)
	local i, j = (index - 1) % L.Cols, math.floor((index - 1) / L.Cols)
	return Vector3.new((i - (L.Cols - 1) / 2) * L.S, 0, (j - (L.Rows - 1) / 2) * L.S), i, j
end

function FrontMap.SectorAt(x, z)
	local i = math.floor(x / L.S + L.Cols / 2)
	local j = math.floor(z / L.S + L.Rows / 2)
	if i < 0 or j < 0 or i >= L.Cols or j >= L.Rows then
		return nil
	end
	return j * L.Cols + i + 1
end

function FrontMap.Index(i, j)
	if i < 0 or j < 0 or i >= L.Cols or j >= L.Rows then
		return nil
	end
	return j * L.Cols + i + 1
end

-- ===== generation =====
local TYPES = { "Village", "Village", "Village", "Trenches", "Trenches", "Craters", "Craters", "Deadwood", "Deadwood", "Works" }
local KITS = { Farmhouse = { W = 18, D = 16 }, Hall = { W = 24, D = 20 } }

function FrontMap.Generate(seed)
	local C = cfg()
	local H = Config.War.Hill
	seed = if seed and seed ~= 0 then seed else Random.new():NextInteger(1, 2 ^ 30)
	local rng = Random.new(seed)
	L = { Seed = seed, S = H.SectorSize, Cols = H.Cols, Rows = H.Rows, Buckets = {}, Sectors = {}, Fords = {}, Ridges = {}, Scatter = {} }
	FrontMap.L = L
	L.HalfX, L.HalfZ = L.Cols * L.S / 2, L.Rows * L.S / 2
	L.BaseX = L.HalfX + C.RearDepth
	L.PlayX, L.PlayZ = L.BaseX + C.Margin, L.HalfZ + C.Margin
	local edge = 200
	-- voxel-aligned (WriteVoxels regions must sit on the 4-stud grid)
	local bx, bz = math.ceil((L.PlayX + edge) / 8) * 8, math.ceil((L.PlayZ + edge) / 8) * 8
	L.Bounds = { X0 = -bx, X1 = bx, Z0 = -bz, Z1 = bz }
	local S = L.S
	local mid = math.floor(L.Cols / 2)

	-- sector types
	local glades = {}
	for index = 1, L.Cols * L.Rows do
		local c, i, j = FrontMap.SectorCenter(index)
		local t
		if i == 0 or i == L.Cols - 1 then
			t = "Line"
		elseif i == mid then
			t = "Barrows"
		else
			t = TYPES[rng:NextInteger(1, #TYPES)]
			if j > 0 and j < L.Rows - 1 then
				table.insert(glades, index)
			end
		end
		L.Sectors[index] = { Index = index, I = i, J = j, Center = c, Type = t, Pads = {}, Trenches = {}, Dugouts = {} }
	end
	if #glades > 0 then
		L.Sectors[glades[rng:NextInteger(1, #glades)]].Type = "Glade"
	end
	local works = 0
	for _, s in L.Sectors do
		works += if s.Type == "Works" then 1 else 0
	end
	if works == 0 then
		for _ = 1, 20 do
			local s = L.Sectors[rng:NextInteger(1, #L.Sectors)]
			if s.Type == "Village" or s.Type == "Craters" then
				s.Type = "Works"
				break
			end
		end
	end

	-- the Spine: the oldest ridge, down the middle column, with two low saddles to cross at
	local function ridge(x0, z0, z1, hLo, hHi, width, saddles)
		local pts, hs = {}, {}
		local n = math.max(3, math.floor((z1 - z0) / 40))
		local x = x0
		for k = 0, n do
			local z = z0 + (z1 - z0) * k / n
			x += rng:NextNumber(-9, 9)
			x = math.clamp(x, x0 - 30, x0 + 30)
			table.insert(pts, Vector2.new(x, z))
			local hh = rng:NextNumber(hLo, hHi)
			for _, sz in saddles do
				hh *= 1 - 0.8 * bell(math.abs(z - sz) / 50)
			end
			table.insert(hs, hh)
		end
		addLine("Ridge", pts, width, { Heights = hs })
		table.insert(L.Ridges, { Points = pts, Heights = hs, W = width })
	end
	local cmid = FrontMap.SectorCenter(FrontMap.Index(mid, 0))
	local saddles = {}
	for j = 0, L.Rows - 2 do
		if rng:NextNumber() < 0.6 then
			table.insert(saddles, (j + 1 - L.Rows / 2) * S + rng:NextNumber(-30, 30))
		end
	end
	if #saddles == 0 then
		saddles = { 0 }
	end
	ridge(cmid.X + rng:NextNumber(-20, 20), -L.HalfZ - 40, L.HalfZ + 40, 9, 17, 34, saddles)
	-- older, broken lines between the columns either side of the centre
	for _, side in { -1, 1 } do
		local x0 = side * (S * 1.5 + rng:NextNumber(-20, 20))
		local zA = rng:NextNumber(-L.HalfZ, -L.HalfZ * 0.2)
		ridge(x0, zA, zA + rng:NextNumber(S * 1.2, S * 2.2), 5, 11, 26, { zA + rng:NextNumber(40, 120) })
		local zB = rng:NextNumber(L.HalfZ * 0.0, L.HalfZ * 0.4)
		ridge(x0 + side * rng:NextNumber(-30, 30), zB, zB + rng:NextNumber(S * 0.8, S * 1.4), 4, 9, 24, {})
	end

	-- the canal: east-west across the field, between two rows, with three fords
	do
		local zc = (math.floor(L.Rows / 2) - L.Rows / 2) * S + rng:NextNumber(-20, 20)
		local pts = {}
		local z = zc
		for x = -L.HalfX - 60, L.HalfX + 60, 50 do
			z = math.clamp(z + rng:NextNumber(-14, 14), zc - 45, zc + 45)
			table.insert(pts, Vector2.new(x, z))
		end
		addLine("Canal", pts, C.CanalWidth, { Depth = C.CanalDepth, WaterDepth = C.CanalWater })
		L.Canal = pts
		for _, u in { 0.2, 0.5, 0.8 } do
			local k = math.clamp(math.floor(#pts * u + rng:NextNumber(-1.5, 1.5)), 1, #pts)
			table.insert(L.Fords, pts[k])
		end
	end
	local function nearCanal(x, z, clear)
		for i = 1, #L.Canal - 1 do
			local a, b = L.Canal[i], L.Canal[i + 1]
			if segDist(a.X, a.Y, b.X, b.Y, x, z) < C.CanalWidth + clear then
				return true
			end
		end
		return false
	end

	-- the old highway between the bases (asphalt under the mud, broken by the craters)
	do
		local zr = (rng:NextInteger(0, L.Rows - 1) - (L.Rows - 1) / 2) * S + rng:NextNumber(-40, 40)
		local pts = {}
		local z = zr
		for x = -L.BaseX, L.BaseX, 60 do
			z = math.clamp(z + rng:NextNumber(-10, 10), zr - 50, zr + 50)
			-- it runs into each base's gate at z = 0
			local toBase = math.clamp((math.abs(x) - L.HalfX) / (L.BaseX - L.HalfX), 0, 1)
			table.insert(pts, Vector2.new(x, z * (1 - smooth(toBase))))
		end
		addLine("Road", pts, 7)
		L.Road = pts
	end

	local function scatter(sector, kind, x, z, yaw, extra)
		local s = { Kind = kind, X = x, Z = z, Yaw = yaw or rng:NextNumber(0, 360), Sector = sector and sector.Index }
		for k, v in extra or {} do
			s[k] = v
		end
		table.insert(L.Scatter, s)
		return s
	end

	-- per sector: the crest, trenches, building pads, craters, then the scatter
	for _, sec in L.Sectors do
		local c = sec.Center
		local t = sec.Type
		local function inSector(margin)
			return c.X + rng:NextNumber(-S / 2 + margin, S / 2 - margin), c.Z + rng:NextNumber(-S / 2 + margin, S / 2 - margin)
		end
		local trenchPts = {}
		local function clearOf(x, z, r, opts)
			opts = opts or {}
			for _, p in sec.Pads do
				if math.sqrt((x - p.X) ^ 2 + (z - p.Z) ^ 2) < p.R + r then
					return false
				end
			end
			if not opts.trench then
				for _, p in trenchPts do
					if math.sqrt((x - p.X) ^ 2 + (z - p.Y) ^ 2) < 7 + r then
						return false
					end
				end
			end
			local crestClear = if opts.crest then 0.2 else 0.55
			if sec.Crest and math.sqrt((x - sec.Crest.X) ^ 2 + (z - sec.Crest.Z) ^ 2) < sec.Crest.R * crestClear + r then
				return false
			end
			if not opts.canal and nearCanal(x, z, r) then
				return false
			end
			if L.Road and not opts.road then
				for i = 1, #L.Road - 1 do
					local a, b = L.Road[i], L.Road[i + 1]
					if segDist(a.X, a.Y, b.X, b.Y, x, z) < 7 + r then
						return false
					end
				end
			end
			return true
		end
		local function spot(margin, r, opts)
			for _ = 1, 24 do
				local x, z = inSector(margin)
				if clearOf(x, z, r, opts) then
					return x, z
				end
			end
			return nil
		end

		-- the crest: the barrow the sector is held around (the hill marker stands on it)
		do
			local x, z
			for _ = 1, 30 do
				x, z = c.X + rng:NextNumber(-S * 0.22, S * 0.22), c.Z + rng:NextNumber(-S * 0.22, S * 0.22)
				if t == "Line" then
					-- out in front of the faction's trench, on the field side
					x = c.X + (if sec.I == 0 then 1 else -1) * rng:NextNumber(S * 0.06, S * 0.24)
				end
				if not nearCanal(x, z, 30) then
					break
				end
			end
			local big = t == "Barrows"
			local r = if big then rng:NextNumber(42, 52) else rng:NextNumber(28, 38)
			local h = if big then rng:NextNumber(15, 21) else rng:NextNumber(7, 12)
			if t == "Glade" then
				r, h = 26, 5
			end
			addMound(x, z, r, h)
			sec.Crest = { X = x, Z = z, R = r, H = h }
			scatter(sec, "Barrow", x, z, nil, { Big = big, Top = true })
		end

		-- trenches
		local function trench(points, width, depth)
			for _, p in points do
				table.insert(trenchPts, p)
			end
			addLine("Trench", points, width, { Depth = depth })
			table.insert(sec.Trenches, points)
		end
		local function zigzag(x0, z0, z1, amp, step)
			local pts = {}
			local k = 0
			for z = z0, z1, step do
				table.insert(pts, Vector2.new(x0 + (if k % 2 == 0 then -amp else amp), z))
				k += 1
			end
			return pts
		end
		if t == "Line" then
			-- the faction's line: one continuous trench down the column (same x every row), facing the field
			local inward = if sec.I == 0 then 1 else -1
			local lineX = c.X - inward * S * 0.18
			trench(zigzag(lineX, c.Z - S / 2, c.Z + S / 2, 4, 16), C.TrenchWidth, C.TrenchDepth)
			-- a communication trench back toward the rear
			local cz = c.Z + rng:NextNumber(-S * 0.3, S * 0.3)
			trench({ Vector2.new(lineX, cz), Vector2.new(lineX - inward * 30, cz + rng:NextNumber(-8, 8)), Vector2.new(lineX - inward * 80, cz + rng:NextNumber(-15, 15)) }, C.TrenchWidth, C.TrenchDepth)
			-- wire in front of the line
			for k = 1, 5 do
				local z = c.Z - S / 2 + (k - 0.5) * S / 5 + rng:NextNumber(-6, 6)
				scatter(sec, "Wire", lineX + inward * rng:NextNumber(24, 34), z, 90 + rng:NextNumber(-12, 12))
			end
			scatter(sec, "FieldGun", lineX - inward * rng:NextNumber(30, 50), c.Z + rng:NextNumber(-60, 60), if inward > 0 then 90 else -90)
		elseif t == "Trenches" then
			-- two lines either side of the crest (the barrow itself is not dug through) and a cut between them
			local crest = sec.Crest
			local xs = {}
			for _, side in { -1, 1 } do
				local x0 = crest.X + side * (crest.R * 0.75 + rng:NextNumber(6, 18))
				x0 = math.clamp(x0, c.X - S * 0.45, c.X + S * 0.45)
				table.insert(xs, x0)
				trench(zigzag(x0, c.Z - S * 0.42, c.Z + S * 0.42, 5, 14), C.TrenchWidth, C.TrenchDepth)
			end
			local zc = crest.Z + (if rng:NextNumber() < 0.5 then -1 else 1) * (crest.R * 0.75 + rng:NextNumber(6, 14))
			zc = math.clamp(zc, c.Z - S * 0.42, c.Z + S * 0.42)
			trench({ Vector2.new(xs[1], zc), Vector2.new((xs[1] + xs[2]) / 2, zc + rng:NextNumber(-8, 8)), Vector2.new(xs[2], zc) }, C.TrenchWidth, C.TrenchDepth)
			for _ = 1, 6 do
				local x, z = spot(14, 6, { trench = true })
				if x then
					scatter(sec, "Wire", x, z, rng:NextNumber(60, 120))
				end
			end
		end
		-- sandbag nests and dugouts along the trenches
		for _, pts in sec.Trenches do
			for k = 2, #pts - 1, 2 do
				local p = pts[k]
				scatter(sec, "Nest", p.X + rng:NextNumber(-1, 1) + (if rng:NextNumber() < 0.5 then -1 else 1) * (C.TrenchWidth + 2.5), p.Y, 90)
			end
		end

		-- building pads
		local nPads = ({ Village = rng:NextInteger(5, 7), Works = 3, Line = 1, Trenches = 1, Craters = 1, Deadwood = 1, Barrows = 1, Glade = 1 })[t]
		for _ = 1, nPads do
			local kitName = if t == "Works" or (t == "Village" and rng:NextNumber() < 0.3) then "Hall" else "Farmhouse"
			local kit = KITS[kitName]
			local r = math.sqrt(kit.W * kit.W + kit.D * kit.D) / 2 + 3
			local x, z = spot(r + 10, r + 6)
			if x then
				local y = base(x, z)
				table.insert(sec.Pads, { X = x, Z = z, R = r, Kit = kitName, Y = y })
				addPad(x, z, r, y)
			end
		end

		-- craters
		local nCraters = ({ Village = 8, Works = 6, Line = 6, Trenches = 10, Craters = 34, Deadwood = 12, Barrows = 10, Glade = 0 })[t]
		for _ = 1, nCraters do
			local r = if t == "Craters" then rng:NextNumber(4, 13) else rng:NextNumber(3.5, 9)
			local x, z = spot(6, r, { crest = true, trench = t == "Craters" })
			if x then
				addCrater(x, z, r, r * rng:NextNumber(0.35, 0.5), t == "Craters" and r > 7 and rng:NextNumber() < 0.45)
			end
		end

		-- what lies about
		local function many(kind, n, margin, r, opts, extra)
			for _ = 1, n do
				local x, z = spot(margin, r, opts)
				if x then
					scatter(sec, kind, x, z, nil, extra)
				end
			end
		end
		local bodies = ({ Village = 6, Works = 5, Line = 8, Trenches = 10, Craters = 14, Deadwood = 8, Barrows = 22, Glade = 0 })[t]
		many("Calcified", bodies, 6, 2, { crest = true, trench = true })
		if t == "Barrows" then
			for _ = 1, rng:NextInteger(3, 5) do
				local x, z = spot(30, 20, { crest = true })
				if x then
					local r, h = rng:NextNumber(18, 30), rng:NextNumber(5, 12)
					addMound(x, z, r, h)
					scatter(sec, "Barrow", x, z, nil, { Top = true, H = h })
				end
			end
			many("Barrow", 3, 20, 10, { crest = true })
		end
		if t == "Deadwood" then
			many("DeadTree", rng:NextInteger(14, 20), 6, 3)
			many("Stump", rng:NextInteger(24, 34), 4, 2)
		elseif t == "Glade" then
			local x, z = sec.Crest.X, sec.Crest.Z
			L.Glade = { X = x, Z = z, R = 46, Sector = sec.Index }
			scatter(sec, "LiveTree", x, z, nil, { Top = true })
			for _ = 1, 10 do
				local a, d = rng:NextNumber(0, math.pi * 2), rng:NextNumber(14, 40)
				scatter(sec, if rng:NextNumber() < 0.6 then "Bush" else "Pine", x + math.cos(a) * d, z + math.sin(a) * d)
			end
			many("Stump", 10, 4, 2)
		else
			many("Stump", ({ Village = 4, Works = 2, Line = 5, Trenches = 6, Craters = 8, Barrows = 3 })[t] or 3, 4, 2)
		end
		if t == "Works" then
			many("Chimney", rng:NextInteger(1, 2), 30, 8)
			many("Pylon", 1, 30, 6)
			many("Rubble", 10, 10, 4)
		end
		if t == "Village" or t == "Works" then
			many("Rubble", 6, 10, 3)
			many("Wreck", rng:NextInteger(1, 2), 20, 8, { road = true })
		end
		if t ~= "Glade" then
			many("Nest", ({ Village = 6, Works = 4, Line = 3, Trenches = 3, Craters = 4, Deadwood = 3, Barrows = 4 })[t], 10, 4)
			many("Crate", 2, 14, 2)
			many("Hedgehog", rng:NextInteger(1, 3), 8, 3)
		end
		if t == "Craters" or t == "Barrows" or t == "Deadwood" then
			many("Wire", rng:NextInteger(1, 3), 12, 6, { trench = true })
		end
		if rng:NextNumber() < 0.15 then
			many("FieldGun", 1, 20, 6)
		end

		-- the dugouts: each faction's forward deploy point in this sector, on its own side, door to its rear
		for _, faction in Config.War.Factions do
			local side = if faction == "Union" then -1 else 1
			local x, z
			for _ = 1, 30 do
				x, z = c.X + side * rng:NextNumber(S * 0.28, S * 0.4), c.Z + rng:NextNumber(-S * 0.3, S * 0.3)
				if clearOf(x, z, 8) then
					break
				end
			end
			sec.Dugouts[faction] = { X = x, Z = z, Yaw = if side < 0 then 90 else -90, Out = side }
			addPad(x, z, 7, base(x, z))
			scatter(sec, "Dugout", x, z, sec.Dugouts[faction].Yaw)
		end
	end

	-- the rears: each faction's base on a flattened apron, the highway runs in, smokestacks and pylons behind
	L.Bases = {}
	for _, faction in Config.War.Factions do
		local side = if faction == "Union" then -1 else 1
		local x = side * L.BaseX
		local y = base(x, 0)
		L.Bases[faction] = { X = x, Z = 0, Y = y }
		addPad(x, 0, 70, y)
		for k = 1, 6 do
			local z = (k - 3.5) * 120 + rng:NextNumber(-20, 20)
			if math.abs(z) > 90 then
				scatter(nil, "Wire", x - side * rng:NextNumber(150, 190), z, 90 + rng:NextNumber(-10, 10))
			end
		end
		for _ = 1, 4 do
			scatter(nil, "Pylon", x + side * rng:NextNumber(60, 110), rng:NextNumber(-L.HalfZ, L.HalfZ))
		end
		for _ = 1, 3 do
			local z = rng:NextNumber(-L.HalfZ, L.HalfZ)
			if math.abs(z) > 90 then
				scatter(nil, "FieldGun", x - side * rng:NextNumber(90, 140), z, if side < 0 then 90 else -90)
			end
		end
	end
	-- the ground outside the grid (the rears and the north/south margins): older craters, the dead, stumps,
	-- broken barrow ridges along the outer edge
	local function outside(x, z)
		if math.abs(x) < L.HalfX + 10 and math.abs(z) < L.HalfZ + 10 then
			return false
		end
		for _, b in L.Bases do
			if math.sqrt((x - b.X) ^ 2 + (z - b.Z) ^ 2) < 90 then
				return false
			end
		end
		for i = 1, #L.Road - 1 do
			local a, b = L.Road[i], L.Road[i + 1]
			if segDist(a.X, a.Y, b.X, b.Y, x, z) < 10 then
				return false
			end
		end
		return true
	end
	local function outerSpot()
		for _ = 1, 30 do
			local x, z = rng:NextNumber(-L.PlayX + 20, L.PlayX - 20), rng:NextNumber(-L.PlayZ + 20, L.PlayZ - 20)
			if outside(x, z) then
				return x, z
			end
		end
		return nil
	end
	for _, n in { { "Crater", C.RearCraters }, { "Calcified", C.RearDead }, { "Stump", C.RearStumps }, { "Nest", 16 }, { "Wreck", 6 }, { "Wire", 14 }, { "Hedgehog", 14 } } do
		for _ = 1, n[2] do
			local x, z = outerSpot()
			if x then
				if n[1] == "Crater" then
					local r = rng:NextNumber(3.5, 10)
					addCrater(x, z, r, r * rng:NextNumber(0.35, 0.5), r > 7 and rng:NextNumber() < 0.3)
				else
					scatter(nil, n[1], x, z)
				end
			end
		end
	end
	for _, side in { -1, 1 } do
		for _ = 1, 3 do
			local z0 = side * (L.HalfZ + rng:NextNumber(40, C.Margin - 10))
			local x0 = rng:NextNumber(-L.HalfX, L.HalfX)
			local pts, hs = {}, {}
			for k = 0, 4 do
				table.insert(pts, Vector2.new(x0 + k * 45, z0 + rng:NextNumber(-15, 15)))
				table.insert(hs, if k == 0 or k == 4 then 1 else rng:NextNumber(4, 9))
			end
			addLine("Ridge", pts, 22, { Heights = hs })
		end
	end
	-- the skyline beyond the outer barrows: the industrial world that made all this, still smoking
	L.Skyline = {}
	for _ = 1, C.Smokestacks do
		local a = rng:NextNumber(0, math.pi * 2)
		local x = math.cos(a) * (L.PlayX + rng:NextNumber(260, 520))
		local z = math.sin(a) * (L.PlayZ + rng:NextNumber(260, 520))
		table.insert(L.Skyline, { X = x, Z = z, Scale = rng:NextNumber(3, 5.5) })
	end
	return L
end

function FrontMap.Layout()
	return L
end

return FrontMap
