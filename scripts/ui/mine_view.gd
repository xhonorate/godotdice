extends Control
## A vein being worked, drawn as the rocks the authority rolled. Each swing in the log lands
## on its rock in turn: the rock jolts, cracks spread across it as the swings add up, and it
## bursts when the last one lands — throwing out ore, and a glint if a stone was inside.
##
## The swings were all decided before this was shown. How far through them the picture is
## comes from `index_source`, the same counter the screen skips to the end of.

const TONES := {"Small": Color("8d939f"), "Medium": Color("767b87"), "Large": Color("5c616d"),
	"Gold": Color("c99a3c"), "Shiny": Color("8fc8e8")}
const REACH := {"Small": 0.30, "Medium": 0.37, "Large": 0.45, "Gold": 0.36, "Shiny": 0.36}
const GOLD := Color("e8b661")
const SPARK := Color("fff1c2")

var rocks: Array = []
var events: Array = []
## Hero id → {"name", "tint"}.
var heroes: Dictionary = {}
var index_source: Callable
var reduced := false
var _clock := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size.y = 230

func _process(delta: float) -> void:
	_clock += delta
	queue_redraw()

func _hash(value: int) -> float:
	var mixed := int(value) * 2654435761
	mixed = (mixed ^ (mixed >> 13)) & 0x7fffffff
	return float(mixed % 10007) / 10007.0

func shown() -> int:
	var index: int = int(index_source.call()) if index_source.is_valid() else events.size()
	return clampi(index, 0, events.size())

func _draw() -> void:
	if rocks.is_empty():
		return
	var at_step := shown()
	var progress: Dictionary = {}
	var broken: Dictionary = {}
	var struck: Dictionary = {}
	var ore := 0
	for index in at_step:
		var event: Dictionary = events[index]
		var rock_id := str(event.get("rock_id", ""))
		progress[rock_id] = int(event.get("progress", 0))
		struck[rock_id] = index
		if event.get("broken", false):
			broken[rock_id] = true
	for rock in rocks:
		if broken.has(str(rock.get("id", ""))):
			ore += int(rock.get("ore", 0))
	var ticker_height := 30.0
	var area := Rect2(Vector2(0, ticker_height), size - Vector2(0, ticker_height))
	var columns := maxi(1, ceili(sqrt(float(rocks.size()) * area.size.x / maxf(area.size.y, 1.0))))
	var rows := maxi(1, ceili(float(rocks.size()) / float(columns)))
	var cell := Vector2(area.size.x / float(columns), area.size.y / float(rows))
	var font := ThemeDB.fallback_font
	for index in rocks.size():
		var rock: Dictionary = rocks[index]
		var rock_id := str(rock.get("id", ""))
		var kind := str(rock.get("kind", "Medium"))
		var centre := area.position + Vector2(cell.x * (float(index % columns) + 0.5), cell.y * (float(index / columns) + 0.55))
		var radius := minf(cell.x, cell.y) * float(REACH.get(kind, 0.36))
		var tone: Color = TONES.get(kind, TONES.Medium)
		var hits := maxi(1, int(rock.get("hits", 1)))
		var done := int(progress.get(rock_id, 0))
		# How long ago this rock was last hit, in swings: the jolt and the burst read from it.
		var since := float(at_step - 1 - int(struck.get(rock_id, -99)))
		draw_set_transform(centre + Vector2(0, radius * 0.85), 0.0, Vector2(1.0, 0.25))
		draw_circle(Vector2.ZERO, radius * 1.05, Color(0, 0, 0, 0.35))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		if broken.has(rock_id):
			_draw_rubble(centre, radius, tone, index, rock, since)
			continue
		var jolt := Vector2.ZERO
		if since == 0.0 and not reduced:
			jolt = Vector2(sin(_clock * 60.0), cos(_clock * 47.0)) * radius * 0.06
		var outline := PackedVector2Array()
		for corner in 9:
			var angle := TAU * float(corner) / 9.0 + _hash(index * 5 + corner) * 0.3
			var bulge := 0.78 + 0.26 * _hash(index * 13 + corner * 7)
			outline.append(centre + jolt + Vector2(cos(angle), sin(angle) * 0.82) * radius * bulge)
		draw_colored_polygon(outline, tone.darkened(0.15))
		var facet := PackedVector2Array()
		for point in outline:
			facet.append(centre + jolt + (point - centre - jolt) * 0.62 + Vector2(-radius * 0.12, -radius * 0.14))
		draw_colored_polygon(facet, tone.lightened(0.12))
		var closed := outline.duplicate()
		closed.append(outline[0])
		draw_polyline(closed, tone.darkened(0.6), 2.0, true)
		if kind in ["Gold", "Shiny"]:
			var twinkle := maxf(0.0, sin(_clock * 3.0 + index))
			var glint := centre + jolt + Vector2(radius * 0.25, -radius * 0.2)
			draw_line(glint - Vector2(4, 0) * twinkle, glint + Vector2(4, 0) * twinkle, Color(SPARK, twinkle), 1.5, true)
			draw_line(glint - Vector2(0, 4) * twinkle, glint + Vector2(0, 4) * twinkle, Color(SPARK, twinkle), 1.5, true)
		# Cracks: one for each swing it has taken, reaching further towards the break.
		for crack in done:
			var angle := TAU * _hash(index * 31 + crack * 11)
			var length := radius * (0.45 + 0.5 * float(crack + 1) / float(hits))
			var from := centre + jolt
			var bend := from + Vector2(cos(angle), sin(angle)) * length * 0.5 + Vector2(cos(angle + 1.4), sin(angle + 1.4)) * radius * 0.12
			var to := from + Vector2(cos(angle), sin(angle)) * length
			draw_polyline(PackedVector2Array([from, bend, to]), Color(0.05, 0.05, 0.07, 0.9), 2.2, true)
		var tally := "%d / %d" % [done, hits]
		var measured := font.get_string_size(tally, HORIZONTAL_ALIGNMENT_LEFT, -1, 12)
		draw_string_outline(font, centre + Vector2(-measured.x * 0.5, radius + 16.0), tally, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, 4, Color(0, 0, 0, 0.8))
		draw_string(font, centre + Vector2(-measured.x * 0.5, radius + 16.0), tally, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1, 1, 1, 0.7))
	var line := ""
	if at_step <= 0:
		line = "The party sets to work…"
	elif at_step < events.size():
		var event: Dictionary = events[at_step - 1]
		line = "Swing %d of %d  ·  %s" % [at_step, events.size(), str(heroes.get(str(event.get("actor_id", "")), {}).get("name", "A hero"))]
	else:
		line = "The vein is spent: %d swings." % events.size()
	draw_string_outline(font, Vector2(4, 20), line, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, 5, Color(0, 0, 0, 0.8))
	draw_string(font, Vector2(4, 20), line, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("cfe9dc"))
	var tally_text := "%d ORE" % ore
	var width := font.get_string_size(tally_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x
	draw_string_outline(font, Vector2(size.x - width - 6, 22), tally_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, 6, Color(0, 0, 0, 0.8))
	draw_string(font, Vector2(size.x - width - 6, 22), tally_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, GOLD)

func _draw_rubble(centre: Vector2, radius: float, tone: Color, index: int, rock: Dictionary, since: float) -> void:
	## A broken rock: shards on the floor, a burst of dust the moment it went, and whatever
	## it was holding left glinting among the pieces.
	var burst := 0.0 if reduced else clampf(1.0 - since / 3.0, 0.0, 1.0)
	for shard in 5:
		var angle := TAU * float(shard) / 5.0 + _hash(index * 3 + shard)
		var spread := radius * (0.45 + 0.35 * (1.0 - burst))
		var at := centre + Vector2(cos(angle), sin(angle) * 0.45) * spread + Vector2(0, radius * 0.35)
		var piece := PackedVector2Array()
		for corner in 4:
			var turn := angle + TAU * float(corner) / 4.0 + _hash(index * 9 + shard * 4 + corner)
			piece.append(at + Vector2(cos(turn), sin(turn)) * radius * 0.2)
		draw_colored_polygon(piece, tone.darkened(0.25))
	if burst > 0.0:
		draw_circle(centre, radius * (1.0 + 0.6 * (1.0 - burst)), Color(tone.lightened(0.4), 0.25 * burst))
	if int(rock.get("ore", 0)) > 0:
		for coin in mini(5, 1 + int(rock.get("ore", 0)) / 10):
			var at := centre + Vector2((_hash(index * 17 + coin) - 0.5) * radius * 1.2, radius * (0.2 + 0.2 * _hash(index * 19 + coin)))
			draw_circle(at, 3.5, GOLD)
			draw_circle(at - Vector2(1, 1), 1.4, SPARK)
	if not rock.get("gems", []).is_empty():
		var twinkle := 0.6 + 0.4 * sin(_clock * 4.0 + index)
		var at := centre + Vector2(0, radius * 0.05)
		draw_colored_polygon(PackedVector2Array([at + Vector2(0, -7), at + Vector2(6, 0), at + Vector2(0, 7), at + Vector2(-6, 0)]), Color("b98bff"))
		draw_line(at - Vector2(10, 0) * twinkle, at + Vector2(10, 0) * twinkle, Color(SPARK, twinkle), 1.5, true)
		draw_line(at - Vector2(0, 10) * twinkle, at + Vector2(0, 10) * twinkle, Color(SPARK, twinkle), 1.5, true)
