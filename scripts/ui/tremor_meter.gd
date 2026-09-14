extends Control
## The tremor meter: how close the mine's boss is to breaking through. It fills with every
## step and every blow, and the three warnings the engine announces are marked on it so a
## party can see the next one coming.

const Seam = preload("res://scripts/core/seam.gd")
const WARNINGS := [500, 750, 900]

var tremor := 0
var boss_name := "The boss"
var _shake := 0.0
var reduced_motion := false

func _ready() -> void:
	custom_minimum_size = Vector2(200, 26)
	mouse_filter = Control.MOUSE_FILTER_PASS

func set_tremor(value: int, boss: String) -> void:
	if value > tremor:
		_shake = 0.35
	tremor = clampi(value, 0, Seam.TREMOR_FULL)
	boss_name = boss
	tooltip_text = "Tremors %d%%. %s breaks through when this fills, wherever the party is.\nEvery step down fills it; deeper steps and long fights fill it faster." % [roundi(fraction() * 100.0), boss_name]
	queue_redraw()

func fraction() -> float:
	return float(tremor) / float(Seam.TREMOR_FULL)

func _process(delta: float) -> void:
	if _shake > 0.0:
		_shake = maxf(0.0, _shake - delta)
		queue_redraw()

func _draw() -> void:
	var offset := Vector2.ZERO
	if _shake > 0.0 and not reduced_motion:
		offset = Vector2(sin(_shake * 90.0) * 2.0, 0.0)
	var bar := Rect2(offset + Vector2(0, 8), Vector2(size.x, size.y - 10))
	draw_rect(bar, Color("0b0e15"))
	var hot := Color("ffcf7a").lerp(Color("ff5b4f"), clampf((fraction() - 0.5) * 2.0, 0.0, 1.0))
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * fraction(), bar.size.y)), hot)
	# A crack along the filled part, so the bar reads as rock giving way, not a health bar.
	var points := PackedVector2Array()
	var steps := 18
	for index in range(steps + 1):
		var x: float = bar.size.x * fraction() * float(index) / float(steps)
		var y: float = bar.position.y + bar.size.y * (0.5 + 0.32 * sin(float(index) * 2.7))
		points.append(Vector2(bar.position.x + x, y))
	if points.size() > 1 and fraction() > 0.0:
		draw_polyline(points, Color("2a0f0c", 0.8), 1.5, true)
	for mark in WARNINGS:
		var x: float = bar.position.x + bar.size.x * float(mark) / float(Seam.TREMOR_FULL)
		draw_line(Vector2(x, bar.position.y - 3), Vector2(x, bar.end.y), Color("eef1f7", 0.55), 1.0)
	draw_rect(bar, Color("3a2e20"), false, 1.5)
	draw_string(get_theme_default_font(), Vector2(offset.x, 7), "TREMORS  %d%%" % roundi(fraction() * 100.0), HORIZONTAL_ALIGNMENT_LEFT, size.x, 10, hot if fraction() >= 0.5 else Color("d8c7a4"))
