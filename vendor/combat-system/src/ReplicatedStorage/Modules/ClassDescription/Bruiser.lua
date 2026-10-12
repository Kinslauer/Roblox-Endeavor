--knight
--rocket boots
local module = {["Name"] = script.Name,}

module[1] = require(script.Brawler)
module[2] = require(script.Sword)
module[3] = require(script.Spear)

module[4] = {
	["Name"] = "Knight",
	["Power"] = 3,
	["Range"] = 3,
	["Speed"] = 3,
	["Difficulty"] = 2,
	["Skills"] = {
		"Shield Strike"
	}
}

return module
