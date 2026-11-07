# The sound tools

Everything the game plays is written from code twice over: once in GDScript, for the game
(`view/audio/synth.gd`, `kit.gd`, `sound_bank.gd`), and once in JavaScript, here, for the
review pages, the score and the DAW. `synth.js` is the JavaScript engine: the same voices as
the game's synth, the kit, every version of every sound the review rounds offered, and the
score engine with the eight pieces' specs. `picks.mjs` says which version of each sound is
the game's.

Nothing here runs in the game. The game bakes its sounds from `sound_bank.gd` at boot and
plays the music from the Ogg strips in `audio/music`, which these tools write.
The bank is written at 44.1 kHz (`GAME_RATE`), the score at 24 kHz (`MUSIC_RATE`), both in
`picks.mjs`.

## The score

```
node tools/sound/bake_music.mjs [id ...]      bake the pieces in content/score.json to
                                              audio/music/<id>/{bed,deep,fight,warden}.ogg
                                              (all of them, and retire any others, with no id)
```

A piece in `content/score.json` names the spec it is written from (`from`); the rest of its
fields are what `view/audio/composer.gd` would write it from if a strip were missing. After
a bake, import the project once (open it in the editor, or `godot --headless --import`) so
Godot knows the new files; `tests/test_audio.gd` checks every strip is there and the length
of the piece.

## The bank

```
node tools/sound/parity.mjs <out> [<godot dump>]   render the JavaScript bank at the game's
                                                   rate; with a dump from
                                                   build/sound_dump.gd, compare the two
```

The two banks are kept recipe for recipe. A sound changed in one is changed in the other,
and parity says when they drift: loudness within 3 dB, length and brightness within 1.6 to 1.

## The DAW round trip (FL Studio or any other)

```
node tools/sound/stems.mjs <id> [<out>]       the piece as its four strips, a stem per
                                              instrument and a MIDI file (one track an
                                              instrument), at 44.1 kHz, in build/daw/<id>/
node tools/sound/stems.mjs --bank [<out>]     every sound in the bank as WAV at 44.1 kHz
node tools/sound/soundfont.mjs [<out.sf2>]    the score's voices and drums as a SoundFont
                                              (build/daw/deep_cut.sf2), so the MIDI plays
                                              with the game's instruments in the DAW
node tools/sound/import.mjs music <id> <strip> <file>   a bounced strip back into the game
node tools/sound/import.mjs music <id> <dir>            every strip found in a folder
node tools/sound/import.mjs sound <name> <file>         a hand-made sound in place of a recipe
```

A bounced strip is written to `audio/music/<id>/<strip>.ogg` at its own rate and channels,
cut or padded to exactly the piece's length so it loops with the other three, and noted in
`render.json` as replaced by hand; a later `bake_music.mjs` writes over it. A hand-made sound
goes to `audio/sfx/<name>.ogg`, which `DeepSoundBank` plays instead of the recipe. Either
way, import the project once afterwards.

The stems add back up to the strips (the strips are also lowpassed and lightly saturated as a
whole, which the stems are not). Drums are on channel 10 in the MIDI, on General MIDI notes,
so a DAW's own kit answers them until the SoundFont's drum preset (bank 128) is chosen.
