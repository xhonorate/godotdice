extends Control
## A lost gem breaks into drifting facets, leaving a faint cracked outline. Presentation
## only: the caller has already removed it from the run or profile.

const Thumbs = preload("res://view/gems/thumbs.gd")

var _stone: Dictionary
var _edge: float
var _delay: float
var _age: float = 0.0
var _tone: Color
var _picture: Control
var _sounded: bool = false
var _animate: bool

func _init(stone: Dictionary, edge: float = 64.0, delay: float = 0.0, animate: bool = true) -> void:
	_stone = stone.duplicate(true)
	_edge = edge
	_delay = delay
	_animate = animate
	_tone = DeepUi.color(DeepStone.color(stone))
	custom_minimum_size = Vector2(edge, edge)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _ready() -> void:
	_picture = Thumbs.GemThumb.new(_stone, _edge * 0.8)
	_picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_picture.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_picture.position = -Vector2.ONE * _edge * 0.4
	add_child(_picture)
	if not _animate or DeepUi.headless():
		_age = _delay + 2.0
		_picture.hide()
		set_process(false)

func _process(delta: float) -> void:
	_age += delta
	var elapsed: float = _age - _delay
	if elapsed >= 0.0:
		if not _sounded:
			_sounded = true
			DeepAudio.from(self, "salvage_lose", {"volume": 0.7})
		_picture.modulate.a = maxf(0.0, 1.0 - elapsed * 7.0)
		queue_redraw()
	if elapsed > 1.5:
		set_process(false)

func _draw() -> void:
	var elapsed: float = maxf(0.0, _age - _delay)
	if _age < _delay:
		return
	var centre: Vector2 = size * 0.5
	var radius: float = _edge * 0.28
	var outline := PackedVector2Array([centre + Vector2(-radius, 0), centre + Vector2(0, -radius), centre + Vector2(radius, 0), centre + Vector2(0, radius), centre + Vector2(-radius, 0)])
	draw_polyline(outline, Color(_tone, 0.22), 1.5, true)
	draw_polyline(PackedVector2Array([centre + Vector2(0, -radius), centre + Vector2(-radius * 0.2, 0), centre + Vector2(radius * 0.3, radius * 0.25), centre + Vector2(0, radius)]), Color(_tone, 0.5), 1.5, true)
	if elapsed >= 1.5:
		return
	for index in range(10):
		var angle: float = TAU * float(index) / 10.0
		var drift: Vector2 = Vector2.from_angle(angle) * radius * (0.25 + elapsed * 1.8) + Vector2(0, elapsed * elapsed * radius * 0.5)
		var shard := PackedVector2Array()
		for corner in [Vector2(-0.15, -0.22), Vector2(0.23, 0), Vector2(-0.08, 0.27)]:
			shard.append(centre + drift + (corner * radius).rotated(angle + elapsed * 2.0))
		draw_colored_polygon(shard, Color(_tone.lightened(float(index % 3) * 0.2), maxf(0.0, 1.0 - elapsed / 1.5)))
