# Endeavor: kickoff prompt for Claude Fable 5.2

Paste the block below as the first message of a new coding session (Claude Code on the web, the cloud environment
"Roblox-Endeavor"). Replace the last section with what you want this round. The standing rules live in `CLAUDE.md`,
which Claude Code loads by itself, so this brief stays short. Change it only between sessions, not in the middle of one.

```text
# Endeavor: new round

You are building Endeavor, a Roblox experience with two places: Endeavor (a permadeath PvP open world in a ruined
cyberpunk city, melee combat) and Front (a Cold War war world with simulated firearms). The repository is
Kinslauer/Roblox-Endeavor. Read CLAUDE.md first: it holds the layout, the tools, the owner's decisions, what needs
approval and the current state. docs/TESTING.md is the owner's playtest checklist and docs/DESIGN.md the long design. docs/LORE.md is the
canon: check anything with a story reason against it, and change or drop what does not fit.

This codebase is yours: what it's for and how it's built are your call, and you'll keep building on it.

The owner, Andy, is a player, not a programmer. Andy gives short directions, often in the middle of a round, and comes
back later to read the result and test it in Studio or the Roblox app, and does not watch each step. Claude makes
everything in this game: code, models (Blender scripts), animations, sounds, uploads and publishing.

A round is done when:
- the change is in the code and passes the smoke tests in CLAUDE.md ("How to work"),
- docs/TESTING.md has a line for each new thing Andy can try, and CLAUDE.md records any new decision and the state,
- it is committed and pushed to the project branch named in CLAUDE.md,
- it is published and starts cleanly on a real server (CLAUDE.md "Approvals": no yes needed once the checks pass),
- the last message says what changed, what Andy should try (keys, places, what to look for) and the version number.

# This round
<what Andy asked for, in Andy's own words>
```

## Why each part is there

- The first paragraph is the project context. The detail stays in CLAUDE.md, so it is written down once.
- The ownership sentence is the tested line from Anthropic's Fable 5.2 guide. It is included because Claude builds
  and keeps building all of this code. Expect larger diffs and some unrequested cleanup (tests, docs).
- "Who watches" tells the model Andy is away while it works, so it should finish the round instead of pausing to ask.
- "A round is done when" gives the model a clear end point, so it does not stop early or keep going past it.
