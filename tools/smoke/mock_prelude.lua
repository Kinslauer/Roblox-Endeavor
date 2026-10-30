-- Minimal Roblox mock, just enough to execute the game's server code and catch runtime errors.
local G = _G
local now, frame = 0, 0
local task_
local newInstance
local sleepers, spawnedErrors = {}, {}

-------------------------------------------------- math types
local V3 = {}
V3.__index = function(t, k)
	if k == "Magnitude" then return math.sqrt(t.X*t.X + t.Y*t.Y + t.Z*t.Z) end
	if k == "Unit" then local m = t.Magnitude; if m == 0 then return t end; return V3.new(t.X/m, t.Y/m, t.Z/m) end
	return V3[k]
end
function V3.new(x, y, z) return setmetatable({X = x or 0, Y = y or 0, Z = z or 0}, V3) end
V3.zero = V3.new(0,0,0)
V3.yAxis = V3.new(0,1,0)
local function isV3(v) return getmetatable(v) == V3 end
V3.__add = function(a, b) return V3.new(a.X+b.X, a.Y+b.Y, a.Z+b.Z) end
V3.__sub = function(a, b) return V3.new(a.X-b.X, a.Y-b.Y, a.Z-b.Z) end
V3.__mul = function(a, b)
	if type(a) == "number" then return V3.new(a*b.X, a*b.Y, a*b.Z) end
	if type(b) == "number" then return V3.new(a.X*b, a.Y*b, a.Z*b) end
	return V3.new(a.X*b.X, a.Y*b.Y, a.Z*b.Z)
end
V3.__div = function(a, b) if type(b) == "number" then return V3.new(a.X/b, a.Y/b, a.Z/b) end return V3.new(a.X/b.X, a.Y/b.Y, a.Z/b.Z) end
V3.__unm = function(a) return V3.new(-a.X, -a.Y, -a.Z) end
V3.__eq = function(a, b) return a.X == b.X and a.Y == b.Y and a.Z == b.Z end
function V3.Dot(a, b) return a.X*b.X + a.Y*b.Y + a.Z*b.Z end
function V3.Cross(a, b) return V3.new(a.Y*b.Z - a.Z*b.Y, a.Z*b.X - a.X*b.Z, a.X*b.Y - a.Y*b.X) end

local CF = {}
CF.__index = function(t, k)
	if k == "LookVector" then return V3.new(-t.r[3], -t.r[6], -t.r[9]) end
	if k == "RightVector" then return V3.new(t.r[1], t.r[4], t.r[7]) end
	if k == "UpVector" then return V3.new(t.r[2], t.r[5], t.r[8]) end
	return CF[k]
end
local ID = {1,0,0, 0,1,0, 0,0,1}
local function mkcf(p, r) return setmetatable({Position = p, r = r or ID}, CF) end
local function mmul(a, b)
	local o = {}
	for i = 0, 2 do for j = 0, 2 do
		o[i*3+j+1] = a[i*3+1]*b[j+1] + a[i*3+2]*b[3+j+1] + a[i*3+3]*b[6+j+1]
	end end
	return o
end
local function rot(r, v) return V3.new(r[1]*v.X + r[2]*v.Y + r[3]*v.Z, r[4]*v.X + r[5]*v.Y + r[6]*v.Z, r[7]*v.X + r[8]*v.Y + r[9]*v.Z) end
function CF.new(a, b, c)
	if a == nil then return mkcf(V3.zero) end
	if isV3(a) then
		if b and isV3(b) then return CF.lookAt(a, b) end
		return mkcf(a)
	end
	return mkcf(V3.new(a, b, c))
end
function CF.lookAt(pos, target)
	local look = (target - pos)
	assert(look.Magnitude > 0, "lookAt: zero-length direction")
	look = look.Unit
	local up = V3.new(0, 1, 0)
	if math.abs(look.Y) > 0.999 then up = V3.new(0, 0, 1) end
	local z = -look
	local x = up:Cross(z).Unit
	local y = z:Cross(x)
	return mkcf(pos, {x.X, y.X, z.X, x.Y, y.Y, z.Y, x.Z, y.Z, z.Z})
end
function CF.Angles(rx, ry, rz)
	local cx, sx, cy, sy, cz, sz = math.cos(rx), math.sin(rx), math.cos(ry), math.sin(ry), math.cos(rz), math.sin(rz)
	local Rx = {1,0,0, 0,cx,-sx, 0,sx,cx}
	local Ry = {cy,0,sy, 0,1,0, -sy,0,cy}
	local Rz = {cz,-sz,0, sz,cz,0, 0,0,1}
	return mkcf(V3.zero, mmul(mmul(Rx, Ry), Rz))
end
CF.__mul = function(a, b)
	if isV3(b) then return a.Position + rot(a.r, b) end
	return mkcf(a.Position + rot(a.r, b.Position), mmul(a.r, b.r))
end
CF.__add = function(a, b) return mkcf(a.Position + b, a.r) end
CF.__sub = function(a, b) return mkcf(a.Position - b, a.r) end
function CF.Inverse(a) return a end

local Color3 = { new = function(r, g, b) return {R = r, G = g, B = b} end, fromRGB = function(r, g, b) return {R = r/255, G = g/255, B = b/255} end }
local UDim = { new = function(s, o) return {Scale = s, Offset = o} end }
local UDim2 = {
	new = function(a, b, c, d) return {X = UDim.new(a, b), Y = UDim.new(c, d)} end,
	fromOffset = function(x, y) return {X = UDim.new(0, x), Y = UDim.new(0, y)} end,
	fromScale = function(x, y) return {X = UDim.new(x, 0), Y = UDim.new(y, 0)} end,
}
local Vector2 = { new = function(x, y) return {X = x, Y = y} end }

local Enum = setmetatable({}, { __index = function(_, e) return setmetatable({}, { __index = function(_, i) return e .. "." .. i end }) end })

-------------------------------------------------- signals
local Signal = {}
Signal.__index = Signal
local function runSafe(fn, ...)
	local co = coroutine.create(fn)
	local ok, err = coroutine.resume(co, ...)
	if not ok then table.insert(spawnedErrors, err .. "\n" .. debug.traceback(co)); print("!! ERROR: " .. tostring(err)); print(debug.traceback(co)) end
	return co
end
function Signal.new() return setmetatable({conns = {}, waiters = {}}, Signal) end
function Signal:Connect(fn) local c = {fn = fn, connected = true}; function c:Disconnect() self.connected = false end; table.insert(self.conns, c); return c end
function Signal:Once(fn) local c; c = self:Connect(function(...) c:Disconnect(); fn(...) end); return c end
function Signal:Wait() local co = coroutine.running(); table.insert(self.waiters, co); return coroutine.yield() end
function Signal:Fire(...)
	for _, c in self.conns do if c.connected then runSafe(c.fn, ...) end end
	local w = self.waiters; self.waiters = {}
	for _, co in w do local ok, err = coroutine.resume(co, ...); if not ok then print("!! ERROR(wait): " .. tostring(err)) end end
end

-------------------------------------------------- instances
local EVENTS = { Changed=1, Triggered=1, Died=1, HealthChanged=1, Touched=1, AncestryChanged=1, OnServerEvent=1, OnClientEvent=1,
	PlayerAdded=1, PlayerRemoving=1, CharacterAdded=1, CharacterRemoving=1, Event=1, Heartbeat=1, RenderStepped=1, Destroying=1, Activated=1, InputBegan=1, InputEnded=1 }
local Instance, new = {}, nil
local methods = {}
local Inst = {}
local FireLog = {}

local function sig(self, name)
	local s = rawget(self, "_sigs"); if not s then s = {}; rawset(self, "_sigs", s) end
	if not s[name] then s[name] = Signal.new() end
	return s[name]
end
local function descendants(self, out)
	for _, c in self._children do table.insert(out, c); descendants(c, out) end
	return out
end
local PARTS = { Part = 1, MeshPart = 1, WedgePart = 1, SpawnLocation = 1 }
function methods.IsA(self, cls)
	return self.ClassName == cls or cls == "Instance" or (cls == "BasePart" and PARTS[self.ClassName] ~= nil) or (cls == "PVInstance" and (PARTS[self.ClassName] or self.ClassName == "Model"))
end
function methods.GetChildren(self) return table.clone(self._children) end
function methods.GetDescendants(self) return descendants(self, {}) end
function methods.FindFirstChild(self, name, rec)
	for _, c in self._children do if c.Name == name then return c end end
	if rec then for _, d in descendants(self, {}) do if d.Name == name then return d end end end
	return nil
end
function methods.FindFirstChildOfClass(self, cls) for _, c in self._children do if c.ClassName == cls then return c end end end
function methods.FindFirstChildWhichIsA(self, cls) for _, c in self._children do if c:IsA(cls) then return c end end end
function methods.WaitForChild(self, name) local c = self:FindFirstChild(name); if not c then print("!! WaitForChild would hang: " .. self:GetFullName() .. " -> " .. name) end return c end
function methods.FindFirstAncestorOfClass(self, cls) local p = self.Parent; while p do if p.ClassName == cls then return p end p = p.Parent end end
function methods.IsDescendantOf(self, a) local p = self.Parent; while p do if p == a then return true end p = p.Parent end return false end
function methods.GetFullName(self) if self.Parent and self.Parent.Name ~= "game" then return self.Parent:GetFullName() .. "." .. self.Name end return self.Name end
function methods.Destroy(self) self.Parent = nil; rawset(self, "Destroyed", true); sig(self, "Destroying"):Fire() end
function methods.SetAttribute(self, k, v) local a = self._attrs; if a[k] ~= v then a[k] = v; sig(self, "attr:" .. k):Fire() end end
function methods.GetAttribute(self, k) return self._attrs[k] end
function methods.GetAttributeChangedSignal(self, k) return sig(self, "attr:" .. k) end
function methods.PivotTo(self, cf)
	rawset(self, "_pivot", cf)
	local root = self.PrimaryPart or self:FindFirstChild("HumanoidRootPart")
	if root then root.CFrame = cf end
	for _, c in self._children do if c:IsA("BasePart") and c ~= root then c.CFrame = cf end end
end
function methods.GetPivot(self)
	local root = self.PrimaryPart or self:FindFirstChild("HumanoidRootPart") or self:FindFirstChildWhichIsA("BasePart")
	return (root and root.CFrame) or self._pivot or mkcf(V3.zero)
end
function methods.Clone(self)
	local c = newInstance(self.ClassName); c.Name = self.Name
	for k, v in pairs(self) do
		if k ~= "_children" and k ~= "_parent" and k ~= "_sigs" and k ~= "_attrs" and k ~= "ClassName" and k ~= "Name" then rawset(c, k, v) end
	end
	for k, v in self._attrs do c._attrs[k] = v end
	for _, ch in self._children do local cc = ch:Clone(); cc.Parent = c end
	return c
end
function methods.TakeDamage(self, n) self.Health = math.max(0, self.Health - n) end
function methods.MoveTo(self, p) end
function methods.FireClient(self, p, ...) local e = {self.Name, "client", ...}; e.player = p; table.insert(FireLog, e) end
function methods.FireAllClients(self, ...) table.insert(FireLog, {self.Name, "all", ...}) end
function methods.FireServer(self, ...) sig(self, "OnServerEvent"):Fire(Instance.CurrentPlayer, ...) end
function methods.Fire(self, ...) sig(self, "Event"):Fire(...) end
function methods.Play(self) end
function methods.Kick(self, msg) print("!! KICKED: " .. tostring(msg)) end
function methods.Reconcile() end
function methods.GetPartBoundsInRadius(self, origin, radius, params)
	local out, list = {}, (params and params.FilterDescendantsInstances) or {}
	local include = params and params.FilterType == "RaycastFilterType.Include"
	for _, d in descendants(self, {}) do
		if d:IsA("BasePart") and d.Position and (d.Position - origin).Magnitude <= radius then
			local listed = false
			for _, ex in list do if d == ex or d:IsDescendantOf(ex) then listed = true end end
			if include == listed then table.insert(out, d) end
		end
	end
	return out
end
function methods.GetPartBoundsInBox(self, cf, size, params)
	local out, list = {}, (params and params.FilterDescendantsInstances) or {}
	for _, d in descendants(self, {}) do
		if d:IsA("BasePart") and d.Position then
			local o = d.Position - cf.Position
			if math.abs(o.X) <= size.X/2 and math.abs(o.Y) <= size.Y/2 and math.abs(o.Z) <= size.Z/2 then
				local listed = false
				for _, ex in list do if d == ex or d:IsDescendantOf(ex) then listed = true end end
				if not listed then table.insert(out, d) end
			end
		end
	end
	return out
end
function methods.GetPartBoundsInBox() return {} end
-- Raycast: only characters block (good enough for hit-scan and line-of-sight tests)
function methods.Raycast(self, origin, dir, params)
	local list = (params and params.FilterDescendantsInstances) or {}
	local len = dir.Magnitude
	if len < 1e-6 then return nil end
	local u = dir / len
	local best, bestT = nil, math.huge
	for _, d in descendants(self, {}) do
		if d.ClassName == "Part" and (d.Name == "HumanoidRootPart" or d.Name == "Torso" or d.Name == "Head") then
			local model = d:FindFirstAncestorOfClass("Model")
			if model and model:FindFirstChildOfClass("Humanoid") then
				local skip = false
				for _, ex in list do if d == ex or d:IsDescendantOf(ex) then skip = true end end
				if not skip then
					local rel = d.Position - origin
					local t = rel:Dot(u)
					if t > 0 and t < len and (rel - u * t).Magnitude <= 2.5 and t < bestT then best, bestT = d, t end
				end
			end
		end
	end
	if best then return { Instance = best, Position = origin + u * bestT, Normal = V3.new(0, 1, 0), Distance = bestT } end
	return nil
end
function methods.GetJoinData(self) return rawget(self, "_joinData") or {} end
function methods.SetTeleportData(self, d) rawset(self, "_td", d) end
function methods.TeleportAsync(self, placeId, players, options) table.insert(FireLog, { "Teleport", placeId, players, options }) end
function methods.IsStudio() return true end
function methods.IsServer() return true end
function methods.IsClient() return false end
function methods.BindToClose() end
function methods.SetNetworkOwner() end
function methods.GetDebugId() return "id" end

local DEFAULTS = {
	Humanoid = function(i) rawset(i, "MaxHealth", 100); rawset(i, "_Health", 100); rawset(i, "WalkSpeed", 16); rawset(i, "HipHeight", 0) end,
	Part = function(i) rawset(i, "_cf", mkcf(V3.zero)); rawset(i, "Size", V3.new(4,1,2)); rawset(i, "Anchored", false); rawset(i, "CanCollide", true) end,
	MeshPart = function(i) rawset(i, "_cf", mkcf(V3.zero)); rawset(i, "Size", V3.new(4,1,2)) end,
}

local MT = {}
MT.__index = function(self, k)
	local cls = rawget(self, "ClassName")
	if PARTS[cls] then
		if k == "CFrame" then return rawget(self, "_cf") elseif k == "Position" then return rawget(self, "_cf").Position end
	elseif cls == "Humanoid" and k == "Health" then return rawget(self, "_Health") end
	if k == "Parent" then return rawget(self, "_parent") end
	if cls == "Folder" then -- a folder's children win over method names (a remote called "Fire")
		for _, c in rawget(self, "_children") do if c.Name == k then return c end end
	end
	if methods[k] then return methods[k] end
	if EVENTS[k] then return sig(self, k) end
	for _, c in rawget(self, "_children") do if c.Name == k then return c end end
	return nil
end
MT.__newindex = function(self, k, v)
	local cls = rawget(self, "ClassName")
	if k == "Parent" then
		local old = rawget(self, "_parent")
		if old then for i, c in old._children do if c == self then table.remove(old._children, i) break end end end
		rawset(self, "_parent", v)
		if v then table.insert(v._children, self) end
		return
	end
	if PARTS[cls] and k == "Position" then rawset(self, "_cf", mkcf(v, rawget(self, "_cf").r)); return end
	if PARTS[cls] and k == "CFrame" then rawset(self, "_cf", v); return end
	if cls == "Humanoid" and k == "Health" then
		local old = rawget(self, "_Health"); local new = math.clamp(v, 0, (self.MaxHealth or 100) + 1e9)
		rawset(self, "_Health", new)
		if old ~= new then sig(self, "HealthChanged"):Fire(new) end
		if new <= 0 and old and old > 0 then sig(self, "Died"):Fire() end
		return
	end
	rawset(self, k, v)
end
newInstance = function(cls)
	local i = setmetatable({ClassName = cls, Name = cls, _children = {}, _attrs = {}}, MT)
	if DEFAULTS[cls] then DEFAULTS[cls](i) end
	if cls == "Model" then rawset(i, "PrimaryPart", nil) end
	return i
end
Instance.new = function(cls, parent) local i = newInstance(cls); if parent then i.Parent = parent end return i end

-------------------------------------------------- services
local game_ = newInstance("DataModel"); game_.Name = "game"
local services = {}
local Players_
local function service(name)
	if services[name] then return services[name] end
	local s = newInstance(name); s.Name = name; s.Parent = (name ~= "Workspace") and game_ or game_
	services[name] = s
	return s
end
function methods.GetService(self, name)
	local s = service(name)
	if name == "Players" and not s._init then
		s._init = true; Players_ = s
		s.CharacterAutoLoads = true
		function s.GetPlayers() local out = {} for _, c in s._children do if c.ClassName == "Player" then table.insert(out, c) end end return out end
		function s.GetPlayerFromCharacter(_, char) for _, p in s:GetPlayers() do if p.Character == char then return p end end return nil end
		function s.GetPlayerByUserId(_, id) for _, p in s:GetPlayers() do if p.UserId == id then return p end end return nil end
	elseif name == "CollectionService" and not s._init then
		s._init = true; local tags = {}
		function s.AddTag(_, inst, tag) tags[tag] = tags[tag] or {}; table.insert(tags[tag], inst) end
		function s.GetTagged(_, tag) return tags[tag] or {} end
	elseif name == "Debris" and not s._init then
		s._init = true; function s.AddItem(_, inst, t) task_.delay(t, function() if inst.Parent then inst:Destroy() end end) end
	elseif name == "TweenService" and not s._init then
		s._init = true; function s.Create() return newInstance("Tween") end
	elseif name == "DataStoreService" and not s._init then
		s._init = true
		function s.GetDataStore() local ds = {}; function ds.GetAsync() return nil end; function ds.SetAsync() end; function ds.UpdateAsync(_, k, f) return f(nil) end; function ds.RemoveAsync() end; return ds end
	elseif name == "RunService" and not s._init then
		s._init = true; s.Heartbeat = sig(s, "Heartbeat"); s.RenderStepped = sig(s, "RenderStepped")
	end
	return s
end
game_.GetService = methods.GetService
local workspace_ = game_:GetService("Workspace")
workspace_.Name = "Workspace"

-------------------------------------------------- scheduler
task_ = {}
function task_.spawn(fn, ...) local args = table.pack(...); return runSafe(function() fn(table.unpack(args, 1, args.n)) end) end
task_.defer = task_.spawn
function task_.delay(t, fn, ...) local args = table.pack(...); table.insert(sleepers, {at = now + t, fn = function() fn(table.unpack(args, 1, args.n)) end}) end
function task_.wait(t) local co = coroutine.running(); table.insert(sleepers, {at = now + (t or 1/30), co = co}); coroutine.yield(); return t or 1/30 end
function task_.cancel() end
local rs = game_:GetService("RunService")
local function step(dt)
	now += dt; frame += 1
	local due, rest = {}, {}
	for _, s in sleepers do if s.at <= now then table.insert(due, s) else table.insert(rest, s) end end
	sleepers = rest
	for _, s in due do
		if s.co then local ok, err = coroutine.resume(s.co); if not ok then print("!! ERROR(task): " .. tostring(err)); print(debug.traceback(s.co)) end
		else runSafe(s.fn) end
	end
	rs.Heartbeat:Fire(dt)
end

-------------------------------------------------- modules / environment
local SOURCES, moduleCache = {}, {}
local mockEnv = {
	game = game_, workspace = workspace_, Instance = Instance, Vector3 = V3, CFrame = CF, Color3 = Color3, UDim = UDim, UDim2 = UDim2,
	Vector2 = Vector2, Enum = Enum, task = task_,
	TweenInfo = { new = function() return {} end }, OverlapParams = { new = function() return {} end }, RaycastParams = { new = function() return {} end },
	Random = { new = function() local r = {}; function r:NextNumber(a, b) return (a or 0) + math.random() * ((b or 1) - (a or 0)) end; function r:NextInteger(a, b) return math.random(a, b) end return r end },
	typeof = function(v)
		if type(v) == "table" then
			local mt = getmetatable(v)
			if mt == V3 then return "Vector3" elseif mt == CF then return "CFrame" elseif mt == MT then return "Instance" end
		end
		return type(v)
	end,
	os = { clock = function() return now end, time = function() return 1700000000 + math.floor(now) end },
	warn = function(...) print("WARN:", ...) end,
}
local function makeEnv(inst)
	local env = setmetatable({ script = inst }, { __index = function(_, k) if mockEnv[k] ~= nil then return mockEnv[k] end return G[k] end })
	env.require = function(m) return mockEnv.__require(m) end
	return env
end
local function loadSource(inst)
	local src = inst._source
	local fn, err = loadstring(src, "=" .. inst:GetFullName())
	assert(fn, err)
	setfenv(fn, makeEnv(inst))
	return fn
end
mockEnv.__require = function(inst)
	if moduleCache[inst] ~= nil then return moduleCache[inst].v end
	assert(inst and inst._source, "require: not a module: " .. tostring(inst and inst.Name))
	local entry = { v = nil }
	moduleCache[inst] = entry
	entry.v = loadSource(inst)()
	return entry.v
end

local function mkTree(spec, parent)
	for name, node in spec do
		local cls = node.class or "Folder"
		local inst = newInstance(cls); inst.Name = name; inst._source = node.source; inst.Parent = parent
		if node.children then mkTree(node.children, inst) end
	end
end

return {
	game = game_, workspace = workspace_, step = step, newInstance = newInstance, mkTree = mkTree, loadSource = loadSource, FireLog = FireLog,
	setNow = function() return now end, mockEnv = mockEnv, runSafe = runSafe, V3 = V3, CF = CF, errors = spawnedErrors, task = task_,
	setPlayer = function(p) Instance.CurrentPlayer = p end, sig = sig,
}
