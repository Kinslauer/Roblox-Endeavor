# Sounds (synthesized -> Roblox Audio assets)

Every effect is generated from noise, tones and envelopes in `synth.py` (numpy + ffmpeg, no samples), so there
is nothing to license. `upload.py` sends the .ogg files through the Open Cloud Assets API as Audio assets
(key needs Assets: Write; audio uploads count against the creator's monthly audio quota).

    python3 tools/sounds/synth.py                                   # -> tools/sounds/out/*.ogg
    ROBLOX_API_KEY=... python3 tools/sounds/upload.py name out/name.ogg [...]   # prints "name assetId"

Ids live in `src/shared/Sounds.lua` (`Sounds.Ids`, with per-sound volume/range/pitch-jitter defaults) and the
clients call `Sounds.Play(name, partOrPosition, opts)` from their existing event handlers: Endeavor's
CombatEvent (swings, hits, parries, guard breaks, Black Flash, flicker, devour) and World (breaks, breaches,
catches, explosions); the Front's Weapon (shots near/far, dry clicks, impacts), World (dig, explosion,
artillery whistle) and the rack key. Audio uploaded this way is private to the creator and plays only in
their own experiences, which is what we want.
