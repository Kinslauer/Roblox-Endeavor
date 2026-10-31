-- Implant art: the 13 Studio-generated implant meshes from the combat-feel branch (design/art/implant-models.md
-- there), rebuilt here at startup as Models under ReplicatedStorage.Implants.<PieceId> with their limb parts named
-- by segment (UpperArm / Forearm / Hand, Thigh / Shin / Foot) or Body. Needs AssetService:CreateMeshPartAsync; if
-- that is missing or an id fails, that piece simply keeps the client's metal-shell placeholder.
local AssetService = game:GetService("AssetService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ImplantLibrary = {}

-- piece -> { { part name, mesh id, texture id }, ... }
ImplantLibrary.Meshes = {
	ArcGauntlet = { { "UpperArm", 116966869604521, 86956616708174 }, { "Forearm", 132621741693185, 129982272368303 }, { "Hand", 100555950910123, 139299762988393 } },
	AudioPickup = { { "Body", 138577078620412, 104154309306079 } },
	BloodTracer = { { "Body", 78446808427201, 132319620821207 } },
	ChemSniffer = { { "Body", 87148983306431, 112436166449860 } },
	EchoArray = { { "Body", 71677714028373, 114975238733801 } },
	NeuralCore = { { "Body", 135941728962792, 81737586774829 } },
	OverclockCore = { { "Body", 104926320795986, 133304949232544 } },
	PistonLeg = { { "Thigh", 72686592543374, 70622811859279 }, { "Shin", 125131881454456, 92308146492403 }, { "Foot", 90280586835759, 78334904252712 } },
	PlatedCore = { { "Body", 103062681322896, 97423108968008 } },
	ReflexOptic = { { "Body", 92597413953303, 124006780294489 } },
	ServoArm = { { "UpperArm", 109596935892157, 123484466561551 }, { "Forearm", 117913305058042, 123484466561551 }, { "Hand", 99362802900026, 123484466561551 } },
	StriderLeg = { { "Thigh", 70440054170695, 99309353775119 }, { "Shin", 81620025645933, 73515705302297 }, { "Foot", 126035701524605, 108501653607988 } },
	TargetingLens = { { "Body", 137169954176648, 107686318955076 } },
}

ImplantLibrary.Built = 0

function ImplantLibrary.Init()
	local folder = Instance.new("Folder")
	folder.Name = "Implants"
	folder.Parent = ReplicatedStorage
	task.spawn(function()
		for pieceId, list in ImplantLibrary.Meshes do
			local model = Instance.new("Model")
			model.Name = pieceId
			local ok = true
			for _, entry in list do
				local good, part = pcall(function()
					return AssetService:CreateMeshPartAsync(Content.fromAssetId(entry[2]), { CollisionFidelity = Enum.CollisionFidelity.Box })
				end)
				if good and part then
					part.Name = entry[1]
					pcall(function()
						part.TextureID = "rbxassetid://" .. entry[3]
					end)
					part.Anchored, part.CanCollide, part.CanQuery, part.CanTouch = true, false, false, false
					part.Parent = model
				else
					ok = false
					warn("[ImplantLibrary] mesh failed for", pieceId, entry[1], part)
					break
				end
			end
			if ok then
				model.Parent = folder
				ImplantLibrary.Built += 1
			else
				model:Destroy()
			end
			task.wait()
		end
	end)
end

return ImplantLibrary
