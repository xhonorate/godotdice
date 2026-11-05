class_name DeepScore
extends RefCounted
## Every piece of music in the game, written as a few lines of intent.
##
## A piece is not notes: it is a key and a mode, a tempo, a chord for every two bars, the
## voices that play it and a seed the tune is drawn from, in four strips that always play
## together (see `DeepComposer.LAYERS`); the score player in `music.gd` turns the strips up
## and down with what is happening in the mine.
##
## The pieces are written in `content/score.json`. The game does not write them while it
## plays: each is baked ahead of time to one Ogg loop a strip in `audio/music/<id>/`, by
## `node tools/sound/bake_music.mjs`, from the engine in `tools/sound/synth.js` (the spec a
## track's `from` names). A strip there may be replaced by hand (a master from a DAW, say) as
## long as it stays the same length as the others. `composer.gd` writes a piece from the
## other fields only as a fallback, when a baked strip is missing.
##
## One piece a place since the sound review of November 2026; the book still allows more,
## and the first written for a place is the default.
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

## Where the pieces are written down: one line a piece, edited by hand or by the soundtrack
## editor (`node tools/data-browser/server.mjs`, then Soundtrack).
const FILE: String = "res://content/score.json"

static var _book_and_tracks: Array = _read()
## Each place's pieces, the default first.
static var BOOK: Dictionary = _book_and_tracks[0]
## Every piece's spec, by id.
static var TRACKS: Dictionary = _book_and_tracks[1]

static func _read() -> Array:
	var text: String = FileAccess.get_file_as_string(FILE)
	var parsed: Variant = JSON.parse_string(text)
	if not parsed is Dictionary:
		push_error("The score at %s could not be read" % FILE)
		return [{}, {}]
	var book: Dictionary = {}
	var places: Dictionary = parsed.get("places", {})
	for place in places:
		book[str(place)] = Array(places[place].get("tracks", []))
	var tracks: Dictionary = {}
	var written: Dictionary = parsed.get("tracks", {})
	for id in written:
		tracks[str(id)] = whole(written[id])
	return [book, tracks]

static func whole(value: Variant) -> Variant:
	## JSON has only one kind of number: a whole one is read back as the int it was written as.
	if value is float and is_equal_approx(value, roundf(value)):
		return int(value)
	if value is Array:
		return value.map(func(v: Variant) -> Variant: return whole(v))
	if value is Dictionary:
		var out: Dictionary = {}
		for key in value:
			out[key] = whole(value[key])
		return out
	return value

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
