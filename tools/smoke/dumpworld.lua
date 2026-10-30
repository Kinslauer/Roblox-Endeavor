-- Boots the server and writes every world part (position, size, colour, folder) as JSON so
-- tools/smoke/map.py can draw a top-down map of the generated city.
local game_, workspace_ = M.game, M.workspace
local RS = game_:GetService("ReplicatedStorage")
local SSS = game_:GetService("ServerScriptService")
M.mkTree({ Shared = { class = "Folder", children = TREE_SHARED } }, RS)
M.mkTree({ Server = { class = "Folder", children = TREE_SERVER } }, SSS)
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
print("JSON_BEGIN")
print("[" .. table.concat(rows, ",\n") .. "]")
print("JSON_END")
