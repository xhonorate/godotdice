extends Node
## Stones and dice photographed once and shown as pictures.
##
## A live stone is a SubViewport with its own world, four lights, glow and MSAA, and a page
## of fifty of them was the heaviest thing the game drew: every rebuild of the vault or a
## landing's haul made fifty new 3D scenes. Here a small pool of offscreen views takes each
## distinct stone or die in turn, renders it once, and hands back a texture keyed by exactly
## what the picture depends on. Grids, rails, merchants and hauls show those textures; the
## one stone the pointer rests on comes alive, and nothing else is ever live 3D.
##
## With no display the service never starts and every thumb keeps its flat 2D stand-in,
## which is drawn from the same outline the 3D stone is cut from.

const GemView = preload("res://view/gems/gem_view.gd")
const DiceView = preload("res://view/dice/dice_view.gd")
const GemMesh = preload("res://view/gems/gem_mesh.gd")
const DiceIcons = preload("res://view/dice/dice_icons.gd")

## The size stones and dice are photographed at. Heavy stones are photographed into a larger
## frame around the same centre, exactly as the live view draws them.
const GEM_EDGE := 176.0
const DIE_EDGE := 128.0
const STATIONS := 3
const FRAMES_TO_SETTLE := 3
const CACHE_LIMIT := 320

static var _service: Node = null
static var _textures: Dictionary = {}
static var _order: Array = []
static var _waiting: Dictionary = {}

var _queue: Array = []
var _gem_stations: Array = []
var _die_stations: Array = []
var _jobs: Array = []

static func headless() -> bool:
	return DisplayServer.get_name() == "headless"

static func service() -> Node:
	if headless():
		return null
	if _service != null and is_instance_valid(_service):
		return _service
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return null
	_service = load("res://view/gems/thumbs.gd").new()
	_service.name = "Thumbs"
	tree.root.add_child.call_deferred(_service)
	return _service

static func gem_key(stone: Dictionary) -> String:
	return "gem|" + GemView.thumbnail_key(stone) + "|" + str(stone.get("id", ""))

static func die_key(die: Dictionary, face: int) -> String:
	var faces: Array = []
	for f in die.get("faces", []):
		faces.append("%s%s" % [str(f.get("value", 0)) if f is Dictionary else str(f), str(f.get("kind", "")) if f is Dictionary else ""])
	return "die|%s|%s|%s|%d" % [str(die.get("key", die.get("shape", "D6"))), ",".join(faces), str(die.get("engraving", "")), face]

static func cached(key: String) -> Texture2D:
	return _textures.get(key, null)

static func request(key: String, kind: String, data: Dictionary, callback: Callable) -> Texture2D:
	## The picture if it has been taken; otherwise null now and `callback(texture)` later.
	var texture: Texture2D = _textures.get(key, null)
	if texture != null:
		return texture
	var node: Node = service()
	if node == null:
		return null
	if not _waiting.has(key):
		_waiting[key] = []
		node.call("_enqueue", {"key": key, "kind": kind, "data": data})
	_waiting[key].append(callback)
	return null

static func release() -> void:
	_textures.clear()
	_order.clear()
	_waiting.clear()

func _enqueue(job: Dictionary) -> void:
	_queue.append(job)

func _ready() -> void:
	## Stations stand far off the edge of the screen. They are real controls in the tree so
	## their viewports render, and nobody ever sees them.
	for i in range(STATIONS):
		var gem := GemView.new()
		gem.position = Vector2(-6000 - i * 400, -6000)
		gem.size = Vector2(GEM_EDGE, GEM_EDGE)
		gem.set_drift(false)
		add_child(gem)
		gem.call("_fit_frame")
		_gem_stations.append({"view": gem, "busy": false})
	for i in range(2):
		var die := DiceView.new()
		die.live = false
		die.position = Vector2(-6000 - i * 400, -5000)
		die.size = Vector2(DIE_EDGE, DIE_EDGE)
		add_child(die)
		_die_stations.append({"view": die, "busy": false})
	## Idle from the start: an unused station never renders a frame.
	for station in _gem_stations + _die_stations:
		_idle(station)

func _viewport_of(view: Control) -> SubViewport:
	return view.get("_viewport") as SubViewport

func _idle(station: Dictionary) -> void:
	station.busy = false
	var viewport := _viewport_of(station.view)
	if viewport != null:
		viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED

func _process(_delta: float) -> void:
	for job in _jobs.duplicate():
		job.frames -= 1
		if job.frames > 0:
			continue
		_jobs.erase(job)
		var viewport := _viewport_of(job.station.view)
		var texture: ImageTexture = null
		if viewport != null:
			var image: Image = viewport.get_texture().get_image()
			if image != null and not image.is_empty():
				image.generate_mipmaps()
				texture = ImageTexture.create_from_image(image)
		_idle(job.station)
		_store(str(job.key), texture)
	while not _queue.is_empty():
		var job: Dictionary = _queue.front()
		var stations: Array = _gem_stations if str(job.kind) == "gem" else _die_stations
		var free: Dictionary = {}
		for station in stations:
			if not bool(station.busy):
				free = station
				break
		if free.is_empty():
			break
		_queue.pop_front()
		_shoot(free, job)

func _shoot(station: Dictionary, job: Dictionary) -> void:
	station.busy = true
	var view: Control = station.view
	if str(job.kind) == "gem":
		view.call("configure", job.data.stone)
	else:
		view.call("configure", job.data.die, {}, false, false, DeepUi.ACCENT)
		var pivot: Node3D = view.get("_pivot")
		if pivot != null:
			var target: Quaternion = view.call("_orientation", int(job.data.get("face", 0)))
			pivot.quaternion = Quaternion.from_euler(Vector3(-0.42, 0.52, 0.0)) * target
	var viewport := _viewport_of(view)
	if viewport != null:
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_jobs.append({"key": job.key, "station": station, "frames": FRAMES_TO_SETTLE})

static func _store(key: String, texture: Texture2D) -> void:
	if texture != null:
		_textures[key] = texture
		_order.append(key)
		while _order.size() > CACHE_LIMIT:
			_textures.erase(_order.pop_front())
	for callback in _waiting.get(key, []):
		if callback.is_valid():
			callback.call(texture)
	_waiting.erase(key)

# --- the controls that show them -----------------------------------------------------------

class GemThumb extends Control:
	## A stone's picture, sized against the slot it sits in the way the live view is: a
	## heavy stone hangs over the edges. Until its photograph arrives it shows its own cut
	## outline flat. Rest the pointer on it and it comes alive and turns in the light.
	var stone: Dictionary = {}
	var live_on_hover: bool = true
	var glint: bool = false
	var _texture: Texture2D = null
	var _fade: float = 0.0
	var _hover: float = 0.0
	var _hovering: bool = false
	var _hover_time: float = 0.0
	var _live: Control = null
	var _clock: float = 0.0
	var _key: String = ""
	var _hue: Color = Color.WHITE
	var _outline: PackedVector2Array = PackedVector2Array()
	var _span: float = 1.0
	var _brilliance: float = 0.5

	func _init(new_stone: Dictionary = {}, edge: float = 64.0) -> void:
		custom_minimum_size = Vector2(edge, edge)
		mouse_filter = Control.MOUSE_FILTER_PASS
		clip_contents = false
		mouse_entered.connect(func() -> void:
			_hovering = true
			_hover_time = 0.0
			set_process(true))
		mouse_exited.connect(func() -> void:
			_hovering = false
			_end_live()
			set_process(true))
		if not new_stone.is_empty():
			configure(new_stone)

	func _gui_input(event: InputEvent) -> void:
		## Right-click anywhere a stone is shown opens the close look.
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT and not stone.is_empty():
			load("res://view/inspect/inspector.gd").stone(stone)
			accept_event()

	func configure(new_stone: Dictionary) -> void:
		stone = new_stone
		var thumbs = load("res://view/gems/thumbs.gd")
		var key: String = thumbs.gem_key(stone)
		if key == _key:
			return
		_key = key
		_hue = GemMesh.tint(stone)
		_span = GemMesh.carat_span(int(stone.get("carat", 1)))
		_brilliance = GemMesh.brilliance(GemMesh.clarity_grade(stone))
		_outline = GemMesh.girdle(stone)
		var appraised: bool = bool(stone.get("appraised", true))
		var tier: String = str(DeepStone.grade(stone).tier)
		var star: bool = false
		for inclusion in stone.get("inclusions", []):
			if str(DeepContent.inclusion(str(inclusion)).get("class", "")) == "STAR":
				star = true
		glint = star or (appraised and tier in ["EXQUISITE", "PEERLESS"])
		_texture = null
		_fade = 0.0
		var shot: Texture2D = thumbs.request(key, "gem", {"stone": stone}, _arrived.bind(key))
		if shot != null:
			_texture = shot
			_fade = 1.0
		set_process(glint or _texture == null)
		queue_redraw()

	func _arrived(texture: Texture2D, key: String) -> void:
		if key != _key or not is_instance_valid(self):
			return
		_texture = texture
		set_process(true)

	func _process(delta: float) -> void:
		_clock += delta
		var busy := glint
		if _texture != null and _fade < 1.0:
			_fade = minf(1.0, _fade + delta * 4.0)
			busy = true
		var goal: float = 1.0 if _hovering else 0.0
		if not is_equal_approx(_hover, goal):
			_hover = move_toward(_hover, goal, delta * 6.0)
			busy = true
		if _hovering and live_on_hover and _live == null:
			_hover_time += delta
			busy = true
			if _hover_time > 0.3:
				_start_live()
		queue_redraw()
		if not busy:
			set_process(false)

	func _start_live() -> void:
		if DisplayServer.get_name() == "headless" or stone.is_empty():
			return
		var view: Control = GemView.new()
		view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		view.mouse_filter = Control.MOUSE_FILTER_IGNORE
		view.set_drift(true)
		view.set_spin(0.9)
		view.configure(stone)
		view.modulate.a = 0.0
		add_child(view)
		## Its own halo would double the one drawn here.
		var halo: Node = view.get("_glow")
		if halo is CanvasItem:
			(halo as CanvasItem).visible = false
		_live = view
		var tween := create_tween()
		tween.tween_property(view, "modulate:a", 1.0, 0.18)

	func _end_live() -> void:
		if _live != null and is_instance_valid(_live):
			_live.queue_free()
		_live = null

	func _draw() -> void:
		var edge: float = minf(size.x, size.y)
		var centre: Vector2 = size * 0.5
		var lift: float = 1.0 + 0.07 * _hover
		## The light a clean stone throws on what it sits on; a cloudy one throws little.
		var halo: float = edge * _span * (1.25 + 0.25 * _hover)
		draw_texture_rect(DeepUi.glow_texture(), Rect2(centre - Vector2(halo, halo) * 0.5, Vector2(halo, halo)), false,
			Color(_hue, (0.10 + 0.22 * _brilliance) * (1.0 + _hover)))
		var live_shown: bool = _live != null and is_instance_valid(_live) and _live.modulate.a > 0.99
		if _fade < 1.0 and not live_shown:
			_draw_outline(centre, edge * 0.42 * _span * lift, 1.0 - _fade)
		if _texture != null and not live_shown:
			var reach: float = edge * (float(_texture.get_width()) / GEM_EDGE) * lift
			draw_texture_rect(_texture, Rect2(centre - Vector2(reach, reach) * 0.5, Vector2(reach, reach)), false, Color(1, 1, 1, _fade))
		if glint:
			## A travelling star of light: the thing a practised eye spots across the room.
			var phase: float = fmod(_clock * 0.55, 1.0)
			if phase < 0.45:
				var t: float = phase / 0.45
				var at: Vector2 = centre + Vector2(lerpf(-0.28, 0.24, t), lerpf(-0.24, 0.06, t)) * edge * _span
				var bright: float = sin(t * PI)
				var arm: float = edge * 0.22 * bright
				draw_line(at - Vector2(arm, 0), at + Vector2(arm, 0), Color(1, 1, 1, 0.85 * bright), 1.5, true)
				draw_line(at - Vector2(0, arm), at + Vector2(0, arm), Color(1, 1, 1, 0.85 * bright), 1.5, true)
				draw_texture_rect(DeepUi.glow_texture(), Rect2(at - Vector2(arm, arm) * 0.5, Vector2(arm, arm)), false, Color(1, 1, 1, 0.9 * bright))

	func _draw_outline(centre: Vector2, radius: float, alpha: float) -> void:
		if _outline.size() < 3:
			return
		var points := PackedVector2Array()
		var table := PackedVector2Array()
		for point in _outline:
			var flat := Vector2(point.x, -point.y) * radius
			points.append(centre + flat)
			table.append(centre + flat * 0.55 + Vector2(0, -radius * 0.04))
		var body: Color = GemMesh.body_colour(GemMesh.colour_key(stone), GemMesh.clarity_grade(stone))
		draw_colored_polygon(points, Color(body.darkened(0.25), alpha))
		for index in range(points.size()):
			var a: Vector2 = points[index]
			var b: Vector2 = points[(index + 1) % points.size()]
			var shade: float = 0.5 + 0.5 * sin(float(index) * 1.7)
			draw_colored_polygon(PackedVector2Array([a, b, table[(index + 1) % table.size()], table[index]]), Color(body.lightened(0.15 * shade), alpha * 0.9))
		draw_colored_polygon(table, Color(body.lightened(0.28), alpha))
		var loop := points.duplicate()
		loop.append(points[0])
		draw_polyline(loop, Color(body.lightened(0.5), alpha * 0.8), 1.2, true)

class DieThumb extends Control:
	## A die's picture, three-quarter on so its shape reads, showing one face.
	var die: Dictionary = {}
	var face: int = 0
	var _texture: Texture2D = null
	var _fade: float = 0.0
	var _key: String = ""
	var _hover: float = 0.0
	var _hovering: bool = false

	func _init(new_die: Dictionary = {}, edge: float = 56.0, shown_face: int = -1) -> void:
		custom_minimum_size = Vector2(edge, edge)
		mouse_filter = Control.MOUSE_FILTER_PASS
		mouse_entered.connect(func() -> void:
			_hovering = true
			set_process(true))
		mouse_exited.connect(func() -> void:
			_hovering = false
			set_process(true))
		if not new_die.is_empty():
			configure(new_die, shown_face)

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT and not die.is_empty():
			load("res://view/inspect/inspector.gd").die(die)
			accept_event()

	func configure(new_die: Dictionary, shown_face: int = -1) -> void:
		die = new_die
		var faces: Array = die.get("faces", [])
		## By default the face shown is the die's highest, which is what it is best at.
		if shown_face < 0:
			shown_face = 0
			var best: int = -999
			for index in range(faces.size()):
				var value: int = int(faces[index].get("value", 0)) if faces[index] is Dictionary else int(faces[index])
				if value > best:
					best = value
					shown_face = index
		face = shown_face
		var thumbs = load("res://view/gems/thumbs.gd")
		var key: String = thumbs.die_key(die, face)
		if key == _key:
			return
		_key = key
		_texture = null
		_fade = 0.0
		var shot: Texture2D = thumbs.request(key, "die", {"die": die, "face": face}, _arrived.bind(key))
		if shot != null:
			_texture = shot
			_fade = 1.0
		tooltip_text = DeepDice.describe(die) + "\n" + " ".join(faces.map(func(f: Dictionary) -> String: return DiceIcons.face_text(int(f.value), str(f.kind)))) + "\nRight-click for details"
		set_process(_texture == null)
		queue_redraw()

	func _arrived(texture: Texture2D, key: String) -> void:
		if key != _key or not is_instance_valid(self):
			return
		_texture = texture
		set_process(true)

	func _process(delta: float) -> void:
		var busy := false
		if _texture != null and _fade < 1.0:
			_fade = minf(1.0, _fade + delta * 4.0)
			busy = true
		var goal: float = 1.0 if _hovering else 0.0
		if not is_equal_approx(_hover, goal):
			_hover = move_toward(_hover, goal, delta * 6.0)
			busy = true
		queue_redraw()
		if not busy and _texture != null:
			set_process(false)

	func _draw() -> void:
		var edge: float = minf(size.x, size.y)
		var centre: Vector2 = size * 0.5
		var palette: Dictionary = DiceIcons.palette(str(die.get("key", die.get("shape", "D6"))))
		var lift: float = 1.0 + 0.08 * _hover
		var halo: float = edge * (1.3 + 0.2 * _hover)
		draw_texture_rect(DeepUi.glow_texture(), Rect2(centre - Vector2(halo, halo) * 0.5, Vector2(halo, halo)), false, Color(palette.body, 0.10 + 0.12 * _hover))
		if _fade < 1.0:
			var outline: Dictionary = DiceIcons.silhouette(str(die.get("shape", "D6")))
			var points := PackedVector2Array()
			for point in outline.points:
				points.append(centre + (Vector2(point) - Vector2(0.5, 0.5)) * edge * 0.8 * lift)
			draw_colored_polygon(points, Color(palette.body, 1.0 - _fade))
		if _texture != null:
			var reach: float = edge * lift
			draw_texture_rect(_texture, Rect2(centre - Vector2(reach, reach) * 0.5, Vector2(reach, reach)), false, Color(1, 1, 1, _fade))
