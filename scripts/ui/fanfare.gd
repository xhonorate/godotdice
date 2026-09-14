extends Control
## The moment a fight ends, drawn across the battlefield: a title that lands like a blow,
## light breaking behind it and sparks thrown out from the middle — or, for a lost fight,
## a cold title and ash drifting down.
##
## It holds no animation state of its own. It is told when the moment began, on the reveal
## clock, and poses itself from that, so the page can be rebuilt under it mid-flourish.

enum Kind { VICTORY, BOSS, DEFEAT }

const GOLD := Color("e8b661")
const PALE := Color("fff1c2")
const BLOOD := Color("ff7a6b")
const ASH := Color("b8c0cc")
const SPARKS := 42
const LIFE := 3.2

var kind: int = Kind.VICTORY
var title := "VICTORY"
var subtitle := ""
var started := 0.0
var reduced := false
var clock: Callable

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size.y = 150

func _process(_delta: float) -> void:
	queue_redraw()

func _age() -> float:
	if reduced:
		return LIFE + 1.0
	var moment: float = float(clock.call()) if clock.is_valid() else float(Time.get_ticks_msec()) / 1000.0
	return maxf(0.0, moment - started)

func _draw() -> void:
	var age := _age()
	var centre := Vector2(size.x * 0.5, size.y * 0.46)
	var lost := kind == Kind.DEFEAT
	var tone: Color = BLOOD if lost else GOLD
	var land := ease(clampf(age / 0.32, 0.0, 1.0), 0.35)
	# Light behind the title: slow rays for a win, a low red haze for a loss.
	var bloom := clampf(age / 0.25, 0.0, 1.0) * (0.55 + 0.45 * clampf(1.0 - (age - 0.6) / 1.6, 0.0, 1.0))
	if lost:
		for ring in range(8, 0, -1):
			var t := float(ring) / 8.0
			draw_set_transform(centre, 0.0, Vector2(3.2, 0.7))
			draw_circle(Vector2.ZERO, size.y * 0.5 * t, Color(0.35, 0.02, 0.02, 0.05 * bloom))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	else:
		var rays := 18
		var turn := age * 0.35
		var reach := maxf(size.x, size.y) * 0.62
		for index in rays:
			var angle := turn + TAU * float(index) / float(rays)
			var width := 0.075
			var tip_a := centre + Vector2(cos(angle - width), sin(angle - width)) * reach
			var tip_b := centre + Vector2(cos(angle + width), sin(angle + width)) * reach
			draw_colored_polygon(PackedVector2Array([centre, tip_a, tip_b]), Color(tone, 0.07 * bloom))
		for ring in range(7, 0, -1):
			var t := float(ring) / 7.0
			draw_circle(centre, size.y * 0.55 * t, Color(PALE, 0.045 * bloom))
	# A flash the instant the title lands.
	var flash := clampf(1.0 - absf(age - 0.3) / 0.18, 0.0, 1.0)
	if flash > 0.0:
		for ring in range(6, 0, -1):
			var t := float(ring) / 6.0
			draw_circle(centre, maxf(size.x, size.y) * 0.5 * t, Color(PALE if not lost else BLOOD, 0.05 * flash))
	_draw_particles(age, centre, lost)
	var font := get_theme_default_font()
	var scale := lerpf(2.6, 1.0, land)
	var font_size := int(round(clampf(size.y * 0.42, 40.0, 84.0) * scale))
	var alpha := clampf(age / 0.14, 0.0, 1.0)
	var measured := font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var shake := Vector2.ZERO
	if age > 0.3 and age < 0.55:
		var jolt := (0.55 - age) / 0.25
		shake = Vector2(sin(age * 90.0), cos(age * 70.0)) * 5.0 * jolt
	var at := centre + shake + Vector2(-measured.x * 0.5, measured.y * 0.30)
	draw_string_outline(font, at + Vector2(0, 4), title, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 14, Color(0, 0, 0, 0.55 * alpha))
	draw_string_outline(font, at, title, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 9, Color(tone.darkened(0.7), alpha))
	draw_string(font, at, title, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(tone.lerp(PALE, 0.35 * flash), alpha))
	if not subtitle.is_empty():
		var sub_alpha := clampf((age - 0.55) / 0.35, 0.0, 1.0)
		var sub_size := 18
		var sub_measured := font.get_string_size(subtitle, HORIZONTAL_ALIGNMENT_LEFT, -1, sub_size)
		var sub_at := Vector2(centre.x - sub_measured.x * 0.5, at.y + 34.0)
		draw_string_outline(font, sub_at, subtitle, HORIZONTAL_ALIGNMENT_LEFT, -1, sub_size, 6, Color(0, 0, 0, 0.85 * sub_alpha))
		draw_string(font, sub_at, subtitle, HORIZONTAL_ALIGNMENT_LEFT, -1, sub_size, Color(ASH if lost else PALE, sub_alpha))
	# A win settles into a still frame; ash keeps falling for as long as the loss is on screen.
	if age > LIFE and not lost:
		set_process(false)

func _draw_particles(age: float, centre: Vector2, lost: bool) -> void:
	for index in SPARKS:
		var seed_a := _hash(index * 7 + 3)
		var seed_b := _hash(index * 13 + 11)
		var seed_c := _hash(index * 29 + 5)
		if lost:
			# Ash: drifts down from above the title, swaying, for as long as the moment lasts.
			var fall := fmod(age * (18.0 + 22.0 * seed_b) + seed_c * size.y, size.y + 20.0) - 10.0
			var x := seed_a * size.x + sin(age * (0.8 + seed_b) + index) * 14.0
			var fade := clampf(age / 0.8, 0.0, 1.0) * (0.25 + 0.35 * seed_c)
			draw_circle(Vector2(x, fall), 1.4 + 1.8 * seed_b, Color(ASH, fade))
			continue
		var launch := 0.26 + 0.12 * seed_c
		var life := age - launch
		if life <= 0.0 or life > 1.6:
			continue
		var angle := TAU * seed_a
		var speed := 180.0 + 320.0 * seed_b
		var at := centre + Vector2(cos(angle), sin(angle) * 0.6) * speed * life + Vector2(0, 160.0 * life * life)
		var fade := clampf(1.0 - life / 1.6, 0.0, 1.0)
		var tone := GOLD.lerp(PALE, seed_c)
		var reach := 2.0 + 3.0 * seed_c
		draw_line(at - Vector2(reach, 0), at + Vector2(reach, 0), Color(tone, fade), 1.6, true)
		draw_line(at - Vector2(0, reach), at + Vector2(0, reach), Color(tone, fade), 1.6, true)
		draw_circle(at, reach * 0.35, Color(tone, fade))

func _hash(value: int) -> float:
	var mixed := int(value) * 2654435761
	mixed = (mixed ^ (mixed >> 13)) & 0x7fffffff
	return float(mixed % 10007) / 10007.0
