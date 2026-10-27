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
const GeodeView = preload("res://view/gems/geode_view.gd")
const DiceView = preload("res://view/dice/dice_view.gd")
const GemMesh = preload("res://view/gems/gem_mesh.gd")
const GemRock = preload("res://view/gems/gem_rock.gd")
const DiceIcons = preload("res://view/dice/dice_icons.gd")
const Motes = preload("res://view/gems/motes.gd")

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
## Photographs read back and having their mipmaps made on a worker thread: {task, image, key}.
var _minting: Array = []

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
	return "die|%s|%s|%s|%s|%d" % [str(die.get("shape", "D6")), ",".join(faces), str(die.get("pattern", "")), str(die.get("material", "")), face]

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
		## A copy: the photograph is of the thing as it was when its key was taken, not as it is
		## by the time a station comes free. A stone read at the tray in between came out cut
		## and emblemed under its raw key, on the raw stone's row.
		node.call("_enqueue", {"key": key, "kind": kind, "data": data.duplicate(true)})
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

func _exit_tree() -> void:
	## The game is closing (or the service is being taken down): stop photographing first. A
	## station freed while its viewport is still rendering a stone crashes the engine on its way
	## out, which every quick quit from a page full of new pictures used to do.
	_jobs.clear()
	_queue.clear()
	for entry in _minting:
		WorkerThreadPool.wait_for_task_completion(int(entry.task))
	_minting.clear()
	for station in _gem_stations + _die_stations:
		var viewport := _viewport_of(station.view)
		if viewport != null:
			viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_waiting.clear()
	## The photographs too: a texture still held by a static once the renderer has shut
	## down is leaked and freed too late.
	_textures.clear()
	_order.clear()

func _viewport_of(view: Control) -> SubViewport:
	return view.get("_viewport") as SubViewport

func _idle(station: Dictionary) -> void:
	station.busy = false
	var viewport := _viewport_of(station.view)
	if viewport != null:
		viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED

func _process(_delta: float) -> void:
	## Mipmaps made on a worker are turned into textures here, on the main thread.
	for entry in _minting.duplicate():
		if not WorkerThreadPool.is_task_completed(int(entry.task)):
			continue
		WorkerThreadPool.wait_for_task_completion(int(entry.task))
		_minting.erase(entry)
		_store(str(entry.key), ImageTexture.create_from_image(entry.image))
	for job in _jobs.duplicate():
		job.frames -= 1
		if job.frames > 0:
			continue
		_jobs.erase(job)
		var viewport := _viewport_of(job.station.view)
		var image: Image = null
		if viewport != null:
			## The read back itself waits on the GPU. It stays a plain read: the game can fall
			## back to the Compatibility renderer, which has no asynchronous one.
			image = viewport.get_texture().get_image()
		_idle(job.station)
		if image != null and not image.is_empty():
			_minting.append({"task": WorkerThreadPool.add_task(image.generate_mipmaps), "image": image, "key": job.key})
		else:
			_store(str(job.key), null)
	## One new subject a frame. Cutting a stone is the expensive half of a photograph, and
	## loading all three stations at once put three of them in the same frame. Staggered,
	## each station still comes free every few frames, so a page fills just as fast.
	if not _queue.is_empty():
		var job: Dictionary = _queue.front()
		var stations: Array = _gem_stations if str(job.kind) == "gem" else _die_stations
		for station in stations:
			if not bool(station.busy):
				_queue.pop_front()
				_shoot(station, job)
				break

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
			pivot.quaternion = Quaternion.from_euler(DiceView.tilt_for(str(view.call("_shape")))) * target
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
	## What the rail is handing this stone where it stands, so the close look can read out the
	## ranks it really has rather than the ones it was cut with.
	var context: Dictionary = {}
	## What else its close look is opened with, where the place it stands has more to say (the
	## Market's case: its price and a Buy).
	var inspect_opts: Dictionary = {}
	var _texture: Texture2D = null
	var _fade: float = 0.0
	var _hover: float = 0.0
	var _hovering: bool = false
	var _hover_time: float = 0.0
	var _live: Control = null
	## A Geode (a sealed stone with a recipe) is shown as the rock itself, still, in place of a photograph.
	var _geode: Control = null
	var _clock: float = 0.0
	var _key: String = ""
	var _hue: Color = Color.WHITE
	var _outline: PackedVector2Array = PackedVector2Array()
	var _span: float = 1.0
	var _brilliance: float = 0.5
	## Where the rock sits on a raw stone, for the flat stand-in.
	var _lumps: Array = []
	var _slotless: bool = false
	## The flat stand-in, cut once into meshes in units of its own radius: the stone, and the
	## rock drawn over its rim. Worked out from the outline on every frame of a fade, it was
	## most of what a page of stones cost while waiting for their pictures.
	var _sketch: ArrayMesh = null
	var _sketch_rock: ArrayMesh = null
	var _sketch_loop := PackedVector2Array()
	var _sketch_line := Color.WHITE

	func _init(new_stone: Dictionary = {}, edge: float = 64.0) -> void:
		custom_minimum_size = Vector2(edge, edge)
		mouse_filter = Control.MOUSE_FILTER_PASS
		clip_contents = false
		## Drawn again when the color marks are switched (Settings > Comfort).
		add_to_group(DeepUi.MARKED_GROUP)
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
			var opts: Dictionary = inspect_opts.duplicate()
			if not opts.has("context"):
				opts["context"] = context
			load("res://view/inspect/inspector.gd").stone(stone, opts)
			accept_event()

	func configure(new_stone: Dictionary) -> void:
		stone = new_stone
		var thumbs = load("res://view/gems/thumbs.gd")
		if DeepStone.is_geode(stone):
			_show_geode()
			return
		if _geode != null:
			_geode.queue_free()
			_geode = null
			_key = ""
		var key: String = thumbs.gem_key(stone)
		if key == _key:
			return
		_key = key
		_hue = GemMesh.tint(stone)
		_span = GemMesh.span(stone)
		var appraised: bool = bool(stone.get("appraised", true))
		## A raw stone in its rock throws an ordinary stone's light, whatever it is.
		_brilliance = GemMesh.brilliance(GemMesh.clarity_grade(stone)) if appraised else GemView.SEALED_BRILLIANCE
		_outline = GemMesh.girdle(stone)
		_lumps = [] if appraised else GemRock.layout(stone)
		_slotless = bool(stone.get("appraised", false)) and DeepStone.is_slotless(stone)
		_sketch = null
		_sketch_rock = null
		_sketch_loop = PackedVector2Array()
		var tier: String = str(DeepStone.grade(stone).tier)
		## A Star is only seen once someone has looked inside: a raw stone keeps it hidden.
		var star: bool = false
		if appraised or bool(stone.get("inclusions_revealed", false)):
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
		## A Transcendent carries its ring of motes on every picture of it.
		Motes.refresh(self, stone)
		queue_redraw()

	func _show_geode() -> void:
		var recipe: Dictionary = stone.geode
		var key: String = "geode|%s|%s" % [str(recipe.get("id", "")), str(recipe.get("theme", ""))]
		if key == _key and _geode != null:
			return
		_key = key
		_texture = null
		_fade = 1.0
		glint = false
		_slotless = false
		if _geode != null:
			_geode.queue_free()
		_geode = GeodeView.new(recipe, load("res://view/gems/geode.gd").theme_tone(recipe))
		_geode.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_geode.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_geode.set("drifting", false)
		add_child(_geode)
		set_process(true)
		queue_redraw()

	func _arrived(texture: Texture2D, key: String) -> void:
		if key != _key or not is_instance_valid(self):
			return
		_texture = texture
		set_process(true)

	func _process(delta: float) -> void:
		_clock += delta
		if _geode != null:
			## The rock only leans to the pointer; there is no photograph to wait for.
			var lean: float = move_toward(float(_geode.get("hover")), 1.0 if _hovering else 0.0, delta * 6.0)
			_geode.set("hover", lean)
			if not _hovering and lean <= 0.0:
				set_process(false)
			return
		var busy := glint
		if _texture != null and _fade < 1.0:
			_fade = minf(1.0, _fade + delta * 4.0)
			busy = true
		var goal: float = 1.0 if _hovering else 0.0
		if not is_equal_approx(_hover, goal):
			_hover = move_toward(_hover, goal, delta * 6.0)
			busy = true
		if _hovering and live_on_hover and _live == null and _roomy():
			_hover_time += delta
			busy = true
			if _hover_time > 0.3:
				_start_live()
		queue_redraw()
		if not busy:
			set_process(false)

	func _roomy() -> bool:
		## Big enough to come alive: a live view smaller than this cannot draw its glow, and
		## the renderer fails on every frame after (a Void rider's chip, a daily dig's socket).
		return minf(size.x, size.y) >= GemView.GLOW_LEAST

	func _start_live() -> void:
		if DisplayServer.get_name() == "headless" or stone.is_empty() or _geode != null or not _roomy():
			return
		var view: Control = GemView.new()
		view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		view.set_drift(true)
		view.set_spin(0.9)
		view.configure(stone)
		view.modulate.a = 0.0
		add_child(view)
		## GemView._ready makes itself PASS, so this is set after add_child: the live copy never
		## takes the pointer, or its engine tooltip would show over this thumb's own plate.
		view.mouse_filter = Control.MOUSE_FILTER_IGNORE
		view.tooltip_text = ""
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
		if _geode != null:
			return
		var edge: float = minf(size.x, size.y)
		var centre: Vector2 = size * 0.5
		var lift: float = 1.0 + 0.07 * _hover
		## The light a clean stone throws on what it sits on; a cloudy one throws little.
		var halo: float = edge * _span * (1.25 + 0.25 * _hover)
		draw_texture_rect(DeepUi.glow_texture(), Rect2(centre - Vector2(halo, halo) * 0.5, Vector2(halo, halo)), false,
			Color(_hue, (0.10 + 0.22 * _brilliance) * (1.0 + _hover)))
		var live_shown: bool = _live != null and is_instance_valid(_live) and _live.modulate.a > 0.99
		if _slotless:
			for arc in range(6):
				var angle: float = TAU * float(arc) / 6.0
				draw_arc(centre, edge * 0.47, angle, angle + TAU / 9.0, 12, Color(DeepUi.INFO, 0.7), 1.5, true)
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
		_draw_mark(edge, centre)

	func _draw_mark(edge: float, centre: Vector2) -> void:
		## The color's mark at the foot of the right-hand corner (Settings > Comfort > Color
		## marks). A stone wears its color's cut already, but in the rock, small or badly cut
		## the shape is lost. Not on a stone of several colors (its own cut says so) or one too
		## small to hold it (a Void rider's chip). Not on a Birthstone either, which is no color
		## and goes in no colored socket, nor on a Geode that does not say its color: either
		## would read as White.
		if not DeepUi.color_marks or edge < 36.0 or stone.is_empty():
			return
		if DeepStone.skill_of(stone).get("colors", []).size() > 1 or DeepStone.is_birthstone(stone):
			return
		if DeepStone.is_geode(stone) and str(stone.geode.get("kind", "")) != "color":
			return
		var radius: float = clampf(edge * 0.13, 6.0, 10.0)
		DeepUi.draw_color_mark(self, centre + Vector2(edge, edge) * 0.5 - Vector2(radius, radius), radius, DeepStone.color(stone))

	func _draw_outline(centre: Vector2, radius: float, alpha: float) -> void:
		if _sketch_loop.is_empty():
			_build_sketch()
		if _sketch_loop.is_empty():
			return
		var place := Transform2D(0.0, Vector2(radius, radius), 0.0, centre)
		var fade := Color(1, 1, 1, alpha)
		if _sketch != null:
			draw_mesh(_sketch, null, place, fade)
		draw_polyline(place * _sketch_loop, Color(_sketch_line, _sketch_line.a * alpha), 1.2, true)
		## The rock, seen from the front: a lump per chunk, the bed last and on top.
		if _sketch_rock != null:
			draw_mesh(_sketch_rock, null, place, fade)

	func _build_sketch() -> void:
		if _outline.size() < 3:
			return
		var appraised: bool = bool(stone.get("appraised", true))
		var body: Color = GemMesh.body_color(GemMesh.color_key(stone), GemMesh.clarity_grade(stone) if appraised else 3)
		## A raw stone is drawn smaller, to leave room for the rock round it.
		var chunks: Array = [] if appraised else _lumps
		var shrink: float = 1.0 if chunks.is_empty() else GemView.ROCK_SPAN / GemRock.reach(chunks)
		var points := PackedVector2Array()
		var table := PackedVector2Array()
		for point in _outline:
			var flat := Vector2(point.x, -point.y)
			points.append(flat * shrink)
			table.append((flat * 0.55 + Vector2(0, -0.04)) * shrink)
		var sink: Dictionary = {"verts": [], "colors": []}
		_fill(sink, points, Color(body.darkened(0.25), 1.0))
		for index in range(points.size()):
			var following: int = (index + 1) % points.size()
			var shade: float = 0.5 + 0.5 * sin(float(index) * 1.7)
			_fill(sink, PackedVector2Array([points[index], points[following], table[following], table[index]]), Color(body.lightened(0.15 * shade), 0.9))
		_fill(sink, table, Color(body.lightened(0.28), 1.0))
		_sketch = _mesh_of(sink)
		_sketch_loop = points.duplicate()
		_sketch_loop.append(points[0])
		_sketch_line = Color(body.lightened(0.5), 0.8)
		sink = {"verts": [], "colors": []}
		for chunk in chunks:
			var middle: Vector2 = Vector2(chunk.position.x, -chunk.position.y) * shrink
			var lump := PackedVector2Array()
			for corner in range(9):
				var angle: float = TAU * float(corner) / 9.0 + float(chunk.rotation.z)
				var wobble: float = 0.82 + 0.3 * absf(sin(float(corner) * 2.3 + float(chunk.rotation.z) * 3.0))
				lump.append(middle + Vector2(cos(angle), sin(angle)) * float(chunk.radius) * shrink * wobble)
			_fill(sink, lump, Color(GemRock.TONE.lightened(0.05 * sin(float(chunk.rotation.z))), 1.0))
		_sketch_rock = _mesh_of(sink)

	static func _fill(sink: Dictionary, polygon: PackedVector2Array, tone: Color) -> void:
		## Appends a polygon as triangles to the plain arrays in `sink`.
		for index in Geometry2D.triangulate_polygon(polygon):
			sink.verts.append(polygon[index])
			sink.colors.append(tone)

	static func _mesh_of(sink: Dictionary) -> ArrayMesh:
		if sink.verts.is_empty():
			return null
		var arrays: Array = []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = PackedVector2Array(sink.verts)
		arrays[Mesh.ARRAY_COLOR] = PackedColorArray(sink.colors)
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		return mesh

class DieThumb extends Control:
	## A die's picture, showing one face nearly straight on (the fight's dice rest at the same
	## slight turn, `DiceView.tilt_for`), with a sliver of its sides so its shape reads.
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
		var palette: Dictionary = DiceIcons.die_palette(die)
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
