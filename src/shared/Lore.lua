-- Lore beats (Phase-2 build-order 3, "Tutorial v2 lore"): one line each, shown as a quiet banner
-- (Announce kind "Lore") at the moments that shape the story. Text only - no systems. Rewrite
-- freely; keys are what the code references.
local Lore = {}

Lore.Lines = {
	Creator = "Another one wakes in the dark. Choose the face the city will forget.",
	WakeUp = "Concrete. Cold. One console still hums. Nothing else in here does.",
	FirstSwing = "The pipe knows the rhythm before you do. Listen for the beat under the swing.",
	Flicker = "There is a half-second where the world runs thin. Press into it and it answers.",
	Emergence = "The walls fall away. You were never alone.",
	FirstKill = "Something behind your eyes clicks into place. The Rift in the plaza will answer you now.",
	FirstRift = "The other world has never known anything but the war. The recruits know they are in hell. They have accepted it.",
	FirstDeath = "The city keeps what you carried. It does not keep you.",
	FirstExtract = "The train does not ask where you have been. This room is the only place that is yours.",
	EmptyDesk = "An empty desk, a dead socket. Whatever you learn out there dies with you until something here can hold it.",
	Upload = "The machine wakes and takes you in. Die now and you come back knowing what you knew.",
	FirstContact = "Nobody out here gives their name. They give you a line on your screen, and that is trust.",
	FirstRaid = "A contract is a story someone else started. You find out how it ends.",
	FullConversion = "The last of the flesh goes into the tray. You try to say so, and what comes out is not your voice anymore.",
}

Lore.Seconds = 7 -- how long a lore banner stays up
Lore.Color = Color3.fromRGB(200, 190, 255)

function Lore.Get(key)
	return Lore.Lines[key]
end

return Lore
