-- Boots the Front server and prints the generated open world for tools/smoke/frontmap.py: the ground sampled
-- every 8 studs (height, tag, water), the sectors (type, crest, dugouts) and every scattered prop.
-- Usage: python3 tools/smoke/gen.py tools/smoke/dumpfront.lua > /tmp/f.lua && luau /tmp/f.lua > /tmp/front.txt
--        python3 tools/smoke/frontmap.py /tmp/front.txt docs/maps/front_map.png
local game_, workspace_ = M.game, M.workspace
local RS = game_:GetService("ReplicatedStorage")
local SSS = game_:GetService("ServerScriptService")
M.mkTree({ Shared = { class = "Folder", children = TREE_SHARED } }, RS)
M.mkTree({ Server = { class = "Folder", children = TREE_WAR } }, SSS)
M.mkTree({ Common = { class = "Folder", children = TREE_COMMON } }, SSS.Server)
M.task.spawn(function() M.loadSource(SSS.Server.Main)() end)
for _ = 1, 30 do M.step(1/30) end
local FrontMap = M.mockEnv.__require(RS.Shared.FrontMap)
local L = FrontMap.Layout()
local B = L.Bounds
local STEP = 8
print(("GRID %d %d %d %d %d %d %d"):format(B.X0, B.Z0, B.X1, B.Z1, STEP, L.Seed, L.S))
local tags = {}
for z = B.Z0, B.Z1 - 1, STEP do
	local row = {}
	for x = B.X0, B.X1 - 1, STEP do
		local h, tag, water = FrontMap.Sample(x, z)
		row[#row + 1] = ("%.1f:%s:%s"):format(h, tag:sub(1, 2), water and ("%.1f"):format(water) or "")
	end
	print(table.concat(row, " "))
end
print("END")
for index, s in L.Sectors do
	print(("SECTOR %d %s %.0f %.0f %.0f %.0f %.0f %.0f %.0f %.0f"):format(index, s.Type, s.Center.X, s.Center.Z, s.Crest.X, s.Crest.Z, s.Dugouts.Union.X, s.Dugouts.Union.Z, s.Dugouts.Pact.X, s.Dugouts.Pact.Z))
	for _, p in s.Pads do
		print(("PAD %.0f %.0f %.0f %s"):format(p.X, p.Z, p.R, p.Kit))
	end
end
for _, s in L.Scatter do
	print(("PROP %s %.0f %.0f"):format(s.Kind, s.X, s.Z))
end
for f, b in L.Bases do
	print(("BASE %s %.0f %.0f"):format(f, b.X, b.Z))
end
