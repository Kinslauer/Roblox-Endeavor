# Epic: The places split — hideout, Conduit world, war world (Phase 3, build order 7)

> **Status**: Story 001 implemented (the door); 002–004 need published places · **Layer**: Infrastructure · **Rigor**: standard
> **Brief**: `design/phase-3-brief.md` item 7

## Overview
Everything lives in one place today. The split makes the hideout a private reserved server, the Conduit world its
own place (regions grow there) and the war its own place (the sight picture, first person, the hill). The profile is
already account-shaped (PERSIST fields, Location) so the only moving part is the door: `server/Travel.lua`.

## Stories
| # | Story | Type | Status |
|---|---|---|---|
| 001 | `server/Travel.lua` + `Config.Places`: `Travel.To(player, placeKey, location)` is a no-op while `Enabled = false` or the id is 0 (every trip stays a pivot); with ids set it writes `Location`, releases the ProfileService session and `TeleportAsync`es (reserved server for the hideout). `Hideout.Enter / Leave` and `War.Deploy` ask it first; `Lifecycle.Spawn` deploys an arrival whose `Location == "War"` | Logic | Implemented — smoke: off = false, on = true + Location; live: the pivot path unchanged (enter / deploy / leave / leave) |
| 002 | Publish three places under one experience; put their ids in `Config.Places.Ids`; `Enabled = true` | Ops | Needs the owner (publishing) |
| 003 | Per-place `Main.server.lua` guards: build only what the place needs (`Travel.Here()`): the hideout place skips districts / regions / war; the war place skips districts / hideout; the Conduit place skips the war | Logic | Pending 002 |
| 004 | Shared DataStore keys across places (ProfileService store name is already shared); test a round trip hideout → war → hideout with money and stash intact | QA | Pending 002 |

## Acceptance criteria
1. With places off, nothing changes (today's smoke and live checks hold).
2. With ids set, Deploy / Extract / Return teleport with the profile released and `Location` set, and the far place wakes you in the right spot (hideout, base, city).
3. Money, stash, faction, hubs, contacts, board and house survive the round trip.

## Follow-ups
- Reserved-server hideouts shared with friends (an invite = teleport to the same reserved server).
