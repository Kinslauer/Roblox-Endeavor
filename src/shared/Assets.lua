-- Asset registry for models built in Blender (tools/models) and uploaded through Open Cloud.
-- Props come in conditions: A intact, B worn, C wrecked. A spawn (and every rematerialization)
-- picks one at random, so the city never comes back quite the same. 0 / missing = not uploaded:
-- the game falls back to generated geometry.
local Assets = {}

Assets.Props = {
	Barrel = { A = 138973181515358, B = 79636233128816, C = 125842135926276 },
	CarWreck = { A = 135300185326024, B = 124730379936688, C = 93646164483240 },
	Crate = { A = 109129830991009, B = 138128084039228, C = 134823881595914 },
	FencePanel = { A = 135294127218303, B = 137469842853638, C = 88889940788521 },
	Slab = { A = 93218341089544, B = 85304351471716, C = 74338036722155 },
	StreetSign = { A = 81980116475569, B = 133194607355983, C = 135676038796551 },
	Streetlight = { A = 113165102986052 },
	Terminal = { A = 94139217691513, B = 79807106490326, C = 132427649381419 },
	VendingMachine = { A = 138968722251708, B = 93355970908453, C = 132176714647904 },
	WindowPane = { A = 93084252250236, B = 86227491449117, C = 107425218490351 },
}

Assets.Chunks = {
	LampHead = 102315743005097,
	PipeLong = 97783263877959,
	PipeShort = 136810514088811,
}

-- Buildings per district style: [style] = { { Id, Height, Collapsed } ... }. City.tower picks one whose
-- height class fits the district and rolls Collapsed by the district's Collapse chance.
Assets.Buildings = {
	Transit = {
		{ Id = 127292690964822, Height = 16, Collapsed = false },
		{ Id = 123328971264435, Height = 28, Collapsed = false },
		{ Id = 126527051147462, Height = 40, Collapsed = false },
		{ Id = 140082823721054, Height = 16, Collapsed = true },
		{ Id = 80388090754028, Height = 28, Collapsed = true },
		{ Id = 124529424193237, Height = 40, Collapsed = true },
	},
	Corp = {
		{ Id = 100673641895848, Height = 44, Collapsed = false },
		{ Id = 102115072037501, Height = 76, Collapsed = false },
		{ Id = 131917010107929, Height = 108, Collapsed = false },
		{ Id = 83480503628071, Height = 44, Collapsed = true },
		{ Id = 136541096106617, Height = 76, Collapsed = true },
		{ Id = 109374262907940, Height = 108, Collapsed = true },
	},
	Sprawl = {
		{ Id = 105370784022791, Height = 9, Collapsed = false },
		{ Id = 106326847400008, Height = 15, Collapsed = false },
		{ Id = 104460521756486, Height = 22, Collapsed = false },
		{ Id = 109508146985957, Height = 9, Collapsed = true },
		{ Id = 107665691190154, Height = 15, Collapsed = true },
		{ Id = 122556073961573, Height = 22, Collapsed = true },
	},
	Blackout = {
		{ Id = 116818105369683, Height = 22, Collapsed = false },
		{ Id = 117319727727542, Height = 46, Collapsed = false },
		{ Id = 114976683337134, Height = 70, Collapsed = false },
		{ Id = 98793224659140, Height = 22, Collapsed = true },
		{ Id = 120670767685060, Height = 46, Collapsed = true },
		{ Id = 114306096688948, Height = 70, Collapsed = true },
	},
	Outskirts = {
		{ Id = 77282177830136, Height = 7, Collapsed = false },
		{ Id = 119170534861661, Height = 11, Collapsed = false },
		{ Id = 86369990451471, Height = 16, Collapsed = false },
		{ Id = 71479955444102, Height = 7, Collapsed = true },
		{ Id = 90300686818780, Height = 11, Collapsed = true },
		{ Id = 128795308345139, Height = 16, Collapsed = true },
	},
}

-- Animations (tools/anims/anims.py: keyframes written in code, uploaded as Animation assets): played by
-- shared/Anims. Swing_<shape> moves the body under the traced right arm; Hit_*, Stagger, Recoil, Block, Parry;
-- Idle/Walk/Run are the Conduit's everyday set (character/Animate).
Assets.Anims = {
	Swing_SlashR = 125453914534844,
	Swing_SlashL = 73868502712886,
	Swing_Overhead = 82447544544973,
	Swing_Diagonal = 99303551700047,
	Swing_Uppercut = 110688569815812,
	Swing_Thrust = 99804045337219,
	Swing_Jab = 107045455247167,
	Hit_Front = 122579126667254,
	Hit_Left = 118351776617847,
	Hit_Right = 103567354485994,
	Hit_High = 140492060345571,
	Stagger = 140483288537415,
	Recoil = 120336715080347,
	Block = 105542552524914,
	Parry = 108022873654671,
	Idle = 95711191696003,
	Walk = 88349487105275,
	Run = 71610497642397,
	Hit_Heavy = 84055358382990,
	Block_Hit = 120346734727672,
	Step_Left = 135515038003880,
	Step_Right = 116259253404942,
	Step_Back = 105953688996479,
	-- stealth and the train (2026-11-10)
	Crouch_Idle = 112950960956405,
	Crouch_Walk = 91586344441197,
	Downed = 111743961368604,
	Takedown_Rear = 100208122176591,
	Takedown_RearVictim = 90119187057374,
	Takedown_Drop = 101715306821033,
	Takedown_DropVictim = 106251039326651,
	Takedown_Slam = 82457300416009,
	Takedown_SlamVictim = 102440986971544,
	Intro_Seated = 117858725061961,
	Intro_Stand = 106629137625017,
	Intro_CloakToss = 130150410671633,
	Intro_Draw = 128112239674852,
	Intro_Rack = 104303564446122,
	-- Metal Gear handling (2026-11-11): prone, the pistol, hands up, CQC, the wall
	Prone_Idle = 99254683617405,
	Prone_Crawl = 93255193883909,
	Prone_RollL = 126125091482574,
	Prone_RollR = 104668146435989,
	Rifle_Ready = 73218657444853,
	Aim_Rifle = 123778705669365,
	Reload_Rifle = 124676858383066,
	Pistol_Ready = 86762919139050,
	Aim_Pistol = 89194078829770,
	Reload_Pistol = 140353059622291,
	HandsUp = 107954558883133,
	Takedown_Throw = 137070777628766,
	Takedown_ThrowVictim = 113920668067731,
	Takedown_Shove = 127654576653763,
	Takedown_ShoveVictim = 76277529951374,
	Hold = 96501380522226,
	Held = 112742222259734,
	Carry = 75410357814439,
	Cover_Idle = 91326331770227,
}

-- Character rigs (see server/Rigs.lua): [npcType] = assetId. Since 2026-11-12 these are the plain, invisible limbs
-- made by tools/models/figure.py (joints, hitboxes, what a violent death scatters); the body people see is the skin
-- below. The old blocky bodies (conduit.py, raider.py, enemies.py, station.py) were 128592453586650 (Conduit),
-- 106712459976546 (Raider), 89905917757019 (Brute), 117184966040084 (Shocker), 80181254073544 (Warden),
-- 96318406423907 (Sentry).
Assets.Rigs = {
	Soldier = 136167091483135, -- the Front's recruits, both sides (war/server/Bodies.lua makes it the StarterCharacter)
	Rival = 78681752690687, -- the raider in other colours (NPCs.Types.Rival)
	Conduit = 115965815211389, -- the player's body (server/Body.lua makes it the StarterCharacter)
	Raider = 78681752690687,
	Brute = 135898125228151,
	Shocker = 74684713775243,
	Warden = 70570830309045,
	Sentry = 70378884781864, -- transit security in the arrival station
}

-- One-piece skinned bodies (tools/models/figure.py + figures.py): [rig kind] = { Id, Tints, Mats }. Tints = the
-- colour each piece should be (Assets.Tint works out the multiplier for the neutral textures); the lists are printed
-- by figure.py ("LUA <Name> Tints = ..."). Mats renames a piece's material for code that recolours by it
-- (server/Body.lua paints ConduitJacket per life).
Assets.Skins = {
	Conduit = { Id = 107250598898245, Mats = { Coat_Techcloth = "ConduitJacket" }, Tints = { Trousers_Twill = Color3.fromRGB(33, 33, 37), Boots_HideLeather = Color3.fromRGB(158, 148, 140), Coat_Techcloth = Color3.fromRGB(43, 46, 54), LowerArms_Twill = Color3.fromRGB(26, 26, 29), Hands_HideLeather = Color3.fromRGB(158, 148, 140), Head_Twill = Color3.fromRGB(33, 33, 36), Hood_Techcloth = Color3.fromRGB(26, 26, 29), Plates_PlateSteel = Color3.fromRGB(76, 79, 87), Straps_HideLeather = Color3.fromRGB(158, 148, 140), LowerArmPlates_PlateSteel = Color3.fromRGB(76, 79, 87), Pouches_HideLeather = Color3.fromRGB(158, 148, 140) } },
	Raider = { Id = 127425818791062, Tints = { Trousers_Twill = Color3.fromRGB(51, 48, 46), Boots_HideLeather = Color3.fromRGB(158, 148, 140), Coat_Techcloth = Color3.fromRGB(64, 51, 41), Head_Twill = Color3.fromRGB(33, 33, 36), Hood_Techcloth = Color3.fromRGB(41, 38, 43), Wrap_Gauze = Color3.fromRGB(128, 117, 97), Scrap_PlateSteel = Color3.fromRGB(107, 61, 38), Straps_HideLeather = Color3.fromRGB(153, 140, 128), Pouches_HideLeather = Color3.fromRGB(153, 140, 128) } },
	Rival = { Id = 127425818791062, Tints = { Trousers_Twill = Color3.fromRGB(51, 48, 46), Boots_HideLeather = Color3.fromRGB(158, 148, 140), Coat_Techcloth = Color3.fromRGB(34, 40, 62), Head_Twill = Color3.fromRGB(33, 33, 36), Hood_Techcloth = Color3.fromRGB(41, 38, 43), Wrap_Gauze = Color3.fromRGB(128, 117, 97), Scrap_PlateSteel = Color3.fromRGB(107, 61, 38), Straps_HideLeather = Color3.fromRGB(153, 140, 128), Pouches_HideLeather = Color3.fromRGB(153, 140, 128) } },
	Brute = { Id = 80409033921236, Tints = { Trousers_Twill = Color3.fromRGB(51, 48, 46), Boots_HideLeather = Color3.fromRGB(158, 148, 140), Coat_Techcloth = Color3.fromRGB(61, 51, 43), Head_Twill = Color3.fromRGB(33, 33, 36), Helmet_PlateSteel = Color3.fromRGB(76, 79, 84), Collar_PlateSteel = Color3.fromRGB(102, 59, 36), Plates_PlateSteel = Color3.fromRGB(76, 79, 84), Scrap_PlateSteel = Color3.fromRGB(102, 59, 36), Straps_HideLeather = Color3.fromRGB(140, 128, 117), Pipes_PlateSteel = Color3.fromRGB(102, 59, 36) } },
	Shocker = { Id = 104823811581787, Tints = { Trousers_Twill = Color3.fromRGB(26, 26, 28), Boots_HideLeather = Color3.fromRGB(158, 148, 140), Coat_Techcloth = Color3.fromRGB(33, 31, 41), Head_Twill = Color3.fromRGB(33, 33, 36), Hood_Techcloth = Color3.fromRGB(20, 20, 26), Straps_HideLeather = Color3.fromRGB(128, 128, 128), Pack_PlateSteel = Color3.fromRGB(66, 69, 76) } },
	Warden = { Id = 89938150254967, Tints = { Trousers_Twill = Color3.fromRGB(128, 18, 31), Boots_PlateSteel = Color3.fromRGB(128, 133, 143), Coat_Techcloth = Color3.fromRGB(128, 18, 31), LowerArms_Twill = Color3.fromRGB(51, 51, 56), Hands_PlateSteel = Color3.fromRGB(51, 51, 56), Head_Twill = Color3.fromRGB(33, 33, 36), Helmet_PlateSteel = Color3.fromRGB(128, 133, 143), Plates_PlateSteel = Color3.fromRGB(128, 133, 143), Tasset_PlateSteel = Color3.fromRGB(51, 51, 56), LowerArmPlates_PlateSteel = Color3.fromRGB(128, 133, 143), Straps_HideLeather = Color3.fromRGB(51, 51, 56), Cape_Techcloth = Color3.fromRGB(128, 18, 31) } },
	-- the Front's recruits, in layers (figures.py; server/Bodies.lua; Rigs.Dress):
	--   Groups = pieces that show only while their group is on; Covers = what a showing piece hides in any layer;
	--   Factions = the cloth tints of each side on the shared body.
	Recruit = { Id = 134582974124443, Tints = { Head_Flesh = Color3.fromRGB(168, 153, 145), Torso_Flesh = Color3.fromRGB(168, 153, 145), ArmL_Flesh = Color3.fromRGB(168, 153, 145), ArmR_Flesh = Color3.fromRGB(168, 153, 145), HandL_Flesh = Color3.fromRGB(168, 153, 145), HandR_Flesh = Color3.fromRGB(168, 153, 145), LegL_Flesh = Color3.fromRGB(168, 153, 145), LegR_Flesh = Color3.fromRGB(168, 153, 145), FootL_Flesh = Color3.fromRGB(168, 153, 145), FootR_Flesh = Color3.fromRGB(168, 153, 145), Under_Gauze = Color3.fromRGB(133, 128, 112), Singlet_Twill = Color3.fromRGB(51, 57, 37), TrouserL_Twill = Color3.fromRGB(64, 71, 46), TrouserR_Twill = Color3.fromRGB(64, 71, 46), Trousers_Twill = Color3.fromRGB(64, 71, 46), BootR_HideLeather = Color3.fromRGB(51, 48, 46), BootL_HideLeather = Color3.fromRGB(51, 48, 46), Armband_Twill = Color3.fromRGB(51, 92, 184) },
		Factions = {
			Union = { Singlet_Twill = Color3.fromRGB(51, 57, 37), Trousers_Twill = Color3.fromRGB(64, 71, 46), TrouserL_Twill = Color3.fromRGB(64, 71, 46), TrouserR_Twill = Color3.fromRGB(64, 71, 46),
				BootL_HideLeather = Color3.fromRGB(51, 48, 46), BootR_HideLeather = Color3.fromRGB(51, 48, 46), Armband_Twill = Color3.fromRGB(51, 92, 184) },
			Pact = { Singlet_Twill = Color3.fromRGB(61, 55, 45), Trousers_Twill = Color3.fromRGB(76, 69, 56), TrouserL_Twill = Color3.fromRGB(76, 69, 56), TrouserR_Twill = Color3.fromRGB(76, 69, 56),
				BootL_HideLeather = Color3.fromRGB(38, 36, 36), BootR_HideLeather = Color3.fromRGB(38, 36, 36), Armband_Twill = Color3.fromRGB(178, 41, 36) },
		},
		Groups = { Under = { "Under" }, Attire = { "Singlet", "Trousers", "TrouserL", "TrouserR", "BootL", "BootR", "SoleL", "SoleR", "Armband" } },
		Covers = { Singlet = { "Torso" }, Trousers = { "Under" }, TrouserL = { "LegL" }, TrouserR = { "LegR" }, BootL = { "FootL" }, BootR = { "FootR" } } },
	UnionKit = { Id = 102725707924128, Tints = { Coat_Twill = Color3.fromRGB(64, 71, 46), LowerArmL_Twill = Color3.fromRGB(64, 71, 46), LowerArmR_Twill = Color3.fromRGB(64, 71, 46), GloveL_HideLeather = Color3.fromRGB(51, 48, 46), GloveR_HideLeather = Color3.fromRGB(51, 48, 46), Wrap_Gauze = Color3.fromRGB(117, 112, 87), Webbing_Twill = Color3.fromRGB(128, 117, 84), Canteen_Twill = Color3.fromRGB(41, 46, 33), Helmet_PlateSteel = Color3.fromRGB(59, 66, 43), Vest_Twill = Color3.fromRGB(41, 46, 33), Plates_PlateSteel = Color3.fromRGB(76, 79, 76) },
		Groups = { Kit = { "Coat", "LowerArmL", "LowerArmR", "GloveL", "GloveR", "Wrap", "GoggleRims", "Goggles", "GoggleStrap", "Webbing", "Fittings", "Canteen" },
			Helmet = { "Helmet" }, Vest = { "Vest" }, Plates = { "Plates" } },
		Covers = { Coat = { "Torso", "Singlet", "ArmL", "ArmR" }, GloveL = { "HandL" }, GloveR = { "HandR" } } },
	PactKit = { Id = 110965730805821, Tints = { Coat_Twill = Color3.fromRGB(112, 97, 71), LowerArmL_Twill = Color3.fromRGB(112, 97, 71), LowerArmR_Twill = Color3.fromRGB(112, 97, 71), GloveL_HideLeather = Color3.fromRGB(87, 61, 43), GloveR_HideLeather = Color3.fromRGB(87, 61, 43), Straps_HideLeather = Color3.fromRGB(87, 61, 43), Pouches_HideLeather = Color3.fromRGB(87, 61, 43), Bedroll_Twill = Color3.fromRGB(76, 79, 66), Helmet_PlateSteel = Color3.fromRGB(66, 64, 56), Vest_Twill = Color3.fromRGB(61, 56, 48), Plates_PlateSteel = Color3.fromRGB(69, 69, 71) },
		Groups = { Kit = { "Coat", "LowerArmL", "LowerArmR", "GloveL", "GloveR", "Mask", "MaskFittings", "Visor", "Straps", "Pouches", "Fittings", "Bedroll" },
			Helmet = { "Helmet" }, Vest = { "Vest" }, Plates = { "Plates" } },
		Covers = { Coat = { "Torso", "Singlet", "ArmL", "ArmR" }, GloveL = { "HandL" }, GloveR = { "HandR" } } },
	-- limbs that take the place of the flesh ones (one group a limb), and a large armour set over the whole body
	CyberLimbs = { Id = 117173596961679, Tints = { CyArmL_PlateSteel = Color3.fromRGB(56, 59, 64), CyArmLHand_PlateSteel = Color3.fromRGB(56, 59, 64), CyLegL_PlateSteel = Color3.fromRGB(56, 59, 64), CyLegLFoot_PlateSteel = Color3.fromRGB(56, 59, 64), CyArmR_PlateSteel = Color3.fromRGB(56, 59, 64), CyArmRHand_PlateSteel = Color3.fromRGB(56, 59, 64), CyLegR_PlateSteel = Color3.fromRGB(56, 59, 64), CyLegRFoot_PlateSteel = Color3.fromRGB(56, 59, 64) },
		Groups = { CyArmL = { "CyArmL", "CyArmJointsL", "CyArmLHand" }, CyArmR = { "CyArmR", "CyArmJointsR", "CyArmRHand" },
			CyLegL = { "CyLegL", "CyLegJointsL", "CyLegLFoot" }, CyLegR = { "CyLegR", "CyLegJointsR", "CyLegRFoot" } },
		Covers = { CyArmL = { "ArmL", "HandL", "GloveL", "LowerArmL" }, CyArmR = { "ArmR", "HandR", "GloveR", "LowerArmR" },
			CyLegL = { "LegL", "FootL", "TrouserL", "BootL", "SoleL" }, CyLegR = { "LegR", "FootR", "TrouserR", "BootR", "SoleR" } } },
	HeavyArmor = { Id = 117965408196673, Tints = { Heavy_PlateSteel = Color3.fromRGB(61, 66, 56), HeavySkirt_PlateSteel = Color3.fromRGB(33, 36, 33), HeavyHelm_PlateSteel = Color3.fromRGB(61, 66, 56) },
		Groups = { Heavy = { "Heavy", "HeavySkirt", "HeavyHelm", "HeavyVisor" } },
		Covers = { Heavy = { "Vest", "Plates" }, HeavyHelm = { "Helmet" } } },
	Sentry = { Id = 115292944079963, Tints = { Trousers_Twill = Color3.fromRGB(51, 48, 46), Boots_HideLeather = Color3.fromRGB(76, 76, 76), Coat_Techcloth = Color3.fromRGB(33, 31, 38), LowerArms_Twill = Color3.fromRGB(33, 31, 38), Hands_HideLeather = Color3.fromRGB(76, 76, 76), Head_Twill = Color3.fromRGB(33, 33, 36), Helmet_PlateSteel = Color3.fromRGB(36, 36, 41), Plates_PlateSteel = Color3.fromRGB(71, 76, 84), Straps_HideLeather = Color3.fromRGB(76, 76, 76), Pouches_HideLeather = Color3.fromRGB(76, 76, 76), LowerArmPlates_PlateSteel = Color3.fromRGB(71, 76, 84) } },
}

-- The arrival (tools/models/station.py): the rider's cloak (origin = UpperTorso centre) and the train car shell.
-- the poncho as one skinned mesh with a grid of bones that client/Cloth.lua simulates (tools/models/train.py build_cloak)
Assets.Intro = { Cloak = 131482831788974 }
-- The gun parts library (tools/models/gunparts.py + gun_<platform>.py): every part of a hammer-fired pistol, a
-- striker-fired pistol, a revolver and an AR-pattern rifle, combined into these guns. Each model is one MeshPart per
-- moving group and material: Slide/Barrel/Frame/Hammer/Trigger/Grips/Magazine (+ Suppressor, Light, LightLens) for
-- handguns (Pistol grip), Upper/Lower/Barrel/Charging/Carrier/Stock/Magazine/Muzzle for rifles (Rifle grip).
Assets.GunKit = {
	Hammer1911 = 134129735068524, -- hammer-fired, 5 in barrel, spur hammer
	HammerCommander = 103160933605924, -- hammer-fired, 4.25 in, ring hammer
	Whisper = 113109859891091, -- hammer-fired, railed frame, threaded barrel, suppressor, light (the arrival's pistol)
	HammerRail = 115146323108250, -- hammer-fired, railed frame, light
	Striker19 = 102992385285716, -- striker-fired, compact
	Striker17 = 72220435844363, -- striker-fired, full size
	StrikerWhisper = 135877201521289, -- striker-fired, threaded, suppressor, light
	Revolver4 = 120759454158266, -- double-action six-shot, 4 in barrel, half lug
	Revolver2 = 129931511458686, -- 2 in snub
	Revolver6 = 129254275557472, -- 6 in, full lug
	Rifle16 = 126895041429166, -- AR-pattern carbine, 16 in barrel
	Rifle10 = 114913695609617, -- AR-pattern, 10.5 in barrel, suppressor, light
	Rifle20 = 106608856147388, -- AR-pattern, 20 in barrel
}
Assets.Subway = { Car = 111234592172091, Door = 71136245040287 } -- tools/models/train.py (2026-11-11, the realistic pass)

-- Weapons held in the right hand (see server/HeldWeapons.lua): [weaponId] = { Id, Grip }
-- Grip "Melee" (default): business end along Roblox +Z from the grip; "Pistol": grip along -Z, barrel along +Y.
Assets.Weapons = {
	PipeClub = { Id = 98352702068074 },
	RebarBlade = { Id = 109978068606651 },
	ShockBaton = { Id = 90209087116064 },
	ScrapSpear = { Id = 103214457247078 },
	Sledge = { Id = 140412858794705 },
	ArcPistol = { Id = 137041276570028, Grip = "Pistol" },
	DutyPistol = { Id = 72220435844363, Grip = "Pistol" }, -- Assets.GunKit.Striker17
	Whisper = { Id = 113109859891091, Grip = "Pistol" }, -- Assets.GunKit.Whisper; the part named Slide moves when it is racked
	-- the Front's firearms (tools/models/firearms.py): grip at the origin, barrel along Roblox +Z
	AKM = { Id = 92592283500275, Grip = "Rifle" },
	M16A1 = { Id = 75033829373197, Grip = "Rifle" },
	SKS = { Id = 113075471282186, Grip = "Rifle" },
	M14 = { Id = 95671280962993, Grip = "Rifle" },
	Mosin = { Id = 75786990315304, Grip = "Rifle" },
	Makarov = { Id = 132304088878022, Grip = "Rifle" },
	M1911 = { Id = 134129735068524, Grip = "Pistol" }, -- Assets.GunKit.Hammer1911 (2026-11-12: the Front's guns come from the parts library)
	Glock17 = { Id = 72220435844363, Grip = "Pistol" }, -- GunKit.Striker17
	Revolver = { Id = 120759454158266, Grip = "Pistol" }, -- GunKit.Revolver4
	-- AKM, AK47, M16A1, M14 and M1Garand are put together from components (shared/GunParts); the ids above them
	-- here are the old one-piece models, used only if a component fails to load
}

-- The Front's battlefield props (see war/server/Battlefield.lua and Soldiers.lua), tools/models/front.py.
-- Sandbags/Truck have condition variants A (fresh) / B (torn, gutted); the rest are single models.
Assets.Front = {
	Sandbags = { A = 95928144285816, B = 132747554423751 },
	LowSandbags = 98333994567972,
	Truck = { A = 100644987503518, B = 98573307241675 },
	Hedgehog = 102101837213656,
	AmmoCrate = 89789308888628,
}

-- The Front's open world (tools/models/front_world.py, war/server/Battlefield.lua): calcified clone bodies,
-- the barrows they fuse into, wire, a ruined chimney and an intact smokestack (skyline, scaled up), the
-- dugout entrances recruits deploy from, an abandoned field gun, blasted stumps and a broken pylon.
-- The Front's dead: a fallen recruit of each side, lying face down (figures.py statics; pieces named and tinted like the
-- living body, Assets.Skins[side].Tints).
Assets.FrontBodies = {
	Fallen = { Union = 111897218046292, Pact = 94176620670545 },
	-- the first-person hand in separate pieces (tools/models/hands.py; joints in shared/HandParts.lua)
	Hands = 116546820790887,
}

Assets.FrontWorld = {
	Calcified = { 83180720241659, 85986141286573 }, -- the soldier body, crawling and kneeling (figures.py statics)
	Barrow = { 138069370564335, 103130517740718 },
	Wire = 115088029929904,
	Chimney = 76062275408401,
	Smokestack = 137578586826447,
	Dugout = 108971902029950,
	FieldGun = 101275246250091,
	Stump = { 93753452796116, 139451660251442 },
	Pylon = 119120807532736,
}

-- The Front's staged buildings (tools/models/front_buildings.py): Stages[1..4] = intact, damaged,
-- ruined, rubble. Battlefield picks the kit nearest the footprint it wanted.
Assets.FrontBuildings = {
	Farmhouse = { Width = 18, Depth = 16, Height = 9, Stages = { 90952332269870, 106074559329466, 77239609557564, 116251743217738 } },
	Hall = { Width = 24, Depth = 20, Height = 12, Stages = { 72519396548568, 83800228553052, 94898623532790, 99432007888838 } },
}

-- Hideout modules (tools/models/hideout.py, server/Hideouts.lua): the mesh rides inside the module's
-- collider part, which turns invisible. Bench[tier] follows the hideout tier.
Assets.Hideout = {
	Bench = { 103394639391010, 139720531727657, 91895806024932 },
	Vault = 105765126742613,
	Bunks = 103383159042765,
	Generator = 117479185712477,
	Turret = 105708684013715,
	Forge = 133914256901308,
	Medbay = 104351297744980,
	Autonet = 88456848122761, -- the surgical table (tools/models/autonet.py)
}

-- Compound pieces (tools/models/compound.py): hideout wall panels tile along the generated wall parts,
-- a gate frame stands over the breach panel, and the raid arena's walls, pillars and gate get shells.
Assets.Compound = {
	WallPanel = 90340909566537, -- 10 wide, 9 tall
	GateFrame = 77590307627537,
	ArenaWall = 133068520008602, -- 22 wide, 28 tall
	ArenaPillar = 119840636382667,
	RaidGate = 113137125539955,
	PodWall = 80397059980222, -- 10 wide, 24 tall: the prologue room
}

-- The Front's faction bases (tools/models/base.py): bunker shell (hollow, door toward the grid), flagpole
-- (the Cloth_Flag part is recoloured per faction) and the locker terminal that opens the recruit app.
Assets.Base = {
	Bunker = 114043336589277,
	Flag = 72596583156716,
	Locker = 111491796184766,
}

-- Worn gear (tools/models/worn.py, common/WornGear.lua): armor and cybernetics welded onto limbs, keyed
-- by item id. Limb "UpperLeg" goes on both legs.
Assets.Worn = {
	ScavHelm = { Id = 91709410827611, Limb = "Head" },
	PlatedHelm = { Id = 92859674573572, Limb = "Head" },
	ArcHood = { Id = 94718008402702, Limb = "Head" },
	Helmet = { Id = 73112723341170, Limb = "Head" },
	ScrapVest = { Id = 77827178367213, Limb = "UpperTorso" },
	RiotPlate = { Id = 101619565204054, Limb = "UpperTorso" },
	ConduitHarness = { Id = 96609756104129, Limb = "UpperTorso" },
	FlakVest = { Id = 91405959496523, Limb = "UpperTorso" },
	SteelPlate = { Id = 88180546853294, Limb = "UpperTorso" },
	ScrapGreaves = { Id = 78063481367635, Limb = "UpperLeg" },
	ServoGreaves = { Id = 127667007495817, Limb = "UpperLeg" },
	PlatedGreaves = { Id = 114276638981555, Limb = "UpperLeg" },
	ReflexOptic = { Id = 131871131352328, Limb = "Head" },
	TargetingLens = { Id = 134076533137550, Limb = "Head" },
	ServoArm = { Id = 99881854714921, Limb = "LeftLowerArm" },
	ArcGauntlet = { Id = 110756870292079, Limb = "LeftLowerArm" },
	NeuralCore = { Id = 114038010201506, Limb = "UpperTorso" },
	OverclockCore = { Id = 128521678913563, Limb = "UpperTorso" },
}

-- Loot containers and the Neural Net terminal shell (tools/models/loot.py): meshes ride inside the lootable
-- part / terminal body, which turn invisible. Loot.Spawn picks by label unless opts.Mesh names one.
-- The frontier kit (tools/models/frontier.py -> server/Frontier.lua chunk builders). Scaled in place
-- with Model:ScaleTo; every one falls back to generated parts when it fails to load.
Assets.Frontier = {
	Pines = { 92768258437635, 120932030100957 },
	Broad = { 100146944193691, 86344580066937 },
	Dead = 132455478470140,
	Rocks = { 136961458265470, 140181270253858, 126475140264638 },
	Tent = 115392531991737,
	Dome = 125608573514511,
	Tower = 86663060548171,
}

-- The megacity's industrial kit (tools/models/industry.py; server/Megacity.lua scales each to its size and
-- falls back to parts): reference sizes stack 120 tall, tank r 12, cooling tower 100, pylon 60, furnace 70,
-- junk pile 50 across, giant tree ~80.
Assets.Industry = {
	Smokestack = 73312579286374,
	Tank = 91873180896771,
	CoolingTower = 118993071636663,
	Pylon = 111982823458563,
	BlastFurnace = 124966171523141,
	JunkPile = 111373200463571,
	GiantTree = 70596173999727,
}

Assets.Loot = {
	CrateA = 135218922360091, -- supply / cache crate
	CrateB = 116144381772246, -- vault cache, glowing lock
	Stash = 74319019375137, -- remains, spoils, salvage
	Terminal = 83359264941281,
}

-- Inventory icons (tools/models/icons.py) for items without a world mesh; weapons and worn gear use their
-- own models. Assets.IconFor(itemId) picks the right one. The server clones them into ReplicatedStorage.Icons.
Assets.Icons = {
	ArcCell = 120885267934580,
	Battery = 115726961795602,
	BreachingCharge = 78652282720972,
	Cloth = 71682467205868,
	FramePack = 72903198857313,
	Glass = 88875630377470,
	Medkit = 130060699441477,
	Pipe = 116871910672691,
	PipeGrenade = 78385289938011,
	Powder = 114655843816962,
	Ration = 95737291663305,
	Rucksack = 131663879854883,
	Satchel = 133696132290653,
	Scrap = 94763134290357,
	SheetMetal = 136803820316386,
	SignPlating = 89360434017768,
	Wire = 125102654490358,
}
-- Endeavor's long guns are built from components in the hand; in the pack they show a whole model
Assets.Icons.Carbine = Assets.GunKit.Rifle16
Assets.Icons.AK47 = Assets.Weapons.AKM.Id
Assets.Icons.M1Garand = Assets.Weapons.M14.Id

function Assets.IconFor(itemId)
	if Assets.Icons[itemId] then
		return Assets.Icons[itemId]
	end
	if Assets.Weapons[itemId] then
		return Assets.Weapons[itemId].Id
	end
	if Assets.Worn[itemId] then
		return Assets.Worn[itemId].Id
	end
	return nil
end

-- Roblox drops Blender material colours on import, so every part is named "<Part>_<Material>"
-- and the material is applied from this table when the model is loaded.
Assets.Materials = {
	Steel = { Color = Color3.fromRGB(80, 82, 88), Material = Enum.Material.Metal },
	DarkMetal = { Color = Color3.fromRGB(42, 42, 46), Material = Enum.Material.Metal },
	Rust = { Color = Color3.fromRGB(96, 54, 32), Material = Enum.Material.CorrodedMetal },
	Housing = { Color = Color3.fromRGB(46, 46, 50), Material = Enum.Material.Metal },
	Lens = { Color = Color3.fromRGB(255, 220, 140), Material = Enum.Material.Neon, Light = Color3.fromRGB(255, 220, 150) },
	Wood = { Color = Color3.fromRGB(110, 78, 44), Material = Enum.Material.WoodPlanks },
	OldWood = { Color = Color3.fromRGB(78, 62, 42), Material = Enum.Material.WoodPlanks },
	Paint = { Color = Color3.fromRGB(140, 42, 36), Material = Enum.Material.Metal },
	SignGreen = { Color = Color3.fromRGB(26, 108, 56), Material = Enum.Material.Metal },
	SignWhite = { Color = Color3.fromRGB(218, 218, 205), Material = Enum.Material.SmoothPlastic },
	Glass = { Color = Color3.fromRGB(120, 170, 205), Material = Enum.Material.Glass, Transparency = 0.45 },
	Neon = { Color = Color3.fromRGB(0, 200, 245), Material = Enum.Material.Neon, Light = Color3.fromRGB(0, 200, 255) },
	NeonPink = { Color = Color3.fromRGB(245, 50, 155), Material = Enum.Material.Neon, Light = Color3.fromRGB(255, 60, 160) },
	Concrete = { Color = Color3.fromRGB(102, 102, 108), Material = Enum.Material.Concrete },
	Tyre = { Color = Color3.fromRGB(22, 22, 22), Material = Enum.Material.Rubber },
	Chainlink = { Color = Color3.fromRGB(102, 108, 115), Material = Enum.Material.DiamondPlate, Transparency = 0.35 },
	Burnt = { Color = Color3.fromRGB(32, 26, 24), Material = Enum.Material.Slate },
	Screen = { Color = Color3.fromRGB(14, 80, 115), Material = Enum.Material.Neon, Light = Color3.fromRGB(30, 150, 230) },
	-- characters
	Hood = { Color = Color3.fromRGB(41, 38, 43), Material = Enum.Material.Fabric },
	Jacket = { Color = Color3.fromRGB(61, 51, 43), Material = Enum.Material.Fabric },
	Cloth = { Color = Color3.fromRGB(51, 48, 46), Material = Enum.Material.Fabric },
	Grip = { Color = Color3.fromRGB(32, 30, 28), Material = Enum.Material.Rubber },
	Bandage = { Color = Color3.fromRGB(168, 153, 128), Material = Enum.Material.Fabric },
	Skin = { Color = Color3.fromRGB(158, 122, 97), Material = Enum.Material.SmoothPlastic },
	Boot = { Color = Color3.fromRGB(26, 23, 23), Material = Enum.Material.Leather },
	Goggle = { Color = Color3.fromRGB(255, 115, 38), Material = Enum.Material.Neon, Light = Color3.fromRGB(255, 120, 40) },
	Strap = { Color = Color3.fromRGB(31, 28, 26), Material = Enum.Material.Leather },
	Plate = { Color = Color3.fromRGB(71, 76, 84), Material = Enum.Material.DiamondPlate },
	ArcCoil = { Color = Color3.fromRGB(25, 204, 255), Material = Enum.Material.Neon, Light = Color3.fromRGB(40, 200, 255) },
	Chrome = { Color = Color3.fromRGB(140, 145, 158), Material = Enum.Material.Metal },
	WardenRed = { Color = Color3.fromRGB(140, 20, 36), Material = Enum.Material.Fabric },
	Visor = { Color = Color3.fromRGB(255, 25, 25), Material = Enum.Material.Neon, Light = Color3.fromRGB(255, 40, 40) },
	Coat = { Color = Color3.fromRGB(33, 31, 38), Material = Enum.Material.Fabric },
	Sandbag = { Color = Color3.fromRGB(150, 132, 92), Material = Enum.Material.Fabric },
	-- the frontier kit
	Bark = { Color = Color3.fromRGB(78, 56, 38), Material = Enum.Material.Wood },
	DeadBark = { Color = Color3.fromRGB(70, 62, 56), Material = Enum.Material.Wood },
	Needle = { Color = Color3.fromRGB(42, 88, 46), Material = Enum.Material.Grass },
	Leaf = { Color = Color3.fromRGB(72, 124, 56), Material = Enum.Material.Grass },
	LeafDark = { Color = Color3.fromRGB(46, 92, 66), Material = Enum.Material.Grass },
	Stone = { Color = Color3.fromRGB(102, 100, 104), Material = Enum.Material.Slate },
	StoneDark = { Color = Color3.fromRGB(70, 68, 76), Material = Enum.Material.Slate },
	Canvas = { Color = Color3.fromRGB(92, 96, 76), Material = Enum.Material.Fabric },
	Frame = { Color = Color3.fromRGB(218, 212, 198), Material = Enum.Material.Metal },
	DomeGlass = { Color = Color3.fromRGB(180, 230, 220), Material = Enum.Material.Glass, Transparency = 0.5 },
	SolarGlass = { Color = Color3.fromRGB(26, 46, 90), Material = Enum.Material.Glass },
	SandbagDark = { Color = Color3.fromRGB(112, 96, 62), Material = Enum.Material.Fabric },
	Char = { Color = Color3.fromRGB(28, 26, 25), Material = Enum.Material.CorrodedMetal },
	Olive = { Color = Color3.fromRGB(70, 78, 46), Material = Enum.Material.Metal },
	Rubber = { Color = Color3.fromRGB(23, 23, 26), Material = Enum.Material.Rubber },
	-- the industrial kit (NoCollide: lattices, canopies and roots never become a solid hull)
	TankPaint = { Color = Color3.fromRGB(158, 153, 140), Material = Enum.Material.CorrodedMetal },
	Cooling = { Color = Color3.fromRGB(150, 146, 138), Material = Enum.Material.Concrete },
	Lattice = { Color = Color3.fromRGB(86, 88, 96), Material = Enum.Material.Metal, NoCollide = true },
	Insulator = { Color = Color3.fromRGB(128, 76, 52), Material = Enum.Material.Glass, NoCollide = true },
	Canopy = { Color = Color3.fromRGB(66, 128, 56), Material = Enum.Material.Grass, NoCollide = true },
	RootBark = { Color = Color3.fromRGB(70, 52, 36), Material = Enum.Material.Wood, NoCollide = true },
	Moss = { Color = Color3.fromRGB(70, 110, 52), Material = Enum.Material.Grass },
	-- the Conduit body (server/Body.lua recolours these per life)
	Proxy = { Color = Color3.fromRGB(34, 33, 36), Material = Enum.Material.Fabric }, -- the plain limbs under a skinned body
	ConduitJacket = { Color = Color3.fromRGB(44, 46, 54), Material = Enum.Material.Fabric },
	ConduitTrim = { Color = Color3.fromRGB(0, 215, 255), Material = Enum.Material.Neon },
	ConduitVisor = { Color = Color3.fromRGB(0, 215, 255), Material = Enum.Material.Neon, Light = Color3.fromRGB(0, 215, 255) },
	-- buildings
	DarkConcrete = { Color = Color3.fromRGB(44, 44, 51), Material = Enum.Material.Concrete },
	Panel = { Color = Color3.fromRGB(66, 69, 84), Material = Enum.Material.Metal },
	Brick = { Color = Color3.fromRGB(97, 61, 43), Material = Enum.Material.Brick },
	GlassDark = { Color = Color3.fromRGB(20, 26, 36), Material = Enum.Material.Glass, Transparency = 0.15 },
	GlassCorp = { Color = Color3.fromRGB(26, 46, 66), Material = Enum.Material.Glass, Transparency = 0.2 },
	GlassLit = { Color = Color3.fromRGB(217, 191, 115), Material = Enum.Material.Neon },
	NeonAmber = { Color = Color3.fromRGB(255, 158, 38), Material = Enum.Material.Neon, Light = Color3.fromRGB(255, 170, 60) },
	NeonRed = { Color = Color3.fromRGB(255, 30, 30), Material = Enum.Material.Neon, Light = Color3.fromRGB(255, 50, 50) },
	SootBrick = { Color = Color3.fromRGB(58, 42, 36), Material = Enum.Material.Brick },
	Plaster = { Color = Color3.fromRGB(158, 148, 128), Material = Enum.Material.Concrete },
	Canvas = { Color = Color3.fromRGB(92, 97, 76), Material = Enum.Material.Fabric },
	Mattress = { Color = Color3.fromRGB(140, 128, 108), Material = Enum.Material.Fabric },
	Yellow = { Color = Color3.fromRGB(178, 152, 38), Material = Enum.Material.Metal },
	White = { Color = Color3.fromRGB(216, 222, 224), Material = Enum.Material.SmoothPlastic },
	Ember = { Color = Color3.fromRGB(255, 115, 25), Material = Enum.Material.Neon, Light = Color3.fromRGB(255, 120, 30) },
	Red = { Color = Color3.fromRGB(178, 30, 30), Material = Enum.Material.SmoothPlastic },
	Hazard = { Color = Color3.fromRGB(216, 166, 26), Material = Enum.Material.Metal },
	Flag = { Color = Color3.fromRGB(220, 220, 220), Material = Enum.Material.Fabric },
	Copper = { Color = Color3.fromRGB(184, 108, 50), Material = Enum.Material.Metal },
	Powder = { Color = Color3.fromRGB(52, 52, 58), Material = Enum.Material.Fabric },
	Rubble = { Color = Color3.fromRGB(84, 82, 79), Material = Enum.Material.Concrete },
	-- the Front's calcified clone bodies (tools/models/front_world.py): pale mineral, darker in the folds
	Calcified = { Color = Color3.fromRGB(184, 176, 160), Material = Enum.Material.Limestone },
	CalcifiedDark = { Color = Color3.fromRGB(122, 116, 106), Material = Enum.Material.Limestone },
	BrickDark = { Color = Color3.fromRGB(70, 44, 36), Material = Enum.Material.Brick },
}

-- The material library (tools/textures, 2026-11-11): tileable PBR surfaces uploaded as swatch models. A MeshPart
-- named "<Part>_<Name>" gets a clone of that SurfaceAppearance (common/SurfaceLibrary.lua sets Assets.SurfaceFor
-- on the server). Tile = studs per repeat; tools/models/lib.py TILE uses the same numbers for the models' UVs.
-- Material/Color below only matter for footsteps, physics and the distant flat look.
Assets.Surfaces = {
	CarBody = { Id = 98254339854841, Tile = 8, Material = Enum.Material.Metal, Color = Color3.fromRGB(150, 152, 150) },
	CarLivery = { Id = 112736865012669, Tile = 8, Material = Enum.Material.Metal, Color = Color3.fromRGB(150, 40, 30) },
	CarPanel = { Id = 140267941794015, Tile = 6, Material = Enum.Material.SmoothPlastic, Color = Color3.fromRGB(175, 178, 170) },
	CarFloor = { Id = 130930165945884, Tile = 4, Material = Enum.Material.Rubber, Color = Color3.fromRGB(50, 52, 55) },
	Moquette = { Id = 128011240005037, Tile = 2.5, Material = Enum.Material.Fabric, Color = Color3.fromRGB(30, 40, 70) },
	SeatShell = { Id = 93140818164219, Tile = 4, Material = Enum.Material.Plastic, Color = Color3.fromRGB(55, 62, 70) },
	Stainless = { Id = 110057387975935, Tile = 3, Material = Enum.Material.Metal, Color = Color3.fromRGB(190, 192, 195) },
	Underframe = { Id = 104170739046483, Tile = 6, Material = Enum.Material.CorrodedMetal, Color = Color3.fromRGB(40, 38, 36) },
	Gunmetal = { Id = 125466534889036, Tile = 1.5, Material = Enum.Material.Metal, Color = Color3.fromRGB(45, 46, 48) },
	Polymer = { Id = 128020204355917, Tile = 1, Material = Enum.Material.Plastic, Color = Color3.fromRGB(30, 30, 32) },
	Waxcloth = { Id = 86046108044156, Tile = 2.5, Material = Enum.Material.Fabric, Color = Color3.fromRGB(45, 47, 40) },
	HideLeather = { Id = 91466596182777, Tile = 1.5, Material = Enum.Material.Leather, Color = Color3.fromRGB(50, 36, 28) },
	CarTrim = { Id = 113939627951069, Tile = 4, Material = Enum.Material.Metal, Color = Color3.fromRGB(30, 32, 34) },
	-- characters (tools/models/figure.py). Base = the texture's mean brightness (linear): these are pale, neutral
	-- textures made to be tinted per character (Assets.Tint), so one cloth dresses everybody.
	Techcloth = { Id = 81964054183740, Tile = 2, Material = Enum.Material.Fabric, Color = Color3.fromRGB(120, 120, 120), Base = 0.42 },
	Twill = { Id = 104454762397293, Tile = 1.5, Material = Enum.Material.Fabric, Color = Color3.fromRGB(110, 110, 112), Base = 0.36 },
	Gauze = { Id = 130850579621389, Tile = 1.2, Material = Enum.Material.Fabric, Color = Color3.fromRGB(150, 140, 120), Base = 0.45 },
	PlateSteel = { Id = 88687879872901, Tile = 2, Material = Enum.Material.Metal, Color = Color3.fromRGB(120, 120, 122), Base = 0.40 },
	Flesh = { Id = 84428858142888, Tile = 2, Material = Enum.Material.SmoothPlastic, Color = Color3.fromRGB(168, 153, 145), Base = 0.485 }, -- the clone body (tinted)
}
Assets.SurfaceFor = nil -- function(name) -> SurfaceAppearance template; set by common/SurfaceLibrary on the server

-- Colours a part that wears a library texture. `color` is the look wanted; a neutral texture (Surfaces[name].Base)
-- is multiplied up or down to reach it, any other texture is simply tinted by it.
function Assets.Tint(part, color)
	local name = part.Name:match("_(%w+)$")
	local spec = name and Assets.Surfaces[name]
	part.Color = color
	local surface = part:FindFirstChildOfClass("SurfaceAppearance")
	if not surface then
		return
	end
	local tint = color
	if spec and spec.Base then
		local function lin(c)
			return if c <= 0.04045 then c / 12.92 else ((c + 0.055) / 1.055) ^ 2.4
		end
		local function srgb(c)
			c = math.clamp(c, 0, 1)
			return if c <= 0.0031308 then c * 12.92 else 1.055 * c ^ (1 / 2.4) - 0.055
		end
		tint = Color3.new(srgb(lin(color.R) / spec.Base), srgb(lin(color.G) / spec.Base), srgb(lin(color.B) / spec.Base))
	end
	pcall(function()
		surface.Color = tint
	end)
end

-- Applies the named material to every part of a loaded model.
function Assets.Dress(model)
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			local matName = part.Name:match("_(%w+)$")
			local spec = matName and (Assets.Materials[matName] or Assets.Surfaces[matName])
			local surface = matName and Assets.Surfaces[matName] and Assets.SurfaceFor and part:IsA("MeshPart") and Assets.SurfaceFor(matName)
			if surface and not part:FindFirstChildOfClass("SurfaceAppearance") then
				surface:Clone().Parent = part
			end
			if spec then
				part.Color = spec.Color
				part.Material = spec.Material
				part.Transparency = spec.Transparency or 0
				if spec.NoCollide then
					part.CanCollide = false
				end
				if spec.Light and not part:FindFirstChildOfClass("PointLight") then
					local light = Instance.new("PointLight")
					light.Color, light.Range, light.Brightness = spec.Light, 16, 1
					light.Parent = part
				end
			end
		end
	end
end

-- Picks a building for a district style whose height is within [minH, maxH]; collapsed ones
-- are chosen with probability `collapseChance`. Returns the entry or nil.
function Assets.PickBuilding(style, minH, maxH, collapseChance, rng)
	local kit = Assets.Buildings[style]
	if not kit then
		return nil
	end
	local wantCollapsed = (rng and rng:NextNumber() or math.random()) < collapseChance
	local pool, fallback = {}, {}
	for _, entry in kit do
		if entry.Id ~= 0 then
			if entry.Collapsed == wantCollapsed then
				if entry.Height >= minH * 0.7 and entry.Height <= maxH * 1.3 then
					table.insert(pool, entry)
				end
				table.insert(fallback, entry)
			end
		end
	end
	if #pool == 0 then
		pool = fallback
	end
	if #pool == 0 then
		return nil
	end
	return pool[(rng and rng:NextInteger(1, #pool)) or math.random(#pool)]
end

-- Picks a random condition's asset id for a prop, or nil.
function Assets.PickProp(propId, rng)
	local set = Assets.Props[propId]
	if not set then
		return nil
	end
	local ids = {}
	for _, cond in { "A", "B", "C" } do
		if set[cond] and set[cond] ~= 0 then
			table.insert(ids, set[cond])
		end
	end
	if #ids == 0 then
		return nil
	end
	return ids[(rng and rng:NextInteger(1, #ids)) or math.random(#ids)]
end

return Assets
