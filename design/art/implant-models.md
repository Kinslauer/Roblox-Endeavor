# Implant models (generated 2026-10-29)

The 13 implant models live in the place file at `ReplicatedStorage.Assets.Implants.<PieceId>`, not in the repo
(Rojo syncs only `src/`). `client/Implants.lua` draws a piece with its model when one is there, and with the
placeholder metal shell when not (`Presentation.Implants` ART). Made with Studio's mesh generator; limbs were
generated (or, for the Servo Arm, segmented afterwards) into three parts so they bend at the elbow and knee.
The one-piece Servo Arm from the first pilot is kept at `ReplicatedStorage.Assets.ImplantArchive.ServoArm_OnePiece`.

If the place is ever lost, rebuild each model from these ids: a MeshPart per row, `MeshId` and `TextureID` as
listed, named as listed (the renderer matches limb parts by name: upper arm / forearm / hand, thigh / shin / foot),
inside a Model named after the piece.

| Piece | Part | MeshId | TextureID |
|---|---|---|---|
| ArcGauntlet | upper arm | rbxassetid://116966869604521 | rbxassetid://86956616708174 |
| ArcGauntlet | forearm | rbxassetid://132621741693185 | rbxassetid://129982272368303 |
| ArcGauntlet | hand | rbxassetid://100555950910123 | rbxassetid://139299762988393 |
| AudioPickup | body | rbxassetid://138577078620412 | rbxassetid://104154309306079 |
| BloodTracer | body | rbxassetid://78446808427201 | rbxassetid://132319620821207 |
| ChemSniffer | body | rbxassetid://87148983306431 | rbxassetid://112436166449860 |
| EchoArray | body | rbxassetid://71677714028373 | rbxassetid://114975238733801 |
| NeuralCore | body | rbxassetid://135941728962792 | rbxassetid://81737586774829 |
| OverclockCore | body | rbxassetid://104926320795986 | rbxassetid://133304949232544 |
| PistonLeg | thigh | rbxassetid://72686592543374 | rbxassetid://70622811859279 |
| PistonLeg | shin | rbxassetid://125131881454456 | rbxassetid://92308146492403 |
| PistonLeg | foot | rbxassetid://90280586835759 | rbxassetid://78334904252712 |
| PlatedCore | body | rbxassetid://103062681322896 | rbxassetid://97423108968008 |
| ReflexOptic | body | rbxassetid://92597413953303 | rbxassetid://124006780294489 |
| ServoArm | upper arm | rbxassetid://109596935892157 | rbxassetid://123484466561551 |
| ServoArm | forearm | rbxassetid://117913305058042 | rbxassetid://123484466561551 |
| ServoArm | hand | rbxassetid://99362802900026 | rbxassetid://123484466561551 |
| StriderLeg | thigh | rbxassetid://70440054170695 | rbxassetid://99309353775119 |
| StriderLeg | shin | rbxassetid://81620025645933 | rbxassetid://73515705302297 |
| StriderLeg | foot | rbxassetid://126035701524605 | rbxassetid://108501653607988 |
| TargetingLens | body | rbxassetid://137169954176648 | rbxassetid://107686318955076 |

First look (owner Studio test, 2026-10-29): all 17 parts land on the right body parts and the flesh limbs hide. The
textures read paler than the prompts' gunmetal; worth a look in normal lighting before any re-generation.
