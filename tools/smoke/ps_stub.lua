local PS = {}
local function deepCopy(v)
	if type(v) ~= "table" then
		return v
	end
	local c = {}
	for a, b in v do
		c[a] = deepCopy(b)
	end
	return c
end
local function reconcile(data, template)
	for k, v in template do
		if data[k] == nil then
			data[k] = deepCopy(v) -- like the real ProfileService: nested tables are never shared
		elseif type(v) == "table" and type(data[k]) == "table" then
			reconcile(data[k], v)
		end
	end
end
function PS.GetProfileStore(name, template)
	local store = {}
	function store:LoadProfileAsync(key, handler)
		local profile = { Data = {} }
		function profile:Reconcile() reconcile(self.Data, template) end
		function profile:ListenToRelease() end
		function profile:Release() end
		return profile
	end
	return store
end
return PS
