# Smoke test (no Roblox needed)

Runs the real server scripts against a small mocked Roblox API using the standalone Luau CLI, and walks a
player through the whole game: join -> tutorial (all steps, with real combat against the dummy) -> Emergence into
the arena -> PvP -> permadeath/loot/respawn. It fails on any script error.

    python3 tools/smoke/gen.py > /tmp/harness.lua && luau /tmp/harness.lua

Get `luau` from https://github.com/luau-lang/luau/releases. The mock is deliberately small: it catches nil
indexing, missing functions, bad requires and logic regressions, but it is NOT Roblox - always check Studio's
Output window too. ProfileService is replaced by a stub (`ps_stub.lua`).

## Other scenarios

    python3 tools/smoke/gen.py tools/smoke/stress.lua > /tmp/hs.lua && luau /tmp/hs.lua   # story 8: 20 players, 60 rounds of explosions/deaths; asserts the chunk, corpse and salvage caps
    python3 tools/smoke/gen.py tools/smoke/dumpworld.lua > /tmp/hd.lua && luau /tmp/hd.lua | sed -n '/JSON_BEGIN/,/JSON_END/p' | sed '1d;$d' > world.json
    python3 tools/smoke/map.py world.json docs/maps/conduit_map.png   # top-down map of the generated world (needs Pillow)
