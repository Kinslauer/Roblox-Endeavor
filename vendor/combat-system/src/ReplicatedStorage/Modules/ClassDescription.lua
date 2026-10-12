local module = {}

module[1] = require(script.Bruiser)

--module[2] = require(script.Ranger)
--module[2].Name = "Ranger"

module[2] = require(script.Blasters)

module[3] = require(script.Pirate)

--module[4] = require(script.Assassin)
--module[4].Name = "Assassin"

--module[5] = require(script.Tank)
--module[5].Name = "Tank"

module[4] = require(script.Hammer)

--module[7] = require(script.Special)
--module[7].Name = "Special"

module[#script:GetChildren()] = require(script.Special)

return module
