-- Boots the server and writes every world part (position, size, colour, folder) as JSON so
-- tools/smoke/map.py can draw a top-down map of the generated city.
local game_, workspace_ = M.game, M.workspace
local RS = game_:GetService("ReplicatedStorage")
local SSS = game_:GetService("ServerScriptService")
M.mkTree({ Shared = { class = "Folder", children = TREE_SHARED } }, RS)
M.mkTree({ Server = { class = "Folder", children = TREE_SERVER } }, SSS)
M.mkTree({ Common = { class = "Folder", children = TREE_COMMON } }, SSS.Server)
M.task.spawn(function() M.loadSource(SSS.Server.Main)() end)
for _ = 1, 30 do M.step(1/30) end

local function topFolder(inst)
	local p = inst
	while p.Parent and p.Parent ~= workspace_ do p = p.Parent end
	return p and p.Name or "?"
end
local rows = {}
for _, d in workspace_:GetDescendants() do
	if d:IsA("BasePart") and d.Size and d.CFrame then
		local c = d.Color or { R = 0.5, G = 0.5, B = 0.5 }
		local look = d.CFrame.LookVector
		local model = d:FindFirstAncestorOfClass("Model")
		table.insert(rows, string.format('{"f":"%s","n":"%s","m":"%s","x":%.1f,"y":%.1f,"z":%.1f,"sx":%.1f,"sy":%.1f,"sz":%.1f,"lx":%.3f,"lz":%.3f,"r":%d,"g":%d,"b":%d,"neon":%s,"tier":"%s","prop":"%s","label":"%s"}',
			topFolder(d), d.Name, model and model.Name or "", d.Position.X, d.Position.Y, d.Position.Z, d.Size.X, d.Size.Y, d.Size.Z, look.X, look.Z,
			math.floor(c.R * 255), math.floor(c.G * 255), math.floor(c.B * 255), tostring(tostring(d.Material):find("Neon") ~= nil),
			tostring(model and model:GetAttribute("Tier") or ""), tostring(model and model:GetAttribute("Prop") or ""), tostring(d:GetAttribute("Label") or "")))
	end
end
-- the frontier's ground: Frontier.Height sampled every 8 studs over its bounds (map.py shades it)
do
	local FS = M.mockEnv.__require(RS.Shared.Frontier)
	local B = FS.Bounds
	local lines = {}
	for z = B.Z0, B.Z1, 8 do
		local row = {}
		for x = B.X0, B.X1, 8 do
			table.insert(row, string.format("%.0f", if FS.InCity(x, z) then FS.CityTop else FS.Height(x, z)))
		end
		table.insert(lines, table.concat(row, ","))
	end
	print("HEIGHT_BEGIN " .. B.X0 .. " " .. B.Z0 .. " 8")
	print(table.concat(lines, "\n"))
	print("HEIGHT_END")
	local labels = { ("[\"VERDANT REACH\",%d,%d]"):format(FS.Reach.Center.X, FS.Reach.Center.Z) }
	for _, site in FS.Sites do table.insert(labels, ("[%q,%d,%d]"):format(site.Name, site.Position.X, site.Position.Z)) end
	for r = 1, FS.Rows do for c = 1, FS.Cols do local cell = FS.L.Cells[r][c]; if cell.Zone == "Valley" and not cell.Site and cell.Type ~= "Reach" then table.insert(labels, ("[%q,%d,%d]"):format(cell.Type:lower(), cell.Center.X, cell.Center.Z)) end end end
	print("LABELS_BEGIN")
	print("[" .. table.concat(labels, ",") .. "]")
	print("LABELS_END")
end
print("JSON_BEGIN")
print("[" .. table.concat(rows, ",\n") .. "]")
print("JSON_END")
