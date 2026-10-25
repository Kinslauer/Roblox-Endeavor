-- Character look: every player is the same standardized R15 body, varied only by the fixed
-- choices below. The profile stores *indices into these lists* (never raw ids or colors), so
-- the client can only ever pick something we offer. Server: Rig.Build applies it.
--
-- Face ids are Roblox decal asset ids; 0 keeps the rig's built-in face. Add your own below.
-- Hair is procedural (Rig builds it from blocks), so it needs no asset ids.
local Appearance = {}

-- Body scales are applied through HumanoidDescription. Kept in a narrow band so hitboxes,
-- reach and animations stay consistent between players.
Appearance.BodyTypes = {
	{ Name = "Lean", Height = 1.00, Width = 0.90, BodyType = 0.0, Proportion = 0.0 },
	{ Name = "Average", Height = 1.00, Width = 1.00, BodyType = 0.3, Proportion = 0.0 },
	{ Name = "Broad", Height = 1.00, Width = 1.10, BodyType = 0.6, Proportion = 0.0 },
}

Appearance.SkinTones = {
	{ Name = "Porcelain", Color = Color3.fromRGB(245, 222, 205) },
	{ Name = "Sand", Color = Color3.fromRGB(226, 187, 150) },
	{ Name = "Tan", Color = Color3.fromRGB(192, 140, 100) },
	{ Name = "Bronze", Color = Color3.fromRGB(150, 100, 70) },
	{ Name = "Umber", Color = Color3.fromRGB(105, 70, 50) },
	{ Name = "Ebony", Color = Color3.fromRGB(62, 42, 34) },
}

Appearance.Faces = {
	{ Name = "Default", Id = 0 },
	-- { Name = "Stoic", Id = 000000000 },
}

-- Style: how Rig builds it. "None" | "Buzz" | "Crop" | "Mohawk" | "Long"
Appearance.HairStyles = {
	{ Name = "Bald", Style = "None" },
	{ Name = "Buzz", Style = "Buzz" },
	{ Name = "Crop", Style = "Crop" },
	{ Name = "Mohawk", Style = "Mohawk" },
	{ Name = "Long", Style = "Long" },
}

Appearance.HairColors = {
	{ Name = "Black", Color = Color3.fromRGB(20, 20, 24) },
	{ Name = "Brown", Color = Color3.fromRGB(80, 52, 34) },
	{ Name = "Blonde", Color = Color3.fromRGB(205, 176, 108) },
	{ Name = "Ash", Color = Color3.fromRGB(150, 150, 155) },
	{ Name = "Crimson", Color = Color3.fromRGB(150, 28, 36) },
	{ Name = "Neon", Color = Color3.fromRGB(60, 220, 255) },
}

-- Field name -> catalog list. The profile table has exactly these keys, each an index.
Appearance.Fields = {
	BodyType = Appearance.BodyTypes,
	SkinTone = Appearance.SkinTones,
	Face = Appearance.Faces,
	Hair = Appearance.HairStyles,
	HairColor = Appearance.HairColors,
}
Appearance.FieldOrder = { "BodyType", "SkinTone", "Face", "Hair", "HairColor" }

function Appearance.Default()
	local out = {}
	for field in Appearance.Fields do
		out[field] = 1
	end
	return out
end

-- Accepts anything (it may come straight from a client remote); always returns a valid table.
function Appearance.Sanitize(input)
	local out = Appearance.Default()
	if type(input) ~= "table" then
		return out
	end
	for field, list in Appearance.Fields do
		local v = input[field]
		if type(v) == "number" and v == math.floor(v) and v >= 1 and v <= #list then
			out[field] = v
		end
	end
	return out
end

-- Resolves a sanitized table into the actual catalog entries.
function Appearance.Resolve(appearance)
	local a = Appearance.Sanitize(appearance)
	return {
		BodyType = Appearance.BodyTypes[a.BodyType],
		SkinTone = Appearance.SkinTones[a.SkinTone],
		Face = Appearance.Faces[a.Face],
		Hair = Appearance.HairStyles[a.Hair],
		HairColor = Appearance.HairColors[a.HairColor],
	}
end

return Appearance
