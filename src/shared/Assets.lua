-- Asset registry: Roblox asset IDs for models built in Blender (tools/models) and uploaded
-- through Open Cloud. 0 means "not uploaded yet": the game falls back to generated geometry.
-- Props: the intact model. Chunks: what the prop breaks into (see shared/Props.lua Chunks order).
local Assets = {}

Assets.Props = {
	Streetlight = 0,
}

Assets.Chunks = {
	PipeLong = 0,
	PipeShort = 0,
	LampHead = 0,
}

return Assets
