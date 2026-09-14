extends Control
## A small lit diorama for the top of a room: the chamber's own picture standing in a cave
## mouth, lit in the room's colour, with something moving in the air — embers over a camp
## fire, glints in a jeweller's lamp, dust in a working vein, mist at a chance meeting.
##
## It is drawn, not painted: a rock arch, a floor, a glow and the room's generated sprite.
## Replacing the sprite with real art needs no change here. Everything that moves is a pure
## function of a clock, so the scene costs one redraw a frame and holds no state worth saving.

const SPARK := Color("fff1c2")

var kind := "shop"
var accent := Color("e8b661")
var art: Texture2D
## A second, smaller picture beside the first: what an event is about, a cache, a pool.
var prop: Texture2D
var mood := ""
var reduced := false
var _clock := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true

func _process(delta: float) -> void:
	if reduced:
		return
	_clock += delta
	queue_redraw()

func _hash(value: int) -> float:
	var mixed := int(value) * 2654435761
	mixed = (mixed ^ (mixed >> 13)) & 0x7fffffff
	return float(mixed % 10007) / 10007.0

func _draw() -> void:
	var w := size.x
	var h := size.y
	if w < 4.0 or h < 4.0:
		return
	var deep := accent.darkened(0.86)
	var lit := accent.darkened(0.45)
	for band in 14:
		var t := float(band) / 13.0
		draw_rect(Rect2(0, h * t, w, h / 13.0 + 1.0), deep.lerp(lit, pow(1.0 - absf(t - 0.55) * 1.6, 2.0) * 0.55))
	var centre := Vector2(w * 0.5, h * 0.60)
	# The light the room keeps: a soft pool behind whatever stands in it.
	for ring in range(9, 0, -1):
		var t := float(ring) / 9.0
		draw_circle(centre, h * 0.62 * t, Color(accent.lightened(0.25), 0.055 * (1.0 - t)))
	if mood == "lift":
		var beam := PackedVector2Array([Vector2(w * 0.40, 0), Vector2(w * 0.60, 0), Vector2(w * 0.78, h), Vector2(w * 0.22, h)])
		draw_colored_polygon(beam, Color(SPARK, 0.07))
	# The floor, then the pool when there is one.
	draw_set_transform(Vector2(w * 0.5, h * 0.86), 0.0, Vector2(1.0, 0.22))
	draw_circle(Vector2.ZERO, w * 0.42, Color(0, 0, 0, 0.35))
	draw_circle(Vector2.ZERO, w * 0.30, Color(accent, 0.10))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if mood == "pool":
		draw_set_transform(Vector2(w * 0.5, h * 0.84), 0.0, Vector2(1.0, 0.24))
		draw_circle(Vector2.ZERO, w * 0.36, Color("123a4a"))
		draw_circle(Vector2.ZERO, w * 0.30, Color("1d5a6e"))
		for ripple in 3:
			var phase := fmod(_clock * 0.35 + float(ripple) / 3.0, 1.0)
			draw_arc(Vector2.ZERO, w * 0.05 + w * 0.26 * phase, 0.0, TAU, 40, Color("9fe0ff", 0.35 * (1.0 - phase)), 2.0 / 0.24 * 0.5, true)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	_rock_arch(w, h)
	var bob := sin(_clock * 1.6) * 3.0
	if art != null:
		var edge := minf(h * 0.62, w * 0.5)
		var spot := Rect2(centre - Vector2(edge, edge) * 0.5 + Vector2(-edge * 0.28 if prop != null else 0.0, bob - h * 0.04), Vector2(edge, edge))
		draw_texture_rect(art, spot.grow(2.0), false, Color(0, 0, 0, 0.25))
		draw_texture_rect(art, spot, false)
	if prop != null:
		var small := minf(h * 0.40, w * 0.32)
		var place := Rect2(centre + Vector2(small * 0.35, h * 0.06 - bob * 0.5), Vector2(small, small))
		draw_texture_rect(prop, place, false)
	_particles(w, h)
	# A vignette so the diorama sits in its frame.
	for edge_band in 6:
		var t := float(edge_band) / 6.0
		draw_rect(Rect2(Vector2.ZERO, size).grow(-t * 18.0), Color(0, 0, 0, 0.06), false, 18.0 / 6.0 + 1.0)

func _rock_arch(w: float, h: float) -> void:
	## Jagged rock down both sides and across the top, the same every frame.
	var rock := accent.darkened(0.92)
	var left := PackedVector2Array([Vector2(0, 0), Vector2(w * 0.20, 0)])
	var right := PackedVector2Array([Vector2(w, 0), Vector2(w * 0.80, 0)])
	var steps := 9
	for step in range(steps + 1):
		var t := float(step) / float(steps)
		left.append(Vector2(w * (0.16 - 0.10 * t) + _hash(step * 11 + 3) * w * 0.05, h * t))
		right.append(Vector2(w * (0.84 + 0.10 * t) - _hash(step * 17 + 5) * w * 0.05, h * t))
	left.append(Vector2(0, h))
	right.append(Vector2(w, h))
	draw_colored_polygon(left, rock)
	draw_colored_polygon(right, rock)
	var top := PackedVector2Array([Vector2(0, 0), Vector2(w, 0)])
	for step in range(steps, -1, -1):
		var t := float(step) / float(steps)
		top.append(Vector2(w * t, h * (0.05 + 0.07 * _hash(step * 23 + 7))))
	draw_colored_polygon(top, rock)

func _particles(w: float, h: float) -> void:
	var count := 26
	for index in count:
		var a := _hash(index * 7 + 1)
		var b := _hash(index * 13 + 2)
		var c := _hash(index * 31 + 3)
		match mood:
			"embers":
				var life := fmod(_clock * (0.22 + 0.25 * b) + c, 1.0)
				var at := Vector2(w * (0.40 + 0.20 * a) + sin(_clock * 2.0 + index) * 8.0 * life, h * (0.78 - 0.70 * life))
				draw_circle(at, 1.2 + 1.8 * (1.0 - life), Color(Color("ffb15a").lerp(Color("ff5a2a"), life), 0.9 * (1.0 - life)))
			"glints":
				var twinkle := maxf(0.0, sin(_clock * (1.5 + 2.0 * b) + c * TAU))
				var at := Vector2(w * (0.22 + 0.56 * a), h * (0.14 + 0.66 * c))
				var reach := 2.0 + 3.5 * twinkle
				draw_line(at - Vector2(reach, 0), at + Vector2(reach, 0), Color(SPARK, 0.8 * twinkle), 1.4, true)
				draw_line(at - Vector2(0, reach), at + Vector2(0, reach), Color(SPARK, 0.8 * twinkle), 1.4, true)
			"coins":
				var life := fmod(_clock * (0.10 + 0.12 * b) + c, 1.0)
				var at := Vector2(w * (0.22 + 0.56 * a), h * (-0.05 + 1.05 * life))
				draw_set_transform(at, 0.0, Vector2(absf(sin(_clock * 3.0 + index)) * 0.8 + 0.2, 1.0))
				draw_circle(Vector2.ZERO, 3.5, Color("e8b661", 0.55))
				draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			"mist":
				var drift := fmod(_clock * 0.03 * (0.5 + b) + a, 1.0)
				draw_circle(Vector2(w * drift, h * (0.45 + 0.45 * c)), h * (0.10 + 0.12 * b), Color(accent.lightened(0.5), 0.028))
			"lift":
				if index % 3 == 0:
					var life := fmod(_clock * 0.3 * (0.5 + b) + c, 1.0)
					draw_circle(Vector2(w * (0.40 + 0.20 * a), h * (1.0 - life)), 1.4, Color(SPARK, 0.5 * (1.0 - life)))
			_:
				var life := fmod(_clock * (0.04 + 0.05 * b) + c, 1.0)
				var at := Vector2(w * (0.2 + 0.6 * a) + sin(_clock * 0.7 + index) * 10.0, h * life)
				draw_circle(at, 1.0 + 1.2 * b, Color(SPARK, 0.22 * sin(life * PI)))
