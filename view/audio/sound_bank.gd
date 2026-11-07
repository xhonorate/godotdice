class_name DeepSoundBank
extends RefCounted
## Every sound in the game, written as a recipe.
##
## One name, one short list of gestures from the kit (`kit.gd`), one stream. The bank bakes a
## sound the first time it is asked for and keeps it, so a fight never pays for the same crack
## twice.
##
## The palette is the one the owner settled over six rounds of review (November 2026, the
## "Modular Vein, warmed" profile): the interface is pings on felt, in key, never a beep; dice
## are toks; gems ring as pings on a chord of their own (Red, Gold and Blue on D and A at three
## heights, Green on G, White on E) and a Violet gem gurgles, because it poisons; the count is
## one instrument on C, which the mixer walks up the music's key; a blow is a gem on stone (a
## crack, debris, weight), never a drum; the big moments (a grade, a Star, the altar) are
## chords on a warm pad with glitter over them. Nothing in the bank has a square wave but the
## one refusal, and nothing slides down in pitch, which is what an error beep does.
##
## The same recipes, in JavaScript, are what the review pages played and what the soundtrack
## tools render (`tools/sound/`); `tools/sound/parity.mjs` checks the two banks still agree.

## Concert pitch for everything tuned. Notes are written as semitone steps off a root so the
## fanfares stay in one key with each other.
const A4: float = 440.0
const C5: float = 523.25
const C6: float = 1046.5

## Which gem color rings as what. The name is the sound; the hue is only how it is drawn.
const GEM_SOUNDS: Dictionary = {"RED": "gem_red", "BLUE": "gem_blue", "GREEN": "gem_green",
	"VIOLET": "gem_violet", "GOLD": "gem_gold", "WHITE": "gem_white"}
const GRADE_SOUNDS: Dictionary = {"ROUGH": "grade_rough", "FINE": "grade_fine", "PRECIOUS": "grade_precious",
	"EXQUISITE": "grade_exquisite", "PEERLESS": "grade_peerless"}
## A creature's blow, by the way its move is animated (content `anim`); a move animated some
## other way (a cast, a rally, a song) lands as the plain strike.
const BLOW_SOUNDS: Dictionary = {"slam": "hit_slam", "bite": "hit_bite", "claw": "hit_claw", "breath": "hit_breath",
	"spit": "hit_spit", "lash": "hit_lash", "peck": "hit_peck", "drill": "hit_drill", "erupt": "hit_erupt",
	"burst": "hit_burst", "pull": "hit_pull", "drink": "hit_drink"}

const NAMES: PackedStringArray = [
	"ui_tap", "ui_hover", "ui_confirm", "ui_back", "ui_toggle", "ui_tab", "ui_open", "ui_close",
	"ui_deny", "toast", "toast_bad", "unlock",
	"die_tumble", "die_settle", "die_pick", "die_drop", "dice_lock", "dice_reroll",
	"battle_begin", "turn_begin", "resolve", "gem_red", "gem_blue", "gem_green", "gem_violet",
	"gem_gold", "gem_white", "gem_fizzle", "tally_tick", "tally_mult", "tally_fuse", "tally_blaze", "flawless_glint",
	"tick_red", "tick_blue", "tick_green", "tick_violet", "tick_gold", "tick_white", "resonance", "harmony", "hit_light", "hit_heavy",
	"hit_crit", "block", "block_break", "heal", "poison", "stun", "curse", "enemy_windup",
	"enemy_strike", "hit_slam", "hit_bite", "hit_claw", "hit_breath", "hit_spit", "hit_lash", "hit_peck", "hit_drill",
	"hit_erupt", "hit_burst", "hit_pull", "hit_drink",
	"creature_die", "warden_die", "victory", "defeat", "cave_rumble", "ore",
	"pick_strike", "rock_break", "stone_found", "tunnel", "landing", "lift", "depart", "lantern", "oddity",
	"buy", "salvage_save", "salvage_lose", "depth_card", "footstep", "rockfall", "crumble",
	"loupe_spin", "reveal", "grade_rough", "grade_fine", "grade_precious", "grade_exquisite",
	"grade_peerless", "star", "keep", "sell", "chisel", "gleam", "tally", "die_break",
	"altar_hum", "altar_fizzle", "altar_make", "transcendent", "hollow_drop", "hollow_rise",
	"reel_lever", "reel_tick", "reel_stop", "geode_crack", "jackpot", "contract_seal", "gem_shatter", "infinity",
	"flame", "splash", "mirror", "claw", "hammer_strike"]

## A sound replaced by hand (a master bounced from a DAW and brought in with
## `node tools/sound/import.mjs sound <name> <file>`) sits here, and is played instead of the
## recipe. The project has to be imported once for Godot to know a new file.
const OVERRIDES: String = "res://audio/sfx/%s.ogg"

static var _cache: Dictionary = {}
## The bank is baked on a worker thread while the game is played, and asked for sounds from
## the main one at the same time; only the shelf needs guarding, not the baking.
static var _shelf: Mutex = Mutex.new()

static func gem_sound(color: String) -> String:
	return str(GEM_SOUNDS.get(color.to_upper(), "gem_white"))

static func tick_sound(color: String) -> String:
	## A gem's count ticks in its own color's voice: grit for red, glass for blue, wood for
	## green, two bells beating for violet, struck metal for gold, glass with a glint for white.
	var name: String = "tick_" + color.to_lower()
	return name if NAMES.has(name) else "tally_tick"

static func grade_sound(tier: String) -> String:
	return str(GRADE_SOUNDS.get(tier.to_upper(), "grade_rough"))

static func blow_sound(anim: String) -> String:
	return str(BLOW_SOUNDS.get(anim.to_lower(), "enemy_strike"))

static func known(name: String) -> bool:
	return NAMES.has(name)

static func baked(name: String) -> bool:
	_shelf.lock()
	var have: bool = _cache.has(name)
	_shelf.unlock()
	return have

static func stream(name: String) -> AudioStream:
	## The sound, baked on the first ask and kept for the rest of the session (or read off the
	## disk, if a hand-made one sits in `OVERRIDES`). Two callers racing for the same one both
	## bake it and agree on the answer, which costs less than holding the shelf shut for the
	## length of a bake.
	_shelf.lock()
	var shelved: Variant = _cache.get(name, null)
	var known_missing: bool = _cache.has(name)
	_shelf.unlock()
	if shelved != null or known_missing:
		return shelved
	var made: AudioStream = hand_made(name)
	if made == null:
		made = _bake(name)
	_shelf.lock()
	_cache[name] = made
	_shelf.unlock()
	return made

static func hand_made(name: String) -> AudioStream:
	## The sound as a file replaced it, if one has; null for a sound the bank bakes.
	if not NAMES.has(name):
		return null
	var at: String = OVERRIDES % name
	if not ResourceLoader.exists(at):
		return null
	var loaded: AudioStream = load(at)
	if loaded is AudioStreamOggVorbis:
		loaded.loop = false
	return loaded

static func forget() -> void:
	_shelf.lock()
	_cache.clear()
	_shelf.unlock()

# --- the recipes -------------------------------------------------------------------------------

static func _bake(name: String) -> AudioStreamWAV:
	var s: DeepSynth
	match name:
		# --- the interface: pings on felt, in key --------------------------------------------
		"ui_tap":
			s = DeepSynth.new(0.45, 1)
			DeepKit.felt(s, 0.0, 220.0, 0.16)
			DeepKit.ping(s, 0.0, 880.0, 18.0, 0.42, 0.025)
			return DeepKit.fin(s, 0.5)
		"ui_hover":
			s = DeepSynth.new(0.25, 2)
			s.ping(0.0, 1760.0, 9.0, 0.2, 0.0)
			return DeepKit.fin(s, 0.17)
		"ui_confirm":
			## One ping, then two soft echoes up the chord; nothing falls after it.
			s = DeepSynth.new(0.9, 2002)
			DeepKit.felt(s, 0.0, 210.0, 0.18)
			DeepKit.ping(s, 0.0, 783.99, 36.0, 0.4, 0.02)
			s.ping(0.08, 987.8, 30.0, 0.14, 0.0)
			s.ping(0.13, 1174.7, 30.0, 0.14, 0.0)
			return DeepKit.fin(s, 0.56)
		"ui_back":
			s = DeepSynth.new(0.5, 2003)
			DeepKit.felt(s, 0.0, 180.0, 0.3)
			DeepKit.ping(s, 0.0, 440.0, 14.0, 0.36, 0.015)
			return DeepKit.fin(s, 0.46)
		"ui_toggle":
			s = DeepSynth.new(0.3, 6006)
			DeepKit.tok(s, 0.0, 0.3, 900.0)
			DeepKit.ping(s, 0.004, 1568.0, 10.0, 0.26, 0.02)
			return DeepKit.fin(s, 0.5)
		"ui_tab":
			s = DeepSynth.new(0.3, 6005)
			DeepKit.felt(s, 0.0, 240.0, 0.3)
			DeepKit.ping(s, 0.0, 784.0, 9.0, 0.22, 0.01)
			return DeepKit.fin(s, 0.36)
		"ui_open":
			s = DeepSynth.new(0.7, 2005)
			DeepKit.felt(s, 0.0, 230.0, 0.2)
			s.noise(0.0, 0.09, 0.1, 500.0, 2400.0, 2.2, 0.03, 300.0)
			DeepKit.ping(s, 0.05, 1046.5, 22.0, 0.34, 0.015)
			return DeepKit.fin(s, 0.5)
		"ui_close":
			## Two toks falling, a fifth above the die's, the lid heavier under them.
			s = DeepSynth.new(0.5, 6001)
			DeepKit.tok(s, 0.0, 0.26, 1050.0)
			DeepKit.tok(s, 0.045, 0.28, 780.0)
			DeepKit.felt(s, 0.05, 140.0, 0.36)
			return DeepKit.fin(s, 0.5)
		"ui_deny":
			## The one square wave in the bank: a refusal, kept well under everything else.
			s = DeepSynth.new(0.5, 6011)
			for at in [0.0, 0.11]:
				s.analog(at, 0.09, 180.0, {"amp": 0.45, "shape": "square", "cutoff": 600.0, "env": 900.0, "res": 0.3, "decay": 0.08, "release": 0.05})
			DeepKit.felt(s, 0.11, 130.0, 0.3)
			s.lowpass(3000.0)
			return DeepKit.fin(s, 0.2)
		"toast":
			s = DeepSynth.new(0.8, 10)
			DeepKit.ping(s, 0.0, C6, 40.0, 0.34, 0.02)
			DeepKit.ping(s, 0.06, C6 * 1.5, 40.0, 0.26, 0.02)
			return DeepKit.fin(s, 0.5)
		"toast_bad":
			s = DeepSynth.new(0.7, 2009)
			DeepKit.felt(s, 0.0, 120.0, 0.5)
			s.ping(0.01, 330.0, 12.0, 0.3, 0.0)
			s.lowpass(1600.0)
			return DeepKit.fin(s, 0.5)
		"unlock":
			s = DeepSynth.new(1.2, 2011)
			DeepKit.felt(s, 0.0, 200.0, 0.2)
			DeepKit.ladder(s, 0.0, 587.3, [0, 7, 12], 0.09, 50.0, 0.32)
			DeepKit.sparkle(s, 0.25, 0.4, 0.06, 6, 2000.0, 4800.0)
			return DeepKit.fin(s, 0.6)
		# --- dice: hard little solids on felt ------------------------------------------------
		"die_tumble":
			s = DeepSynth.new(0.5, 13)
			for i in range(5):
				var t: float = float(i) * 0.06 + s.rng.randf() * 0.02
				DeepKit.tok(s, t, 0.26 * s.rng.randf_range(0.6, 1.0), s.rng.randf_range(520.0, 760.0))
				DeepKit.felt(s, t, 230.0, 0.12)
			return DeepKit.fin(s, 0.46)
		"die_settle":
			s = DeepSynth.new(0.25, 14)
			DeepKit.tok(s, 0.0, 0.36, 620.0)
			DeepKit.felt(s, 0.0, 230.0, 0.3)
			s.ping(0.0, 480.0, 8.0, 0.12, 0.0)
			return DeepKit.fin(s, 0.5)
		"die_pick":
			s = DeepSynth.new(0.2, 6007)
			DeepKit.tok(s, 0.0, 0.24, 900.0)
			s.ping(0.0, 1046.5, 10.0, 0.16, 0.0)
			return DeepKit.fin(s, 0.42)
		"die_drop":
			s = DeepSynth.new(0.2, 16)
			DeepKit.tok(s, 0.0, 0.24, 700.0)
			DeepKit.felt(s, 0.0, 240.0, 0.2)
			return DeepKit.fin(s, 0.38)
		"dice_lock":
			s = DeepSynth.new(0.4, 2014)
			DeepKit.tok(s, 0.0, 0.36, 620.0)
			DeepKit.tok(s, 0.03, 0.3, 420.0)
			DeepKit.felt(s, 0.03, 150.0, 0.3)
			return DeepKit.fin(s, 0.6)
		"dice_reroll":
			s = DeepSynth.new(0.8, 18)
			s.whoosh(0.0, 0.18, 0.12, 600.0, 1800.0)
			for i in range(11):
				var t: float = 0.04 + float(i) * 0.038 + s.rng.randf() * 0.02
				DeepKit.tok(s, t, 0.3 * s.rng.randf_range(0.5, 1.0), s.rng.randf_range(500.0, 800.0))
			return DeepKit.fin(s, 0.62)
		"die_break":
			## A dull crack, debris, four low rings; lowpassed twice.
			s = DeepSynth.new(0.8, 2015)
			DeepKit.crack(s, 0.0, 0.4, 900.0, 0.05)
			DeepKit.crunch(s, 0.02, 0.3, 7, 0.2, 2800.0, 600.0)
			for _i in range(4):
				s.ping(0.02 + s.rng.randf() * 0.2, s.rng.randf_range(900.0, 1800.0), 14.0, 0.1, 0.0)
			DeepKit.felt(s, 0.0, 160.0, 0.4)
			s.lowpass(4500.0, 2)
			return DeepKit.fin(s, 0.6)
		# --- the fight's frame ------------------------------------------------------------------
		"battle_begin":
			s = DeepSynth.new(1.8, 6009)
			DeepKit.riser(s, 0.0, 1.2, 0.34, 65.4)
			s.rumble(0.0, 1.3, 0.3)
			DeepKit.lay(s, DeepKit.kick({"hz": 140.0, "to": 40.0, "dur": 0.6}), 1.2)
			s.analog(1.2, 0.3, 65.4, {"amp": 0.4, "shape": "saw", "cutoff": 120.0, "env": 400.0, "res": 0.2, "decay": 0.3, "release": 0.2, "drive": 1.2})
			return DeepKit.fin(s, 0.55)
		"turn_begin":
			s = DeepSynth.new(1.2, 6016)
			DeepKit.ping(s, 0.0, 196.0, 90.0, 0.42, 0.02)
			s.tone(0.0, 0.8, 392.0, -1.0, 0.1, "sine", 2.6, 0.004)
			return DeepKit.fin(s, 0.45)
		"resolve":
			s = DeepSynth.new(0.7, 22)
			s.whoosh(0.0, 0.3, 0.2, 220.0, 1900.0)
			DeepKit.ping(s, 0.2, 659.3, 40.0, 0.3, 0.02)
			return DeepKit.fin(s, 0.64)
		# --- gems firing: a chord of pings, each color at its own height ----------------------
		"gem_red":
			## A low D with its fifth, heat under it: lowpassed embers and a warm breath.
			s = DeepSynth.new(0.9, 4001)
			DeepKit.felt(s, 0.0, 110.0, 0.4)
			DeepKit.ping(s, 0.0, 293.66, 44.0, 0.4, 0.02)
			s.ping(0.01, 440.0, 36.0, 0.16, 0.0)
			s.noise(0.0, 0.14, 0.09, 900.0, 300.0, 2.4, 0.01, 150.0)
			DeepKit.embers(s, 0.02, 0.3, 6, 0.12)
			return DeepKit.fin(s, 0.66)
		"gem_blue":
			s = DeepSynth.new(1.3, 6015)
			DeepKit.ping(s, 0.0, 1174.7, 80.0, 0.44, 0.02)
			s.ping(0.03, 1760.0, 50.0, 0.12, 0.0)
			DeepKit.felt(s, 0.0, 220.0, 0.08)
			return DeepKit.fin(s, 0.82)
		"gem_green":
			## A sine blooming up an octave into a ping, with a little glitter.
			s = DeepSynth.new(1.1, 2021)
			DeepKit.felt(s, 0.0, 200.0, 0.1)
			s.tone(0.0, 0.25, 392.0, 784.0, 0.16, "sine", 1.6, 0.03)
			DeepKit.ping(s, 0.12, 784.0, 40.0, 0.3, 0.01)
			DeepKit.sparkle(s, 0.15, 0.3, 0.04, 4, 1600.0, 3600.0)
			return DeepKit.fin(s, 0.6)
		"gem_violet":
			## Miasma: a gurgle of bubbles, a sour low pair beating, a cloud of hiss spreading.
			s = DeepSynth.new(1.0, 5002)
			DeepKit.felt(s, 0.0, 150.0, 0.16)
			DeepKit.bubbles(s, 0.02, 0.4, 5, 150.0, 330.0, 0.14)
			s.tone(0.02, 0.45, 220.0, -1.0, 0.12, "sine", 2.0, 0.03, 0.01, 5.0)
			s.tone(0.02, 0.45, 233.08, -1.0, 0.1, "sine", 2.0, 0.03, 0.01, 5.5)
			s.noise(0.05, 0.5, 0.08, 500.0, 1600.0, 1.6, 0.12, 300.0)
			s.lowpass(3000.0, 2)
			return DeepKit.fin(s, 0.6)
		"gem_gold":
			s = DeepSynth.new(0.8, 2026)
			DeepKit.ladder(s, 0.0, 587.3, [0, 7, 12], 0.03, 45.0, 0.34)
			DeepKit.sparkle(s, 0.05, 0.25, 0.07, 6, 2400.0, 5600.0)
			return DeepKit.fin(s, 0.62)
		"gem_white":
			s = DeepSynth.new(1.0, 28)
			s.ping(0.0, 1318.5, 120.0, 0.4, 0.0)
			s.tone(0.0, 0.5, 2637.0, -1.0, 0.08, "sine", 3.0, 0.003)
			return DeepKit.fin(s, 0.62)
		"gem_fizzle":
			## Nothing happening: a damp puff on felt and four soft grains, nothing above 2 kHz.
			s = DeepSynth.new(0.5, 5004)
			s.noise(0.0, 0.16, 0.14, 900.0, 300.0, 3.0, 0.006, 150.0)
			DeepKit.felt(s, 0.0, 120.0, 0.12)
			for i in range(4):
				s.noise(0.05 + float(i) * 0.045, 0.014, 0.08 * (1.0 - float(i) * 0.2), 1500.0, 600.0, 5.0, 0.0005, 400.0)
			s.lowpass(2200.0)
			return DeepKit.fin(s, 0.26)
		# --- a gem's count: one instrument in six colours, all on C so the mixer can walk them
		# up the music's own scale (see DeepMusic.tonic and the battle screen's Tally) ---------
		"tally_tick":
			s = DeepSynth.new(0.3, 30)
			DeepKit.ping(s, 0.0, C5, 40.0, 0.42, 0.05)
			return DeepKit.fin(s, 0.5)
		"tick_red":
			s = DeepSynth.new(0.3, 31)
			s.fm(0.0, 0.12, C5, {"ratio": 1.0, "index": 2.2, "decay": 4.0, "amp": 0.4, "curve": 4.5, "attack": 0.001, "fb": 0.3})
			s.noise(0.0, 0.04, 0.18, 6000.0, 1500.0, 5.0, 0.0006)
			return DeepKit.fin(s, 0.5)
		"tick_blue":
			s = DeepSynth.new(0.3, 32)
			s.ping(0.0, C5, 50.0, 0.4, 0.04)
			s.ping(0.0, C5 * 2.0, 40.0, 0.16, 0.0)
			return DeepKit.fin(s, 0.5)
		"tick_green":
			s = DeepSynth.new(0.3, 6012)
			s.analog(0.0, 0.08, C5, {"amp": 0.42, "shape": "triangle", "cutoff": 1500.0, "env": 1500.0, "res": 0.3, "decay": 0.08, "release": 0.1})
			s.tone(0.0, 0.06, C5, -1.0, 0.12, "sine", 5.0, 0.001)
			return DeepKit.fin(s, 0.25)
		"tick_violet":
			s = DeepSynth.new(0.3, 34)
			s.ping(0.0, C5, 55.0, 0.34, 0.03)
			s.ping(0.0, C5 * 1.014, 55.0, 0.3, 0.0)
			return DeepKit.fin(s, 0.5)
		"tick_gold":
			s = DeepSynth.new(0.3, 35)
			s.ping(0.0, C5, 45.0, 0.34, 0.04)
			DeepKit.metal(s, 0.005, C5 * 3.0, 0.1, 0.1)
			return DeepKit.fin(s, 0.5)
		"tick_white":
			## The Invert gem's count on glass, its upper partials held back, a glint of
			## something uncanny over it.
			s = DeepSynth.new(0.3, 6003)
			s.bell(0.0, 0.25, C5, 0.38, DeepSynth.GLASS_PARTIALS, 3.8, 0.0)
			DeepKit.sparkle(s, 0.01, 0.12, 0.05, 3, 2400.0, 4800.0)
			return DeepKit.fin(s, 0.5)
		"flawless_glint":
			## A Flawless line at work: a small rising chime over a scatter of glass, the peerless
			## grade's sound in miniature, so the ear has met it before the bonus ever pays.
			s = DeepSynth.new(0.75, 6041)
			DeepKit.ladder(s, 0.0, 1046.5, [0, 7, 12], 0.055, 110.0, 0.2)
			s.bell(0.0, 0.3, C5, 0.2, DeepSynth.GLASS_PARTIALS, 3.8, 0.0)
			DeepKit.sparkle(s, 0.02, 0.42, 0.08, 10, 3200.0, 7800.0)
			return DeepKit.fin(s, 0.6)
		"tally_mult":
			s = DeepSynth.new(0.8, 2029)
			DeepKit.felt(s, 0.0, 110.0, 0.5)
			DeepKit.ping(s, 0.0, 261.6, 40.0, 0.4, 0.01)
			s.ping(0.02, 523.25, 30.0, 0.14, 0.0)
			return DeepKit.fin(s, 0.62)
		"tally_fuse":
			## Three pings closing in on one another, a breath drawn in.
			s = DeepSynth.new(0.9, 2031)
			DeepKit.ping(s, 0.0, 523.25, 50.0, 0.3, 0.01)
			DeepKit.ping(s, 0.04, 784.0, 50.0, 0.28, 0.01)
			DeepKit.ping(s, 0.1, 1046.5, 60.0, 0.32, 0.01)
			s.noise(0.0, 0.2, 0.08, 1500.0, 400.0, 2.0, 0.1, 300.0)
			DeepKit.sparkle(s, 0.1, 0.25, 0.05, 4, 2400.0, 5000.0)
			return DeepKit.fin(s, 0.66)
		"tally_blaze":
			s = DeepSynth.new(1.1, 2033)
			s.whoosh(0.0, 0.4, 0.28, 200.0, 2200.0)
			DeepKit.crackle(s, 0.05, 0.6, 12, 0.14)
			s.thump(0.0, 0.4, 80.0, 0.5, 0.3)
			DeepKit.ladder(s, 0.05, 523.25, [0, 4, 7], 0.04, 60.0, 0.26)
			return DeepKit.fin(s, 0.7)
		"resonance":
			s = DeepSynth.new(0.9, 40)
			DeepKit.ping(s, 0.0, 880.0, 90.0, 0.4, 0.03)
			s.ping(0.02, 1760.0, 60.0, 0.12, 0.0)
			return DeepKit.fin(s, 0.58)
		"harmony":
			s = DeepSynth.new(0.9, 41)
			DeepKit.ping(s, 0.0, 880.0, 80.0, 0.34, 0.03)
			DeepKit.ping(s, 0.03, 1318.5, 80.0, 0.3, 0.02)
			DeepKit.sparkle(s, 0.05, 0.3, 0.08, 6, 2400.0, 5200.0)
			return DeepKit.fin(s, 0.66)
		# --- your blows: a gem on stone -------------------------------------------------------
		"hit_light":
			s = DeepSynth.new(0.4, 2035)
			DeepKit.felt(s, 0.0, 140.0, 0.3)
			DeepKit.crack(s, 0.0, 0.42, 2400.0, 0.025)
			s.tone(0.0, 0.09, 180.0, 90.0, 0.3, "sine", 4.0, 0.001)
			return DeepKit.fin(s, 0.68)
		"hit_heavy":
			s = DeepSynth.new(0.7, 2037)
			s.thump(0.0, 0.3, 120.0, 0.6, 0.3)
			DeepKit.crack(s, 0.0, 0.42, 900.0, 0.045)
			DeepKit.crunch(s, 0.02, 0.18, 6, 0.2, 3000.0, 600.0)
			s.ping(0.005, 260.0, 20.0, 0.2, 0.0)
			return DeepKit.fin(s, 0.84)
		"hit_crit":
			s = DeepSynth.new(1.0, 2039)
			s.thump(0.0, 0.35, 120.0, 0.6, 0.3)
			DeepKit.crack(s, 0.0, 0.48, 900.0, 0.05)
			DeepKit.crunch(s, 0.02, 0.3, 8, 0.22, 3200.0, 600.0)
			for _i in range(6):
				s.ping(0.01 + s.rng.randf() * 0.12, s.rng.randf_range(1500.0, 4000.0), 18.0, 0.1, 0.0)
			s.tone(0.005, 0.4, 55.0, 40.0, 0.5, "sine", 2.6, 0.001)
			s.ping(0.03, 1318.5, 50.0, 0.16, 0.0)
			return DeepKit.fin(s, 0.9)
		"block":
			## A low E ping on felt with the stone clack forward; Back is the A above it.
			s = DeepSynth.new(0.6, 6002)
			DeepKit.ping(s, 0.0, 329.63, 26.0, 0.3, 0.02)
			DeepKit.felt(s, 0.0, 160.0, 0.4)
			s.clack(0.0, 0.22, 700.0)
			s.noise(0.0, 0.03, 0.15, 2500.0, 700.0, 4.5, 0.0005, 300.0)
			return DeepKit.fin(s, 0.66)
		"block_break":
			s = DeepSynth.new(0.8, 6025)
			DeepKit.stone(s, 0.0, 0.7, 300.0)
			for _i in range(7):
				s.ping(0.01 + s.rng.randf() * 0.3, s.rng.randf_range(900.0, 2600.0), s.rng.randf_range(15.0, 40.0), 0.2, 0.02)
			return DeepKit.fin(s, 0.76)
		# --- effects and statuses ---------------------------------------------------------------
		"heal":
			s = DeepSynth.new(1.5, 6030)
			DeepKit.swell_warm(s, 0.0, 261.6, [0, 4, 7], 0.24, 0.6)
			DeepKit.ladder(s, 0.2, 659.3, [0, 4, 7, 12], 0.1, 60.0, 0.26)
			return DeepKit.fin(s, 0.62)
		"poison":
			s = DeepSynth.new(0.9, 48)
			for i in range(5):
				s.tone(float(i) * 0.09, 0.14, 240.0 - float(i) * 22.0, 130.0, 0.2, "sine", 3.4, 0.006, 0.08, 18.0)
			s.noise(0.0, 0.45, 0.12, 900.0, 220.0, 2.0, 0.05)
			DeepKit.bubbles(s, 0.1, 0.5, 4, 120.0, 260.0, 0.12)
			return DeepKit.fin(s, 0.6)
		"stun":
			s = DeepSynth.new(1.0, 49)
			s.tone(0.0, 0.5, 700.0, 620.0, 0.24, "sine", 2.0, 0.006, 0.06, 13.0)
			for i in range(4):
				s.ping(0.1 + float(i) * 0.12, 1400.0 + s.rng.randf_range(-300.0, 500.0), 30.0, 0.14, 0.02)
			return DeepKit.fin(s, 0.62)
		"curse":
			## Two low rings a hair apart, a cold breath, a wavering sub, two faint whispers high
			## up. On F sharp, the tritone against everything else: the spook is deliberate.
			s = DeepSynth.new(1.6, 2049)
			s.ping(0.0, 185.0, 120.0, 0.3, 0.0)
			s.ping(0.0, 187.2, 120.0, 0.26, 0.0)
			s.noise(0.0, 0.9, 0.1, 1200.0, 200.0, 1.6, 0.2, 150.0)
			s.tone(0.05, 1.0, 92.5, 90.0, 0.2, "sine", 1.8, 0.2, 0.015, 5.0)
			s.ping(0.3, 2637.0, 60.0, 0.04, 0.0)
			s.ping(0.55, 2217.0, 60.0, 0.035, 0.0)
			return DeepKit.fin(s, 0.6)
		# --- creatures: the windup, their blows by move, dying -------------------------------
		"enemy_windup":
			## A chopped growl with breath.
			s = DeepSynth.new(0.9, 2044)
			DeepKit.growl(s, 0.0, 0.55, 0.4, 22.0, 2044)
			DeepKit.breath(s, 0.0, 0.5, 0.12, 300.0, 1800.0, 0.5)
			return DeepKit.fin(s, 0.66)
		"enemy_strike":
			s = DeepSynth.new(0.9, 52)
			DeepKit.impact(s, 0.0, 1.15, 240.0)
			s.tone(0.0, 0.45, 72.0, 30.0, 0.6, "sine", 2.6, 0.001)
			return DeepKit.fin(s, 0.94)
		"hit_slam":
			s = DeepSynth.new(1.0, 59)
			DeepKit.impact(s, 0.0, 1.3, 220.0)
			s.rumble(0.02, 0.5, 0.3)
			for _i in range(4):
				DeepKit.tok(s, 0.05 + s.rng.randf() * 0.25, 0.12, s.rng.randf_range(400.0, 700.0))
			return DeepKit.fin(s, 0.9)
		"hit_bite":
			s = DeepSynth.new(0.6, 6018)
			DeepKit.tok(s, 0.0, 0.4, 1400.0)
			DeepKit.stone(s, 0.03, 0.5, 520.0)
			DeepKit.tok(s, 0.075, 0.45, 1100.0)
			DeepKit.stone(s, 0.09, 0.6, 380.0)
			return DeepKit.fin(s, 0.8)
		"hit_claw":
			s = DeepSynth.new(0.7, 6019)
			s.whoosh(0.0, 0.14, 0.26, 700.0, 2600.0)
			DeepKit.stone(s, 0.07, 0.7, 480.0)
			s.noise(0.07, 0.12, 0.3, 9000.0, 1200.0, 3.5, 0.0006, 1500.0)
			for i in range(3):
				s.noise(0.09 + float(i) * 0.03, 0.05, 0.2, 7000.0, 2000.0, 5.0, 0.001, 2000.0)
			return DeepKit.fin(s, 0.8)
		"hit_breath":
			s = DeepSynth.new(1.3, 6014)
			s.whoosh(0.0, 0.7, 0.34, 220.0, 2200.0)
			s.analog(0.05, 0.6, 55.0, {"amp": 0.3, "shape": "saw", "unison": 2, "detune": 12.0, "cutoff": 150.0, "env": 1600.0, "res": 0.3, "attack": 0.1, "decay": 0.6, "sustain": 0.3, "release": 0.3, "drive": 1.6})
			DeepKit.crackle(s, 0.15, 0.8, 14, 0.12)
			DeepKit.stone(s, 0.3, 0.5, 200.0)
			return DeepKit.fin(s, 0.45)
		"hit_spit":
			s = DeepSynth.new(0.8, 63)
			s.noise(0.0, 0.06, 0.3, 3000.0, 1200.0, 4.0, 0.004, 400.0)
			s.whoosh(0.02, 0.2, 0.12, 1400.0, 500.0)
			s.noise(0.2, 0.18, 0.35, 2200.0, 300.0, 3.4, 0.002)
			DeepKit.bubbles(s, 0.22, 0.25, 5, 200.0, 500.0, 0.16)
			DeepKit.felt(s, 0.2, 150.0, 0.3)
			return DeepKit.fin(s, 0.74)
		"hit_lash":
			s = DeepSynth.new(0.6, 6020)
			s.whoosh(0.0, 0.12, 0.2, 500.0, 3200.0)
			s.noise(0.1, 0.03, 0.5, 11000.0, 2500.0, 5.0, 0.0005, 1200.0)
			DeepKit.stone(s, 0.1, 0.55, 600.0)
			return DeepKit.fin(s, 0.8)
		"hit_peck":
			s = DeepSynth.new(0.35, 6021)
			DeepKit.tok(s, 0.0, 0.45, 1900.0)
			DeepKit.stone(s, 0.005, 0.35, 900.0)
			s.ping(0.0, 2600.0, 12.0, 0.12, 0.0)
			return DeepKit.fin(s, 0.66)
		"hit_drill":
			## Chopped grit and wooden toks, a thump to end.
			s = DeepSynth.new(0.9, 2046)
			var grit := DeepSynth.new(0.5, 2046)
			grit.noise(0.0, 0.5, 0.3, 800.0, 3000.0, 1.0, 0.02, 500.0)
			grit.tremolo(30.0, 0.9)
			DeepKit.lay(s, grit.samples, 0.0)
			for i in range(10):
				DeepKit.tok(s, 0.03 + float(i) * 0.047, 0.1, s.rng.randf_range(500.0, 800.0))
			s.thump(0.48, 0.2, 110.0, 0.4, 0.25)
			return DeepKit.fin(s, 0.7)
		"hit_erupt":
			s = DeepSynth.new(1.2, 6022)
			s.rumble(0.0, 0.5, 0.4)
			s.tone(0.1, 0.5, 90.0, 30.0, 0.7, "sine", 2.8, 0.004)
			s.noise(0.12, 0.4, 0.45, 2600.0, 200.0, 2.4, 0.006)
			for _i in range(12):
				DeepKit.tok(s, 0.15 + s.rng.randf() * 0.5, 0.14, s.rng.randf_range(300.0, 700.0))
			DeepKit.stone(s, 0.14, 1.0, 180.0)
			return DeepKit.fin(s, 0.9)
		"hit_burst":
			s = DeepSynth.new(1.0, 6023)
			DeepKit.stone(s, 0.0, 1.1, 260.0)
			s.noise(0.0, 0.35, 0.45, 9000.0, 300.0, 2.6, 0.001)
			DeepKit.sparkle(s, 0.02, 0.3, 0.12, 10, 1500.0, 5000.0)
			s.rumble(0.02, 0.4, 0.2)
			return DeepKit.fin(s, 0.88)
		"hit_pull":
			## Air dragging down, rumble, a low tug; quieter than the rest.
			s = DeepSynth.new(0.9, 2047)
			s.whoosh(0.0, 0.4, 0.2, 900.0, 200.0)
			DeepKit.felt(s, 0.02, 120.0, 0.3)
			s.rumble(0.05, 0.4, 0.2)
			s.pluck(0.4, 0.2, 110.0, 0.4, 0.95, 0.5)
			DeepKit.felt(s, 0.4, 100.0, 0.4)
			return DeepKit.fin(s, 0.6)
		"hit_drink":
			s = DeepSynth.new(1.0, 70)
			for i in range(6):
				s.tone(float(i) * 0.11, 0.1, 180.0 + float(i) * 40.0, 260.0 + float(i) * 60.0, 0.22, "sine", 3.5, 0.01)
			s.noise(0.0, 0.7, 0.12, 1200.0, 400.0, 1.4, 0.1, 300.0)
			DeepKit.bubbles(s, 0.1, 0.6, 6, 150.0, 400.0, 0.12)
			return DeepKit.fin(s, 0.62)
		"creature_die":
			## A crack, crumbling debris, a thud, dust.
			s = DeepSynth.new(1.3, 2051)
			DeepKit.crack(s, 0.0, 0.4, 800.0, 0.05)
			DeepKit.crunch(s, 0.03, 0.5, 10, 0.22, 3000.0, 500.0)
			DeepKit.lay(s, DeepKit.thud(), 0.0, 0.6)
			for _i in range(4):
				s.ping(0.05 + s.rng.randf() * 0.3, s.rng.randf_range(300.0, 700.0), 20.0, 0.1, 0.0)
			s.noise(0.3, 0.5, 0.08, 600.0, 200.0, 1.6, 0.1, 100.0)
			return DeepKit.fin(s, 0.82)
		"warden_die":
			s = DeepSynth.new(2.6, 6026)
			DeepKit.stone(s, 0.0, 1.4, 200.0)
			s.noise(0.01, 0.5, 0.4, 9000.0, 300.0, 2.4, 0.001)
			s.tone(0.0, 0.6, 62.0, 28.0, 0.8, "sine", 2.4, 0.001)
			s.rumble(0.05, 1.6, 0.45)
			for _i in range(16):
				s.ping(0.05 + s.rng.randf() * 0.9, s.rng.randf_range(500.0, 3200.0), s.rng.randf_range(20.0, 60.0), 0.2, 0.02)
			DeepKit.ladder(s, 0.3, 880.0, [12, 7, 3, 0, -5, -12], 0.11, 80.0, 0.26)
			return DeepKit.fin(s, 0.95)
		"victory":
			s = DeepSynth.new(2.4, 6031)
			DeepKit.swell_warm(s, 0.0, C5 / 2.0, [0, 7, 12, 16, 19], 0.22, 1.2)
			DeepKit.ladder(s, 0.1, 659.3, [0, 7, 12, 16, 19, 24], 0.09, 70.0, 0.3)
			DeepKit.lay(s, DeepKit.kick(), 0.0, 0.6)
			DeepKit.sparkle(s, 0.3, 1.0, 0.08, 10, 2400.0, 6000.0)
			return DeepKit.fin(s, 0.72)
		"defeat":
			s = DeepSynth.new(2.4, 6032)
			DeepKit.swell_warm(s, 0.0, 196.0, [0, 3, 7], 0.24, 1.3)
			s.analog(0.1, 1.2, 150.0, {"amp": 0.22, "shape": "saw", "unison": 2, "detune": 12.0, "cutoff": 400.0, "env": 0.0, "res": 0.3, "attack": 0.2, "decay": 1.0, "sustain": 0.5, "release": 0.6, "glide": 2.0})
			s.lowpass(1500.0)
			s.rumble(0.0, 1.2, 0.3)
			return DeepKit.fin(s, 0.8)
		"cave_rumble":
			s = DeepSynth.new(2.6, 57)
			s.rumble(0.0, 2.2, 0.4)
			s.noise(0.3, 1.2, 0.08, 400.0, 120.0, 1.4, 0.4)
			return DeepKit.fin(s, 0.5)
		"ore":
			s = DeepSynth.new(0.8, 58)
			for _i in range(9):
				DeepKit.coin(s, s.rng.randf() * 0.34, 0.16)
			return DeepKit.fin(s, 0.7)
		# --- the mine ---------------------------------------------------------------------------
		"pick_strike":
			s = DeepSynth.new(0.7, 6027)
			DeepKit.stone(s, 0.0, 0.7, 500.0)
			DeepKit.metal(s, 0.0, 1180.0, 0.18, 0.26)
			for _i in range(5):
				DeepKit.tok(s, 0.06 + s.rng.randf() * 0.3, 0.1, s.rng.randf_range(400.0, 800.0))
			return DeepKit.fin(s, 0.86)
		"hammer_strike":
			## A hammer on a die at the anvil (Nov 5 2026, round 5: a Hammered card's charges, the
			## Smithy's hammer): a dull thump under a ringing clang, the anvil answering a
			## beat later, lower and quieter, and a spit of sparks.
			s = DeepSynth.new(0.9, 6041)
			DeepKit.impact(s, 0.0, 0.6, 180.0)
			DeepKit.metal(s, 0.0, 1560.0, 0.55, 0.34)
			DeepKit.metal(s, 0.004, 2340.0, 0.35, 0.16)
			DeepKit.metal(s, 0.09, 990.0, 0.4, 0.1)
			DeepKit.sparkle(s, 0.02, 0.35, 0.06, 7, 3200.0, 7000.0)
			return DeepKit.fin(s, 0.88)
		"rock_break":
			s = DeepSynth.new(1.0, 6028)
			s.noise(0.0, 0.5, 0.42, 3000.0, 180.0, 2.2, 0.004)
			DeepKit.stone(s, 0.0, 0.9, 220.0)
			for _i in range(9):
				DeepKit.tok(s, 0.08 + s.rng.randf() * 0.5, 0.18, s.rng.randf_range(300.0, 600.0))
			return DeepKit.fin(s, 0.86)
		"stone_found":
			s = DeepSynth.new(1.2, 73)
			DeepKit.ping(s, 0.0, 1318.5, 90.0, 0.36, 0.03)
			DeepKit.ping(s, 0.07, 1975.5, 80.0, 0.24, 0.02)
			DeepKit.sparkle(s, 0.05, 0.6, 0.1, 10, 2600.0, 6400.0)
			return DeepKit.fin(s, 0.72)
		"footstep":
			s = DeepSynth.new(0.35, 74)
			DeepKit.felt(s, 0.0, 118.0, 0.5)
			s.noise(0.0, 0.13, 0.2, 2600.0, 480.0, 4.0, 0.001)
			for _i in range(3):
				DeepKit.tok(s, 0.015 + s.rng.randf() * 0.12, 0.06, s.rng.randf_range(600.0, 1200.0))
			return DeepKit.fin(s, 0.42)
		"rockfall":
			s = DeepSynth.new(2.6, 75)
			s.rumble(0.0, 2.0, 0.5)
			for pair in [[0.1, 70.0], [0.42, 60.0], [0.78, 82.0]]:
				var hz: float = float(pair[1])
				DeepKit.lay(s, DeepKit.kick({"hz": hz * 2.0, "to": hz * 0.5, "dur": 0.5, "click": 0.2}), float(pair[0]), 0.9)
			for _i in range(22):
				DeepKit.tok(s, 0.1 + s.rng.randf() * 1.4, 0.2 * s.rng.randf_range(0.4, 1.0), s.rng.randf_range(260.0, 600.0))
			s.noise(0.05, 1.6, 0.35, 2600.0, 160.0, 1.8, 0.01)
			return DeepKit.fin(s, 0.9)
		"crumble":
			s = DeepSynth.new(1.8, 76)
			s.noise(0.0, 1.2, 0.3, 1800.0, 200.0, 2.0, 0.02)
			for _i in range(16):
				DeepKit.tok(s, s.rng.randf() * 1.0, 0.2 * s.rng.randf_range(0.4, 1.0), s.rng.randf_range(300.0, 700.0))
			DeepKit.felt(s, 0.05, 90.0, 0.4)
			return DeepKit.fin(s, 0.8)
		"tunnel":
			s = DeepSynth.new(1.0, 77)
			s.whoosh(0.0, 0.5, 0.26, 1100.0, 220.0)
			DeepKit.felt(s, 0.06, 110.0, 0.35)
			DeepKit.felt(s, 0.3, 96.0, 0.3)
			s.rumble(0.0, 0.7, 0.16)
			return DeepKit.fin(s, 0.72)
		"landing":
			## Walking into the camp: the pack comes off, the lantern clicks, embers under a
			## quiet C and G humming. A breath out, not an arrival announced.
			s = DeepSynth.new(1.4, 5005)
			DeepKit.felt(s, 0.0, 100.0, 0.3)
			s.noise(0.0, 0.08, 0.12, 600.0, 200.0, 3.0, 0.004, 80.0)
			DeepKit.tok(s, 0.12, 0.1, 900.0)
			DeepKit.embers(s, 0.15, 0.6, 8, 0.1)
			s.tone(0.2, 0.7, 261.63, -1.0, 0.07, "sine", 1.6, 0.15)
			s.tone(0.2, 0.7, 392.0, -1.0, 0.05, "sine", 1.6, 0.18)
			s.lowpass(4000.0)
			return DeepKit.fin(s, 0.46)
		"lift":
			## A pulsing motor, rumble, a rattle, a clack at the top.
			s = DeepSynth.new(1.6, 2056)
			var motor := DeepSynth.new(1.2, 2056)
			motor.tone(0.0, 1.2, 60.0, 58.0, 0.5, "sine", 1.2, 0.15)
			motor.tremolo(7.0, 0.5)
			DeepKit.lay(s, motor.samples, 0.0)
			s.rumble(0.0, 1.2, 0.3)
			DeepKit.rattle(s, 0.1, 0.8, 9, 0.08, 800.0, 1.0)
			s.whoosh(0.2, 0.8, 0.1, 150.0, 700.0)
			s.clack(1.05, 0.26, 500.0)
			return DeepKit.fin(s, 0.72)
		"depart":
			s = DeepSynth.new(1.8, 80)
			DeepKit.ping(s, 0.0, 784.0, 80.0, 0.3, 0.02)
			DeepKit.ping(s, 0.22, 1046.5, 80.0, 0.28, 0.02)
			for i in range(9):
				DeepKit.tok(s, 0.42 + float(i) * 0.075 + 0.012 * float(i * i) / 2.0, 0.07 * (1.0 - float(i) / 12.0), 520.0)
			DeepKit.stab(s, 0.5, C5, [0, 4, 7, 12], 0.07, 1.0, {"attack": 0.1})
			s.whoosh(0.4, 1.0, 0.06, 800.0, 360.0)
			return DeepKit.fin(s, 0.36)
		"lantern":
			s = DeepSynth.new(0.9, 81)
			s.whoosh(0.0, 0.3, 0.26, 500.0, 2400.0)
			DeepKit.crackle(s, 0.05, 0.4, 8, 0.08)
			DeepKit.ping(s, 0.06, C6, 70.0, 0.26, 0.02)
			return DeepKit.fin(s, 0.7)
		"oddity":
			s = DeepSynth.new(1.5, 82)
			s.ping(0.0, 587.3, 120.0, 0.3, 0.02)
			s.ping(0.0, 587.3 * 1.02, 120.0, 0.24, 0.0)
			s.tone(0.1, 0.7, 880.0, 933.0, 0.12, "sine", 1.6, 0.25, 0.03, 3.0)
			DeepKit.sparkle(s, 0.1, 0.8, 0.08, 10, 1600.0, 5200.0)
			return DeepKit.fin(s, 0.66)
		"buy":
			s = DeepSynth.new(0.7, 83)
			DeepKit.tok(s, 0.0, 0.3, 700.0)
			for _i in range(5):
				DeepKit.coin(s, 0.03 + s.rng.randf() * 0.2, 0.16)
			return DeepKit.fin(s, 0.7)
		"salvage_save":
			s = DeepSynth.new(0.8, 84)
			DeepKit.ping(s, 0.0, 1568.0, 80.0, 0.34, 0.03)
			DeepKit.sparkle(s, 0.04, 0.3, 0.08, 6, 2600.0, 5600.0)
			return DeepKit.fin(s, 0.66)
		"salvage_lose":
			s = DeepSynth.new(0.9, 2057)
			DeepKit.felt(s, 0.0, 110.0, 0.5)
			DeepKit.crunch(s, 0.02, 0.3, 6, 0.18, 2000.0, 400.0)
			s.ping(0.01, 196.0, 20.0, 0.22, 0.0)
			s.lowpass(3000.0)
			return DeepKit.fin(s, 0.6)
		"depth_card":
			s = DeepSynth.new(1.3, 86)
			DeepKit.ping(s, 0.0, 164.8, 110.0, 0.4, 0.02)
			s.noise(0.0, 0.3, 0.12, 800.0, 200.0, 2.4, 0.03)
			return DeepKit.fin(s, 0.62)
		# --- the loupe and the bench ----------------------------------------------------------
		"loupe_spin":
			## A ratchet over a humming motor, the motor on C.
			s = DeepSynth.new(1.0, 6010)
			for i in range(16):
				s.pluck(0.03 + float(i) * 0.045, 0.05, 2400.0, 0.14, 0.8, 0.2)
			var motor := DeepSynth.new(0.8, 6010)
			motor.tone(0.0, 0.8, 130.81, 128.6, 0.3, "sine", 1.4, 0.05)
			motor.tremolo(11.0, 0.5)
			DeepKit.lay(s, motor.samples, 0.0)
			DeepKit.felt(s, 0.0, 180.0, 0.2)
			return DeepKit.fin(s, 0.5)
		"reveal":
			s = DeepSynth.new(1.5, 88)
			s.whoosh(0.0, 0.2, 0.2, 2000.0, 400.0)
			DeepKit.ping(s, 0.05, C6, 90.0, 0.34, 0.03)
			DeepKit.ping(s, 0.09, C6 * 1.5, 80.0, 0.3, 0.02)
			DeepKit.sparkle(s, 0.05, 1.0, 0.14, 16, 2400.0, 7000.0)
			return DeepKit.fin(s, 0.82)
		"grade_rough":
			s = DeepSynth.new(0.6, 89)
			DeepKit.felt(s, 0.0, 150.0, 0.5)
			DeepKit.ping(s, 0.0, 220.0, 30.0, 0.22, 0.01)
			return DeepKit.fin(s, 0.56)
		"grade_fine":
			s = DeepSynth.new(0.9, 90)
			DeepKit.ping(s, 0.0, A4, 80.0, 0.32, 0.02)
			DeepKit.ping(s, 0.05, A4 * 1.5, 80.0, 0.26, 0.02)
			return DeepKit.fin(s, 0.62)
		"grade_precious":
			s = DeepSynth.new(1.3, 91)
			DeepKit.ladder(s, 0.0, C5, [0, 4, 7], 0.06, 90.0, 0.34)
			DeepKit.sparkle(s, 0.1, 0.6, 0.08, 8, 2200.0, 5000.0)
			return DeepKit.fin(s, 0.72)
		"grade_exquisite":
			## F major, so the grades climb I, IV, V and the Star lands on I.
			s = DeepSynth.new(1.8, 6008)
			DeepKit.ladder(s, 0.0, 698.46, [0, 4, 7, 12], 0.07, 100.0, 0.32)
			DeepKit.swell_warm(s, 0.0, 349.23, [0, 4, 7], 0.14, 0.9)
			DeepKit.sparkle(s, 0.1, 1.1, 0.12, 14, 2600.0, 6400.0)
			return DeepKit.fin(s, 0.84)
		"grade_peerless":
			s = DeepSynth.new(2.6, 6033)
			DeepKit.ladder(s, 0.0, 784.0, [0, 4, 7, 12], 0.08, 110.0, 0.32)
			DeepKit.swell_warm(s, 0.06, 196.0, [0, 7, 12], 0.26, 1.6)
			DeepKit.lay(s, DeepKit.kick(), 0.0, 0.5)
			DeepKit.sparkle(s, 0.1, 1.7, 0.14, 18, 2600.0, 7600.0)
			s.rumble(0.0, 1.0, 0.2)
			return DeepKit.fin(s, 0.95)
		"star":
			s = DeepSynth.new(1.8, 94)
			var star: Array = [0, 7, 12, 16, 19]
			for i in range(star.size()):
				DeepKit.ping(s, float(i) * 0.075, C6 * pow(2.0, float(star[i]) / 12.0), 140.0, 0.34, 0.03)
			DeepKit.sparkle(s, 0.1, 1.2, 0.12, 12, 3000.0, 8000.0)
			return DeepKit.fin(s, 0.88)
		"keep":
			s = DeepSynth.new(0.8, 95)
			DeepKit.felt(s, 0.0, 120.0, 0.55)
			DeepKit.tok(s, 0.02, 0.3, 520.0)
			DeepKit.metal(s, 0.02, 330.0, 0.4, 0.22)
			return DeepKit.fin(s, 0.76)
		"sell":
			s = DeepSynth.new(0.9, 96)
			for _i in range(11):
				DeepKit.coin(s, s.rng.randf() * 0.4, 0.16)
			DeepKit.tok(s, 0.42, 0.24, 600.0)
			return DeepKit.fin(s, 0.74)
		"chisel":
			s = DeepSynth.new(0.8, 97)
			DeepKit.tok(s, 0.0, 0.34, 1500.0)
			DeepKit.metal(s, 0.0, 2350.0, 0.12, 0.16)
			s.noise(0.02, 0.22, 0.3, 4200.0, 700.0, 3.0, 0.002)
			DeepKit.felt(s, 0.02, 120.0, 0.34)
			for _i in range(6):
				DeepKit.tok(s, 0.1 + s.rng.randf() * 0.4, 0.1, s.rng.randf_range(600.0, 1100.0))
			return DeepKit.fin(s, 0.74)
		"gleam":
			s = DeepSynth.new(2.0, 98)
			s.whoosh(0.0, 0.45, 0.12, 900.0, 5600.0)
			DeepKit.ping(s, 0.1, 2093.0, 220.0, 0.28, 0.02)
			DeepKit.ping(s, 0.2, 3136.0, 200.0, 0.2, 0.02)
			DeepKit.sparkle(s, 0.05, 1.5, 0.16, 20, 3200.0, 8400.0)
			return DeepKit.fin(s, 0.8)
		"tally":
			s = DeepSynth.new(0.35, 99)
			DeepKit.tok(s, 0.0, 0.22, 1700.0)
			DeepKit.ping(s, 0.0, 1760.0, 25.0, 0.2, 0.01)
			return DeepKit.fin(s, 0.5)
		# --- rites: allowed to be enormous ----------------------------------------------------
		"altar_hum":
			s = DeepSynth.new(1.8, 6013)
			DeepKit.swell_warm(s, 0.0, 110.0, [0, 7, 12], 0.26, 1.5)
			DeepKit.ping(s, 0.2, 659.3, 110.0, 0.14, 0.01)
			DeepKit.ping(s, 0.25, 987.8, 110.0, 0.12, 0.01)
			DeepKit.sparkle(s, 0.25, 1.2, 0.08, 10, 2400.0, 6000.0)
			return DeepKit.fin(s, 0.3)
		"altar_fizzle":
			## A falling third, E down to C, as two warm pings on felt; the smoke hisses out.
			s = DeepSynth.new(1.1, 4007)
			DeepKit.ping(s, 0.0, 659.26, 60.0, 0.34, 0.01)
			DeepKit.ping(s, 0.14, 523.25, 70.0, 0.3, 0.01)
			DeepKit.felt(s, 0.14, 150.0, 0.2)
			s.noise(0.1, 0.4, 0.07, 1500.0, 400.0, 2.0, 0.05, 200.0)
			DeepKit.dust(s, 0.2, 0.4, 5, 0.06)
			return DeepKit.fin(s, 0.5)
		"altar_make":
			s = DeepSynth.new(2.4, 6034)
			DeepKit.riser(s, 0.0, 0.9, 0.22, 65.0)
			DeepKit.ladder(s, 0.0, C5, [0, 4, 7, 12, 16], 0.12, 120.0, 0.3)
			DeepKit.swell_warm(s, 0.65, C5, [0, 4, 7, 12], 0.22, 1.4)
			DeepKit.sparkle(s, 0.6, 1.4, 0.12, 16, 2600.0, 7200.0)
			return DeepKit.fin(s, 0.86)
		"transcendent":
			s = DeepSynth.new(3.0, 6035)
			s.rumble(0.0, 1.2, 0.26)
			DeepKit.riser(s, 0.0, 1.0, 0.24, 65.0)
			DeepKit.ladder(s, 0.0, 261.6, [0, 7, 12, 16, 19, 24, 28], 0.11, 140.0, 0.3)
			DeepKit.swell_warm(s, 0.8, 523.25, [0, 4, 7, 11, 14], 0.22, 2.0)
			DeepKit.swell_warm(s, 0.8, 130.8, [0, 7, 12], 0.24, 2.0)
			DeepKit.lay(s, DeepKit.kick(), 0.8, 0.6)
			DeepKit.sparkle(s, 0.7, 2.0, 0.18, 30, 2600.0, 8800.0)
			return DeepKit.fin(s, 0.97)
		"hollow_drop":
			s = DeepSynth.new(2.8, 104)
			s.whoosh(0.0, 1.1, 0.2, 2600.0, 140.0)
			for i in range(7):
				DeepKit.tok(s, 0.06 * float(i) + 0.016 * float(i * i), 0.34 * pow(0.78, float(i)), 1500.0 - 150.0 * float(i))
			s.tone(1.1, 0.7, 46.0, 20.0, 0.75, "sine", 2.6, 0.002)
			s.rumble(1.1, 1.1, 0.36)
			s.analog(1.1, 0.7, 61.7, {"amp": 0.2, "shape": "saw", "unison": 2, "detune": 12.0, "cutoff": 150.0, "env": 300.0, "res": 0.3, "attack": 0.01, "decay": 0.6, "sustain": 0.5, "release": 0.6, "drive": 1.0})
			return DeepKit.fin(s, 0.88)
		"hollow_rise":
			## Alien by design: a whole-tone ladder and chords no key owns.
			s = DeepSynth.new(3.0, 105)
			s.whoosh(0.0, 0.55, 0.22, 140.0, 3400.0)
			s.analog(0.0, 0.5, 123.5, {"amp": 0.18, "shape": "saw", "unison": 3, "detune": 14.0, "cutoff": 200.0, "env": 2000.0, "res": 0.3, "attack": 0.4, "decay": 0.5, "sustain": 0.5, "release": 0.5})
			DeepKit.ladder(s, 0.42, 493.9, [0, 3, 6, 10, 13, 18], 0.06, 140.0, 0.26)
			DeepKit.swell(s, 0.82, 246.9, [0, 6, 10, 13], 0.2, 1.6)
			DeepKit.swell(s, 0.82, 61.7, [0, 7], 0.22, 1.7)
			DeepKit.sparkle(s, 0.5, 1.7, 0.14, 22, 2400.0, 7800.0)
			return DeepKit.fin(s, 0.9)
		# --- the shop --------------------------------------------------------------------------
		"reel_lever":
			s = DeepSynth.new(1.2, 106)
			for i in range(7):
				DeepKit.tok(s, float(i) * 0.045, 0.2 + 0.03 * float(i), 700.0 + 110.0 * float(i))
			DeepKit.lay(s, DeepKit.kick(), 0.33, 0.6)
			DeepKit.metal(s, 0.34, 880.0, 0.3, 0.2)
			s.whoosh(0.32, 0.7, 0.22, 300.0, 2200.0)
			return DeepKit.fin(s, 0.66)
		"reel_tick":
			s = DeepSynth.new(0.1, 107)
			DeepKit.tok(s, 0.0, 0.34, 1900.0)
			DeepKit.metal(s, 0.0, 2900.0, 0.06, 0.08)
			return DeepKit.fin(s, 0.46)
		"reel_stop":
			s = DeepSynth.new(0.7, 108)
			DeepKit.lay(s, DeepKit.kick({"hz": 120.0, "to": 40.0}), 0.0, 0.8)
			DeepKit.tok(s, 0.0, 0.42, 860.0)
			DeepKit.metal(s, 0.01, 523.25, 0.42, 0.24)
			return DeepKit.fin(s, 0.74)
		"geode_crack":
			s = DeepSynth.new(1.1, 6029)
			s.noise(0.0, 0.14, 0.5, 8000.0, 900.0, 3.4, 0.0008)
			DeepKit.stone(s, 0.0, 0.9, 240.0)
			for _i in range(8):
				s.ping(0.02 + s.rng.randf() * 0.3, s.rng.randf_range(1500.0, 5000.0), s.rng.randf_range(20.0, 60.0), 0.2, 0.02)
			DeepKit.ping(s, 0.05, 1568.0, 120.0, 0.24, 0.02)
			for _i in range(4):
				DeepKit.tok(s, 0.18 + s.rng.randf() * 0.3, 0.18, s.rng.randf_range(400.0, 700.0))
			return DeepKit.fin(s, 0.82)
		"jackpot":
			s = DeepSynth.new(2.6, 6036)
			for _i in range(16):
				DeepKit.coin(s, s.rng.randf() * 0.8, 0.14)
			DeepKit.ladder(s, 0.1, C5, [0, 4, 7, 12, 16], 0.09, 120.0, 0.3)
			DeepKit.swell_warm(s, 0.55, C5, [0, 4, 7, 12], 0.2, 1.5)
			DeepKit.sparkle(s, 0.4, 1.6, 0.14, 24, 2600.0, 8000.0)
			DeepKit.lay(s, DeepKit.kick(), 0.55, 0.5)
			return DeepKit.fin(s, 0.9)
		"contract_seal":
			s = DeepSynth.new(1.8, 111)
			s.whoosh(0.0, 0.6, 0.2, 200.0, 2600.0)
			DeepKit.felt(s, 0.55, 140.0, 0.5)
			DeepKit.tok(s, 0.55, 0.3, 640.0)
			DeepKit.ladder(s, 0.6, C5, [0, 7, 12], 0.02, 100.0, 0.3)
			DeepKit.sparkle(s, 0.6, 0.9, 0.1, 12, 2400.0, 6400.0)
			return DeepKit.fin(s, 0.78)
		"gem_shatter":
			s = DeepSynth.new(2.4, 112)
			s.noise(0.0, 0.12, 0.45, 9000.0, 1400.0, 3.6, 0.0006)
			for _i in range(14):
				s.ping(0.01 + s.rng.randf() * 0.4, s.rng.randf_range(1800.0, 6000.0), s.rng.randf_range(20.0, 60.0), 0.2, 0.02)
			for _i in range(9):
				DeepKit.tok(s, 0.2 + s.rng.randf() * 0.5, 0.16, s.rng.randf_range(900.0, 1800.0))
			s.analog(0.12, 0.6, 146.8, {"amp": 0.2, "shape": "saw", "unison": 2, "detune": 10.0, "cutoff": 500.0, "env": 0.0, "res": 0.3, "attack": 0.06, "decay": 0.6, "sustain": 0.4, "release": 0.6})
			s.analog(0.7, 0.8, 123.5, {"amp": 0.18, "shape": "saw", "unison": 2, "detune": 10.0, "cutoff": 450.0, "env": 0.0, "res": 0.3, "attack": 0.08, "decay": 0.7, "sustain": 0.4, "release": 0.7})
			return DeepKit.fin(s, 0.74)
		"infinity":
			s = DeepSynth.new(3.2, 6037)
			s.rumble(0.0, 1.3, 0.3)
			s.whoosh(0.0, 0.8, 0.26, 90.0, 4200.0)
			DeepKit.ladder(s, 0.0, C5, [0, 4, 7, 12, 7, 4, 0, -5, 0, 4, 7, 12, 16, 19, 24], 0.065, 140.0, 0.24)
			DeepKit.swell_warm(s, 1.0, C5, [0, 4, 7, 11, 14, 19], 0.22, 1.8)
			DeepKit.swell_warm(s, 1.0, 65.4, [0, 7, 12, 19], 0.24, 1.85)
			DeepKit.lay(s, DeepKit.kick(), 1.0, 0.7)
			DeepKit.sparkle(s, 0.85, 1.95, 0.2, 40, 2400.0, 9800.0)
			return DeepKit.fin(s, 0.98)
		# --- the four creature effects with a look of their own --------------------------------
		"flame":
			s = DeepSynth.new(0.9, 114)
			s.whoosh(0.0, 0.45, 0.3, 260.0, 2200.0)
			s.noise(0.04, 0.6, 0.16, 1600.0, 500.0, 2.2, 0.01)
			DeepKit.crackle(s, 0.06, 0.55, 12, 0.1)
			s.analog(0.05, 0.4, 65.0, {"amp": 0.16, "shape": "saw", "cutoff": 150.0, "env": 900.0, "res": 0.2, "attack": 0.1, "decay": 0.4, "sustain": 0.3, "release": 0.2, "drive": 1.0})
			return DeepKit.fin(s, 0.6)
		"splash":
			s = DeepSynth.new(1.1, 115)
			DeepKit.felt(s, 0.0, 110.0, 0.5)
			s.noise(0.0, 0.7, 0.42, 4800.0, 500.0, 2.4, 0.004)
			DeepKit.bubbles(s, 0.18, 0.45, 5, 500.0, 700.0, 0.12)
			return DeepKit.fin(s, 0.62)
		"mirror":
			## A breath drawn in and two glass notes, no sparkle: a find rings and glitters,
			## this inhales.
			s = DeepSynth.new(1.3, 6004)
			s.noise(0.0, 0.35, 0.12, 300.0, 3000.0, 1.6, 0.3, 300.0)
			s.bell(0.3, 0.8, 1760.0, 0.28, DeepSynth.GLASS_PARTIALS, 2.4, 0.0)
			s.bell(0.34, 0.7, 2637.0, 0.16, DeepSynth.GLASS_PARTIALS, 2.4, 0.0)
			return DeepKit.fin(s, 0.55)
		"claw":
			s = DeepSynth.new(0.5, 117)
			DeepKit.tok(s, 0.0, 0.4, 1400.0)
			DeepKit.tok(s, 0.035, 0.45, 1100.0)
			DeepKit.felt(s, 0.03, 190.0, 0.35)
			s.noise(0.03, 0.08, 0.15, 5000.0, 1500.0, 5.0)
			return DeepKit.fin(s, 0.6)
	return null
