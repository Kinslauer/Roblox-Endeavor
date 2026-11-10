# Real-server start check for the Front (like startcheck.py for Endeavor): runs war/server/Main.server.lua's
# startup as a task, then builds one stasis-tank cell, its barracks and a simulation city with no player in
# them (Intro.Probe), so property errors in those builders show up too.
# Usage: python3 tools/realserver/frontcheck.py > /tmp/front.lua
#        python3 tools/realserver/run_luau.py 81481823786216 /tmp/front.lua
import os
root = os.path.join(os.path.dirname(__file__), "..", "..")
src = open(os.path.join(root, "src/war/server/Main.server.lua")).read()
src = src.replace("local Server = script.Parent", 'local Server = game:GetService("ServerScriptService").Server\nlocal t0 = os.clock()')
src += '''
print("startup ok", ok, err, ("%.1fs"):format(os.clock() - t0), "workspace children", #workspace:GetChildren())
local okProbe, summary = pcall(function()
	return require(Server.Intro).Probe(Vector3.new(0, 1500, 0))
end)
print("intro probe", okProbe, summary)
local n = 0
for _, e in ipairs(game:GetService("LogService"):GetLogHistory()) do
	if e.messageType == Enum.MessageType.MessageWarning or e.messageType == Enum.MessageType.MessageError then
		n += 1
		if n <= 25 then print("W:", e.message:sub(1, 300)) end
	end
end
print("warnings", n, "PlaceVersion", game.PlaceVersion)
return ok and okProbe
'''
print(src)
