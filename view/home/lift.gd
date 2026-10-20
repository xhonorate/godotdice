extends Control
## The lift between the workshop and the mine. For a moment the screen is the shaft: the cage
## drops past the strata of every mine (or rises past them on the way home), slows, and the
## shaft opens onto wherever it stopped. The screens behind have already changed when it
## starts; the ride only covers the change, and a click cuts it short.

## The whole ride, and when it starts opening onto the screen behind, in seconds.
const RIDE: float = 1.25
const OPEN_AT: float = 0.8
## How many strata pass the cage over the ride.
const PASSES: float = 5.0

var down: bool = true
var heading: String = ""
var place: String = ""
## The mine the cage stops at; empty for the workshop at the top.
var stop: String = ""
var _clock: float = 0.0
var _strata: Array = []
var _sparks: Array = []
## Each band's facets, cut once: see `_stratum`.
var _facets: Dictionary = {}

static func ride(host: Control, going_down: bool, mine_key: String) -> void:
	## Plays a ride over `host`. Nothing is drawn headless, where nobody would see it.
	if DisplayServer.get_name() == "headless" or not host.is_inside_tree():
		return
	var lift: Control = (load("res://view/home/lift.gd") as GDScript).new()
	lift.down = going_down
	lift.heading = "Going down" if going_down else "Coming up"
	lift.place = DeepContent.mine_name(mine_key) if going_down else "The workshop"
	lift.stop = mine_key if going_down else ""
	host.add_child(lift)
	lift.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 90
	## The rock from the top down: the workshop's own, then every mine's.
	_strata.append(Color("6b6f80"))
	for key in DeepContent.mines_in_order():
		_strata.append(Color(str(DeepContent.mine(str(key)).get("palette", "8a96b6"))))
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for i in range(26):
		_sparks.append(Vector3(rng.randf(), rng.randf(), rng.randf_range(0.4, 1.0)))
	DeepAudio.play("lift", {"volume": 0.9})

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		_clock = maxf(_clock, OPEN_AT)
		accept_event()

func _process(delta: float) -> void:
	_clock += delta
	if _clock >= RIDE:
		queue_free()
		return
	var opening: float = clampf((_clock - OPEN_AT) / (RIDE - OPEN_AT), 0.0, 1.0)
	## Once it opens onto the screen behind, a click is for that screen: one on a card
	## showing through was eaten here.
	if _clock >= OPEN_AT:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	modulate.a = 1.0 - opening * opening * (3.0 - 2.0 * opening)
	queue_redraw()

func _travel() -> float:
	## How far the cage has come, 0 to 1: quick off the mark, slowing into the stop.
	var t: float = clampf(_clock / OPEN_AT, 0.0, 1.0)
	return 1.0 - pow(1.0 - t, 2.4)

func _speed() -> float:
	var t: float = clampf(_clock / OPEN_AT, 0.0, 1.0)
	return pow(1.0 - t, 1.4)

func _stratum(index: int, top: float, band: float, w: float, tone: Color) -> void:
	## One stratum: its rock broken into flat facets, and a ragged seam of its own colour
	## where the rock above gives way to it. The facets are cut once a band and then only
	## moved: cutting them again every frame (a hundred-odd polygons a band) cost the ride
	## a dozen milliseconds a frame.
	draw_rect(Rect2(0, top, w, band), tone.darkened(0.8))
	var key: String = "%d:%d:%d:%s" % [index, int(w), int(band), tone.to_html()]
	var cut: Dictionary = _facets.get(key, {})
	if cut.is_empty():
		cut = _cut(index, band, w, tone)
		_facets[key] = cut
	draw_set_transform(Vector2(0, top))
	RenderingServer.canvas_item_add_triangle_array(get_canvas_item(), cut.indices, cut.points, cut.colors)
	draw_polyline(cut.seam, Color(tone, 0.6), 3.0, true)
	draw_set_transform(Vector2.ZERO)

func _cut(index: int, band: float, w: float, tone: Color) -> Dictionary:
	## A band's facets with its top at 0: the triangles, a colour a corner, and the seam.
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(index) + 7919
	var step: float = 110.0
	var columns: int = int(ceil(w / step)) + 1
	var rows: int = 4
	var points: Array = []
	for r in range(rows + 1):
		var row: Array = []
		for c in range(columns + 1):
			var jitter := Vector2(rng.randf_range(-0.35, 0.35) * step if c > 0 and c < columns else 0.0, rng.randf_range(-0.3, 0.3) * band / rows if r > 0 and r < rows else 0.0)
			row.append(Vector2(float(c) * step, float(r) * band / rows) + jitter)
		points.append(row)
	var corners := PackedVector2Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	for r in range(rows):
		for c in range(columns):
			var a: Vector2 = points[r][c]
			var b: Vector2 = points[r][c + 1]
			var d: Vector2 = points[r + 1][c]
			var e: Vector2 = points[r + 1][c + 1]
			for tri in [[a, b, e, tone.darkened(rng.randf_range(0.7, 0.84))], [a, e, d, tone.darkened(rng.randf_range(0.72, 0.88))]]:
				for corner in range(3):
					indices.append(corners.size())
					corners.append(tri[corner])
					colors.append(tri[3])
	var seam := PackedVector2Array()
	for c in range(columns + 1):
		seam.append(points[0][c])
	return {"points": corners, "colors": colors, "indices": indices, "seam": seam}

func _draw() -> void:
	var w: float = size.x
	var h: float = size.y
	draw_rect(Rect2(Vector2.ZERO, size), DeepUi.INK)
	## The strata, scrolling up past a cage going down and down past one coming up, and
	## lined up so the cage stops in the middle of a band rather than on its floor.
	var cage_mid: float = h * 0.5 - 20.0
	var band: float = h * 0.62
	var offset: float = _travel() * PASSES * band
	var scroll: float = cage_mid - band * 0.5 + (-offset if down else offset)
	var count: int = _strata.size()
	## The band at the cage when it stops is the stop's own rock; those above are shallower.
	var full: float = PASSES * band
	var end_band: int = int(floor((band * 0.5 + (full if down else -full)) / band))
	var stop_index: int = 0 if stop.is_empty() else DeepContent.mines_in_order().find(stop) + 1
	var first: int = int(floor(-scroll / band)) - 1
	for i in range(first, first + int(ceil(h / band)) + 3):
		var top: float = float(i) * band + scroll
		var tone: Color = _strata[posmod(stop_index + i - end_band, count)]
		_stratum(i, top, band, w, tone)
	## The shaft: walls of rock either side, darker down the middle where the cage runs.
	var shaft_w: float = minf(w * 0.34, 520.0)
	var left: float = (w - shaft_w) * 0.5
	draw_rect(Rect2(left, 0, shaft_w, h), Color(0, 0, 0, 0.55))
	for x in [left, left + shaft_w]:
		draw_rect(Rect2(x - 2, 0, 4, h), Color(DeepUi.LINE_HI, 0.7))
	## Rock dust and sparks streaking past, longer the faster the cage goes.
	var speed: float = _speed()
	for spark in _sparks:
		var x: float = spark.x * w
		if x > left - 20.0 and x < left + shaft_w + 20.0:
			x = left - 30.0 - spark.x * 120.0 if spark.x < 0.5 else left + shaft_w + 30.0 + spark.x * 120.0
		var y: float = fposmod(spark.y * h + (-1.0 if down else 1.0) * offset * spark.z * 1.6, h)
		var length: float = 6.0 + 140.0 * speed * spark.z
		draw_rect(Rect2(x, y - (0.0 if down else length), 2.0, length), Color(DeepUi.PAPER, 0.18 * spark.z))
	## The cables and the cage, swaying a little at speed.
	var sway: float = sin(_clock * 37.0) * 2.5 * speed
	var cage := Rect2(Vector2(w * 0.5 - 120.0 + sway, cage_mid - 130.0), Vector2(240.0, 260.0))
	var brass := Color("b08a4a")
	for cx in [cage.position.x + 70.0, cage.end.x - 70.0]:
		draw_line(Vector2(cx, 0), Vector2(cx, cage.position.y), Color("7a6a50"), 3.0, true)
	draw_texture_rect(DeepUi.glow_texture(), cage.grow(90.0), false, Color(DeepUi.ACCENT, 0.18))
	draw_rect(cage, Color(0.05, 0.06, 0.1, 0.92))
	draw_texture_rect(DeepUi.glow_texture(), Rect2(cage.get_center() - Vector2(110, 140), Vector2(220, 200)), false, Color(DeepUi.ACCENT_HI, 0.3))
	draw_circle(cage.position + Vector2(cage.size.x * 0.5, 34.0), 7.0, DeepUi.ACCENT_HI)
	draw_rect(cage, brass, false, 4.0)
	for i in range(1, 5):
		var bx: float = cage.position.x + cage.size.x * float(i) / 5.0
		draw_line(Vector2(bx, cage.position.y), Vector2(bx, cage.end.y), Color(brass, 0.6), 2.0)
	for y in [cage.position.y + 18.0, cage.end.y - 18.0]:
		draw_line(Vector2(cage.position.x, y), Vector2(cage.end.x, y), brass, 3.0)
	draw_line(cage.position + Vector2(0, 18), cage.end - Vector2(0, 18), Color(brass, 0.35), 2.0)
	draw_line(Vector2(cage.end.x, cage.position.y + 18), Vector2(cage.position.x, cage.end.y - 18), Color(brass, 0.35), 2.0)
	## Where it is bound.
	var title_font: Font = DeepUi.display_font()
	var heading_size: int = 30
	var heading_w: float = title_font.get_string_size(heading, HORIZONTAL_ALIGNMENT_LEFT, -1, heading_size).x
	draw_string(title_font, Vector2((w - heading_w) * 0.5, cage.end.y + 62.0), heading, HORIZONTAL_ALIGNMENT_LEFT, -1, heading_size, DeepUi.PAPER)
	var body: Font = DeepUi.body_font()
	var place_w: float = body.get_string_size(place, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
	draw_string(body, Vector2((w - place_w) * 0.5, cage.end.y + 92.0), place, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, DeepUi.ACCENT)
