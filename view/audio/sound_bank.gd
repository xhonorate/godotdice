class_name DeepSoundBank
extends RefCounted
## Every sound in the game, written as a recipe.
##
## One name, one short list of voices, one stream. The bank bakes a sound the first time it is
## asked for and keeps it, so a fight never pays for the same crack twice.
##
## The palette is deliberate, because the whole game sounds like it happens underground:
## the UI is wood and small stones, never a beep; gems ring as struck crystal, tuned by their
## colour; rock is filtered noise; creatures shatter; metal is for the lift, the lock and a
## blow that is turned aside. Anything that matters — a Peerless grade, a Star — is a chord
## the player will learn to recognise before they read the word.

## Concert pitch for everything tuned. Notes are written as semitone steps off a root so the
## fanfares stay in one key with each other.
const A4: float = 440.0
const C5: float = 523.25
const C6: float = 1046.5

## Which gem colour rings as what. The name is the sound; the hue is only how it is drawn.
const GEM_SOUNDS: Dictionary = {"RED": "gem_red", "BLUE": "gem_blue", "GREEN": "gem_green",
	"VIOLET": "gem_violet", "GOLD": "gem_gold", "WHITE": "gem_white"}
const GRADE_SOUNDS: Dictionary = {"ROUGH": "grade_rough", "FINE": "grade_fine", "PRECIOUS": "grade_precious",
	"EXQUISITE": "grade_exquisite", "PEERLESS": "grade_peerless"}

const NAMES: PackedStringArray = [
	"ui_tap", "ui_hover", "ui_confirm", "ui_back", "ui_toggle", "ui_tab", "ui_open", "ui_close",
	"ui_deny", "toast", "toast_bad", "unlock",
	"die_tumble", "die_settle", "die_pick", "die_drop", "dice_lock", "dice_reroll",
	"battle_begin", "turn_begin", "resolve", "gem_red", "gem_blue", "gem_green", "gem_violet",
	"gem_gold", "gem_white", "gem_fizzle", "resonance", "harmony", "hit_light", "hit_heavy",
	"hit_crit", "block", "block_break", "heal", "poison", "stun", "curse", "enemy_windup",
	"enemy_strike", "creature_die", "warden_die", "victory", "defeat", "cave_rumble", "ore",
	"pick_strike", "rock_break", "stone_found", "tunnel", "landing", "lift", "depart", "lantern", "oddity",
	"buy", "salvage_save", "salvage_lose", "depth_card",
	"loupe_spin", "reveal", "grade_rough", "grade_fine", "grade_precious", "grade_exquisite",
	"grade_peerless", "star", "keep", "sell"]

static var _cache: Dictionary = {}
## The bank is baked on a worker thread while the game is played, and asked for sounds from
## the main one at the same time; only the shelf needs guarding, not the baking.
static var _shelf: Mutex = Mutex.new()

static func gem_sound(colour: String) -> String:
	return str(GEM_SOUNDS.get(colour.to_upper(), "gem_white"))

static func grade_sound(tier: String) -> String:
	return str(GRADE_SOUNDS.get(tier.to_upper(), "grade_rough"))

static func known(name: String) -> bool:
	return NAMES.has(name)

static func baked(name: String) -> bool:
	_shelf.lock()
	var have: bool = _cache.has(name)
	_shelf.unlock()
	return have

static func stream(name: String) -> AudioStreamWAV:
	## The sound, baked on the first ask and kept for the rest of the session. Two callers
	## racing for the same one both bake it and agree on the answer, which costs less than
	## holding the shelf shut for the length of a bake.
	_shelf.lock()
	var shelved: Variant = _cache.get(name, null)
	var known_missing: bool = _cache.has(name)
	_shelf.unlock()
	if shelved != null or known_missing:
		return shelved
	var made: AudioStreamWAV = _bake(name)
	_shelf.lock()
	_cache[name] = made
	_shelf.unlock()
	return made

static func forget() -> void:
	_shelf.lock()
	_cache.clear()
	_shelf.unlock()

# --- the recipes -------------------------------------------------------------------------------

static func _bake(name: String) -> AudioStreamWAV:
	match name:
		# --- the interface: wood, small stones and the odd struck glass ---------------------
		"ui_tap":
			return DeepSynth.new(0.1).noise(0.0, 0.012, 0.3, 5200.0, 1400.0, 5.0, 0.0006) \
				.tone(0.0, 0.06, 470.0, 300.0, 0.24, "triangle", 5.0, 0.001).normalise(0.5).stream()
		"ui_hover":
			return DeepSynth.new(0.06).tone(0.0, 0.05, 1560.0, 1480.0, 0.2, "sine", 5.0, 0.002) \
				.noise(0.0, 0.01, 0.06, 6000.0, 3000.0, 5.0).normalise(0.16).stream()
		"ui_confirm":
			return DeepSynth.new(0.5).bell(0.0, 0.34, 622.25, 0.34, DeepSynth.CHIME_PARTIALS, 2.6) \
				.bell(0.045, 0.4, 932.0, 0.26, DeepSynth.CHIME_PARTIALS, 2.4) \
				.noise(0.0, 0.03, 0.12, 4000.0, 900.0, 4.0).normalise(0.62).stream()
		"ui_back":
			return DeepSynth.new(0.16).tone(0.0, 0.1, 430.0, 240.0, 0.3, "triangle", 4.0, 0.002) \
				.noise(0.0, 0.014, 0.16, 3600.0, 800.0, 5.0).normalise(0.45).stream()
		"ui_toggle":
			return DeepSynth.new(0.16).clack(0.0, 0.3, 1120.0) \
				.bell(0.006, 0.12, 1480.0, 0.16, DeepSynth.CHIME_PARTIALS, 4.0).normalise(0.5).stream()
		"ui_tab":
			## Turned often, so a soft wooden tock: no bright partials and no hiss to tire of.
			return DeepSynth.new(0.14).noise(0.0, 0.01, 0.14, 2600.0, 800.0, 5.0, 0.0008) \
				.tone(0.0, 0.09, 540.0, 430.0, 0.3, "sine", 4.4, 0.002) \
				.tone(0.0, 0.05, 1080.0, 860.0, 0.05, "sine", 5.0, 0.002).normalise(0.34).stream()
		"ui_open":
			return DeepSynth.new(0.34).whoosh(0.0, 0.24, 0.24, 300.0, 1500.0) \
				.bell(0.06, 0.26, 523.25, 0.18, DeepSynth.CHIME_PARTIALS, 3.0).normalise(0.52).stream()
		"ui_close":
			return DeepSynth.new(0.3).whoosh(0.0, 0.2, 0.24, 1400.0, 280.0) \
				.thump(0.14, 0.14, 180.0, 0.22, 0.2).normalise(0.5).stream()
		"ui_deny":
			return DeepSynth.new(0.32).thump(0.0, 0.14, 190.0, 0.5, 0.5).thump(0.1, 0.18, 150.0, 0.42, 0.4) \
				.normalise(0.58).stream()
		"toast":
			return DeepSynth.new(0.45).bell(0.0, 0.3, C6, 0.26, DeepSynth.CHIME_PARTIALS, 3.0) \
				.bell(0.05, 0.3, C6 * 1.5, 0.16, DeepSynth.CHIME_PARTIALS, 3.2).normalise(0.5).stream()
		"toast_bad":
			return DeepSynth.new(0.35).tone(0.0, 0.2, 320.0, 170.0, 0.3, "saw", 3.4, 0.004) \
				.noise(0.0, 0.14, 0.2, 1400.0, 300.0, 3.0).normalise(0.55).stream()
		"unlock":
			## A door in the mountain opening: a rolled chord with the light coming through it.
			return DeepSynth.new(1.4).chord(0.0, 0.9, C5, [0, 4, 7, 12], 0.3, DeepSynth.CHIME_PARTIALS, 0.085) \
				.sparkle(0.25, 0.8, 0.14, 2200.0, 6000.0, 16).whoosh(0.0, 0.3, 0.12, 400.0, 2400.0) \
				.echoes(0.13, 0.22, 2).normalise(0.8).stream()

		# --- dice: five hard solids in a wooden tray -----------------------------------------
		"die_tumble":
			return DeepSynth.new(0.42).clatter(0.0, 0.3, 0.26, 5, 950.0).normalise(0.46).stream()
		"die_settle":
			return DeepSynth.new(0.16).clack(0.0, 0.3, 620.0).thump(0.0, 0.08, 130.0, 0.22, 0.0) \
				.normalise(0.5).stream()
		"die_pick":
			return DeepSynth.new(0.12).clack(0.0, 0.22, 1300.0) \
				.tone(0.0, 0.07, 700.0, 1150.0, 0.16, "triangle", 4.0, 0.002).normalise(0.42).stream()
		"die_drop":
			return DeepSynth.new(0.12).clack(0.0, 0.2, 860.0) \
				.tone(0.0, 0.07, 900.0, 560.0, 0.14, "triangle", 4.0, 0.002).normalise(0.38).stream()
		"dice_lock":
			## The latch: a small piece of metal deciding something.
			return DeepSynth.new(0.4).clack(0.0, 0.34, 1400.0) \
				.bell(0.01, 0.3, 780.0, 0.3, DeepSynth.METAL_PARTIALS, 3.0) \
				.thump(0.0, 0.1, 160.0, 0.26, 0.2).normalise(0.66).stream()
		"dice_reroll":
			return DeepSynth.new(0.6).whoosh(0.0, 0.18, 0.14, 600.0, 1800.0) \
				.clatter(0.04, 0.42, 0.3, 11, 820.0).normalise(0.62).stream()

		# --- the fight ------------------------------------------------------------------------
		"battle_begin":
			return DeepSynth.new(1.6).rumble(0.0, 1.3, 0.4).tone(0.0, 1.1, 58.0, 87.0, 0.3, "saw", 1.2, 0.35) \
				.noise(0.0, 0.5, 0.16, 900.0, 200.0, 2.0, 0.2).echoes(0.19, 0.3, 2).normalise(0.72).stream()
		"turn_begin":
			return DeepSynth.new(1.1).bell(0.0, 0.85, 196.0, 0.4, DeepSynth.BELL_PARTIALS, 2.2) \
				.echoes(0.12, 0.3, 2).normalise(0.6).stream()
		"resolve":
			return DeepSynth.new(0.6).whoosh(0.0, 0.34, 0.24, 220.0, 1900.0) \
				.bell(0.2, 0.34, 659.25, 0.24, DeepSynth.CHIME_PARTIALS, 2.8).normalise(0.66).stream()
		"gem_red":
			## Cut and heat: a saw falling through the floor with grit on it.
			return DeepSynth.new(0.5).tone(0.0, 0.26, 900.0, 210.0, 0.34, "saw", 3.0, 0.002) \
				.noise(0.0, 0.16, 0.26, 7000.0, 700.0, 3.4).thump(0.02, 0.22, 130.0, 0.4, 0.3) \
				.normalise(0.74).stream()
		"gem_blue":
			## Glass and cold water.
			return DeepSynth.new(0.6).bell(0.0, 0.46, 1174.66, 0.34, DeepSynth.CHIME_PARTIALS, 2.6) \
				.whoosh(0.0, 0.2, 0.1, 900.0, 2600.0).normalise(0.66).stream()
		"gem_green":
			## Something growing: a warm tone rising into its own fifth.
			return DeepSynth.new(0.55).tone(0.0, 0.3, 392.0, 588.0, 0.3, "triangle", 2.6, 0.01) \
				.bell(0.06, 0.34, 784.0, 0.2, DeepSynth.CHIME_PARTIALS, 2.6).normalise(0.66).stream()
		"gem_violet":
			## Control, and something not quite right about it: two bells beating.
			return DeepSynth.new(0.65).bell(0.0, 0.5, 740.0, 0.3, DeepSynth.BELL_PARTIALS, 2.4, 0.013) \
				.tone(0.0, 0.34, 370.0, 330.0, 0.16, "sine", 2.6, 0.02, 0.02, 5.0).normalise(0.68).stream()
		"gem_gold":
			## Fortune: bright metal, and a little glitter behind it.
			return DeepSynth.new(0.6).bell(0.0, 0.34, 1568.0, 0.3, DeepSynth.CHIME_PARTIALS, 3.0) \
				.bell(0.05, 0.36, 2093.0, 0.2, DeepSynth.CHIME_PARTIALS, 3.0) \
				.sparkle(0.05, 0.3, 0.1, 2600.0, 6000.0, 7).normalise(0.68).stream()
		"gem_white":
			## The hand itself: a pure tone, nothing added.
			return DeepSynth.new(0.55).tone(0.0, 0.4, 1318.5, -1.0, 0.3, "sine", 2.6, 0.003) \
				.bell(0.0, 0.3, 1978.0, 0.12, DeepSynth.CHIME_PARTIALS, 3.0).normalise(0.62).stream()
		"gem_fizzle":
			return DeepSynth.new(0.4).noise(0.0, 0.26, 0.26, 1800.0, 260.0, 2.6, 0.01) \
				.tone(0.0, 0.16, 300.0, 140.0, 0.16, "square", 4.0, 0.004).normalise(0.46).stream()
		"resonance":
			## Played at a higher pitch the longer the chain runs.
			return DeepSynth.new(0.45).bell(0.0, 0.32, 880.0, 0.3, DeepSynth.CHIME_PARTIALS, 2.8) \
				.normalise(0.58).stream()
		"harmony":
			return DeepSynth.new(0.6).chord(0.0, 0.42, 880.0, [0, 7], 0.28, DeepSynth.CHIME_PARTIALS, 0.03) \
				.sparkle(0.05, 0.3, 0.1, 2400.0, 5200.0, 6).normalise(0.66).stream()
		"hit_light":
			return DeepSynth.new(0.3).noise(0.0, 0.08, 0.4, 7000.0, 900.0, 4.0, 0.0008) \
				.thump(0.0, 0.14, 150.0, 0.4, 0.2).normalise(0.7).stream()
		"hit_heavy":
			return DeepSynth.new(0.55).noise(0.0, 0.14, 0.45, 9000.0, 420.0, 3.4, 0.001) \
				.thump(0.0, 0.32, 95.0, 0.6, 0.35).shatter(0.02, 0.16, 1100.0, 4, 0.16) \
				.normalise(0.86).stream()
		"hit_crit":
			return DeepSynth.new(0.8).noise(0.0, 0.18, 0.5, 11000.0, 400.0, 3.0, 0.001) \
				.thump(0.0, 0.4, 78.0, 0.7, 0.4).bell(0.01, 0.4, 1760.0, 0.24, DeepSynth.METAL_PARTIALS, 3.2) \
				.rumble(0.05, 0.5, 0.22).normalise(0.92).stream()
		"block":
			return DeepSynth.new(0.45).bell(0.0, 0.34, 520.0, 0.36, DeepSynth.METAL_PARTIALS, 3.0) \
				.clack(0.0, 0.3, 1600.0).normalise(0.7).stream()
		"block_break":
			return DeepSynth.new(0.5).shatter(0.0, 0.42, 900.0, 7, 0.3).thump(0.0, 0.16, 170.0, 0.3, 0.3) \
				.normalise(0.76).stream()
		"heal":
			return DeepSynth.new(0.8).chord(0.0, 0.55, C5, [0, 4, 7], 0.26, DeepSynth.CHIME_PARTIALS, 0.05) \
				.sparkle(0.05, 0.45, 0.1, 2000.0, 4800.0, 9).normalise(0.66).stream()
		"poison":
			## Something wet working away under the shell.
			var rot := DeepSynth.new(0.6)
			for i in range(5):
				rot.tone(float(i) * 0.09, 0.14, 240.0 - float(i) * 22.0, 130.0, 0.2, "sine", 3.4, 0.006, 0.08, 18.0)
			return rot.noise(0.0, 0.45, 0.14, 900.0, 220.0, 2.0, 0.05).normalise(0.6).stream()
		"stun":
			var ring := DeepSynth.new(0.75).tone(0.0, 0.5, 700.0, 620.0, 0.26, "sine", 2.0, 0.006, 0.06, 13.0)
			for i in range(4):
				ring.bell(0.1 + float(i) * 0.12, 0.2, 1400.0 + ring.rng.randf_range(-300.0, 500.0), 0.12, DeepSynth.CHIME_PARTIALS, 3.4)
			return ring.normalise(0.62).stream()
		"curse":
			return DeepSynth.new(0.9).tone(0.0, 0.7, 190.0, 118.0, 0.3, "saw", 1.8, 0.03) \
				.tone(0.0, 0.7, 193.0, 120.0, 0.24, "saw", 1.8, 0.03) \
				.noise(0.0, 0.6, 0.12, 700.0, 160.0, 1.6, 0.1).echoes(0.15, 0.3, 2).normalise(0.7).stream()
		"enemy_windup":
			## The thing in the dark deciding to come at you.
			return DeepSynth.new(0.55).tone(0.0, 0.42, 88.0, 148.0, 0.36, "saw", 1.4, 0.12, 0.05, 7.0) \
				.noise(0.0, 0.4, 0.2, 320.0, 1100.0, 1.4, 0.2, 180.0).normalise(0.72).stream()
		"enemy_strike":
			## Landing on you, not on them: heavier, duller, and close.
			return DeepSynth.new(0.7).thump(0.0, 0.4, 78.0, 0.7, 0.45) \
				.noise(0.0, 0.12, 0.45, 4200.0, 260.0, 3.2, 0.001) \
				.tone(0.0, 0.18, 420.0, 90.0, 0.2, "saw", 3.4, 0.002).normalise(0.94).stream()
		"creature_die":
			return DeepSynth.new(0.9).shatter(0.0, 0.5, 1200.0, 12, 0.45).thump(0.0, 0.26, 110.0, 0.4, 0.35) \
				.noise(0.05, 0.5, 0.14, 1600.0, 200.0, 2.2, 0.03).normalise(0.86).stream()
		"warden_die":
			return DeepSynth.new(2.2).shatter(0.0, 0.6, 900.0, 16, 0.9).thump(0.0, 0.5, 62.0, 0.8, 0.5) \
				.rumble(0.05, 1.6, 0.45).echoes(0.21, 0.34, 3).normalise(0.95).stream()
		"victory":
			return DeepSynth.new(1.8).chord(0.0, 1.1, C5, [0, 4, 7, 12], 0.3, DeepSynth.CHIME_PARTIALS, 0.09) \
				.sparkle(0.2, 1.0, 0.12, 2200.0, 5600.0, 18).rumble(0.0, 0.5, 0.14) \
				.echoes(0.17, 0.26, 2).normalise(0.84).stream()
		"defeat":
			return DeepSynth.new(2.0).chord(0.0, 1.4, 196.0, [0, 3, 7], 0.3, DeepSynth.BELL_PARTIALS, 0.12) \
				.tone(0.1, 1.2, 150.0, 74.0, 0.26, "saw", 1.4, 0.2).rumble(0.0, 1.2, 0.3) \
				.echoes(0.23, 0.3, 2).normalise(0.8).stream()
		"cave_rumble":
			return DeepSynth.new(2.6).rumble(0.0, 2.2, 0.4).noise(0.3, 1.2, 0.08, 400.0, 120.0, 1.4, 0.4) \
				.echoes(0.29, 0.3, 2).normalise(0.5).stream()
		"ore":
			## Coins and cut stone falling together.
			var coins := DeepSynth.new(0.7)
			for i in range(9):
				var when: float = coins.rng.randf() * 0.34
				coins.bell(when, coins.rng.randf_range(0.14, 0.3), coins.rng.randf_range(1400.0, 3200.0), coins.rng.randf_range(0.12, 0.26), DeepSynth.METAL_PARTIALS, 3.2)
				coins.clack(when, 0.1, coins.rng.randf_range(900.0, 2000.0))
			return coins.normalise(0.7).stream()

		# --- the mine ---------------------------------------------------------------------------
		"pick_strike":
			## Steel into rock: the ring, the bite, and what falls off.
			return DeepSynth.new(0.6).noise(0.0, 0.05, 0.5, 11000.0, 1400.0, 4.0, 0.0006) \
				.bell(0.0, 0.16, 1180.0, 0.24, DeepSynth.METAL_PARTIALS, 4.0).thump(0.0, 0.2, 95.0, 0.5, 0.4) \
				.clatter(0.06, 0.3, 0.1, 5, 600.0).normalise(0.86).stream()
		"rock_break":
			return DeepSynth.new(0.9).noise(0.0, 0.5, 0.42, 3000.0, 180.0, 2.2, 0.004) \
				.thump(0.0, 0.3, 80.0, 0.5, 0.4).clatter(0.08, 0.5, 0.2, 9, 480.0) \
				.echoes(0.13, 0.22, 2).normalise(0.86).stream()
		"stone_found":
			return DeepSynth.new(1.0).bell(0.0, 0.6, 1318.5, 0.34, DeepSynth.CHIME_PARTIALS, 2.4) \
				.bell(0.07, 0.5, 1975.5, 0.2, DeepSynth.CHIME_PARTIALS, 2.6) \
				.sparkle(0.05, 0.6, 0.12, 2600.0, 6400.0, 12).normalise(0.72).stream()
		"tunnel":
			## Walking into the dark: air, two footfalls, and the weight overhead.
			return DeepSynth.new(0.9).whoosh(0.0, 0.5, 0.26, 1100.0, 220.0) \
				.thump(0.06, 0.16, 110.0, 0.3, 0.5).thump(0.3, 0.16, 96.0, 0.26, 0.5) \
				.rumble(0.0, 0.7, 0.16).normalise(0.72).stream()
		"landing":
			## Somewhere to put the lamp down.
			return DeepSynth.new(1.6).chord(0.0, 1.1, 261.63, [0, 7, 12], 0.3, DeepSynth.CHIME_PARTIALS, 0.07) \
				.echoes(0.19, 0.28, 2).normalise(0.68).stream()
		"lift":
			## Old machinery taking the weight.
			return DeepSynth.new(1.4).tone(0.0, 1.0, 124.0, 88.0, 0.3, "saw", 1.2, 0.2, 0.03, 4.0) \
				.rumble(0.0, 1.1, 0.34).noise(0.0, 0.9, 0.14, 1200.0, 300.0, 1.4, 0.3, 200.0) \
				.bell(0.9, 0.4, 420.0, 0.22, DeepSynth.METAL_PARTIALS, 3.2).normalise(0.78).stream()
		"depart":
			## Two strokes on the shaft bell, the signal to lower, and the winch paying out
			## cable: the start of a day's work, bright rather than grim.
			var cage := DeepSynth.new(1.6).bell(0.0, 0.6, 783.99, 0.28, DeepSynth.CHIME_PARTIALS, 2.8) \
				.bell(0.22, 0.8, 1046.5, 0.26, DeepSynth.CHIME_PARTIALS, 2.5)
			var when: float = 0.42
			for i in range(9):
				cage.clack(when, 0.07 * (1.0 - float(i) / 12.0), 520.0)
				when += 0.075 + 0.012 * float(i)
			return cage.chord(0.5, 1.0, C5, [0, 4, 7, 12], 0.07, DeepSynth.CHIME_PARTIALS, 0.06) \
				.whoosh(0.4, 1.0, 0.06, 800.0, 360.0).echoes(0.17, 0.2, 2).normalise(0.3).stream()
		"lantern":
			return DeepSynth.new(0.7).whoosh(0.0, 0.3, 0.3, 500.0, 2400.0) \
				.noise(0.05, 0.4, 0.16, 5000.0, 1200.0, 2.0, 0.05, 900.0) \
				.bell(0.06, 0.4, C6, 0.22, DeepSynth.CHIME_PARTIALS, 2.8).normalise(0.7).stream()
		"oddity":
			## Whatever this is, it should not be down here.
			return DeepSynth.new(1.2).bell(0.0, 0.8, 587.33, 0.26, DeepSynth.BELL_PARTIALS, 1.8, 0.02) \
				.tone(0.1, 0.7, 880.0, 933.0, 0.14, "sine", 1.6, 0.25, 0.03, 3.0) \
				.sparkle(0.1, 0.8, 0.1, 1600.0, 5200.0, 12).echoes(0.17, 0.3, 2).normalise(0.66).stream()
		"buy":
			var till := DeepSynth.new(0.6).clack(0.0, 0.3, 700.0)
			for i in range(5):
				till.bell(0.03 + till.rng.randf() * 0.2, till.rng.randf_range(0.14, 0.26), till.rng.randf_range(1600.0, 2800.0), 0.16, DeepSynth.METAL_PARTIALS, 3.2)
			return till.normalise(0.7).stream()
		"salvage_save":
			return DeepSynth.new(0.6).bell(0.0, 0.42, 1568.0, 0.32, DeepSynth.CHIME_PARTIALS, 2.6) \
				.sparkle(0.04, 0.3, 0.1, 2600.0, 5600.0, 6).normalise(0.66).stream()
		"salvage_lose":
			return DeepSynth.new(0.5).thump(0.0, 0.26, 140.0, 0.5, 0.5) \
				.tone(0.0, 0.3, 260.0, 110.0, 0.24, "triangle", 2.6, 0.006).normalise(0.66).stream()
		"depth_card":
			return DeepSynth.new(1.2).bell(0.0, 0.8, 164.81, 0.36, DeepSynth.BELL_PARTIALS, 2.0) \
				.noise(0.0, 0.3, 0.14, 800.0, 200.0, 2.4, 0.03).echoes(0.15, 0.26, 2).normalise(0.62).stream()

		# --- the loupe: the slot machine the whole game is built around ----------------------
		"loupe_spin":
			return DeepSynth.new(0.9).tone(0.0, 0.7, 180.0, 900.0, 0.24, "saw", 0.8, 0.1, 0.02, 9.0) \
				.noise(0.0, 0.7, 0.14, 600.0, 3000.0, 0.9, 0.3, 300.0).normalise(0.6).stream()
		"reveal":
			return DeepSynth.new(1.4).whoosh(0.0, 0.2, 0.2, 2000.0, 400.0) \
				.chord(0.05, 0.9, C6, [0, 7], 0.3, DeepSynth.CHIME_PARTIALS, 0.04) \
				.sparkle(0.05, 1.0, 0.16, 2400.0, 7000.0, 20).normalise(0.82).stream()
		"grade_rough":
			## Nothing. A stone put back down on the bench.
			return DeepSynth.new(0.5).thump(0.0, 0.22, 150.0, 0.45, 0.5) \
				.bell(0.0, 0.26, 220.0, 0.2, DeepSynth.BELL_PARTIALS, 3.4).normalise(0.56).stream()
		"grade_fine":
			return DeepSynth.new(0.8).chord(0.0, 0.5, A4, [0, 7], 0.28, DeepSynth.CHIME_PARTIALS, 0.05) \
				.normalise(0.62).stream()
		"grade_precious":
			return DeepSynth.new(1.2).chord(0.0, 0.8, C5, [0, 4, 7], 0.3, DeepSynth.CHIME_PARTIALS, 0.06) \
				.sparkle(0.1, 0.6, 0.1, 2200.0, 5000.0, 10).normalise(0.72).stream()
		"grade_exquisite":
			return DeepSynth.new(1.7).chord(0.0, 1.1, 659.25, [0, 5, 9, 12], 0.3, DeepSynth.CHIME_PARTIALS, 0.07) \
				.sparkle(0.1, 1.1, 0.14, 2600.0, 6400.0, 18).echoes(0.15, 0.24, 2).normalise(0.84).stream()
		"grade_peerless":
			## The one a player will talk about next year. It is allowed to be enormous.
			return DeepSynth.new(2.6).chord(0.0, 1.5, 783.99, [0, 4, 7, 12], 0.3, DeepSynth.CHIME_PARTIALS, 0.08) \
				.chord(0.06, 1.6, 195.99, [0, 7], 0.22, DeepSynth.BELL_PARTIALS, 0.0) \
				.sparkle(0.1, 1.7, 0.16, 2600.0, 7600.0, 22).rumble(0.0, 1.0, 0.2) \
				.echoes(0.19, 0.32, 3).normalise(0.95).stream()
		"star":
			## The sound to listen for. Nothing else in the game climbs like this.
			var star := DeepSynth.new(1.6)
			var ladder: Array = [0, 7, 12, 16, 19]
			for i in range(ladder.size()):
				star.bell(float(i) * 0.075, 0.9 - float(i) * 0.06, C6 * pow(2.0, float(ladder[i]) / 12.0), 0.24, DeepSynth.CHIME_PARTIALS, 2.2)
			return star.sparkle(0.1, 1.2, 0.16, 3000.0, 8000.0, 16).echoes(0.11, 0.26, 3).normalise(0.88).stream()
		"keep":
			## The lid of the vault.
			return DeepSynth.new(0.7).thump(0.0, 0.3, 120.0, 0.55, 0.5).clack(0.02, 0.3, 520.0) \
				.bell(0.02, 0.4, 330.0, 0.22, DeepSynth.METAL_PARTIALS, 2.6).normalise(0.76).stream()
		"sell":
			var paid := DeepSynth.new(0.8)
			for i in range(11):
				var when: float = paid.rng.randf() * 0.4
				paid.bell(when, paid.rng.randf_range(0.16, 0.34), paid.rng.randf_range(1200.0, 3000.0), paid.rng.randf_range(0.12, 0.24), DeepSynth.METAL_PARTIALS, 3.0)
			return paid.clack(0.42, 0.24, 600.0).normalise(0.74).stream()
	return null
