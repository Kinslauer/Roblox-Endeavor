# Game Concept: Endeavor — Universe 1: Conduit

*Created: 2026-10-25*
*Status: Draft (reverse-documented from `design/game-brief.md`, `README.md`, `docs/DESIGN.md` and `src/`)*

> Source precedence: the approved one-page brief (`design/game-brief.md`) wins over `README.md` and
> `docs/DESIGN.md` where they disagree. Anything stated here that is not in those three files is marked
> `[inferred — confirm]`. "Endeavor" is the account-level game; this codebase is its first universe,
> "Conduit" (`default.project.json` names the Rojo project `Conduit`).

---

## Elevator Pitch

> It's a permadeath, always-on-PvP action game where you scavenge, craft and fight with timing-based
> melee in a wrecked cyberpunk megacity to survive one more risky trip out — and it feels like a
> single-player game until the city wakes up around you.

---

## Core Identity

| Aspect | Detail |
| ---- | ---- |
| **Genre** | Action RPG / survival-PvP (Deepwoken-style timing melee with permadeath) |
| **Platform** | Roblox (PC keyboard + mouse controls today; `Main.client.lua` binds only keyboard/mouse) |
| **Target Audience** | Roblox combat-game players — Deepwoken / Cursed Gear fans (brief) |
| **Player Count** | Multiplayer, server-authoritative. Structurally **single-player until Emergence**: every player starts alone in a private plot 1500 studs from the next (`Config.PlotSpacing`, `WorldPhase.lua:22-23`); PvP damage is refused while the phase is `Prologue` (`Combat.lua:296-298`). At Emergence all players are teleported into one shared city. Server size is explicitly out of scope for the slice. |
| **Session Length** | "A session feels complete after one risky trip out and back" (brief). NOT ASSESSED — no telemetry; the 10-minute prologue cap (`Config.PrologueSeconds = 600`) bounds the first session's opening. |
| **Monetization** | None defined. NOT ASSESSED — nothing in code or docs. |
| **Estimated Scope** | Medium: server logic exists; the MVP is making it readable and felt (brief, "MVP"). |
| **Comparable Titles** | Deepwoken (timing melee, posture, permadeath), Cursed Gear (flick / Black Flash chain) |

---

## Core Fantasy

You are a *conduit*: a scavenger in a ruined neon city whose only real edge is timing. Everything you
carry is on the line every time you leave cover, and the highest expression of skill — the Black
Flash — is a perfectly timed hit, not a stat check. The emotional promise (brief): "the tension of
having everything on the line and the rush of a perfectly timed hit."

---

## Unique Hook

"It's like Deepwoken, **and also** the first ten minutes are a private, single-player apartment — then
the walls fall away and you discover everyone else was there the whole time." (`docs/DESIGN.md` Pillar 1,
`WorldPhase.Emerge`: announcement "The walls fall away. You were never alone.", `WorldPhase.lua:130`.)

Secondary hook: the **flicker / Black Flash** chain — a rhythm-game layer on top of melee where the
third consecutive well-timed flick lands a x2.5 guard-breaking hit (`Config.Flicker`). See
`design/gdd/flicker.md`.

---

## Player Experience Analysis (MDA Framework)

### Target Aesthetics (What the player FEELS)

| Aesthetic | Priority | How We Deliver It |
| ---- | ---- | ---- |
| **Challenge** (mastery) | 1 | Parry window 0.22 s, dodge i-frames 0.35 s, flick window 0.28 s, posture/guard break; Black Flash as the skill ceiling |
| **Sensation** | 2 | Brief: "combat audio that snaps", bass-drop Black Flash, hit sparks/hitstop — **planned**, today's feedback is Highlight flashes only |
| **Fantasy** | 3 | Conduit identity, cybernetic implants, wrecked neon city at night |
| **Fellowship / Rivalry** | 4 | Always-on PvP, announced supply drops that pull players together (`Events.lua:26-44`), kill announcements |
| **Discovery** | 5 | The Emergence reveal; stat/tag-gated skills that appear when gear changes (`Gear.autoSlot`) |
| **Expression** | 6 | Weapon = moveset; armor tags change which skills you own |
| **Narrative** | 7 | One line of lore at Emergence; brief defers lore beats to Tutorial v2 |
| **Submission** | N/A | Nothing is low-stakes once the world opens |

### Key Dynamics (Emergent player behaviors)
- Players read enemy windups instead of trading hits (parry/dodge beat blocking; blocking a Black Flash fails).
- Players race to announced supply drops and fight over them (brief "working" scenario).
- Players re-spec gear to unlock skills: swapping a chest piece can lock or unlock an ability (`Skills.lua:1-3`).
- Players weigh "one more trip" against losing everything (permadeath + remains drop) — `[inferred — confirm]`.

### Core Mechanics (Systems we build)
1. Server-authoritative timing melee: frame-data attacks, block/parry, posture, i-frame dodge, feint (`Combat.lua`).
2. Flicker / Black Flash chain and the Zone (`Combat.lua:124-188`).
3. Build = weapon moveset + stats + armor/cybernetic tags → skills (`Weapons.lua`, `Gear.lua`, `Skills.lua`).
4. Permadeath with lootable remains and combat-log punishment (`Permadeath.lua`, `Lifecycle.lua:67-70`).
5. Prologue → Emergence world phase with a guided tutorial (`WorldPhase.lua`, `Tutorial.lua`).

---

## Player Motivation Profile

### Primary Psychological Needs Served

| Need | How This Game Satisfies It | Strength |
| ---- | ---- | ---- |
| **Autonomy** | Free stat allocation (5 attributes, 3 points/level), any weapon, no class lock on skills | Supporting |
| **Competence** | Timing windows are the whole fight; Black Flash is a visible, announced mastery moment ("BLACK FLASH" banner, `Main.client.lua:348`) | Core |
| **Relatedness** | Shared city, kill feed, contested drops; no co-op or guild systems yet | Minimal |

### Player Type Appeal (Bartle Taxonomy)
- [x] **Achievers** — levels, crafting tiers, legacy record (deaths, kills, best survival; `Permadeath.lua:21-35`)
- [ ] **Explorers** — city districts are planned, not built
- [ ] **Socializers** — no social systems in scope
- [x] **Killers/Competitors** — always-on PvP, bounty quest for killing another player (`Quests.lua:15`)

### Flow State Design
- **Onboarding curve**: 15-step tutorial in the private room; every step has a live counter; skippable (`Tutorial.lua:151-255`).
- **Difficulty scaling**: NOT ASSESSED — one NPC type at fixed numbers; no scaling by level or time.
- **Feedback clarity**: today limited to Highlight flashes, a flicker aura and a banner; the Combat Feel epic is the fix (brief, build order 1).
- **Recovery from failure**: prologue deaths are free (`Lifecycle.lua:23`); open-world death wipes the character and respawns in 5 s (`Config.RespawnDelay`) with starting gear (Pipe Club, 3 Scrap, 1 Ration; `PlayerData.lua:51-52`).

---

## Core Loop

### Moment-to-Moment (30 seconds)
Approach, read a windup, parry or dodge, punish with a combo, tap flick on the connecting hit, manage
stamina and posture, back off to regen.

### Short-Term (5-15 minutes)
Take the current quest (collect / kill / craft / bounty), chase an event (supply drop every 60-150 s
roll, `Events.lua:64`), loot remains or crates (hold `X`), craft an upgrade from Scrap / Wire / Cloth.

### Session-Level (30-120 minutes)
One risky trip out and back (brief). Ends either safely with new gear or with death and a fresh character.

### Long-Term Progression
Level → attribute points (`Stats.XpNeeded = 100 * level`, 3 points per level) → effective stats + armor
tags unlock the seven skills. Account-level "legacy" (deaths, total kills, best survival) persists
across deaths but grants nothing yet (`docs/DESIGN.md` open question).

### Retention Hooks
- **Curiosity**: what the city looks like after Emergence; which gear unlocks which skill.
- **Investment**: a living character with gear you will lose — the core tension.
- **Social**: kill feed and contested drops. `[inferred — confirm]`
- **Mastery**: landing a Black Flash on a real opponent.

---

## Game Pillars

From `docs/DESIGN.md`:

### Pillar 1: The reveal
Prologue feels single-player; Emergence reveals everyone else.
*Design test*: if a feature would show other players before Emergence (chat, leaderboards, shared map), it waits.

### Pillar 2: Everything is at stake
Permadeath, always-on PvP, loot drops where you fall.
*Design test*: when choosing between a safety net and a consequence, pick the consequence — but add spawn protection so the consequence is fair (brief MVP item 5).

### Pillar 3: Skill-based combat
Timing (parry, dodge i-frames) and stamina management beat stat checking.
*Design test*: a new upgrade should widen a window or add an option, not just add flat damage.

### Pillar 4: A living ruin
A cyberpunk megacity that is wrecked but inhabited; events keep it unpredictable.
*Design test*: prefer a new event type over a new static POI.

### Anti-Pillars (What This Game Is NOT)
From the brief's out-of-scope list:
- **NOT Universe 2 (the FPS world)** — same account, different place, built after this slice.
- **NOT a hand-built art project in code** — meshes, animations and audio are the player's job in Studio; code ships placeholders and ID slots.
- **NOT a faction / territory / talent-tree game yet** — pickpocketing, lockpicking, bounty board, status effects, power trees, cosmetics and leaderboards are deferred.
- **NOT tuned for server size or matchmaking** in this slice.
- **NOT renaming data stores** (`ConduitCharacter_v2`, `ConduitLegacy_v1`) — would wipe saves.

---

## Inspiration and References

| Reference | What We Take From It | What We Do Differently | Why It Matters |
| ---- | ---- | ---- | ---- |
| Deepwoken | Timing melee, posture, permadeath, feint | No talent cards, factions or ocean yet; a single shared city | Validates that permadeath + skill melee retains Roblox players |
| Cursed Gear | The flick / Black Flash chain as the skill ceiling; control layout | Chain of three with a Zone state; charge economy tied to Intelligence | Gives a rhythm-based mastery moment on top of melee |

**Non-game inspirations**: wrecked neon megacity at night; heavy, readable silhouettes (brief art direction).

---

## Target Player Profile

| Attribute | Detail |
| ---- | ---- |
| **Age range** | NOT ASSESSED — not stated |
| **Gaming experience** | Mid-core to hardcore Roblox combat players (brief) |
| **Time availability** | NOT ASSESSED |
| **Platform preference** | Roblox on PC (controls are keyboard/mouse only today) |
| **Current games they play** | Deepwoken, Cursed Gear |
| **What they're looking for** | Tension of everything on the line; rush of a perfectly timed hit |
| **What would turn them away** | Unreadable combat (no windup cue), spawn-killing after Emergence, key conflicts — all named as MVP fixes in the brief |

---

## Technical Considerations

| Consideration | Assessment |
| ---- | ---- |
| **Recommended Engine** | Roblox (Luau), Rojo project (`default.project.json`); not Godot/Unity/Unreal |
| **Key Technical Challenges** | Server-authoritative timing windows under network latency; client-owned knockback/dodge physics (`Combat.lua:279-284`); ProfileService session locking |
| **Art Style** | 3D stylized, procedural placeholders (neon parts) |
| **Art Pipeline Complexity** | Low in code (procedural); custom assets are the owner's Studio work |
| **Audio Needs** | Moderate — sound slots per CombatEvent (planned, none wired today) |
| **Networking** | Roblox client-server; 23 RemoteEvents (`Remotes.lua:5-10`); no rate limits yet (brief MVP item 5) |
| **Content Volume** | 7 weapons, 9 armor pieces, 6 implants, 7 skills, 15 recipes, 4 quests, 1 NPC type, 2 event types |
| **Procedural Systems** | Prologue plots, placeholder city slab, dev arena, loot rolls, event director |

---

## Risks and Open Questions

### Design Risks
- Combat is mechanically complete but currently unreadable (no windup animation, no swing presentation) — the brief's top build-order item.
- Permadeath with spawn-killing after Emergence may churn new players before they land a Black Flash (brief MVP item 5).

### Technical Risks
- Timing windows (0.22-0.35 s) judged on the server against `os.clock()` without latency compensation; feel on real networks is NOT ASSESSED.
- No remote rate limiting; `Attack`/`Flicker` spam is bounded only by stamina/charge and cooldowns.

### Market Risks
- NOT ASSESSED — no market analysis in the repo.

### Scope Risks
- Hand-built city districts are deferred; the slice relies on a generated blockout.

### Open Questions (from `docs/DESIGN.md`)
- Prologue end condition: timer, objective or both? (Code: both — all-ready early exit after 30 s minimum, hard cap 600 s.)
- Does a dead player keep anything (a legacy perk) or is it a clean slate? (Code: clean slate; legacy record exists but is unused.)
- Should low-level players be protected for the first N minutes after Emergence?

---

## MVP Definition

**Core hypothesis**: a new player can finish the tutorial, emerge, win a fight against a telegraphed
enemy by reading its windup, land a Black Flash, and loot a supply drop before another player (brief).

**Required for MVP** (brief, in build order):
1. Combat feel — weapon models, procedural swing/windup animation, windup glow flick cue, hit sparks, hitstop, camera shake, sound slots.
2. Aiming — character faces mouse/camera while in combat.
3. Enemy v2 — R15 raider rig, PathfindingService, telegraphed attacks, Grunt / Brute / Gunner.
4. HUD v2 — labels, custom health bar, damage numbers, hit markers, Tab conflict fix, dodge feedback bug.
5. Fair arrival — spawn protection, in-bounds events, remote rate limits.
6. District blockout — generated first district + safe zone; dev arena behind `Config.Dev`.

**Explicitly NOT in MVP**: everything under Anti-Pillars.

### Scope Tiers

| Tier | Content | Features | Timeline |
| ---- | ---- | ---- | ---- |
| **MVP** | Dev arena, 1-3 enemy variants | Items 1-5 above | NOT ASSESSED |
| **Vertical Slice** | First district blockout + safe zone | Items 1-6 | NOT ASSESSED |
| **Alpha** | Hand-built districts | Status effects, more events | NOT ASSESSED |
| **Full Vision** | Multiple districts, Universe 2 | Factions, talent tree, power trees | NOT ASSESSED |

---

## Next Steps

- [ ] Confirm the `[inferred — confirm]` items with the owner.
- [ ] Use `design/gdd/systems-index.md` to pick the next GDDs (Stats & Gear, Skills, Permadeath, World Phase, Tutorial are "none yet").
- [ ] Run `/design-review` on `combat.md` before the Combat Feel epic is broken into stories.
