---
name: fable-prompt
description: Write or review a system prompt, kickoff brief or project memory file (CLAUDE.md) for Claude Fable 5.2 / Claude Mythos 5.2 running a big, long-horizon project (a game, an app, a codebase it builds over many sessions). Use when asked to "write a prompt for Fable", "set up Fable for this project", "make a kickoff prompt", "tune my system prompt for Fable 5.2", or when carrying a prompt, skills or agent files over from Fable 5.1 / Opus 5.5. Built from Anthropic's "Prompting Claude Fable 5.2" guide (platform.claude.com, prompt-engineering/prompting-claude-fable-5-2).
---

# Fable 5.2 prompts for big projects

Fable 5.2 follows what a prompt says closely: who owns the code, which steps need approval, every "never" rule,
every style rule. Most problems on long projects come from what the prompt says (or leaves out), not from the
model's ability. This skill builds a prompt from tested modules, cleans out instructions written for older models,
and sets the API options that go with it.

Source: Anthropic's guide "Prompting Claude Fable 5.2". Quoted blocks below are that guide's tested text. Adapt the
wording to the project, but keep the distinctions each block makes (they are what was tested).

## Step 1: find out about the project

Get these answers before you write anything. Read them from the repository (README, CLAUDE.md, docs) where you can.
Ask the user only for what you can't find.

1. **The project in a few lines.** What it is, who it is for, where it runs, what "done" looks like for a round of work.
2. **Who owns the code.** Is this the model's own codebase to shape (it builds and keeps building it), or the user's
   code to change as little as possible?
3. **Who watches.** Does a person watch each step live (interactive coding), or come back for the result (long
   unattended or asynchronous runs)?
4. **What needs a human yes.** The exact actions: publishing, deploying, deleting, spending money, messaging people,
   force-pushing. Also what explicitly needs NO yes (safe retries, running tests, local builds).
5. **Hard blockers.** Files not to touch, credentials that are withheld on purpose, guardrails.
6. **The harness.** Claude Code, the Claude API with your own loop, or Managed Agents? Can it append mid-conversation
   system messages? Does it render `thinking` blocks? Does it start subagents, and on which model?
7. **What it carries over.** Existing system prompt, skills, agent files, memory files, notes, CLAUDE.md. You will
   audit all of these in Step 3.
8. **Who reads the output.** Final reports, handoffs, PR descriptions: written for whom?

## Step 2: assemble the prompt from modules

Write the prompt in this order. Include a module only when its condition holds.

### 2a. Project context (always)

Short, factual, current state. What the project is, the layout, how to build and test, how to check work, the
decisions already made (as decisions, with the date and who made them, so they are not reopened). For a big project,
the long-lived home for this is a project memory file (CLAUDE.md); the kickoff prompt then points at it.

Write every rule with its scope and its reason ("Publish only from the main branch, because the live game reads it"),
not as a bare absolute ("NEVER publish"). Fable 5.2 obeys absolutes even past the point where they make sense.

### 2b. Ownership (when the model owns the code)

Include this when the model should improve the structure as it works (merge repeated code, fix nearby problems):

```text
This codebase is yours: what it's for and how it's built are your call, and you'll keep building on it.
```

Leave it out when the user owns the code and wants minimal changes. A "no drive-by refactors" rule elsewhere does NOT
cancel this sentence, so don't include both. With it, expect about 1.5x the output tokens and some unrequested
changes (tests, docs, occasionally changed behaviour): tell the user to review the diff, not only the summary.

### 2c. Finish the whole task (agentic work, especially at `low` / `medium` effort)

```text
# Finishing work
Please avoid stopping while you still owe work the user asked for. Be persistent and do not stop unless needed.

While status notes are welcome, as is clarifying with the user on open decisions, carry on with work that does not depend on the user's answer without unnecessary stops.

If you notice yourself inviting the user to redirect you or offering to wait, instead proceed on the next part of the task. You may meet ordinary obstacles like errors, timeouts, locked files, empty results or failing tools. Diagnose them first, and when they are not real blockers, work through them with the access you have (wait and retry, fix the request, use another tool or source) rather than stopping unnecessarily.

If someone clearly decided something is a hard blocker, such as a file marked not to be touched, access that was intentionally withheld, or a safety guardrail, leave it alone, say plainly what you found, and look for another safe way to finish the task. Stopping before the task is complete is very rarely merited, as in when the task can't move forward without user input, or where the blocker is deliberate and should not be worked past. This does not override the need for confirmation on risky or destructive actions.
```

Keep the split between ordinary obstacles (work through them) and deliberate blockers (leave them, report them).
It costs about 30% more output tokens. Because the model asks less often with it, keep your own confirmation step
for risky or irreversible actions.

### 2d. Approvals (always, when anything needs a human yes)

- Name the exact actions that need approval. The model applies the list as written: a rule that listed "sending
  messages to people outside this conversation" made it hold back about half of its routine requests to colleagues.
- Name the steps that need NO approval (for example: "Retrying a call that is safe to repeat, running the test
  suite and building locally need no approval."). A general "act more freely" line changed nothing in testing; a
  named list did.
- Write the exception into the rule itself: "Publish only after the user says yes to that publish." works; a
  separate "approved steps have their go-ahead" line does not.
- Tell the user: when approving, say what is approved ("Yes, publish Endeavor"), not a bare "go" or "continue".

### 2e. Progress updates (when a person watches live)

First check the client shows them: on Fable 5.2 the notes between tool calls arrive as `thinking` blocks, empty at
the default `display: "omitted"`. Set `thinking.display` to `"updates"` (beta `thinking-display-updates-2026-08-18`)
or `"summarized"`, and render non-empty thinking blocks.

Then add, where a human is in the loop:

```text
Before you start, say in a line what you're about to do; brief updates while you work help the user follow along. Close with a short recap that stands on its own (what you found, what you did, and what's next), so a reader who only sees the last message has the full picture.
```

If the harness can append turn-scoped system messages, the strongest option is a harness counter: after several
tool-calling steps in a row with nothing for the user to read, append this as a system message with
`clear_at: "next_user_message"` (beta `mid-conversation-system-clear-at-2026-08-21`), and never delete or reword
earlier copies:

```text
The user hasn't heard from you in a while: say in a few words what you're doing, then continue.
```

If the harness can't do that, use the one-liner instead:

```text
Every few tool calls, give the user a one-line update on where things stand.
```

Skip this module for unattended or asynchronous runs, where gaps between updates don't matter.

### 2f. Reports and handoffs (when people read the final output)

```text
# Communicating clearly
Write for an intelligent but low-context reader. The person reading has not seen your tool calls, your reasoning or the files you opened, and may be switching in from other work. Messages should generally be self-contained: the reader should understand what you mean without having to dig for other context. Put the key points in the first few sentences. Practice progressive disclosure in your sentence order, and do not use undefined references and ideas in line 1 that won't make sense until the reader reaches line 12.

Use plain words, and write in clear, understandable full sentences. Do not use a term or abbreviation that you made up during the work. Say what the thing is in a way any reader would understand. Write mostly in the style of ASD-STE100 Simplified Technical English: short sentences, one idea per sentence, active voice, and consistently using the same word for the same thing. Use a paragraph of flowing prose where ideas connect, and keep bullets for lists of separate items. Leave out unnecessary details unless the reader asks and practice concision, but do ensure that your messages have the key context. Aim to make your user-facing text as human-readable and clear as possible.
```

Remove older hard style rules first (for example "one instruction per sentence, 20 words or fewer"): Fable 5.2
follows them closely and the prose turns choppy. Add length limits or required details for your readers.

### 2g. Subagents (only when the harness starts them)

Don't add "delegate more" lines. If the model starts more subagents than the work needs, rewrite the description of
the tool that starts them, in this order: (1) what a subagent adds to the cost of a session, (2) when delegation is
worth it and when it isn't, (3) how to brief a subagent. More cost text means less delegation; tune from there.
Check which model subagents run on by default. Fable 5.2 is a good planner/orchestrator for cheaper worker models.

## Step 3: audit everything carried over

Read the existing system prompt, skills, agent files, memory files, notes and CLAUDE.md. For each item below,
remove it or test it, and list what you changed and why:

- **Standing instructions to delegate.** Remove the ones the work doesn't need.
- **A token budget written into the prompt** ("you have N tokens left"). Removing a large one lowered cost at equal
  quality in testing. (This is not the API's `task_budget`, which wasn't tested.)
- **"Treat that answer as done" lines** (from the Opus 5.5 chat guidance). They make the model far less likely to
  point out its own earlier mistakes. Leave them out where re-checking matters.
- **"Think less" / "answer without deliberating" lines.** They don't work on Fable 5.2 at `medium` and above. Delete
  them and lower `effort` instead.
- **Instructions to write reasoning in the response.** Remove them: they can trigger the `reasoning_extraction`
  refusal. To read reasoning, set `display: "summarized"`.
- **Hard style rules.** Remove the ones you no longer need (see 2f).
- **Built-up cautions in memory, notes and rules** (some the model wrote itself). Delete those whose reason no longer
  holds; rewrite absolute rules with scope and reason. One "never retry" note among a dozen cut safe retries from
  nearly always to four in ten. Check what reviewer agents attach ("stop at the first error"). If a system is already
  stuck, restart it with trimmed memory and keep a copy of the originals.
- **Harness code that edits earlier turns.** On Fable 5.2 the prefix check is enforced for every account: changing
  `system`, `tools` or an earlier message invalidates later thinking blocks and returns a 400. Keep history
  append-only; shorten it only with context editing or compaction that keeps no earlier turns after the summary.

## Step 4: set the API options (or tell the user what to set)

- `output_config.effort`: start at `high` explicitly. Run the evals at `medium` and `xhigh` too. `low` for quick
  back-and-forth and subagents, `medium` for interactive coding and chat, `high` for hard coding and long unattended
  runs, `xhigh` only where a gain is measured, `max` only for ceiling tests. Effort barely changes reply length: set
  length in the prompt. Mix levels across a workflow (plan at `medium`, run the long part at `high`); use the
  per-message effort change (beta `mid-conversation-output-config-2026-07-01`) to keep the cache.
- Omit `thinking` (or send `{type: "adaptive"}`); `disabled` and `budget_tokens` return 400.
- `thinking.display`: `"updates"` or `"summarized"` where a person watches (2e).
- Handle `stop_reason: "refusal"` and enable server-side fallbacks (`fallbacks: "default"`, beta
  `server-side-fallback-2026-07-01`). Benign security or life-science work can trip `cyber` / `bio`; Anthropic's
  verification programs exist for that.
- No assistant prefill; forced `tool_choice` `any`/`tool` returns 400 (use `auto` + `strict: true`).

## Step 5: rules for changing a prompt later

Make prompt, tool or rule changes in **new conversations only**. Mid-conversation, put new instructions in the newest
turn, or append a mid-conversation system message. Editing the system prompt of a stored conversation and resuming
it can fail with a 400 (prefix check).

## Step 6: hand over a test plan

Give the user this order, one change at a time, measuring effect and token cost:

1. Effort `high` explicitly; also run `medium` and `xhigh`.
2. Audit carried-over instructions (Step 3).
3. Run the longest agentic tasks. Watch for: early stops, unneeded approval requests, silence, too many subagents,
   adding to code where restructuring was wanted.
4. Apply the module for each behaviour seen (2b to 2g), one at a time, and measure.

## Output

Deliver:
1. The prompt (or CLAUDE.md), as a file, with each module in its own titled section.
2. A short change log: modules included or left out and why, carried-over lines removed or rewritten and why.
3. The API settings to use (Step 4).
4. The test plan (Step 6).

Keep the prompt as short as the project allows. Every line is followed closely; a line with no current reason is a
line that can hold the model back.

## Worked skeleton for a big build project

```text
# <Project>: project memory
Read this first in every session. It is the short, current state of the project.

## What this is
<2-5 lines: product, platform, players/users, what a round of work delivers>

This codebase is yours: what it's for and how it's built are your call, and you'll keep building on it.

## Layout and tools
<directories; build, test and check commands; where tools live; how to verify on the real target>

## Decisions the owner made (do not reopen)
- <decision> (owner, <date>): <one line on what and why>

## Approvals
Publishing to <target>, deleting <data>, and spending money need the owner's yes to that specific action.
Running tests, local builds, retrying a call that is safe to repeat, and committing to <branch> need no approval.
<hard blockers: files not to touch, withheld credentials>

# Finishing work
<2c block>

<2e block if the owner watches live>

# Communicating clearly
<2f block>

## State
<what exists now, what is verified, what is unverified>

## Open items
<what is next, what waits on the owner>
```
