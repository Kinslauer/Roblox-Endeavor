-- Runs the Endeavor client script against the mock with a fake LocalPlayer. Catches any error
-- in the client's top-level setup (which would otherwise kill input handling silently).
CLIENT_MODE = true
local game_, workspace_ = M.game, M.workspace
local RS = game_:GetService("ReplicatedStorage")
local Players = game_:GetService("Players")
M.mkTree({ Shared = { class = "Folder", children = TREE_SHARED } }, RS)
-- the server normally creates the remotes; build them here
local remotesFolder = M.newInstance("Folder"); remotesFolder.Name = "Remotes"; remotesFolder.Parent = RS
local src = TREE_SHARED.Remotes.source
for name in src:gmatch('"(%a+)"') do if name ~= "Remotes" and name ~= "Folder" and name ~= "RemoteEvent" then local r = M.newInstance("RemoteEvent"); r.Name = name; r.Parent = remotesFolder end end
local player = M.newInstance("Player"); player.Name, player.DisplayName, player.UserId = "Tester", "Tester", 1
local pg = M.newInstance("PlayerGui"); pg.Name = "PlayerGui"; pg.Parent = player
player.Parent = Players; Players.LocalPlayer = player
local cam = M.newInstance("Camera"); cam.Name = "CurrentCamera"; cam.CFrame = M.CF.new(0, 5, 0); cam.Parent = workspace_
local client = M.newInstance("LocalScript"); client.Name = "Client"; client._source = TREE_CLIENT.Main.source
client.Parent = game_:GetService("StarterPlayer")
local ok, err = pcall(function() M.loadSource(client)() end)
print("client ran:", ok, err or "")
for _ = 1, 30 do M.step(1/30) end
print("errors:", #M.errors)
for _, e in M.errors do print(e) end
