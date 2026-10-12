# Smoke test (no Roblox needed)

Runs the real server scripts against a small mocked Roblox API using the standalone Luau CLI, and walks a
player through the whole game: join -> tutorial (all steps, with real combat against the dummy) -> Emergence into
the arena -> PvP -> permadeath/loot/respawn. It fails on any script error.

    python3 tools/smoke/gen.py > /tmp/harness.lua && luau /tmp/harness.lua

Get `luau` from https://github.com/luau-lang/luau/releases. The mock is deliberately small: it catches nil
indexing, missing functions, bad requires and logic regressions, but it is NOT Roblox - always check Studio's
Output window too. ProfileService is replaced by a stub (`ps_stub.lua`).
