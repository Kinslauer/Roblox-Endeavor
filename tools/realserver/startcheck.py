# Real-server start check for Endeavor. Scripts do not run on their own in an Open Cloud Luau execution server,
# so this turns src/server/Main.server.lua into a task script that runs the same startup and then reports
# "startup ok", the time taken and every warning/error in the log.
# Usage: python3 tools/realserver/startcheck.py > /tmp/start.lua
#        python3 tools/realserver/run_luau.py 120490278050491 /tmp/start.lua
import os
root = os.path.join(os.path.dirname(__file__), "..", "..")
src = open(os.path.join(root, "src/server/Main.server.lua")).read()
src = src.replace("local Server = script.Parent", 'local Server = game:GetService("ServerScriptService").Server\nlocal t0 = os.clock()')
src += '''
print("startup ok", ok, err, ("%.1fs"):format(os.clock() - t0), "workspace children", #workspace:GetChildren())
local n = 0
for _, e in ipairs(game:GetService("LogService"):GetLogHistory()) do
	if e.messageType == Enum.MessageType.MessageWarning or e.messageType == Enum.MessageType.MessageError then
		n += 1
		if n <= 25 then print("W:", e.message:sub(1, 300)) end
	end
end
print("warnings", n, "PlaceVersion", game.PlaceVersion)
return ok
'''
print(src)
