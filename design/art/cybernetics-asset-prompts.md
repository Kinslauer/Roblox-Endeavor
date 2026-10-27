# Cybernetics asset prompts (scavenger conduit)

> **For**: Higgsfield (images / concept) and Studio's text-to-3D (`generate_mesh`) placeholders
> **Matches**: `design/gdd/cybernetics.md` (eight slots, thirteen pieces). The look is a "scavenger conduit" (owner,
> 2026-10-27): salvage metal, exposed actuators, brass fasteners and a muted palette with one accent glow per piece. It is not fantasy armour.
> **Where the art goes**: `Presentation.Implants.Pieces[<id>].Mesh = { MeshId, TextureId, Scale, Offset }`. Each mesh
> is attached to its slot's body part: Head for eyes, ears and nose; UpperTorso for the core; the upper arm or leg for limbs.

## 1. Turnaround sheet: the body as a set of sockets

> A single full-body scavenger conduit character, designed as a Roblox R15 customization reference, neutral A-pose,
> front / side / back turnaround on one sheet. A lean survivor in a dark patched tactical undersuit. The body is visibly
> modular: every part that can be replaced has a clean mechanical socket ring where flesh meets metal — at both
> shoulders, both elbows, both hips, both knees, around both eyes, at both ears, across the bridge of the nose, and a
> round chest port over the sternum. Left arm and right leg are already replaced: a salvaged servo arm with exposed
> pistons and brass fasteners, and a strider prosthetic leg with a spring-steel shin; the rest is human. Ripped-in,
> not elegant: weld seams, mismatched plates, cable runs taped down. Muted palette (oxidised steel, gunmetal, worn
> leather, brass), one soft accent glow per implant (amber on the arm, green on the leg). Utility belt, chest rig,
> knee guard on the flesh leg, boots. No helmet, no weapon. Flat even lighting, plain mid-gray background, clean
> silhouette, game-ready concept art.

## 2. Parts sheet: every implant laid out

> An exploded parts sheet of scavenger cybernetic implants for a game, each object isolated on a plain mid-gray
> background in a 4×4 grid, consistent scale, three-quarter view, flat even lighting, labelled. Salvage-built: weld
> seams, brass fasteners, exposed wiring, oxidised steel and gunmetal, each with one small accent glow.
> Row 1 (eyes, ears): Reflex Optic (twin amber lenses in a brow bar), Targeting Lens (single red crosshair lens over one
> eye), Audio Pickup (teal-lit ear cups), Echo Array (blue ribbed antenna fins behind each ear).
> Row 2 (nose, core): Chem Sniffer (green-vented nose and upper-lip filter), Blood Tracer (red-lit nasal sensor bridge),
> Neural Core (violet-lit spine and sternum port), Overclock Core (orange-hot chest reactor with heat sinks).
> Row 3 (core, arms): Plated Core (heavy riveted chest plate), Servo Arm (full arm, pistons, amber elbow ring), Arc Gauntlet
> (forearm and hand, cyan coil windings).
> Row 4 (legs): Strider Leg (spring-steel running shin, green knee seam), Piston Leg (hydraulic thigh and calf, pale gold
> knee seam).

## 3. Text-to-3D (one mesh per piece)

Studio's `generate_mesh` works best with short, concrete prompts. These sizes are for the R15 body parts each piece sits on:

| Piece | Prompt | Approx. size (studs) |
|---|---|---|
| ReflexOptic | low-poly scrap-metal brow visor with two round amber lenses, brass rivets | 1.0 × 0.3 × 0.3 |
| TargetingLens | low-poly single monocle lens with crosshair, steel housing, red glass | 0.4 × 0.4 × 0.3 |
| AudioPickup | pair of low-poly salvaged steel ear cups with teal grille | 1.3 × 0.5 × 0.5 |
| EchoArray | pair of low-poly ribbed antenna fins mounted behind the ears | 1.4 × 0.7 × 0.6 |
| ChemSniffer | low-poly metal nose and filter mask over the upper lip, green vents | 0.5 × 0.4 × 0.3 |
| BloodTracer | low-poly steel nose bridge sensor with a red slit | 0.3 × 0.4 × 0.2 |
| NeuralCore | low-poly sternum port plate with a violet core, cables | 1.0 × 1.0 × 0.3 |
| OverclockCore | low-poly chest reactor with heat-sink fins, orange core | 1.2 × 1.0 × 0.5 |
| PlatedCore | low-poly heavy riveted steel chest plate | 1.9 × 1.3 × 0.4 |
| ServoArm | low-poly scrap robotic arm, exposed pistons, brass fasteners | 1.0 × 2.6 × 1.0 |
| ArcGauntlet | low-poly robotic forearm and hand with copper coil windings | 1.0 × 1.6 × 1.0 |
| StriderLeg | low-poly running-blade prosthetic leg, spring steel shin | 1.0 × 2.8 × 1.0 |
| PistonLeg | low-poly hydraulic robotic leg, thigh and calf pistons | 1.1 × 2.8 × 1.1 |

The two-sided pieces (ears, eyes) should be one mesh that covers both sides.

Arm and leg pieces are drawn on whichever side they're in. Give a piece `MeshLeft` as well if the left one should
be its own mesh; otherwise both sides use `Mesh`.
