extends Control
## The mine as the party sees it, for the whole run: one World3D holding the room the party
## stands in, and while it walks, the tunnel and the room ahead.
##
## The beats: a room is shown (built at once, or walked into); its business happens (a
## fight, a vein, a stall) while the camera stands at its mark; then the party walks up to
## the crossroads at the far end, where the mouths light with what waits down them; a mouth
## is chosen and the party walks down its tunnel into the next room. A fight seals the
## mouths with a rockfall as it begins and crumbles them when it is won.
##
## The walk is a dolly with a stride. The room ahead is built a slice a frame on the way,
## the air turns from one biome to the next inside the tunnel, and on arrival everything is
## moved back so the new room sits at the origin, which is where every screen that draws on
## the stage expects it. A click on the way jumps straight there.
##
## The stage decides nothing and knows nothing of the rules: it is told which room, which
## way, when to seal the mouths and when to open them.

const Chamber = preload("res://view/battle/chamber.gd")
const Tunnel = preload("res://view/battle/tunnel.gd")
const Mouth = preload("res://view/battle/mouth.gd")
const Rockfall = preload("res://view/battle/rockfall.gd")
const Biomes = preload("res://view/battle/biomes.gd")
const BattleFx = preload("res://view/battle/battle_fx.gd")
const CameraRig = preload("res://view/battle/camera_rig.gd")
const LensFlare = preload("res://view/battle/lens_flare.gd")
const ScreenFx = preload("res://view/battle/screen_fx.gd")
const Looks = preload("res://view/battle/looks.gd")
const Lowpoly = preload("res://view/battle/lowpoly.gd")
const GemMesh = preload("res://view/gems/gem_mesh.gd")
const GemRock = preload("res://view/gems/gem_rock.gd")
const GemView = preload("res://view/gems/gem_view.gd")
const DiceIcons = preload("res://view/dice/dice_icons.gd")
const VeinFace = preload("res://view/battle/vein_face.gd")
const Stall = preload("res://view/battle/stall.gd")
const LiftHall = preload("res://view/battle/lift_hall.gd")
const Hoard = preload("res://view/battle/hoard.gd")
const DiceGeometry = preload("res://view/dice/dice_geometry.gd")
const GemIcons = preload("res://view/gems/gem_icons.gd")

signal mouth_hovered(index: int)
signal mouth_pressed(index: int)
signal pick_hovered(id: String)
signal pick_pressed(id: String)
signal pick_inspected(id: String)

const HOME := Vector3(0.0, 2.1, 5.2)
const HOME_LOOK := Vector3(0.0, 1.2, -3.5)
## Where the party stands to choose a way on: near enough that the mouths are plain.
const CROSSROADS := Vector3(0.0, 2.05, -9.0)
const CROSSROADS_LOOK := Vector3(0.0, 2.1, Chamber.Z_FAR - 2.0)
const EYE := 1.95
const WALK_SECONDS := 3.9
const BASE_FOV := 58.0
## Slices of the room ahead built each frame of a walk.
const SLICES := 2
## The rockfall that seals a fight: how far across the far wall it reaches, how high it
## stands, and how long from the first block falling to the last one landing.
const SEAL_HALF := 9.6
const SEAL_TALL := 7.2
const SEAL_SECONDS := 1.05
const ENV_FIELDS: Array = ["background_color", "ambient_light_color", "ambient_light_energy", "fog_light_color", "glow_intensity",
	"volumetric_fog_density", "volumetric_fog_albedo", "volumetric_fog_emission", "adjustment_saturation", "adjustment_contrast"]

## The graphics setting: 0 lets the governor decide, 1-3 fixes low, medium or high.
static var quality_pref: int = 0

var camera: Camera3D = null
var fx: Node3D = null
var world: Node3D = null
var viewport: SubViewport = null
var frame: SubViewportContainer = null
var screen_fx: ColorRect = null
## The stylization pass over the 3D frame, under the feedback layer. Off unless picked.
var look: MeshInstance3D = null
var flare: Control = null
var room: Node3D = null
var env: Environment = null
## The place the room was built for: {key, mine, depth, kind, exits, drop}.
var place: Dictionary = {}
## Whether the party walked into the room it stands in; a fight then needs no sweep in.
var arrived_by_walk: bool = false
var quality: int = 3
## A walk held still where it is, for a tool that pictures it.
var frozen: bool = false

var _headless: bool = false
var _warmed: bool = false
var _lantern: SpotLight3D = null
var _lantern_fill: OmniLight3D = null
var _lantern_level: float = 0.0
var _lantern_goal: float = 0.0
var _mouths: Array = []
var _entries: Array = []
var _hovered: int = -1
## "home", "crossroads", "moving" (a stroll inside the room) or "walking" (to the next room).
var _at: String = "home"
var _falls: Array = []
var _spoils: Array = []
var _travel: Dictionary = {}
var _pending: Array = []
var _crumble_timer: SceneTreeTimer = null
var _picks: Dictionary = {}
var _pick_hover: String = ""
var _business: Node3D = null
var _business_key: String = ""
## Half the width of what stands at the arena, for walking round it; nothing, nothing to round.
var _obstacle: float = 0.0
## The mouths can be clicked from where the party stands (a landing), not only at the crossroads.
var _mouths_live: bool = false
## When the last block of a rockfall lands, in engine milliseconds. A fight waits for it:
## the way out is shut first, and what is waiting in the room rises after.
var _seal_until: int = 0
var _footfall: int = 0
var _slow: float = 0.0
var _ambient_clock: float = 0.0
var _next_rumble: float = 7.0

func _ready() -> void:
	_headless = DisplayServer.get_name() == "headless"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if _headless:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		return
	mouse_filter = Control.MOUSE_FILTER_STOP
	frame = SubViewportContainer.new()
	frame.stretch = true
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(frame)
	viewport = SubViewport.new()
	viewport.own_world_3d = true
	viewport.msaa_3d = Viewport.MSAA_4X
	viewport.positional_shadow_atlas_size = 2048
	frame.add_child(viewport)
	world = Node3D.new()
	viewport.add_child(world)
	camera = CameraRig.new()
	viewport.add_child(camera)
	fx = BattleFx.new()
	world.add_child(fx)
	## The party's own lantern, carried: it lights the tunnels, and hands over to each
	## room's lantern mark on arrival.
	_lantern = SpotLight3D.new()
	_lantern.position = Vector3(0.35, -0.2, 0.1)
	_lantern.spot_range = 24.0
	_lantern.spot_angle = 40.0
	_lantern.spot_angle_attenuation = 1.3
	_lantern.light_energy = 0.0
	_lantern.light_volumetric_fog_energy = 1.3
	_lantern.shadow_enabled = false
	camera.add_child(_lantern)
	_lantern_fill = OmniLight3D.new()
	_lantern_fill.position = Vector3(0.3, -0.3, 0.2)
	_lantern_fill.omni_range = 5.5
	_lantern_fill.light_energy = 0.0
	_lantern_fill.shadow_enabled = false
	camera.add_child(_lantern_fill)
	## The stylization pass rides the camera so it is never culled, and draws over the room
	## before the feedback layer paints the vignette and the blows on top of it.
	look = Looks.new()
	camera.add_child(look)
	screen_fx = ScreenFx.new()
	add_child(screen_fx)
	flare = LensFlare.new()
	flare.camera = camera
	flare.viewport = viewport
	flare.transient = fx.flares
	add_child(flare)
	visibility_changed.connect(_on_visibility)
	_set_quality(3 if quality_pref <= 0 else clampi(quality_pref, 1, 3))

func _on_visibility() -> void:
	## A hidden stage costs nothing: its world stops rendering and stops moving.
	if viewport == null:
		return
	var shown := is_visible_in_tree()
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if shown else SubViewport.UPDATE_DISABLED
	world.process_mode = Node.PROCESS_MODE_INHERIT if shown else Node.PROCESS_MODE_DISABLED

func has_room() -> bool:
	return room != null and is_instance_valid(room)

func walking() -> bool:
	return _at == "walking"

func strolling() -> bool:
	## On its feet inside the room, between the mark and the crossroads.
	return _at == "moving"

func at_crossroads() -> bool:
	return _at == "crossroads"

# --- rooms -------------------------------------------------------------------------------------

static func biome_kind(kind: String) -> String:
	## Fights dress their rooms; every other room is the plain biome.
	return kind if kind in ["fight", "elite", "warden"] else "fight"

static func room_seed(p: Dictionary) -> int:
	## A fight room is the room it always was for its mine and depth; other rooms at the same
	## depth (a landing and its Warden's hall) are told apart by what they are.
	var kind: String = str(p.get("kind", "fight"))
	if kind in ["fight", "elite", "warden"]:
		return ("%s|%d" % [str(p.get("mine", "")), int(p.get("depth", 0))]).hash()
	return str(p.get("key", "")).hash()

func _new_room(p: Dictionary, origin: Vector3) -> Dictionary:
	var biome: Dictionary = Biomes.for_depth(str(p.get("mine", DeepContent.starter_mine())), maxi(1, int(p.get("depth", 1))), biome_kind(str(p.get("kind", "fight"))))
	var made: Node3D = Chamber.new()
	made.quality = quality
	made.position = origin
	world.add_child(made)
	var steps: Array = made.plan(biome, room_seed(p), int(p.get("exits", 2)), float(p.get("drop", 2.5)))
	steps.append(_dress_mouths.bind(made, bool(p.get("seal", false))))
	if str(p.get("kind", "")) in ["landing", "head", "warden"]:
		steps.append(_build_hall.bind(made, str(p.kind), room_seed(p)))
	return {"room": made, "steps": steps}

func _dress_mouths(made: Node3D, bright: bool) -> void:
	## Every way on gets its mouth. A room about to be sealed shows its mouths lit and plain
	## as the party comes in, so the rock that comes down is seen to put the light out.
	var mouths: Array = []
	for way in made.exits:
		var mouth: Node3D = Mouth.new()
		mouth.index = int(way.index)
		mouth.position = made.mouth(int(way.index))
		made.add_child(mouth)
		if bright:
			mouth.configure({"kind": "fight", "color": Color("ffc98a"), "glyph": "arch", "plain": true})
			mouth.set_state("open")
			mouth.brighten()
		mouths.append(mouth)
	made.set_meta("mouths", mouths)

func show_room(p: Dictionary, force: bool = false) -> bool:
	## Puts the party in a room at once, with no walk: a run begun or picked up again, a
	## gallery shot. Returns whether anything was built.
	if _headless:
		place = p
		return false
	if not force and has_room() and str(p.get("key", "")) == str(place.get("key", "")):
		return false
	_stop_travel()
	_clear_room()
	place = p
	var made: Dictionary = _new_room(p, Vector3.ZERO)
	room = made.room
	for step in made.steps:
		(step as Callable).call()
	_settle_in()
	camera.home_position = HOME
	camera.home_look = HOME_LOOK
	camera.home_fov = BASE_FOV
	camera.bob = 0.0
	camera.reset()
	arrived_by_walk = false
	_at = "home"
	return true

func _clear_room() -> void:
	_clear_spoils()
	clear_picks()
	_business = null
	_business_key = ""
	_obstacle = 0.0
	_mouths_live = false
	_falls.clear()
	_mouths.clear()
	_entries = []
	_set_hover(-1)
	if has_room():
		room.queue_free()
	room = null

func _lead_eye(look: Vector3, seconds: float = 0.7) -> void:
	## Where a room wants the eye, taken up over a moment rather than snapped to. A room that
	## re-aimed the camera the instant it was arrived in read as a cut in the middle of a
	## step, which is what the jump on walking into a stall or a vein was.
	if camera == null:
		return
	if _headless:
		camera.home_look = look
		return
	var tween := camera.create_tween()
	tween.tween_property(camera, "home_look", look, seconds).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _settle_in() -> void:
	## The room the party now stands in, at the origin: its air, its flares, its mouths.
	env = room.environment()
	camera.environment = env
	room.set_quality(quality, env)
	flare.sources = room.flares
	screen_fx.vignette = 0.42 + 0.12 * float(room.biome.intensity)
	screen_fx.vignette_color = Color(room.biome.background).darkened(0.5)
	screen_fx.desaturate = 0.0
	look.tint(room.biome)
	_mouths = room.get_meta("mouths", []).duplicate()
	_entries = []
	_hovered = -1
	_next_rumble = 5.0

# --- the crossroads ----------------------------------------------------------------------------

func crossroads(entries: Array) -> void:
	## The room's business is done: the way on opens and the party walks up to the forks.
	## `entries` dress the mouths, one per way on: {kind, color, light, glyph, hidden,
	## voters: [Color], mine}.
	if _headless or not has_room():
		return
	_entries = entries
	for mouth in _mouths:
		var index: int = int(mouth.index)
		if index < entries.size():
			mouth.configure(entries[index])
	if _at == "crossroads":
		_open_mouths()
		return
	if _at == "walking" or (_at == "moving" and str(_travel.get("to", "")) == "crossroads") or _crumble_timer != null:
		return
	var wait: float = _crumble() if not _falls.is_empty() else 0.0
	var spent: Node3D = business()
	if spent != null and spent.has_method("collapse"):
		## A vein that is done sinks into the floor and lets the party through.
		wait = maxf(wait, spent.collapse(fx))
		_business = null
		_business_key = ""
		_obstacle = 0.0
		clear_picks()
	if wait > 0.0:
		_at = "moving"
		_crumble_timer = get_tree().create_timer(wait)
		_crumble_timer.timeout.connect(func() -> void:
			_crumble_timer = null
			if _at == "moving" and _travel.is_empty():
				_open_mouths()
				_stroll(CROSSROADS, CROSSROADS_LOOK, 1.8, "crossroads"))
		return
	_open_mouths()
	_stroll(CROSSROADS, CROSSROADS_LOOK, 1.8, "crossroads")

func _open_mouths() -> void:
	for mouth in _mouths:
		mouth.set_state("open" if int(mouth.index) < _entries.size() else "dark")

func mouth_rect(index: int) -> Rect2:
	## Where a mouth (and its plaque) is on the screen, in the stage's own coordinates.
	if not has_room() or index < 0 or index >= room.exits.size() or not _laid_out():
		return Rect2()
	var foot: Vector3 = room.global_transform * room.mouth(index)
	var half: float = Tunnel.WIDTH * 0.5 + 0.2
	var box := Rect2(to_screen(foot + Vector3(-half, 0.0, 0.0)), Vector2.ZERO)
	for corner in [Vector3(half, 0.0, 0.0), Vector3(-half, Tunnel.HEIGHT + 1.6, 0.0), Vector3(half, Tunnel.HEIGHT + 1.6, 0.0)]:
		box = box.expand(to_screen(foot + corner))
	return box

func _mouth_at(local: Vector2) -> int:
	for mouth in _mouths:
		var index: int = int(mouth.index)
		if index < _entries.size() and mouth_rect(index).grow(12.0).has_point(local):
			return index
	return -1

func _set_hover(index: int) -> void:
	if index == _hovered:
		return
	_hovered = index
	for mouth in _mouths:
		mouth.set_hover(int(mouth.index) == index)
	if camera != null and has_room():
		if index >= 0:
			DeepAudio.play("ui_hover", {"volume": 0.5})
			camera.lean(room.global_transform * (room.mouth(index) + Vector3(0, 1.8, 0)), 0.14)
		else:
			camera.lean(CROSSROADS_LOOK, 0.0)
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if index >= 0 else Control.CURSOR_ARROW
	mouth_hovered.emit(index)

func _gui_input(event: InputEvent) -> void:
	if _headless:
		return
	var still: bool = _at in ["home", "crossroads"]
	if event is InputEventMouseButton and not event.pressed and event.button_index == MOUSE_BUTTON_LEFT and still:
		## Things are clicked on the release, so a press that becomes a drag is not a click.
		## A click on nothing in particular is reported too: it puts down whatever was picked up.
		var picked: String = _pick_under(event.position)
		pick_pressed.emit(picked)
		if not picked.is_empty():
			accept_event()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT and still:
		## Right-click anything standing in the room for the close look, the same as a stone
		## on the rail: a stall's goods and a Warden's hoard are read before they are bought
		## or taken, not after.
		var looked: String = _pick_under(event.position)
		if not looked.is_empty():
			pick_inspected.emit(looked)
			accept_event()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if _at == "walking":
			hurry()
			accept_event()
		elif (_at == "crossroads" or (_mouths_live and _at == "home")) and _pick_under(event.position).is_empty():
			var index: int = _mouth_at(event.position)
			if index >= 0:
				DeepAudio.play("ui_confirm", {"volume": 0.7})
				mouth_pressed.emit(index)
				accept_event()
	elif event is InputEventMouseMotion:
		var over: String = _pick_under(event.position) if still else ""
		_hover_pick(over)
		_set_hover(_mouth_at(event.position) if (_at == "crossroads" or (_mouths_live and _at == "home")) and over.is_empty() else -1)
		if not over.is_empty():
			mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo and is_visible_in_tree()):
		return
	if _at == "walking" and event.keycode in [KEY_SPACE, KEY_ENTER]:
		hurry()
		get_viewport().set_input_as_handled()
	elif event.keycode == KEY_F9 and look != null:
		## Walks the stylization passes while the game is running, so a look can be judged
		## against the room it has to live in rather than against a still.
		Looks.pref = look.cycle(-1 if event.shift_pressed else 1)
		print("look: %s - %s" % [Looks.pref, str(Looks.LOOKS[Looks.pref].name)])
		get_viewport().set_input_as_handled()

# --- things to point at --------------------------------------------------------------------------
##
## What a room's business is done with: a spot on a vein, an item on a stall's counter, the
## campfire at a landing. Each is registered with a node and the size of the box it fills,
## and the stage reports when one is pointed at or clicked. One can also be dragged from
## (a stall's goods) or dropped on (the scales, the lens), with what that means left to
## whoever registered it.

func add_pick(id: String, node: Node3D, half: Vector3, options: Dictionary = {}) -> void:
	## options: hover (Callable(bool)), drag (Callable() -> data or null), preview (Callable() ->
	## Control), accepts (Callable(data) -> bool), drop (Callable(data)), enabled (bool).
	var entry: Dictionary = {"node": node, "half": half, "enabled": bool(options.get("enabled", true))}
	entry.merge(options, true)
	_picks[id] = entry

func enable_pick(id: String, on: bool) -> void:
	if _picks.has(id):
		_picks[id].enabled = on
		if not on and _pick_hover == id:
			_hover_pick("")

func remove_pick(id: String) -> void:
	if _pick_hover == id:
		_hover_pick("")
	_picks.erase(id)

func has_pick(id: String) -> bool:
	return _picks.has(id)

func clear_picks() -> void:
	_hover_pick("")
	_picks.clear()

func pick_rect(id: String) -> Rect2:
	## Where a registered thing is on the screen, in the stage's own coordinates.
	var entry: Dictionary = _picks.get(id, {})
	if entry.is_empty() or not is_instance_valid(entry.node) or not _laid_out():
		return Rect2()
	var node: Node3D = entry.node
	var half: Vector3 = entry.half
	var offset: Vector3 = entry.get("offset", Vector3.ZERO)
	var box := Rect2()
	var first: bool = true
	for sx in [-1.0, 1.0]:
		for sy in [-1.0, 1.0]:
			for sz in [-1.0, 1.0]:
				var corner: Vector3 = node.global_transform * (offset + Vector3(half.x * sx, half.y * sy, half.z * sz))
				if camera.is_position_behind(corner):
					continue
				var at: Vector2 = to_screen(corner)
				box = Rect2(at, Vector2.ZERO) if first else box.expand(at)
				first = false
	return box

func _pick_under(local: Vector2, wanted: Callable = Callable()) -> String:
	## The smallest registered thing under a point, of those `wanted` allows.
	var best: String = ""
	var best_area: float = INF
	for id in _picks:
		var entry: Dictionary = _picks[id]
		if not bool(entry.enabled) or not is_instance_valid(entry.node):
			continue
		if wanted.is_valid() and not bool(wanted.call(entry)):
			continue
		var box: Rect2 = pick_rect(str(id))
		if box.size == Vector2.ZERO or not box.grow(6.0).has_point(local):
			continue
		var area: float = box.size.x * box.size.y
		if area < best_area:
			best_area = area
			best = str(id)
	return best

func _hover_pick(id: String) -> void:
	if id == _pick_hover:
		return
	var old: Dictionary = _picks.get(_pick_hover, {})
	if not old.is_empty() and (old.get("hover", Callable()) as Callable).is_valid():
		(old.hover as Callable).call(false)
	_pick_hover = id
	var entry: Dictionary = _picks.get(id, {})
	if not entry.is_empty():
		if (entry.get("hover", Callable()) as Callable).is_valid():
			(entry.hover as Callable).call(true)
		DeepAudio.play("ui_hover", {"volume": 0.4})
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if not id.is_empty() else Control.CURSOR_ARROW
	pick_hovered.emit(id)

func _get_drag_data(at: Vector2) -> Variant:
	if _at in ["walking", "moving"]:
		return null
	var id: String = _pick_under(at, func(entry: Dictionary) -> bool: return (entry.get("drag", Callable()) as Callable).is_valid())
	if id.is_empty():
		return null
	var entry: Dictionary = _picks[id]
	var data: Variant = (entry.drag as Callable).call()
	if data == null:
		return null
	if (entry.get("preview", Callable()) as Callable).is_valid():
		var shown: Control = (entry.preview as Callable).call()
		shown.modulate = Color(1, 1, 1, 0.85)
		set_drag_preview(DeepUi.held(shown))
	DeepAudio.play("die_pick", {"gap": 0.0, "volume": 0.7})
	return data

func _drop_target(at: Vector2, data: Variant) -> String:
	if not data is Dictionary:
		return ""
	return _pick_under(at, func(entry: Dictionary) -> bool:
		var accepts: Callable = entry.get("accepts", Callable())
		return accepts.is_valid() and bool(accepts.call(data)))

func _can_drop_data(at: Vector2, data: Variant) -> bool:
	var id: String = _drop_target(at, data)
	_hover_pick(id)
	return not id.is_empty()

func _drop_data(at: Vector2, data: Variant) -> void:
	var id: String = _drop_target(at, data)
	if not id.is_empty():
		(_picks[id].drop as Callable).call(data)

func _notification(what: int) -> void:
	## While something is being dragged, whatever would take it glows.
	if what == NOTIFICATION_DRAG_BEGIN or what == NOTIFICATION_DRAG_END:
		var data: Variant = get_viewport().gui_get_drag_data() if what == NOTIFICATION_DRAG_BEGIN else null
		for id in _picks:
			var entry: Dictionary = _picks[id]
			var accepts: Callable = entry.get("accepts", Callable())
			var hover: Callable = entry.get("hover", Callable())
			if accepts.is_valid() and hover.is_valid() and is_instance_valid(entry.node):
				hover.call(data is Dictionary and bool(accepts.call(data)))

# --- a room's business -----------------------------------------------------------------------------
##
## The thing a room is for stands where a fight would: an outcrop of vein, a stall's counter,
## the hoard's pedestals. The party strolls round it on the way to the crossroads.

func business() -> Node3D:
	return _business if _business != null and is_instance_valid(_business) else null

func set_business(key: String, node: Node3D, half_width: float) -> void:
	## Stands `node` at the arena of the room the party is in, in place of whatever stood there.
	## It is not simply there: it comes up out of the floor in its own dust as the party walks
	## in, because a counter that blinks into an empty room reads as a bug rather than a room.
	if _business != null and is_instance_valid(_business):
		_business.queue_free()
	_business = node
	_business_key = key
	_obstacle = half_width
	if node != null and has_room():
		if node.get_parent() == null:
			room.add_child(node)
		if not _headless:
			var rest: Vector3 = node.position
			node.position = rest - Vector3(0.0, 2.6, 0.0)
			var lift := node.create_tween()
			lift.tween_property(node, "position", rest, 0.75).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			lift.parallel().tween_callback(func() -> void:
				if is_instance_valid(fx):
					fx.puff(room.global_transform * (rest + Vector3(0, 0.2, 0.6)), Color("8a7a66"), 18, 1.8, 1.6, 0.4)
				DeepAudio.play("cave_rumble", {"volume": 0.35}))

func retire_business() -> float:
	## Whatever stood at the arena and is done with goes, if it knows how to go.
	var done: Node3D = business()
	if done == null or not done.has_method("collapse"):
		return 0.0
	var wait: float = done.collapse(fx)
	_business = null
	_business_key = ""
	_obstacle = 0.0
	clear_picks()
	return wait

func business_key() -> String:
	return _business_key if business() != null else ""

func _round_business(from: Vector3, to: Vector3) -> Array:
	## The way past whatever stands at the arena, if it stands in the way: round its nearer end.
	if _obstacle <= 0.0 or business() == null:
		return []
	var z: float = business().position.z
	if not (from.z > z + 1.0 and to.z < z - 1.0):
		return []
	var side: float = 1.0 if from.x >= 0.0 else -1.0
	return [Vector3(side * (_obstacle + 1.7), EYE + 0.1, z + 1.5), Vector3(side * (_obstacle + 1.4), EYE + 0.1, z - 2.5)]

# --- the lift hall ------------------------------------------------------------------------------
##
## A landing, the shaft head and a Warden's hall have the lift in them: the cage in its shaft
## off to one side, with (at a landing) the campfire, the workbench and the wheel. It is built
## with the room, so it is there as the party walks in.

func _build_hall(made: Node3D, kind: String, seed_value: int) -> void:
	var hall: Node3D = LiftHall.new()
	made.add_child(hall)
	hall.build(made.biome, seed_value + 41, kind == "landing", kind == "head", made.ground)
	made.set_meta("hall", hall)

func hall() -> Node3D:
	if not has_room():
		return null
	if not room.has_meta("hall"):
		return null
	var found: Variant = room.get_meta("hall")
	return found if found != null and is_instance_valid(found) else null

func open_ways(entries: Array) -> void:
	## The mouths lit and clickable from where the party stands, without walking up to them:
	## a landing's ways down, chosen from beside the lift.
	if _headless or not has_room():
		return
	_entries = entries
	for mouth in _mouths:
		var index: int = int(mouth.index)
		if index < entries.size():
			mouth.configure(entries[index])
	_open_mouths()
	_mouths_live = true

func close_ways() -> void:
	_mouths_live = false
	_set_hover(-1)

func ride_lift(done: Callable) -> void:
	## The run's closing shot: into the cage, and up into the light.
	var lift: Node3D = hall()
	if _headless or lift == null or lift.cage == null:
		if done.is_valid():
			done.call()
		return
	_stop_travel()
	close_ways()
	clear_picks()
	var cage: Node3D = lift.cage
	var inside: Vector3 = cage.global_position + Vector3(0.1, EYE + 0.16, 0.0)
	var front: Vector3 = cage.global_position + Vector3(2.6, EYE + 0.1, 0.4)
	var from: Vector3 = camera.home_position
	var path: Curve3D = _smooth([from, from.lerp(front, 0.5) + Vector3(0, 0.05, 0), front, inside])
	_travel = {"kind": "stroll", "path": path, "length": path.get_baked_length(), "seconds": 2.2, "t": 0.0, "look_from": camera.home_look,
		"look_end": inside + Vector3(4.0, -0.4, 1.5), "to": "home", "last": 0.0}
	_at = "moving"
	camera.settle(0.5)
	var tween := create_tween()
	tween.tween_interval(2.35)
	tween.tween_callback(func() -> void:
		DeepAudio.play("lift", {"volume": 0.9})
		camera.add_trauma(0.15))
	var rise: float = LiftHall.SHAFT_TOP - 1.0
	tween.tween_method(func(t: float) -> void:
		if is_instance_valid(cage):
			var lift_by: float = rise * t * t
			cage.position.y = lift_by
			camera.home_position = inside + Vector3(0, lift_by, 0)
			camera.home_look = inside + Vector3(4.0, -0.4 + lift_by * 0.6, 1.5).lerp(inside + Vector3(0.2, lift_by + 5.0, 0.0), t * t)
			camera.bob = 0.0, 0.0, 1.0, 3.2)
	tween.parallel().tween_property(screen_fx, "flash", 0.9, 3.0).set_delay(1.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback(func() -> void:
		screen_fx.flash_color = Color("fff0d0")
		if done.is_valid():
			done.call())

func darken(done: Callable) -> void:
	## A fall: the lights of the room go out one by one and the color drains from it.
	if _headless or not has_room():
		if done.is_valid():
			done.call()
		return
	close_ways()
	clear_picks()
	var tween := create_tween().set_parallel(true)
	tween.tween_property(screen_fx, "desaturate", 0.9, 2.0)
	tween.tween_property(screen_fx, "vignette", 0.95, 2.0)
	if env != null:
		tween.tween_property(env, "ambient_light_energy", 0.05, 2.2)
		tween.tween_property(env, "tonemap_exposure", 0.45, 2.2)
	tween.chain().tween_callback(func() -> void:
		if done.is_valid():
			done.call())

# --- the hoard -----------------------------------------------------------------------------------

func hoard(stones: Array, chosen: String) -> Node3D:
	if _headless or not has_room():
		return null
	var key: String = "hoard|%s" % str(place.get("key", ""))
	if business_key() != key:
		var made: Node3D = Hoard.new()
		made.position = Chamber.ARENA + Vector3(0, 0, 0.6)
		set_business(key, made, Hoard.SPREAD * float(stones.size()) * 0.5 + 0.2)
		made.build(room.biome, stones, room_seed(place) + 29)
		made.settle(chosen)
	return business()

func hoard_take(stone_id: String, bag_at: Vector2) -> void:
	var pile: Node3D = business()
	if _headless or pile == null or not pile.has_method("take"):
		return
	var stone: Node3D = pile.take(stone_id)
	if stone != null and _laid_out():
		fx.flash(stone.global_position, Color("ffe0a0"), 6.0, 5.0, 0.5, 1.0)
		_fly(stone, from_screen(bag_at, 1.5), 0.3, 0.7, "stone_found", Callable())

# --- an oddity's shrine ----------------------------------------------------------------------------

func shrine(glyph: String, color: Color) -> Node3D:
	## Something strange on a plinth: the oddity's mark burning in the air over it.
	if _headless or not has_room():
		return null
	var key: String = "shrine|%s" % str(place.get("key", ""))
	if business_key() == key:
		return business()
	var made := Node3D.new()
	made.position = Chamber.ARENA + Vector3(0, 0, -1.2)
	set_business(key, made, 0.0)
	var rng := RandomNumberGenerator.new()
	rng.seed = room_seed(place) + 31
	var rock := StandardMaterial3D.new()
	rock.vertex_color_use_as_albedo = true
	rock.roughness = 0.8
	var plinth := MeshInstance3D.new()
	plinth.mesh = Lowpoly.column(rng, Color(room.biome.rock).lightened(0.25), 6, 0.7, 1.0)
	plinth.material_override = rock
	made.add_child(plinth)
	var top := MeshInstance3D.new()
	top.mesh = Lowpoly.slab(Vector3(1.7, 0.14, 1.7), Color(room.biome.rock).lightened(0.35), rng, 0.03)
	top.material_override = rock
	top.position = Vector3(0, 1.05, 0)
	made.add_child(top)
	var mark := Sprite3D.new()
	mark.texture = GemIcons.texture(glyph, 128)
	mark.pixel_size = 1.1 / float(mark.texture.get_width())
	mark.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	mark.shaded = false
	mark.modulate = color * 1.5
	mark.position = Vector3(0, 2.2, 0)
	made.add_child(mark)
	var float_tween := mark.create_tween().set_loops()
	float_tween.tween_property(mark, "position:y", 2.35, 1.6).set_trans(Tween.TRANS_SINE)
	float_tween.tween_property(mark, "position:y", 2.1, 1.6).set_trans(Tween.TRANS_SINE)
	var glow := OmniLight3D.new()
	glow.light_color = color
	glow.light_energy = 2.6
	glow.omni_range = 6.0
	glow.light_volumetric_fog_energy = 2.0
	glow.position = Vector3(0, 2.2, 0.4)
	glow.shadow_enabled = false
	made.add_child(glow)
	var motes: GPUParticles3D = BattleFx.ambient("motes", {"key": color, "accent": color, "lights": [color]}, 0.5)
	motes.position = Vector3(0, 1.8, 0)
	(motes.process_material as ParticleProcessMaterial).emission_box_extents = Vector3(1.2, 1.0, 1.2)
	made.add_child(motes)
	return made

# --- salvage -------------------------------------------------------------------------------------

func _die_mesh(sides: int) -> ArrayMesh:
	## A plain die of the right shape, flat-shaded, for throwing.
	var solid: Dictionary = DiceGeometry.solid(DiceGeometry.shape_for_sides(sides))
	var points: PackedVector3Array = solid.vertices
	var surface := Lowpoly.begin()
	for face in solid.faces:
		var centre := Vector3.ZERO
		for index in face:
			centre += points[index]
		centre /= float(face.size())
		for k in range(1, face.size() - 1):
			Lowpoly.tri(surface, points[face[0]], points[face[k]], points[face[k + 1]], Color("e8e2d4"), centre)
	return surface.commit()

func salvage(rolls: Array, bag_at: Vector2) -> void:
	## The fall's reckoning, thrown on the floor in front of the party: a die for every raw
	## stone. The top face keeps the stone and it goes to the bag; anything else shatters it.
	if _headless or not has_room() or not _laid_out():
		return
	var ahead: Vector3 = camera.global_position + (-camera.global_transform.basis.z * Vector3(1, 0, 1)).normalized() * 2.8
	var count: int = rolls.size()
	var bag_goal: Vector3 = from_screen(bag_at, 1.5)
	for i in range(count):
		var roll: Dictionary = rolls[i]
		var kept: bool = bool(roll.get("kept", false))
		var node := MeshInstance3D.new()
		node.mesh = _die_mesh(int(roll.get("sides", 6)))
		var body := StandardMaterial3D.new()
		body.vertex_color_use_as_albedo = true
		body.roughness = 0.4
		node.material_override = body
		node.scale = Vector3.ONE * 0.16
		room.add_child(node)
		var across: float = (float(i) - float(count - 1) * 0.5) * 0.7
		var side: Vector3 = camera.global_transform.basis.x * Vector3(1, 0, 1)
		var land: Vector3 = ahead + side.normalized() * across
		land.y = room.ground(land.x - room.global_position.x, land.z - room.global_position.z) + 0.16
		var start: Vector3 = land + Vector3(0, 1.8, 0) - (-camera.global_transform.basis.z * Vector3(1, 0, 1)).normalized() * 1.2
		node.global_position = start
		var spin := Vector3(randf_range(-14, 14), randf_range(-14, 14), randf_range(-14, 14))
		var delay: float = 0.4 + 0.45 * float(i)
		var number := Label3D.new()
		number.text = str(int(roll.get("roll", 1)))
		number.font = DeepUi.display_font()
		number.font_size = 64
		number.pixel_size = 0.005
		number.outline_size = 12
		number.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		number.modulate = Color(DeepUi.GOOD if kept else DeepUi.BAD, 0.0)
		number.position = land + Vector3(0, 0.55, 0)
		room.add_child(number)
		var tween := node.create_tween()
		tween.tween_interval(delay)
		tween.tween_callback(func() -> void: DeepAudio.play("die_tumble", {"volume": 0.6, "gap": 0.02}))
		tween.tween_method(func(t: float) -> void:
			if is_instance_valid(node):
				var bounce: float = absf(sin(t * PI * 2.5)) * (1.0 - t) * 0.5
				node.global_position = start.lerp(land, t) + Vector3(0, bounce, 0)
				node.rotation = spin * (1.0 - t) * (1.0 - t), 0.0, 1.0, 0.9)
		tween.tween_callback(func() -> void:
			if not is_instance_valid(node):
				return
			number.modulate.a = 1.0
			if kept:
				DeepAudio.play("salvage_save", {"gap": 0.0})
				fx.flash(land + Vector3(0, 0.4, 0), DeepUi.GOOD, 4.0, 4.0, 0.4, 0.6)
				_lift_stone(land + Vector3(0, 0.3, 0), roll.get("stone", {}), bag_goal, 0.3, Callable())
			else:
				DeepAudio.play("salvage_lose", {"gap": 0.0})
				fx.flash(land + Vector3(0, 0.4, 0), DeepUi.BAD, 4.0, 4.0, 0.4, 0.6)
				var tint: Color = GemMesh.tint(roll.get("stone", {}))
				fx.shards(land + Vector3(0, 0.5, 0), tint, 14, 3.5, 0.12, 1.1)
				fx.sparks(land + Vector3(0, 0.5, 0), tint, 30, 4.0, 0.5, 0.05))

# --- the stall -----------------------------------------------------------------------------------

func stall(stock: Array, appraise_cost: int) -> Node3D:
	## The merchant's counter, built once for the room.
	if _headless or not has_room():
		return null
	var key: String = "stall|%s" % str(place.get("key", ""))
	if business_key() != key:
		var made: Node3D = Stall.new()
		made.position = Chamber.ARENA + Vector3(0, 0, 1.9)
		set_business(key, made, Stall.WIDTH * 0.5 + 0.3)
		made.build(room.biome, stock, room_seed(place) + 23)
		_lead_eye(Vector3(0.0, 0.85, -3.0))
	var counter: Node3D = business()
	counter.show_stock(stock)
	counter.set_lens_price(appraise_cost)
	return counter

func stall_sold(item_id: String, bag_at: Vector2, mine: bool) -> void:
	## Goods off the counter: into the party's bag, or away with whoever bought them.
	var counter: Node3D = business()
	if _headless or counter == null or not counter.has_method("take"):
		return
	var goods: Node3D = counter.take(item_id)
	if goods == null:
		return
	if mine and _laid_out():
		_fly(goods, from_screen(bag_at, 1.5), 0.05, 0.6, "", Callable())
	else:
		fx.puff(goods.global_position, Color("8a7a66"), 6, 0.5, 0.8, 0.2)
		var tween := goods.create_tween()
		tween.tween_property(goods, "scale", Vector3.ONE * 0.01, 0.4)
		tween.tween_callback(goods.queue_free)

# --- the vein ------------------------------------------------------------------------------------

func vein(spots: Array, hazard: bool, finders: Dictionary) -> Node3D:
	## The vein's outcrop, built once for the room and brought up to date: spots already
	## struck are holes lit in their finder's color (`finders`: spot index -> color).
	if _headless or not has_room():
		return null
	var key: String = "vein|%s" % str(place.get("key", ""))
	if business_key() != key:
		var face: Node3D = VeinFace.new()
		face.position = Chamber.ARENA + Vector3(0, 0, -0.8)
		## The blocks lie either side of the way through, so nobody rounds them.
		set_business(key, face, 0.0)
		face.build(room.biome, spots, room_seed(place) + 17, hazard, func(x: float, z: float) -> float: return room.ground(x, z))
		_lead_eye(HOME_LOOK + Vector3(0, 0.55, -1.0))
	var face: Node3D = business()
	for index in range(spots.size()):
		if finders.has(index):
			face.hollow(index, finders[index])
	return face

func vein_strike(index: int, finder: Color, mine: bool, hazard: bool, through: bool = true) -> Vector3:
	## A pick goes into the vein at a spot. The rock answers; if the blow went through, the
	## spot is left a hole. Returns where the find comes out, for it to be thrown from.
	var face: Node3D = business()
	if _headless or face == null or not face.has_method("strike"):
		return Vector3.ZERO
	var at: Vector3 = face.global_transform * face.spot_point(index)
	## The pick goes up and comes down, and the rock only answers when it lands. Playing both
	## at once read as the rock breaking itself while somebody waved a tool at it.
	var wait: float = 0.0
	if mine:
		wait = _swing(at)
	var land: Callable = func() -> void:
		if not is_instance_valid(face):
			return
		face.strike(index, fx, mine)
		if through:
			face.hollow(index, finder)
		DeepAudio.play("pick_strike", {"gap": 0.0})
		camera.add_trauma(0.28 if mine else 0.12)
		if mine:
			camera.punch(-3.0, 0.3)
			camera.focus(at, 0.12, 0.6)
		if hazard:
			## The vug: every blow shakes the room, and the room bites back.
			camera.add_trauma(0.35)
			fx.dust_fall(40)
			room.surge(Color("ff5a3a"), 0.6)
			if mine:
				screen_fx.wound(0.6)
				screen_fx.blink(Color(1.0, 0.25, 0.15), 0.18)
	if wait <= 0.0:
		land.call()
	else:
		var beat := create_tween()
		beat.tween_interval(wait)
		beat.tween_callback(land)
	return at

func _swing(target: Vector3) -> float:
	## The party's pick, seen at the edge of the view: up over the shoulder, and down into the
	## rock. A real pickaxe head, not a blade — a long tapered point on one side and a stubby
	## flat on the other, set across the haft. Returns how long until it lands.
	var pick := Node3D.new()
	camera.add_child(pick)
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color("6a4428")
	wood.roughness = 0.9
	var steel := StandardMaterial3D.new()
	steel.albedo_color = Color("8a8f98")
	steel.metallic = 0.8
	steel.roughness = 0.35
	var handle := MeshInstance3D.new()
	var shaft := BoxMesh.new()
	shaft.size = Vector3(0.055, 0.68, 0.055)
	handle.mesh = shaft
	handle.material_override = wood
	handle.position = Vector3(0, 0.34, 0)
	pick.add_child(handle)
	## The eye the head is hung in.
	var eye := MeshInstance3D.new()
	var collar := BoxMesh.new()
	collar.size = Vector3(0.11, 0.13, 0.11)
	eye.mesh = collar
	eye.material_override = steel
	eye.position = Vector3(0, 0.68, 0)
	pick.add_child(eye)
	## The point: long, tapered, and lying along the swing rather than across it, so the tip
	## is what meets the rock. Set across the haft it went in sideways, which is a hammer
	## blow with the cheek of the head and not a pick at all.
	var point := MeshInstance3D.new()
	var spike := PrismMesh.new()
	spike.size = Vector3(0.09, 0.48, 0.07)
	point.mesh = spike
	point.material_override = steel
	point.position = Vector3(0.0, 0.70, -0.26)
	point.rotation = Vector3(-PI * 0.5 - 0.22, 0.0, 0.0)
	pick.add_child(point)
	## The flat on the other side, short and blunt, counterweighting it.
	var flat := MeshInstance3D.new()
	var chisel := BoxMesh.new()
	chisel.size = Vector3(0.075, 0.09, 0.20)
	flat.mesh = chisel
	flat.material_override = steel
	flat.position = Vector3(0.0, 0.69, 0.15)
	flat.rotation = Vector3(0.1, 0.0, 0.0)
	pick.add_child(flat)
	## Swung from low on the right toward the spot, quick: up in a beat and down in less.
	var aim: Vector3 = camera.to_local(target).normalized()
	pick.position = Vector3(0.55, -0.55, -0.7)
	pick.rotation = Vector3(0.9, 0.0, -0.5)
	var strike_rot := Vector3(-0.6 + clampf(-aim.y, -0.4, 0.4), clampf(-aim.x * 0.8, -0.5, 0.5), -0.25)
	var tween := pick.create_tween()
	tween.tween_property(pick, "rotation", Vector3(1.45, 0.0, -0.45), 0.09).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(pick, "rotation", strike_rot, 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_interval(0.1)
	tween.tween_property(pick, "position", Vector3(0.7, -0.9, -0.6), 0.22).set_ease(Tween.EASE_IN)
	tween.tween_callback(pick.queue_free)
	return 0.17

func throw_find(result: Dictionary, at: Vector3, ore_at: Vector2, bag_at: Vector2, arrived: Callable, mine: bool, after: float = 0.0) -> float:
	## What came out of the rock, thrown up and away: to the strip if it is the party's own
	## (`arrived` is told when it lands), off into the dark toward whoever struck it if not.
	if _headless or not has_room() or not _laid_out():
		if arrived.is_valid():
			arrived.call()
		return 0.0
	var ore_goal: Vector3 = from_screen(ore_at, 1.5) if mine else at + Vector3(0, 3.0, 4.0)
	var bag_goal: Vector3 = from_screen(bag_at, 1.5) if mine else at + Vector3(0, 3.0, 4.0)
	var told: Array = [false]
	var tell: Callable = func() -> void:
		if not bool(told[0]):
			told[0] = true
			if arrived.is_valid():
				arrived.call()
	var spent: float = 0.3
	match str(result.get("kind", "")):
		"stone":
			spent = _lift_stone(at, result.get("stone", {}), bag_goal, after + 0.12, tell)
		"die":
			spent = _fly(_die_node(result.get("die", {}), at), bag_goal, after + 0.35, 0.6, "die_settle", tell)
		"ore":
			var count: int = clampi(int(result.get("ore", 0)) / 2, 3, 7)
			var rng := RandomNumberGenerator.new()
			rng.randomize()
			for i in range(count):
				var nugget := MeshInstance3D.new()
				nugget.mesh = Lowpoly.rock(rng, DeepUi.ORE, 0.42)
				nugget.material_override = _metal(DeepUi.ORE, 0.35)
				nugget.scale = Vector3.ONE * rng.randf_range(0.07, 0.11)
				room.add_child(nugget)
				nugget.global_position = at + Vector3(rng.randf_range(-0.3, 0.3), rng.randf_range(-0.2, 0.2), 0.2)
				spent = maxf(spent, _fly(nugget, ore_goal, after + 0.15 + 0.06 * float(i), 0.55, "ore" if i == 0 else "", tell))
		_:
			fx.puff(at, Color("8a7a66"), 12, 1.0, 1.6, 0.3)
			tell.call()
	return spent

# --- sealing and opening -----------------------------------------------------------------------

func seal(animated: bool = true) -> void:
	## The whole far end of the room comes down, not a plug in each mouth: nobody leaves
	## until the fight is won, and the room says so with a wall.
	if _headless or not has_room() or not _falls.is_empty():
		return
	var fall: Node3D = Rockfall.new()
	fall.position = Vector3(0.0, 0.0, Chamber.Z_FAR + 0.6)
	fall.fx = fx
	fall.jolt = func(amount: float) -> void: camera.add_trauma(amount)
	room.add_child(fall)
	fall.build(Color(room.biome.rock).lightened(0.05), room_seed(place), SEAL_HALF, SEAL_TALL)
	if animated:
		fall.fall()
		_seal_until = Time.get_ticks_msec() + int(SEAL_SECONDS * 1000.0)
	else:
		fall.rest()
	_falls.append(fall)
	if animated:
		## The light goes out as the rock comes down over it.
		var snuff := create_tween()
		snuff.tween_interval(0.75)
		snuff.tween_callback(func() -> void:
			for mouth in _mouths:
				if is_instance_valid(mouth):
					mouth.set_state("sealed"))
	else:
		for mouth in _mouths:
			mouth.set_state("sealed")
	if animated:
		DeepAudio.play("rockfall", {"volume": 0.95})
		camera.add_trauma(0.25)
		camera.focus(room.global_transform * Vector3(0.0, 2.2, Chamber.Z_FAR), 0.1, 1.8)
		fx.dust_fall(50)
		room.surge(Color(room.biome.accent), 0.4)

func sealed() -> bool:
	return not _falls.is_empty()

func seal_remaining() -> float:
	## How long the rock still has to fall. A fight holds its creatures back this long, so
	## the way out is seen to shut before anything comes up out of the floor.
	return maxf(0.0, float(_seal_until - Time.get_ticks_msec()) / 1000.0)

func _crumble() -> float:
	## The rockfall comes apart; returns how long before the way is clear.
	for fall in _falls:
		if is_instance_valid(fall):
			fall.crumble()
	_falls.clear()
	DeepAudio.play("crumble", {"volume": 0.9})
	camera.add_trauma(0.18)
	return 0.95

# --- travelling --------------------------------------------------------------------------------

static func _smooth(points: Array) -> Curve3D:
	var made := Curve3D.new()
	made.bake_interval = 0.1
	for i in range(points.size()):
		var handle := Vector3.ZERO
		if i > 0 and i < points.size() - 1:
			handle = (Vector3(points[i + 1]) - Vector3(points[i - 1])) / 6.0
		made.add_point(points[i], -handle, handle)
	return made

static func _ease(t: float) -> float:
	## Gathers pace, walks on, slows to a stop: a trapezoid of speed, never a lurch.
	var a: float = 0.18
	var b: float = 0.24
	var top: float = 1.0 / (1.0 - a * 0.5 - b * 0.5)
	if t < a:
		return top * t * t / (2.0 * a)
	if t > 1.0 - b:
		return 1.0 - top * (1.0 - t) * (1.0 - t) / (2.0 * b)
	return top * a * 0.5 + top * (t - a)

func _stroll(to: Vector3, look: Vector3, seconds: float, mode: String) -> void:
	## A few steps inside the room: up to the crossroads, or back to the mark.
	var from: Vector3 = camera.home_position
	camera.settle(0.6)
	var tween := camera.create_tween()
	tween.tween_property(camera, "home_fov", BASE_FOV, 0.6)
	var detour: Array = _round_business(from, to)
	var path: Curve3D = _smooth([from] + (detour if not detour.is_empty() else [from.lerp(to, 0.5) + Vector3(0, 0.05, 0)]) + [to])
	_travel = {"kind": "stroll", "path": path, "length": path.get_baked_length(), "seconds": seconds, "t": 0.0, "look_from": camera.home_look,
		"look_end": look, "to": mode, "last": 0.0}
	_at = "moving"

func _stop_travel() -> void:
	## Whatever the party was doing on its feet, it stops where it is.
	if _crumble_timer != null:
		_crumble_timer = null
	if not _falls.is_empty():
		_crumble()
	if str(_travel.get("kind", "")) == "walk":
		_travel.t = 1.0
		_advance(0.0)
	_travel = {}
	if camera != null:
		camera.bob = 0.0

func walk(p: Dictionary, exit_index: int, arrive: Callable = Callable(), halfway: Callable = Callable()) -> void:
	## Down the chosen mouth's tunnel and into the next room.
	if _headless or not has_room() or exit_index < 0 or exit_index >= room.exits.size():
		show_room(p)
		if arrive.is_valid():
			arrive.call()
		return
	_stop_travel()
	_clear_spoils()
	_set_hover(-1)
	var way: Dictionary = room.exits[exit_index]
	var origin: Vector3 = way.origin
	var made: Dictionary = _new_room(p, origin)
	var ahead: Node3D = made.room
	_pending = made.steps
	## The rest of the tunnel, from where its stub stops; the stub's dead end goes.
	var tunnel: Node3D = Tunnel.new()
	world.add_child(tunnel)
	tunnel.build(room.biome, ahead.biome, way.points, int(way.seed), Tunnel.STUB, INF, false)
	var stub: Node3D = way.get("stub", null)
	if stub != null and is_instance_valid(stub) and stub.cap != null:
		stub.cap.visible = false
	for mouth in _mouths:
		if int(mouth.index) != exit_index:
			mouth.set_state("dark")
	## The path: from where the party stands, up to the mouth, down the tunnel's middle at
	## eye height, out into the next room and onto its mark.
	var from: Vector3 = camera.home_position
	var mouth_at: Vector3 = room.mouth(exit_index)
	var points: Array = [from]
	points.append_array(_round_business(from, Vector3(mouth_at.x, EYE, Chamber.Z_FAR + 5.0)))
	if from.z > Chamber.Z_FAR + 8.0:
		points.append(Vector3(mouth_at.x, EYE + 0.05, Chamber.Z_FAR + 5.0))
	var s: float = 0.8
	while s < tunnel.length - 0.8:
		points.append(tunnel.point_at(s) + Vector3.UP * EYE)
		s += 2.4
	points.append(tunnel.point_at(tunnel.length) + Vector3.UP * EYE)
	points.append(origin + HOME)
	var path: Curve3D = _smooth(points)
	var ahead_env: Environment = ahead.environment()
	_travel = {"kind": "walk", "path": path, "length": path.get_baked_length(), "seconds": WALK_SECONDS, "t": 0.0,
		"look_from": camera.home_look, "look_end": origin + HOME_LOOK, "tunnel": tunnel, "ahead": ahead, "ahead_env": ahead_env,
		"place": p, "origin": origin, "arrive": arrive, "halfway": halfway, "told": false, "rested": false,
		"env_from": _env_values(env), "env_to": _env_values(ahead_env), "key_from": Color(room.biome.key), "key_to": Color(ahead.biome.key),
		"portal": path.get_closest_offset(mouth_at + Vector3.UP * EYE), "entrance": path.get_closest_offset(origin + Vector3(0, EYE, Chamber.Z_NEAR)), "last": 0.0}
	_at = "walking"
	camera.settle(0.4)
	var tween := camera.create_tween()
	tween.tween_property(camera, "home_fov", BASE_FOV, 0.4)
	_lantern_goal = 1.0
	DeepAudio.play("tunnel", {"volume": 0.75})

func hurry() -> void:
	## Straight to where the party is going.
	if _travel.is_empty():
		return
	_travel.t = 1.0
	_advance(0.0)

func _advance(delta: float) -> void:
	var travel: Dictionary = _travel
	travel.t = minf(1.0, float(travel.t) + delta / maxf(0.01, float(travel.seconds)))
	var t: float = float(travel.t)
	var total: float = float(travel.length)
	var d: float = _ease(t) * total
	var path: Curve3D = travel.path
	camera.home_position = path.sample_baked(d)
	## Eyes on the way ahead, a little down; at the end, where the room wants them. The point
	## ahead is the average of three further along rather than one, so a tunnel's bend turns
	## the view instead of whipping it, and the whole aim is then chased rather than snapped
	## to, which takes the last of the jerk out of a hard corner.
	var ahead: Vector3 = Vector3.ZERO
	for reach in [3.0, 6.0, 9.0]:
		ahead += path.sample_baked(minf(total, d + float(reach)))
	ahead = ahead / 3.0 + Vector3(0, -0.12, 0)
	var look: Vector3 = Vector3(travel.look_from).lerp(ahead, smoothstep(0.0, 3.5, d))
	look = look.lerp(travel.look_end, smoothstep(total - 6.0, total, d))
	if str(travel.kind) == "stroll":
		look = Vector3(travel.look_from).lerp(travel.look_end, smoothstep(0.0, 1.0, t))
	var chased: Vector3 = Vector3(travel.get("look_now", travel.look_from))
	if delta > 0.0 and t < 1.0:
		chased = chased.lerp(look, 1.0 - exp(-delta * 4.5))
	else:
		chased = look
	travel.look_now = chased
	camera.home_look = chased
	## The stride follows the pace: full at a walk, dying away as the party stops.
	var pace: float = (d - float(travel.last)) / maxf(delta, 0.0001) if delta > 0.0 else 0.0
	travel.last = d
	var usual: float = total / maxf(0.01, float(travel.seconds))
	var gait: float = clampf(pace / maxf(0.01, usual), 0.0, 1.2)
	camera.bob = lerpf(camera.bob, minf(1.0, gait), clampf(delta * 6.0, 0.0, 1.0))
	camera.stride += delta * TAU * 1.2 * clampf(gait, 0.35, 1.2)
	## A footfall every time the head comes down.
	var fall: int = int(floor(camera.stride / PI))
	if fall != _footfall and delta > 0.0:
		_footfall = fall
		if camera.bob > 0.2:
			DeepAudio.play("footstep", {"volume": 0.25 + 0.3 * camera.bob, "vary": 0.18, "gap": 0.05})
	if str(travel.kind) == "walk":
		for _i in range(SLICES):
			if not _pending.is_empty():
				(_pending.pop_front() as Callable).call()
		## The air turns from this room's to the next one's inside the tunnel.
		var through: float = clampf(inverse_lerp(float(travel.portal), float(travel.entrance), d), 0.0, 1.0)
		var turn: float = smoothstep(0.15, 0.85, through)
		_blend_env(env, travel.env_from, travel.env_to, turn)
		var key: Color = Color(travel.key_from).lerp(travel.key_to, turn)
		_lantern.light_color = key
		_lantern_fill.light_color = key
		if has_room():
			room.lamp = 1.0 - smoothstep(0.0, 0.3, through)
			if through > 0.55 and not bool(travel.rested):
				travel.rested = true
				room.rest_lights(false)
		if t > 0.55 and not bool(travel.told):
			travel.told = true
			if (travel.halfway as Callable).is_valid():
				(travel.halfway as Callable).call()
	if t >= 1.0:
		_finish_travel()

func _finish_travel() -> void:
	var travel: Dictionary = _travel
	_travel = {}
	var fade := camera.create_tween()
	fade.tween_property(camera, "bob", 0.0, 0.35)
	if str(travel.get("kind", "")) == "walk":
		_arrive(travel)
	else:
		_at = str(travel.get("to", "home"))

func _arrive(travel: Dictionary) -> void:
	## In the new room: finish it, drop the old one and the tunnel, and move the world back
	## so the new room stands at the origin. Nobody sees the move.
	while not _pending.is_empty():
		(_pending.pop_front() as Callable).call()
	var ahead: Node3D = travel.ahead
	var tunnel: Node3D = travel.tunnel
	_clear_room()
	if is_instance_valid(tunnel):
		tunnel.queue_free()
	ahead.position = Vector3.ZERO
	room = ahead
	place = travel.place
	_settle_in()
	camera.home_position = HOME
	camera.home_look = HOME_LOOK
	arrived_by_walk = true
	_at = "home"
	_lantern_goal = 0.0
	if (travel.arrive as Callable).is_valid():
		(travel.arrive as Callable).call()

static func _env_values(e: Environment) -> Dictionary:
	var out: Dictionary = {}
	if e == null:
		return out
	for field in ENV_FIELDS:
		out[field] = e.get(field)
	return out

static func _blend_env(e: Environment, a: Dictionary, b: Dictionary, weight: float) -> void:
	if e == null or a.is_empty() or b.is_empty():
		return
	for field in ENV_FIELDS:
		e.set(field, lerp(a[field], b[field], weight))

# --- spoils ------------------------------------------------------------------------------------

func _metal(color: Color, glow: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.albedo_color = Color.WHITE
	m.metallic = 0.65
	m.roughness = 0.32
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = glow
	return m

func shed(at: Vector3, tint: Color) -> void:
	## What a creature leaves as it dies: nuggets of ore and one rough lump that might hold a
	## stone, thrown out and left lying in the lantern light until the fight is settled.
	if _headless or not has_room():
		return
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var count: int = rng.randi_range(3, 4)
	for i in range(count + 1):
		var rough: bool = i == count
		var node := MeshInstance3D.new()
		node.mesh = Lowpoly.rock(rng, Color("8d8479") if rough else DeepUi.ORE, 0.3 if rough else 0.42)
		node.material_override = _metal(tint.darkened(0.6), 0.25) if rough else _metal(DeepUi.ORE, 0.35)
		var size: float = rng.randf_range(0.2, 0.25) if rough else rng.randf_range(0.075, 0.12)
		node.scale = Vector3.ONE * size
		node.position = at
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		room.add_child(node)
		if rough:
			var glint := Sprite3D.new()
			glint.texture = DeepUi.glow_texture()
			glint.shaded = false
			glint.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			glint.pixel_size = 0.9 / 64.0
			glint.modulate = Color(tint.lightened(0.5), 0.0)
			glint.position = Vector3(0.3, 0.6, 0.4)
			node.add_child(glint)
			var twinkle := glint.create_tween().set_loops()
			twinkle.tween_property(glint, "modulate:a", 0.9, 0.35).set_delay(rng.randf_range(0.3, 1.2))
			twinkle.tween_property(glint, "modulate:a", 0.0, 0.5)
		var land := Vector3(at.x + rng.randf_range(-1.2, 1.2), 0.0, at.z + rng.randf_range(-0.4, 1.2))
		land.y = room.ground(land.x, land.z) + size * 0.55
		var peak: float = rng.randf_range(0.9, 1.7)
		var spin := Vector3(rng.randf_range(-9, 9), rng.randf_range(-9, 9), rng.randf_range(-9, 9))
		var rest := Vector3(rng.randf() * TAU, rng.randf() * TAU, rng.randf() * TAU)
		var start: Vector3 = at
		var tween := node.create_tween()
		tween.tween_method(func(t: float) -> void:
			if is_instance_valid(node):
				node.position = start.lerp(land, t) + Vector3(0, 4.0 * peak * t * (1.0 - t), 0)
				node.rotation = rest + spin * (1.0 - t), 0.0, 1.0, rng.randf_range(0.45, 0.65))
		tween.tween_method(func(t: float) -> void:
			if is_instance_valid(node):
				node.position = land + Vector3(0, 4.0 * 0.12 * t * (1.0 - t), 0), 0.0, 1.0, 0.2)
		_spoils.append({"node": node, "rough": rough})

func _clear_spoils() -> void:
	for spoil in _spoils:
		if is_instance_valid(spoil.node):
			spoil.node.queue_free()
	_spoils.clear()

func claim(rewards: Dictionary, ore_at: Vector2, bag_at: Vector2, on_ore: Callable, on_bag: Callable, done: Callable) -> void:
	## The fight is settled: the pile resolves into what was really won. Nuggets fly up to
	## the ore count; a rough cracks open into the stone it held, turns in the light a moment,
	## and flies to the bag; a die the same. Roughs that held nothing crumble.
	if _headless or not has_room() or not _laid_out():
		_clear_spoils()
		for callback in [on_ore, on_bag, done]:
			if (callback as Callable).is_valid():
				(callback as Callable).call()
		return
	var ore: int = int(rewards.get("ore", 0))
	var stones: Array = rewards.get("stones", [])
	var dice: Array = rewards.get("dice", [])
	var nuggets: Array = _spoils.filter(func(s: Dictionary) -> bool: return not bool(s.rough) and is_instance_valid(s.node)).map(func(s: Dictionary) -> Node3D: return s.node)
	var roughs: Array = _spoils.filter(func(s: Dictionary) -> bool: return bool(s.rough) and is_instance_valid(s.node)).map(func(s: Dictionary) -> Node3D: return s.node)
	_spoils.clear()
	var pile: Vector3 = room.global_transform * (Chamber.ARENA + Vector3(0, 0.2, 0.8))
	if not nuggets.is_empty():
		pile = Vector3.ZERO
		for node in nuggets:
			pile += (node as Node3D).global_position
		pile /= float(nuggets.size())
	if ore > 0 and nuggets.is_empty():
		for i in range(4):
			var node := MeshInstance3D.new()
			var rng := RandomNumberGenerator.new()
			rng.randomize()
			node.mesh = Lowpoly.rock(rng, DeepUi.ORE, 0.42)
			node.material_override = _metal(DeepUi.ORE, 0.35)
			node.scale = Vector3.ONE * 0.1
			room.add_child(node)
			node.global_position = pile + Vector3(rng.randf_range(-0.6, 0.6), 0.0, rng.randf_range(-0.4, 0.4))
			nuggets.append(node)
	var ore_goal: Vector3 = from_screen(ore_at, 1.5)
	var bag_goal: Vector3 = from_screen(bag_at, 1.5)
	var last: float = 0.2
	var bagged: Array = [false]
	var tell_bag: Callable = func() -> void:
		if not bool(bagged[0]):
			bagged[0] = true
			if on_bag.is_valid():
				on_bag.call()
	## Stones first: each rough that held one cracks and gives it up.
	for i in range(maxi(roughs.size(), stones.size())):
		var rough: Node3D = roughs[i] if i < roughs.size() else null
		var at: Vector3 = rough.global_position if rough != null else pile + Vector3(0.4 * float(i), 0.1, 0.2)
		if rough != null:
			var spot: Vector3 = rough.global_position
			var crack := rough.create_tween()
			crack.tween_interval(0.12 + 0.55 * float(i))
			crack.tween_callback(func() -> void:
				fx.shards(spot, Color("8d8479"), 8, 2.6, 0.1, 0.8)
				fx.puff(spot, Color("8a7a66"), 6, 0.6, 1.0, 0.3)
				DeepAudio.play("rock_break", {"volume": 0.55, "gap": 0.02})
				rough.queue_free())
		if i < stones.size():
			last = maxf(last, _lift_stone(at, stones[i], bag_goal, 0.12 + 0.55 * float(i), tell_bag))
	for i in range(dice.size()):
		last = maxf(last, _fly(_die_node(dice[i], pile + Vector3(-0.5, 0.1, 0.3)), bag_goal, 0.5 + 0.35 * float(i) + 0.4 * float(stones.size()), 0.6, "die_settle", tell_bag))
	## Then the ore, nugget by nugget; the count ticks over as the first one lands.
	var counted: Array = [false]
	for i in range(nuggets.size()):
		var node: Node3D = nuggets[i]
		if ore <= 0:
			fx.puff(node.global_position, Color("8a7a66"), 5, 0.5, 0.8, 0.2)
			node.queue_free()
			continue
		last = maxf(last, _fly(node, ore_goal, 0.3 + 0.07 * float(i), 0.55, "ore", func() -> void:
			if not bool(counted[0]):
				counted[0] = true
				if on_ore.is_valid():
					on_ore.call()))
	if ore <= 0 and on_ore.is_valid():
		on_ore.call()
	if stones.is_empty() and dice.is_empty():
		tell_bag.call()
	var finish := create_tween()
	finish.tween_interval(last + 0.2)
	finish.tween_callback(func() -> void:
		if done.is_valid():
			done.call())

func _fly(node: Node3D, goal: Vector3, delay: float, seconds: float, sound: String, arrived: Callable) -> float:
	## Hop up off the floor and away to a place on the HUD, shrinking as it goes.
	var start: Vector3 = node.global_position
	var size: Vector3 = node.scale
	var lift: Vector3 = start + Vector3(randf_range(-0.3, 0.3), 0.9, 0.3)
	var tween := node.create_tween()
	tween.tween_interval(delay)
	tween.tween_method(func(t: float) -> void:
		if is_instance_valid(node):
			var a: Vector3 = start.lerp(lift, t)
			var b: Vector3 = lift.lerp(goal, t)
			node.global_position = a.lerp(b, t)
			node.rotation += Vector3(0.2, 0.3, 0.1)
			node.scale = size * lerpf(1.0, 0.35, t), 0.0, 1.0, seconds).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback(func() -> void:
		if not sound.is_empty():
			DeepAudio.play(sound, {"volume": 0.35, "gap": 0.04, "vary": 0.15})
		if arrived.is_valid():
			arrived.call()
		node.queue_free())
	return delay + seconds

func _lift_stone(at: Vector3, stone: Dictionary, goal: Vector3, delay: float, arrived: Callable) -> float:
	## The stone itself, cut from its own numbers: up out of the rough, a turn in the light so
	## its color and size are read off it, then into the bag.
	var holder := Node3D.new()
	room.add_child(holder)
	holder.global_position = at
	holder.scale = Vector3.ONE * 0.001
	var gem: Node3D = GemMesh.solid(stone)
	var extent: float = float(gem.get_meta("extent", 1.0))
	gem.scale = Vector3.ONE * (0.42 / extent) * clampf(0.8 + float(DeepStone.shown_carat(stone)) * 0.05, 0.8, 1.4)
	gem.rotation = Vector3(deg_to_rad(-70), 0, 0)
	holder.add_child(gem)
	## A raw stone comes out of the wall with its rock still on it, the way it will sit under
	## the loupe: its color and its size class show, and nothing else.
	if not bool(stone.get("appraised", false)):
		var chunks: Array = GemRock.chunks(stone)
		var rock := GemRock.material()
		var seams := GemRock.seam_material(GemMesh.tint(stone))
		for chunk in chunks:
			var piece := MeshInstance3D.new()
			piece.mesh = chunk.mesh
			GemRock.dress(piece, rock, seams)
			piece.position = chunk.position
			piece.rotation = chunk.rotation
			gem.add_child(piece)
		## As big as the stone alone would be, give or take, the way it sits on the bench.
		gem.scale *= GemView.ROCK_SPAN / GemRock.reach(chunks)
	var tint: Color = GemMesh.tint(stone)
	var shine := OmniLight3D.new()
	shine.light_color = tint
	shine.light_energy = 0.0
	shine.omni_range = 2.5
	shine.position = Vector3(0, 0.3, 0.4)
	holder.add_child(shine)
	## A stone coming out of the rock is the best thing that happens in a room, so it is
	## given the room: it comes up out of the rough into the middle of the view, twice the
	## size it was, turns there under its own light while the room reads it out, and only
	## then goes into the bag.
	var held: Vector3 = from_screen(size * Vector2(0.5, 0.44), 3.4) if _laid_out() else at + Vector3(0, 1.4, 1.2)
	var loud: bool = not bool(stone.get("appraised", false)) or int(DeepStone.grade(stone).index) >= 2
	var tween := holder.create_tween()
	tween.tween_interval(delay)
	tween.tween_callback(func() -> void:
		DeepAudio.play("stone_found", {"volume": 0.9, "gap": 0.02})
		fx.flash(at + Vector3(0, 0.3, 0), tint, 7.0, 5.5, 0.55, 1.4)
		fx.glow_burst(at + Vector3(0, 0.3, 0), tint.lightened(0.25), 2.2, 0.45)
		fx.ring_wave(Vector3(at.x, 0.02, at.z), tint, 2.6, 0.7, 0.28)
		fx.sparks(at + Vector3(0, 0.2, 0), tint.lightened(0.3), 34, 3.4, 0.7, 0.055)
		fx.rise(at + Vector3(0, 0.1, 0), tint.lightened(0.4), 22, 0.9, 1.6)
		if camera.has_method("punch"):
			camera.punch(-2.4, 0.5))
	tween.tween_property(holder, "scale", Vector3.ONE * 2.6, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(holder, "global_position", held, 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(shine, "light_energy", 3.2, 0.5)
	tween.parallel().tween_property(holder, "rotation:y", TAU, 1.6)
	tween.parallel().tween_callback(func() -> void:
		announce(stone)
		fx.glow_burst(held, tint.lightened(0.3), 3.0, 0.6)
		if loud:
			fx.stars(held, tint.lightened(0.45), 1.3, 0.8)).set_delay(0.3)
	tween.tween_interval(1.0)
	tween.tween_callback(func() -> void:
		fx.sparks(holder.global_position, tint.lightened(0.5), 14, 2.0, 0.45, 0.04)
		_fly(holder, goal, 0.0, 0.5, "", arrived))
	return delay + 0.55 + 1.0 + 0.5

func announce(stone: Dictionary) -> void:
	## What came out of the rock, said plainly across the middle of the room: a size and a
	## colour for a stone nobody has read, its whole name for one that has been.
	if _headless or not _laid_out():
		return
	var read: bool = bool(stone.get("appraised", false))
	var tint: Color = DeepUi.tier_color(str(DeepStone.grade(stone).tier)) if read else GemMesh.tint(stone)
	var banner := PanelContainer.new()
	banner.add_theme_stylebox_override("panel", DeepUi.raised(Color(0.03, 0.035, 0.05, 0.82), Color(tint, 0.85), 14, 12, 0.6))
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(banner)
	var box := DeepUi.vbox(banner, 2)
	DeepUi.title(box, DeepUi.stone_name(stone), 30, tint.lightened(0.3), HORIZONTAL_ALIGNMENT_CENTER)
	DeepUi.label(box, "found" if read else "found, still in its rock", 14, DeepUi.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	banner.reset_size()
	banner.position = Vector2(size.x * 0.5 - banner.size.x * 0.5, size.y * 0.44 + 92.0)
	DeepUi.pop_in(banner, 0.0, 0.88, 0.28)
	DeepUi.burst(self, banner.position + banner.size * 0.5, tint.lightened(0.3), 26, 220.0, 0.8, 5.0)
	var fade := banner.create_tween()
	fade.tween_interval(1.25)
	fade.tween_property(banner, "modulate:a", 0.0, 0.35)
	fade.tween_callback(banner.queue_free)

func _die_node(die: Dictionary, at: Vector3) -> Node3D:
	var node := MeshInstance3D.new()
	var shape: String = str(die.get("shape", "D6"))
	if shape == "D6":
		var box := BoxMesh.new()
		box.size = Vector3.ONE * 0.2
		node.mesh = box
	else:
		var rng := RandomNumberGenerator.new()
		rng.seed = 5
		node.mesh = Lowpoly.rock(rng, Color.WHITE, 0.0)
		node.scale = Vector3.ONE * 0.13
	var m := StandardMaterial3D.new()
	m.albedo_color = DiceIcons.palette(str(die.get("key", "D6"))).body
	m.roughness = 0.35
	m.emission_enabled = true
	m.emission = m.albedo_color
	m.emission_energy_multiplier = 0.3
	node.material_override = m
	room.add_child(node)
	node.global_position = at
	return node

# --- space -------------------------------------------------------------------------------------

func _laid_out() -> bool:
	## The viewport is only sized once the stage has been on screen; until then there is no
	## projection to speak of.
	return camera != null and viewport != null and frame.size.x >= 1.0 and frame.size.y >= 1.0 and viewport.size.x >= 1 and viewport.size.y >= 1

func to_screen(point: Vector3) -> Vector2:
	## Where a point in the room is, in the stage's own coordinates.
	if not _laid_out():
		return size * 0.5
	var at: Vector2 = _steady(func() -> Variant: return camera.unproject_position(point))
	return at * (frame.size / Vector2(viewport.size)) + frame.position

func from_screen(local: Vector2, distance: float) -> Vector3:
	if not _laid_out():
		return Vector3(0.0, 1.3, 5.2 - distance) if camera == null or not camera.is_inside_tree() else camera.global_position + (-camera.global_transform.basis.z) * distance
	var at: Vector2 = (local - frame.position) * (Vector2(viewport.size) / frame.size)
	var point: Vector3 = _steady(func() -> Variant: return camera.project_position(at, distance))
	return point if point.is_finite() else camera.global_position + (-camera.global_transform.basis.z) * distance

func _steady(work: Callable) -> Variant:
	## Runs a projection through the view as it would be standing still. The camera breathes
	## and sways the whole time nothing is happening; everything the HUD pins to a place in
	## the room (a mouth's box, a plate over a creature, a tooltip) would drift with it and
	## slide out from under the pointer, so those are read off the steady view instead.
	if not camera.has_method("steady_transform"):
		return work.call()
	var live: Transform3D = camera.global_transform
	camera.global_transform = camera.steady_transform()
	var answer: Variant = work.call()
	camera.global_transform = live
	return answer

# --- the frame ---------------------------------------------------------------------------------

func _process(delta: float) -> void:
	if _headless or camera == null:
		return
	if not _travel.is_empty() and not frozen:
		_advance(delta)
	_lantern_level = move_toward(_lantern_level, _lantern_goal, delta * (1.6 if _lantern_goal > _lantern_level else 0.9))
	_lantern.light_energy = 2.4 * _lantern_level
	_lantern_fill.light_energy = 0.45 * _lantern_level
	_lantern.visible = _lantern_level > 0.01
	_lantern_fill.visible = _lantern_level > 0.01
	_lantern.rotation = Vector3(-0.08 + sin(camera.stride) * 0.015 * camera.bob, sin(camera.stride * 0.5) * 0.05 * camera.bob, 0.0)
	if not is_visible_in_tree():
		return
	_govern(delta)
	if _at in ["home", "crossroads"]:
		_ambience(delta)

func _govern(delta: float) -> void:
	## Keeps the mine smooth: after a few seconds under 40 frames a second, the room gives
	## up its most expensive effects one step at a time.
	if quality <= 1 or quality_pref > 0:
		return
	if Engine.get_frames_per_second() < 40:
		_slow += delta
	else:
		_slow = maxf(0.0, _slow - delta * 2.0)
	if _slow > 3.0:
		_slow = 0.0
		_set_quality(quality - 1)

func apply_quality() -> void:
	## The settings menu changed the graphics setting: take it up now, even mid-fight.
	_slow = 0.0
	_set_quality(3 if quality_pref <= 0 else clampi(quality_pref, 1, 3))

func apply_look() -> void:
	## The outline setting was switched: the room in front of you changes with it, no reload.
	if look == null:
		return
	look.set_look(Looks.pref)
	if has_room():
		look.tint(room.biome)

func _set_quality(level: int) -> void:
	quality = level
	if fx != null:
		fx.quality = quality
	if has_room() and env != null:
		room.set_quality(quality, env)
	if viewport != null:
		viewport.msaa_3d = Viewport.MSAA_8X if quality >= 3 else (Viewport.MSAA_4X if quality == 2 else Viewport.MSAA_DISABLED)
		## Multisampling only smooths where two triangles meet. Everything else the room
		## draws — the ink pass's own creases, the lit edge of a crystal, the alpha of a
		## sprite over the rock — is a shader edge inside one triangle, and stays as ragged
		## as it was written until a screen-space pass has been over it too.
		viewport.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA if quality >= 1 else Viewport.SCREEN_SPACE_AA_DISABLED

func _ambience(delta: float) -> void:
	## The room keeps moving on its own: a Warden's hall shakes and sheds dust, the magma
	## seam heaves, the Rift flickers.
	_ambient_clock += delta
	if not has_room() or _ambient_clock < _next_rumble:
		return
	var biome: Dictionary = room.biome
	_ambient_clock = 0.0
	_next_rumble = randf_range(6.0, 11.0)
	DeepAudio.play("cave_rumble", {"volume": 0.4 if bool(biome.get("warden", false)) else 0.22, "vary": 0.12})
	if bool(biome.get("warden", false)):
		camera.add_trauma(0.22)
		fx.dust_fall(50)
		room.surge(Color(biome.accent), 0.5)
	elif str(biome.get("id", "")) == "magma":
		camera.add_trauma(0.12)
		fx.sparks(Vector3(randf_range(-7, 7), 0.2, randf_range(-14, -6)), Color("ff7a2a"), 30, 4.0, 1.2, 0.08)
	elif str(biome.get("id", "")) == "rift":
		room.surge(Color(biome.accent), 0.8)
		screen_fx.blink(Color(biome.accent), 0.08)
	elif str(biome.get("id", "")) == "galleries" and randf() < 0.5:
		fx.dust_fall(24, 4.0)

# --- warming up --------------------------------------------------------------------------------

func warm_up() -> void:
	## The first fight used to stall for half a second while the GPU compiled everything a
	## room uses. This builds a throwaway room far below the real one, with one of each effect,
	## a tunnel, a mouth and a rockfall, and has a small hidden view of the same world draw it
	## a few times, so the cost is paid before anyone is looking.
	if _headless or _warmed or viewport == null:
		return
	_warmed = true
	var below := Vector3(0, -400, 0)
	var spare := Node3D.new()
	spare.position = below
	world.add_child(spare)
	var sample: Node3D = Chamber.new()
	sample.quality = quality
	spare.add_child(sample)
	sample.build(Biomes.for_depth(DeepContent.starter_mine(), 1, "warden"), 7, 2, 2.5)
	var way: Dictionary = sample.exits[0]
	var tunnel: Node3D = Tunnel.new()
	spare.add_child(tunnel)
	tunnel.build(sample.biome, sample.biome, way.points, int(way.seed), Tunnel.STUB, INF, false)
	var mouth: Node3D = Mouth.new()
	mouth.position = sample.mouth(1)
	sample.add_child(mouth)
	mouth.configure({"kind": "fight", "color": DeepUi.ACCENT, "glyph": "sword", "voters": [DeepUi.ACCENT]})
	mouth.set_state("open")
	var fall: Node3D = Rockfall.new()
	fall.position = sample.mouth(0)
	sample.add_child(fall)
	fall.build(Color(sample.biome.rock), 3)
	fall.rest()
	var creature: CrystalCreature = CrystalCreature.make("CAVE_TICK", true)
	creature.position = below + Vector3(0, 0, -4.4)
	world.add_child(creature)
	var at := below + Vector3(0, 1.2, -4.4)
	fx.sparks(at, DeepUi.ACCENT, 8)
	fx.glow_burst(at, DeepUi.ACCENT)
	fx.puff(at, DeepUi.POISON, 4)
	fx.rise(at, DeepUi.GOOD, 4)
	fx.ring_wave(at, DeepUi.ACCENT)
	fx.flash(at, DeepUi.ACCENT)
	fx.shards(at, DeepUi.ACCENT, 3)
	fx.projectile(below + Vector3(0, 1.5, 2.0), at, DeepUi.ACCENT, 0.1)
	fx.shield(at, Vector3(0, 0, 1), DeepUi.BLOCK)
	fx.coins(at, below + Vector3(0, 1, 2), 2)
	fx.stars(at)
	fx.sigil(at, DeepUi.INFO)
	var view := SubViewport.new()
	view.size = Vector2i(320, 180)
	view.world_3d = viewport.world_3d
	view.msaa_3d = viewport.msaa_3d
	view.positional_shadow_atlas_size = viewport.positional_shadow_atlas_size
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(view)
	var eye := Camera3D.new()
	eye.environment = sample.environment()
	view.add_child(eye)
	eye.look_at_from_position(below + HOME, below + HOME_LOOK, Vector3.UP)
	for _i in range(4):
		await get_tree().process_frame
	view.queue_free()
	spare.queue_free()
	creature.queue_free()
