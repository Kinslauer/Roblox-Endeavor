# Fable 5.2 setup for Endeavor: change log, settings, test plan

Made with the repo skill `.claude/skills/fable-prompt` (based on Anthropic's "Prompting Claude Fable 5.2" guide),
2026-11-10. The prompt has two parts: `CLAUDE.md` (standing rules, loaded by Claude Code in every session) and
`docs/prompts/fable-5.2-kickoff.md` (the first message of a new session).

## What was added, and why

| Module | In? | Why |
|---|---|---|
| Project context | Yes | Already in CLAUDE.md. The kickoff points at it instead of repeating it. |
| Ownership sentence | Yes | Claude builds and keeps building all of this code. Expect bigger diffs and some unasked cleanup. |
| Finishing work | Yes | Andy gives a direction and leaves, so a round that pauses to ask is a stalled round. |
| Approvals | Yes | New section. Names what needs Andy's yes (publishing, profile wipes, deleting assets or versions, Robux, Dashboard settings, the release switch) and what needs none (tests, builds, real-server checks, asset uploads, pushes, safe retries). |
| Progress updates | No | Andy does not watch each step. The Claude app's project threads already show a progress checklist. |
| Communicating clearly | Yes | Andy reads every result. Added one Endeavor line: describe what to try in the game, give the version, ask for F9 screenshots. |
| Subagents | No | Nothing in the project asks for more or less delegation, so no line is needed. |

## What carried over, and what changed

- "Never write the key to a file" became a rule with its scope and reason (files, logs and commits; the repository
  is on GitHub and the key can publish).
- The one-branch rule now says why (Andy publishes from that branch) and to rebase before pushing, because more than
  one session pushes to it.
- Nothing else needed removing: CLAUDE.md has no token budget, no "delegate more", no "think less", no request to
  write reasoning out, and no hard style rule.
- The stale memory line "ask for the API key each session" was corrected in the project memory: the key is now a
  secret on the "Roblox-Endeavor" cloud environment.
- Publishing needs Andy's yes for now. If Andy decides rounds may publish without asking, change that one line in
  CLAUDE.md "Approvals".
- Not done yet, worth doing: CLAUDE.md is about 370 lines, most of it per-system notes under "State" and "Decisions".
  Fable follows every line, so a later round could move the per-system notes to `docs/SYSTEMS.md` and keep CLAUDE.md
  to the decisions, approvals and current state. It was left alone this round because another session is editing
  CLAUDE.md for blocking at the same time.

## Settings

Claude Code on the web (the way Endeavor is built): choose Fable 5.2 as the model and effort **high** for build rounds.
Use **medium** for quick questions. Try **xhigh** only on a round that went wrong at high.

If the prompt is ever run through the Claude API directly: `output_config.effort: "high"`; leave `thinking` out or
send `{type: "adaptive"}` (`disabled` and `budget_tokens` return an error); no assistant prefill; `tool_choice`
`auto`; handle `stop_reason: "refusal"` and turn on server-side fallbacks (`fallbacks: "default"`). Keep the history
append-only: editing an earlier turn or the system prompt of a stored conversation returns an error.

## Test plan

Change one thing at a time, and note what changed and what it cost.

1. Run one normal round (for example the next playtest fix) at effort high with this CLAUDE.md and the kickoff.
2. Run the same kind of round at medium, then at xhigh, and compare.
3. Watch for: stopping before the round is committed and written up, asking for a yes that the Approvals list does
   not need, adding code where merging or restructuring was the better fix, and replies that use code names instead
   of what to try in the game.
4. Fix only what you saw, one line at a time, in a new session.

Change CLAUDE.md or the kickoff only between sessions. In the middle of a session, give new directions as a new message.
