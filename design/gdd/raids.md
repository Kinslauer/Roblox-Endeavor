# Raids, the hideout computer, contacts, rival crews

> **Status**: v1 implemented 2026-10-26 (`shared/Raids.lua`, `server/Raids.lua`, `server/Terminal.lua`, `server/Contacts.lua`,
> `server/Rivals.lua`, `client/HouseView.lua`), live-verified, owner playtest pending
> **Owner (2026-10-26 09:46)**: raids from the computer in the hideout, which also orders for the house and sells off the
> black market; every app unlocked by finding its contact out in the world; raids with varied objectives ending in an
> extraction or a continuation; contracts also dropped by enemy conduits doing the same thing, met unannounced; all of it
> immersive and emergent. **Also (10:00)**: all enemies drop all their loot, both worlds.

## 1. The rule under everything
Nothing is announced that you would not have noticed yourself. Contacts stand where they stand with a name over their
head and a Talk prompt — no quest marker, no "new contact available". Rival crews walk their routes and notice you when
they see you (short aggro), as you notice them. A raid tells you its objective and lights a beacon at a point; it does
not tell you what else is out there. The one concession to legibility is the raid line under the wallet on the HUD.

## 2. The computer (`server/Terminal.lua`)
> **Fiction (owner, 2026-10-26 17:53)**: a conduit's consciousness is uploaded to their home computer — that's why
> what's on it survives permadeath, and why a body can be re-wired at all; cybernetics are ripped in at an Autonet the
> conduit learns, crafts and builds in the hideout (`design/gdd/dematerialization.md` §6).

A console in the hideout ("Computer", hold X) opens a panel with three apps. Each is **locked until its contact has been
met** (`profile.Contacts`, persists):

| App | Contact | Where they stand | What the app does |
|---|---|---|---|
| RAIDS | the Broker | Verdant Market, by the stalls | the board: take a contract, drop the one you are on |
| HOUSE | the Fixer | Ferrite Court's plaza | furnishings for the hideout, for money, bought once |
| MARKET | the Dealer | the road, out by the wrecks past the brute | the black market: parts, cybernetics, an Arc Rifle, intel |

The contact's first line is their only introduction; two seconds later "RAIDS unlocked on your computer", and the first
contact you ever meet earns the lore line. Walking out of the hideout closes the computer; so does the panel's Close.
State goes to the client as one table (`TerminalChanged`) and re-pushes on every change.

**HOUSE** furnishings (`Raids.House`: rug, floor lamp, shelf, fern, poster, couch) are stored in the profile and
published as a JSON attribute; the **client** draws them in the hideout room for their owner only (`HouseView.lua`),
since the room is shared geometry for now. **MARKET** (`Raids.Market`) sells what the enclave's trader does not:
Suppressor, 4x Scope, Light Bolt, Long Barrel, Reflex Optic, Servo Arm, Arc Rifle, and Intel itself at 50.

## 3. Raids (`shared/Raids.lua`, `server/Raids.lua`)
A **contract** is a template: a name, the broker's one-line text, a chain of **steps**, a reward. Step kinds:

| Kind | Progress from | Example |
|---|---|---|
| `kill` { Target = QuestTag or EnemyType, Count } | `NPCs.Killed` (the killer is the player) | put down 4 raiders · kill the warmonger · 2 rival conduits |
| `reach` { Point, Radius } | a 1 Hz position watch; a 60-stud neon beacon marks the point for the owner | the dead drop by the wrecks |
| `hold` { Point, Radius, Seconds } | the same watch, seconds accumulate while inside | hold the enclave gate 25 s |
| `extract` | added by the server as the last step | a station (`Hideout.Extract`) or a train (`Transport.Ride`) |

Six templates ship (`Raids.Templates`): Clear the Highway, Dead Drop, Hold the Gate, A Warmonger's Head, Competition,
Ferrite Sweep (a two-step one). Points (`Raids.Points`) are built from the regions so they move with the world.

**The board** (`profile.Board`, persists): three contracts drawn from the templates, refilled when one is taken. Taking
one needs its contact — unless it came from **intel**. **The raid** (`profile.Raid`, dies with the body): the accepted
contract with its steps and a `Chain` of template ids. Permadeath wipes it like everything else the body carried; the
board on the computer is unaffected.

**Continuation.** When the objectives are done, with `LeadChance` (0.6) a **lead** is offered on the extract step:
*"Objectives done. A lead turned up: 'Dead Drop' — ... Follow it, or extract and get paid."* Extract and you are paid
for the chain so far. Do the lead's first objective instead (its kill, or step into its point) and the raid **follows
the lead**: its steps are appended, the chain grows, `Bonus` × 1.5 on the money, and a new extract step waits at the
end — where another lead may turn up. Every contract in the chain pays out at the final extraction, money × bonus, xp
and items summed. This is the owner's "ending with an extraction or continuation, travelling on your own or picking up
a new quest on the way": the lead is the new quest, extracting is going home.

**Intel.** `Items.Defs.Intel` is a consumable: using it (Tab → Use) puts a named contract on the board, marked
[intel], takeable with no contact. Rival crews carry it 60 % of the time; the black market sells it.

## 4. Rival crews (`server/Rivals.lua`)
Two crews of two **Rival Conduits** (`Enemies.Defs.Rival`: 110 HP, Shock Baton, poise 3, a short flicker-step Dash,
aggro 48 — sight range, not radar) walk routes between raid points (`Raids.Crews`: the road crew wrecks → road's end →
enclave gate; the city crew Ferrite's edge → Relay's north), linger 10 s at each, and move on. Their Home is the crew's
current point, so after a fight they go back to work. A wiped crew is replaced after 180 s. Nothing announces them —
no "Raiders have found you" line — and their loot is what they were working on: intel, scrap, wire, a medkit, a part.

## 5. Everything drops (owner, 2026-10-26 10:00)
`NPCs.packCarry`: what an enemy carries is rolled **when it spawns** — its held weapon (always), the armour its supply
kit put on it (Armed → Scav Helm; Plated → Plated Helm + Riot Plate), and one roll of its loot table — and **all of it**
is dropped where it dies (`NPCs.Carrying(model)`, `Carrying` attribute = item count). Both worlds: a recruit drops its
rifle, a brute its sledge, a rival its baton and its intel. Held weapons were removed from the roll tables so they are
never doubled. Kill credit is tagged before the damage lands, so a synchronous death still pays the right player.

## 6. Acceptance (smoke: 17 checks)
1. Three contacts stand; two crews of two rivals walk.
2. The board fills to three; a contract needs its contact; meeting the broker unlocks RAIDS; taking one sets the raid and the HUD line.
3. Four raider kills finish the objective; a lead's first objective continues the raid (chain 2, bonus 1.5); extraction pays the chain × bonus.
4. Intel adds a [intel] contract to the board. HOUSE and MARKET refuse without their contacts and sell with them; the house attribute publishes.
5. Leaving the hideout closes the computer. An enemy carries its weapon from spawn and drops all of it on death.

## 7. The tells (added the same day)
- **Barks** (`Enemies.Barks`, `NPCs` Bark attribute, `client/WorldFX.lua`): the first time a body sees you it says one
  line in a speech bubble over its head — only drawn if you are within 90 studs, 12 s cooldown per body. Grunts
  ("Fresh meat."), rivals ("They're on our contract."), warmongers ("Another one come to die."), recruits ("Open fire!").
  That is the *hear* in "until you see or hear each other": the bubble is the warning, there is no other.
- **Contested holds** (`Raids.Contested`): a rival crew standing inside your hold point stops the timer ("· contested"
  on the line, one announcement). Crews walk between the raid points on their own, so this is not scripted.
- **WorldFX** also draws the dash streak (red for a warmonger, teal for a rival, a shake if it lands near you), a shake
  when a pod or crate lands within 40 studs, red / green pulses for downed / revived, the hill ring flashing its new
  side's colour, and a gold pulse when a shipment is opened.

## 8. Follow-ups
- More templates per region as regions arrive; contracts that name a *place* to clear rather than a type to kill.
- Rival crews that actually run contracts (visible objectives, racing you to a dead drop); crews that loot what you leave.
- Footstep audio and a voice sound slot for barks (Presentation) once audio assets exist.
- A dedicated terminal UI (apps as tabs) once the row panel gets long; a radio in the hideout for the broker's lines.
- Furnishings with function (the couch heals, the shelf is extra stash) and visible to visitors when the hideout is a place.
