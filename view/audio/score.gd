class_name DeepScore
extends RefCounted
## Every piece of music in the game, written as a few lines of intent.
##
## A piece is not notes: it is a key and a mode, a tempo, a chord for every two bars, the
## voices that play it and a seed the tune is drawn from. `composer.gd` writes the notes, in
## five layers that always play together (see `DeepComposer.LAYERS`), and the score player in
## `music.gd` turns the layers up and down with what is happening in the mine.
##
## Each mine has three pieces to choose between, the workshop two. Which one plays is the
## player's pick on the Soundtrack page (Esc, Settings, Soundtrack); the first is the default.
##
## Chords are scale degrees counted from 0 (the key's own chord) in the piece's mode: in D
## dorian, 0 is D minor, 3 is G major, 6 is C major. `chords` is the first eight two-bar
## phrases, `bridge` the four after them; the last of each should lead home.
##
## Voices: pads `pad_warm`, `pad_glass`, `pad_choir`, `pad_dark`; basses `bass_sub`,
## `bass_pluck`, `bass_saw`; tunes `lead_flute`, `lead_bell`, `lead_glass`, `lead_pluck`,
## `lead_marimba`, `lead_reed`; drum kits `frame`, `drip`, `glass`, `wood`, `anvil`, `chime`,
## `void`, `hearth` (see `DeepComposer.KITS`).

## The workshop is not a mine, but it has music and air of its own.
const HOME: String = "HOME"

## Where each place's air comes from: the family of rock it is cut in.
const AIR: Dictionary = {HOME: "workshop", "QUARRY": "galleries", "SEEPS": "seeps", "GLASS_VEINS": "crystal",
	"WARRENS": "fungal", "FURNACE": "magma", "GEODE": "geode", "RIFT": "rift"}

## The places in the order the Soundtrack page lists them.
const PLACES: Array = [HOME, "QUARRY", "SEEPS", "GLASS_VEINS", "WARRENS", "FURNACE", "GEODE", "RIFT"]

const BOOK: Dictionary = {
	HOME: ["home_bench", "home_lamplight"],
	"QUARRY": ["quarry_lantern", "quarry_timber", "quarry_galleries"],
	"SEEPS": ["seeps_lanterns", "seeps_sluice", "seeps_sump"],
	"GLASS_VEINS": ["glass_prism", "glass_kaleidoscope", "glass_black"],
	"WARRENS": ["warrens_rootwork", "warrens_spores", "warrens_heartrot"],
	"FURNACE": ["furnace_anvil", "furnace_slagfall", "furnace_kiln"],
	"GEODE": ["geode_amethyst", "geode_gilded", "geode_crown"],
	"RIFT": ["rift_void", "rift_remembered", "rift_unmaking"],
}

const TRACKS: Dictionary = {
	## The workshop: warm, unhurried, a guitar by the fire. No fight is ever had here, so it is
	## written in three layers only.
	"home_bench": {"name": "The Bench", "key": "D", "mode": "mixolydian", "bpm": 76, "meter": 4, "seed": 11,
		"chords": [0, 3, 0, 6, 0, 3, 4, 4], "bridge": [5, 3, 1, 4],
		"pad": "pad_warm", "bass": "bass_pluck", "bass_style": "walk", "lead": "lead_pluck", "kit": "hearth",
		"layers": 3, "drone": false, "echo": 0.18},
	"home_lamplight": {"name": "Lamplight", "key": "F", "mode": "lydian", "bpm": 66, "meter": 3, "seed": 23,
		"chords": [0, 1, 0, 4, 0, 1, 5, 4], "bridge": [3, 1, 5, 4],
		"pad": "pad_glass", "bass": "bass_sub", "bass_style": "pedal", "lead": "lead_bell", "lead_octave": 1, "kit": "hearth",
		"layers": 3, "drone": false, "echo": 0.3},

	## The Quarry: timber, lamp oil and dust. Earthy and folk-like, mostly dorian.
	"quarry_lantern": {"name": "Lantern Light", "key": "D", "mode": "dorian", "bpm": 88, "meter": 4, "seed": 101,
		"chords": [0, 6, 3, 0, 0, 6, 4, 4], "bridge": [2, 3, 6, 4],
		"pad": "pad_warm", "bass": "bass_pluck", "bass_style": "walk", "lead": "lead_pluck", "arp": "lead_marimba", "arp_rate": 2, "kit": "frame"},
	"quarry_timber": {"name": "Pick and Timber", "key": "E", "mode": "aeolian", "bpm": 96, "meter": 4, "seed": 117,
		"chords": [0, 5, 2, 6, 0, 5, 3, 4], "bridge": [3, 6, 2, 4],
		"pad": "pad_warm", "bass": "bass_pluck", "bass_style": "syncop", "lead": "lead_flute", "arp": "lead_pluck", "arp_rate": 1, "kit": "frame"},
	"quarry_galleries": {"name": "Old Galleries", "key": "A", "mode": "dorian", "bpm": 80, "meter": 3, "seed": 131,
		"chords": [0, 3, 0, 6, 0, 3, 6, 4], "bridge": [5, 6, 3, 4],
		"pad": "pad_choir", "bass": "bass_sub", "bass_style": "walk", "lead": "lead_marimba", "arp": "lead_pluck", "arp_rate": 2, "kit": "wood"},

	## The Seeps: water in every crack. Slow, wet, echoing; bells that drip.
	"seeps_lanterns": {"name": "Drowned Lanterns", "key": "C", "mode": "aeolian", "bpm": 72, "meter": 3, "seed": 203,
		"chords": [0, 5, 3, 4, 0, 5, 6, 4], "bridge": [2, 5, 3, 4],
		"pad": "pad_glass", "bass": "bass_sub", "bass_style": "pedal", "lead": "lead_glass", "lead_octave": 1, "arp": "lead_bell", "arp_rate": 2, "kit": "drip", "echo": 0.42},
	"seeps_sluice": {"name": "Lock and Sluice", "key": "F#", "mode": "dorian", "bpm": 84, "meter": 4, "seed": 219,
		"chords": [0, 3, 0, 6, 5, 3, 6, 4], "bridge": [2, 3, 1, 4],
		"pad": "pad_glass", "bass": "bass_sub", "bass_style": "syncop", "lead": "lead_flute", "arp": "lead_bell", "arp_rate": 1, "kit": "drip", "echo": 0.35},
	"seeps_sump": {"name": "The Black Sump", "key": "B", "mode": "aeolian", "bpm": 66, "meter": 4, "seed": 227,
		"chords": [0, 5, 0, 6, 0, 5, 3, 4], "bridge": [5, 2, 6, 4],
		"pad": "pad_dark", "bass": "bass_sub", "bass_style": "pedal", "lead": "lead_bell", "arp": "lead_glass", "arp_rate": 2, "kit": "drip", "echo": 0.45},

	## The Glass Veins: crystal. Bright, ringing, lydian, arpeggios like light through a prism.
	"glass_prism": {"name": "Prism Song", "key": "E", "mode": "lydian", "bpm": 100, "meter": 4, "seed": 307,
		"chords": [0, 1, 0, 4, 5, 1, 3, 4], "bridge": [5, 1, 2, 4],
		"pad": "pad_glass", "bass": "bass_sub", "bass_style": "syncop", "lead": "lead_bell", "lead_octave": 1, "arp": "lead_bell", "arp_rate": 1, "kit": "glass", "echo": 0.3},
	"glass_kaleidoscope": {"name": "Kaleidoscope", "key": "G", "mode": "lydian", "bpm": 92, "meter": 3, "seed": 311,
		"chords": [0, 1, 5, 4, 0, 1, 2, 4], "bridge": [3, 1, 5, 4],
		"pad": "pad_choir", "bass": "bass_sub", "bass_style": "walk", "lead": "lead_glass", "lead_octave": 1, "arp": "lead_pluck", "arp_rate": 1, "kit": "glass", "echo": 0.3},
	"glass_black": {"name": "Black Glass", "key": "C#", "mode": "phrygian", "bpm": 84, "meter": 4, "seed": 329,
		"chords": [0, 1, 0, 6, 0, 1, 5, 6], "bridge": [3, 1, 5, 6],
		"pad": "pad_dark", "bass": "bass_saw", "bass_style": "pedal", "lead": "lead_glass", "lead_octave": 1, "arp": "lead_bell", "arp_rate": 1, "kit": "glass", "echo": 0.35},

	## The Warrens: fungus and roots. Woody, organic, a little sick.
	"warrens_rootwork": {"name": "Rootwork", "key": "E", "mode": "phrygian", "bpm": 84, "meter": 4, "seed": 401,
		"chords": [0, 1, 0, 6, 0, 1, 3, 6], "bridge": [5, 1, 3, 6],
		"pad": "pad_choir", "bass": "bass_pluck", "bass_style": "syncop", "lead": "lead_marimba", "arp": "lead_marimba", "arp_rate": 1, "kit": "wood"},
	"warrens_spores": {"name": "Spore Drift", "key": "D", "mode": "dorian", "bpm": 70, "meter": 3, "seed": 419,
		"chords": [0, 3, 2, 0, 0, 3, 6, 4], "bridge": [5, 3, 6, 4],
		"pad": "pad_warm", "bass": "bass_sub", "bass_style": "pedal", "lead": "lead_flute", "arp": "lead_marimba", "arp_rate": 2, "kit": "wood", "echo": 0.3},
	"warrens_heartrot": {"name": "Heartrot", "key": "G", "mode": "harmonic", "bpm": 90, "meter": 4, "seed": 431,
		"chords": [0, 5, 3, 4, 0, 5, 1, 4], "bridge": [3, 0, 5, 4],
		"pad": "pad_dark", "bass": "bass_pluck", "bass_style": "syncop", "lead": "lead_reed", "arp": "lead_marimba", "arp_rate": 1, "kit": "wood"},

	## The Furnace: lava and slag. Heavy, hammered, harmonic minor, anvils on the backbeat.
	"furnace_anvil": {"name": "Anvil Hymn", "key": "D", "mode": "harmonic", "bpm": 104, "meter": 4, "seed": 503,
		"chords": [0, 5, 3, 4, 0, 5, 1, 4], "bridge": [5, 3, 6, 4],
		"pad": "pad_dark", "bass": "bass_saw", "bass_style": "syncop", "lead": "lead_reed", "arp": "lead_pluck", "arp_rate": 1, "kit": "anvil"},
	"furnace_slagfall": {"name": "Slagfall", "key": "A", "mode": "phrygian_dominant", "bpm": 96, "meter": 4, "seed": 521,
		"chords": [0, 1, 0, 6, 0, 1, 5, 1], "bridge": [3, 6, 1, 0],
		"pad": "pad_dark", "bass": "bass_saw", "bass_style": "pedal", "lead": "lead_reed", "arp": "lead_marimba", "arp_rate": 1, "kit": "anvil"},
	"furnace_kiln": {"name": "Kiln Heart", "key": "F", "mode": "harmonic", "bpm": 112, "meter": 4, "seed": 537,
		"chords": [0, 3, 4, 0, 5, 3, 1, 4], "bridge": [3, 5, 1, 4],
		"pad": "pad_warm", "bass": "bass_saw", "bass_style": "syncop", "lead": "lead_pluck", "arp": "lead_pluck", "arp_rate": 1, "kit": "anvil"},

	## The Geode: crystal and gold. Wonder, a little grandeur; choirs and bells.
	"geode_amethyst": {"name": "Amethyst Throat", "key": "Bb", "mode": "lydian", "bpm": 86, "meter": 4, "seed": 601,
		"chords": [0, 1, 5, 4, 0, 1, 2, 4], "bridge": [5, 2, 1, 4],
		"pad": "pad_choir", "bass": "bass_sub", "bass_style": "walk", "lead": "lead_bell", "lead_octave": 1, "arp": "lead_bell", "arp_rate": 2, "kit": "chime", "echo": 0.3},
	"geode_gilded": {"name": "Gilded Hollow", "key": "Eb", "mode": "mixolydian", "bpm": 94, "meter": 4, "seed": 617,
		"chords": [0, 6, 3, 0, 0, 6, 1, 4], "bridge": [5, 3, 6, 4],
		"pad": "pad_warm", "bass": "bass_pluck", "bass_style": "syncop", "lead": "lead_flute", "arp": "lead_marimba", "arp_rate": 1, "kit": "chime"},
	"geode_crown": {"name": "The Hollow Crown", "key": "C", "mode": "aeolian", "bpm": 78, "meter": 3, "seed": 631,
		"chords": [0, 5, 2, 6, 0, 5, 3, 4], "bridge": [5, 6, 2, 4],
		"pad": "pad_choir", "bass": "bass_sub", "bass_style": "walk", "lead": "lead_glass", "lead_octave": 1, "arp": "lead_bell", "arp_rate": 2, "kit": "chime", "echo": 0.35},

	## The Rift: below everything. Slow, unmoored, detuned; the ground has stopped making sense.
	"rift_void": {"name": "The Infinite Void", "key": "B", "mode": "locrian", "bpm": 64, "meter": 4, "seed": 701,
		"chords": [0, 1, 0, 6, 0, 1, 4, 6], "bridge": [5, 1, 3, 6],
		"pad": "pad_dark", "bass": "bass_sub", "bass_style": "pedal", "lead": "lead_glass", "lead_octave": 1, "arp": "lead_bell", "arp_rate": 2, "kit": "void", "echo": 0.5},
	"rift_remembered": {"name": "Remembered", "key": "F#", "mode": "phrygian", "bpm": 76, "meter": 3, "seed": 719,
		"chords": [0, 1, 6, 0, 0, 1, 5, 6], "bridge": [3, 5, 1, 6],
		"pad": "pad_choir", "bass": "bass_sub", "bass_style": "pedal", "lead": "lead_bell", "arp": "lead_glass", "arp_rate": 2, "kit": "void", "echo": 0.45},
	"rift_unmaking": {"name": "Unmaking", "key": "D", "mode": "phrygian_dominant", "bpm": 88, "meter": 4, "seed": 733,
		"chords": [0, 1, 0, 6, 5, 1, 6, 1], "bridge": [3, 1, 5, 1],
		"pad": "pad_dark", "bass": "bass_saw", "bass_style": "syncop", "lead": "lead_reed", "arp": "lead_bell", "arp_rate": 1, "kit": "void", "echo": 0.35},
}

static func tracks_for(place: String) -> Array:
	return BOOK.get(place, [])

static func track(id: String) -> Dictionary:
	return TRACKS.get(id, {})

static func pick(place: String, picks: Dictionary = {}) -> String:
	## The piece that plays in a place: the player's pick if it is still in the book, else
	## the first written for it.
	var offered: Array = tracks_for(place)
	if offered.is_empty():
		offered = tracks_for("QUARRY")
	var chosen: String = str(picks.get(place, ""))
	return chosen if offered.has(chosen) else str(offered[0])

static func air(place: String) -> String:
	return str(AIR.get(place, "galleries"))

static func place_name(place: String) -> String:
	if place == HOME:
		return "The Workshop"
	return str(DeepContent.mine(place).get("name", place.capitalize()))
