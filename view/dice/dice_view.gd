extends Control
## A single physical die rendered as real 3D geometry inside its own SubViewport.
##
## Face colors and numerals come from the die's face data, so engraved and
## alternative-distribution dice show their true faces. Rolling spins the solid and
## settles it with the rolled physical face turned toward the camera; the animation is
## presentation only and never chooses the result.

const Geometry = preload("res://view/dice/dice_geometry.gd")
const DiceIcons = preload("res://view/dice/dice_icons.gd")
const FaceMarks = preload("res://view/dice/face_marks.gd")
const GemCut = preload("res://view/dice/gem_cut.gd")
const BloodFx = preload("res://view/dice/blood_fx.gd")

static func look_of(material: String) -> Dictionary:
	## What a die of `material` is drawn as: its MATERIAL_LOOKS entry (empty for a die made of
	## nothing in particular).
	return MATERIAL_LOOKS.get(material, {})

const VIEW_DIRECTION := Vector3(0.0, 0.0, 1.0)
const SPIN_SECONDS := 0.72
const TURN_PER_PIXEL := 0.011
## Past this many faces a numeral cut into one of them is too small to read at tray size, so
## the number it landed on is also written over the settled solid.
const READOUT_SIDES := 20
## A d20's numerals are cut a little larger than its faces' size alone would give them (the
## owner, November 10, 2026: they were hard to read on a phone), still clear of the face's
## edges; the phone, where the dice are smallest, gets the most.
const D20_NUMERAL := 1.14
const D20_NUMERAL_PHONE := 1.22

## How a die made of something catches the light. `alpha` under 1 makes it see-through,
## `glow` lights it from inside. A die of nothing in particular uses the first entry, as it
## always has: pastel, satin, mirroring nothing (`glint` 0).
## `coat` is a clear lacquer over the body (its strength; `coat_rough` how glossy it is),
## `spec` how much light its surface throws back face-on, `rim` the light along its
## silhouette, `body` a tint over the palette's color for the solid alone, `glint` how
## strongly it mirrors the studio (`studio()`) around it, `shine` how hot the close lamp's
## highlight is on it, and `grain` a relief cut into every face (`grain_texture`): pyrite's
## crystal mosaic, brushed steel, a gem's inner facets. `streaks` gives brushed steel its
## drawn roughness and `aniso` stretches its highlight along the brushing.
const PLAIN_LOOK := {"alpha": 1.0, "roughness": 0.42, "metallic": 0.22, "glow": 0.0, "glint": 0.0}
const MATERIAL_LOOKS := {
	## Clear: a thin tint over what lies behind, its far faces showing through, white numbers.
	## Its rims light white and bright, and a very shallow facet relief breaks its highlight
	## into glints (the owner's pick, November 10, 2026, round 3).
	"glass": {"alpha": 0.12, "roughness": 0.0, "metallic": 0.0, "glow": 0.05, "coat": 1.0, "coat_rough": 0.0, "rim": 1.0, "rim_tint": 0.0,
		"spec": 0.85, "glint": 1.6, "shine": 3.0, "clear": true, "inner": 0.44, "tint": "8fe3f2", "grain": "facets", "grain_depth": 0.35},
	## Crystal (round 3): clear, rainbow prism bands sliding through its inside as it turns.
	"crystal": GemCut.CRYSTAL,
	## Diamond and opal (the owner's picks, November 10, 2026, round 2): a brilliant with
	## rainbow fire, and a milky white opal whose patches of color flare as it turns; both quiet
	## behind the numeral and ringed heavily, so its numbers read on every face.
	"diamond": GemCut.DIAMOND,
	"opal": GemCut.OPAL,
	## Gems (the owner's pick, November 10, 2026): cut as brilliants, drawn by their own
	## shaders (gem_cut.gd, `cut`): dark rich color at the rims, bright and near-black facets
	## inside that flash as the die turns, a crown of sparkles on the skin.
	"ruby": GemCut.RUBY,
	"sapphire": GemCut.SAPPHIRE,
	"emerald": GemCut.EMERALD,
	"amethyst": GemCut.AMETHYST,
	"citrine": GemCut.CITRINE,
	## Brushed steel: drawn one way, its highlight stretched along the brushing, a few
	## scratches across it, the edges dark.
	"iron": {"alpha": 1.0, "roughness": 0.55, "metallic": 1.0, "glow": 0.0, "coat": 0.0, "body": "8a96a8", "edge": "232931",
		"grain": "brushed", "grain_depth": 0.3, "grain_scale": 2.6, "streaks": true, "aniso": 0.75, "glint": 1.1, "shine": 1.4, "rim": 0.0},
	## Cloud (round 3): a silvery storm cloud roiling slowly, lightning flickering inside.
	"cloud": GemCut.CLOUD,
	## Fool's gold (the owner's pick, November 10, 2026, round 2): a polished brassy nugget,
	## softly dented, its reflections bending over the dents.
	"fools_gold": GemCut.NUGGET,
	## Granite (round 3): charcoal grey, rough-hewn grains, mica glinting when tipped to a lamp.
	"granite": GemCut.GRANITE,
	## Blood (the owner's pick, November 10, 2026): opaque wet oxblood, marbled with darker
	## veins under a glossy coat, more solid than the see-through gems. It bleeds (`bleeds`):
	## blood runs to its owner's health when it is thrown again, and a kill's blood runs into it.
	"blood": GemCut.OXBLOOD}

## A creature's action die carries one move a face instead of a number: each face is colored
## by what kind of move it is and engraved with the move's mark (face_marks.gd), ivory on
## every face but a dud's, where it is slate. Its colors are true colors (sRGB), not shades.
const MOVE_TINTS := {"attack": Color("d72d47"), "guard": Color("2c6ae8"), "meddle": Color("7f4dd1"),
	"mend": Color("3fb57a"), "ready": Color("f1bb25"), "dud": Color("4d5363")}
const MARK_INK := Color("f5e9c8")
const DUD_INK := Color("9aa3b8")
## The pastels an opal's faces flash (`play` in its look).
## How hot the close lamp's highlight is, before a material's own `shine`.
const SHINE_SPECULAR: float = 6.0
const PLAY_OF_COLOR: Array = [Color("ff9fcf"), Color("8ff0c4"), Color("8fc8ff"), Color("ffe08a"), Color("c7a6ff")]
const MARKED_LOOK := {"alpha": 1.0, "roughness": 0.3, "metallic": 0.45, "glow": 0.0, "glint": 0.0}
## The engraving's shadow: half-dark, a hair down and right of the mark, just under it.
const MARK_SHADOW := Color(0.0, 0.0, 0.0, 0.5)

@export var live := true
## How the solid's edges are smoothed: set before the view joins the tree. A creature's die
## on its tag is rendered at the size it is shown and asks for 8x (the owner, November 5).
@export var msaa: Viewport.MSAA = Viewport.MSAA_4X
## How loud its tumble is: another player's dice land more quietly than the reader's own.
var hush: float = 1.0

## Interactive views are steered by the reader instead of by the roll: dragging
## turns the solid freely and focus_face() swings one face to the front.
var interactive := false
## Rest turned a little off face-on, the way the dice's pictures are drawn (thumbs.gd), so a
## die in a fight looks like the same die as the one on the dock outside it. The turn is
## slight on purpose: the rolled face looks straight out and its number is the big one, with
## only a sliver of the sides showing to say it is a solid. At a full three-quarter turn the
## side faces' numbers read as loudly as the rolled one ("m6" for a 6, "6 5" for a d8's 5).
var tilt := false
const TILT := Vector3(-0.14, 0.17, 0.0)
## A d8 under the cube's tilt turns half its faces edge-on: it turns about the upright only.
const OCTA_TILT := Vector3(0.0, 0.13, 0.0)
var spin_seconds: float = SPIN_SECONDS
var suspense: bool = false
var suspense_scale: float = 1.0

var die: Dictionary = {}
var roll: Dictionary = {}
var selected := false
var highlighted := false
var accent := Color("e8b661")

var _viewport: SubViewport
var _environment: Environment
var _shine: OmniLight3D
## A clear die's inside: its far faces, seen through its near ones (`clear` in its look).
var _inner: MeshInstance3D
var _key: DirectionalLight3D
## The solid's own materials, put back when a cut look (gem_cut.gd) is taken off.
var _body_standard: StandardMaterial3D
var _inner_standard: StandardMaterial3D
var _pivot: Node3D
var _body: MeshInstance3D
var _shell: MeshInstance3D
var _glow: Control
var _readout: Label
var _labels: Array[Label3D] = []
## An action die's engraved marks (two sprites a face, the shadow first), and whether this
## die is one: built in place of the numerals.
var _marks: Array[Sprite3D] = []
var _marked := false
var _frames: Array = []
var _face_index := 0
var _signature := ""
var _roll_token := ""
var _spin_time := 99.0
var _spin_from := Quaternion.IDENTITY
var _spin_axis := Vector3.UP
var _spin_turns := 2.0
var _target := Quaternion.IDENTITY
var _clock := 0.0
var _manual := Quaternion.IDENTITY
var _goal := Quaternion.IDENTITY
var _dragging := false
var _steered := false
## An exploding face lands on its own number first, then the die is thrown again for each
## extra, and every one lands before it is added. `_chain` is the throws still to come,
## `_chain_face` the face it is showing meanwhile, `_running` what has been added up so far.
var _chain: Array = []
var _chain_face := -1
var _chain_wait := 0.0
var _running := -1

## The total so far, each time the die lands: the first face, then each extra added on.
signal chain_stepped(total: int)

## A die that bleeds (blood, `bleeds` in its look) plays blood_fx.gd's effects: "stream" when
## it is thrown again (`blood_reroll`), "thread" when it feeds on a kill (`blood_fed`). `_fx` is
## the one playing, `_fx_time` how long since it began, `_fx_seed` its seed and `_fx_point`
## its far end (the health ring, the creature) on the canvas. `_fx_layer` draws it: top level,
## so the dock does not clip it, made when an effect starts and freed when it ends.
var _bleeds := false
var _fx := ""
var _fx_time := 0.0
var _fx_seed := 0
var _fx_point := Vector2.ZERO
var _fx_layer: Control

## A die a gem counts hops where it stands and twists, a ring of light going out from it.
const POP_SECONDS := 0.42
var _pop_time := 99.0
var _pop_strength := 1.0
var _pop_axis := Vector3.RIGHT
var _pop_tint := Color.WHITE

static func headless() -> bool:
	return DisplayServer.get_name() == "headless"

func _ready() -> void:
	## A view handed to the reader before it joined the tree keeps its grip: resetting this
	## unconditionally is what made the inspector's die refuse to turn.
	mouse_filter = Control.MOUSE_FILTER_STOP if interactive else Control.MOUSE_FILTER_IGNORE
	clip_contents = false
	_glow = Control.new()
	_glow.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_glow.draw.connect(_draw_glow.bind(_glow))
	add_child(_glow)
	## Above the solid whatever order the viewport container lands in.
	_readout = DeepUi.title(self, "", 22, DeepUi.PAPER, HORIZONTAL_ALIGNMENT_CENTER)
	_readout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_readout.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_readout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_readout.z_index = 1
	_readout.visible = false
	_readout.add_theme_color_override("font_outline_color", Color(0.02, 0.03, 0.05, 0.9))
	_readout.add_theme_constant_override("outline_size", 8)
	if headless():
		return
	var container := SubViewportContainer.new()
	container.stretch = true
	container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(container)
	_viewport = SubViewport.new()
	_viewport.transparent_bg = true
	_viewport.own_world_3d = true
	_viewport.disable_3d = false
	_viewport.msaa_3d = msaa
	container.add_child(_viewport)
	_follow_visibility()
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 2.55
	camera.position = Vector3(0, 0, 5)
	camera.near = 0.05
	camera.far = 20.0
	var environment := Environment.new()
	environment.background_mode = Environment.BG_CLEAR_COLOR
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("4d5f7d")
	environment.ambient_light_energy = 1.15
	## Nothing is drawn behind the die, but its polished faces mirror a studio (`studio()`):
	## a few hard-edged softboxes in the dark, so metal and gem catch crisp highlights.
	_environment = environment
	camera.environment = environment
	_viewport.add_child(camera)
	var key_light := DirectionalLight3D.new()
	key_light.light_energy = 1.5
	key_light.light_color = Color("fff2d8")
	key_light.rotation_degrees = Vector3(-38, -34, 0)
	_viewport.add_child(key_light)
	_key = key_light
	var fill_light := DirectionalLight3D.new()
	fill_light.light_energy = 0.55
	fill_light.light_color = Color("7fa8ff")
	fill_light.rotation_degrees = Vector3(24, 148, 0)
	_viewport.add_child(fill_light)
	## A lamp close in, up and to the left: under the flat camera a face lit only from far
	## away is one flat shade, and this puts a hot spot towards a corner of the face turned to
	## the reader, the glint that says "polished". Specular mostly; it barely lights the body.
	_shine = OmniLight3D.new()
	_shine.position = Vector3(-0.3, 0.34, 1.35)
	_shine.omni_range = 4.0
	_shine.omni_attenuation = 1.4
	_shine.light_energy = 0.35
	_shine.light_specular = SHINE_SPECULAR
	_shine.light_color = Color("fff6e6")
	_viewport.add_child(_shine)
	_pivot = Node3D.new()
	_viewport.add_child(_pivot)
	_shell = MeshInstance3D.new()
	_shell.scale = Vector3.ONE * 1.055
	var shell_material := StandardMaterial3D.new()
	shell_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	shell_material.cull_mode = BaseMaterial3D.CULL_FRONT
	shell_material.albedo_color = Color("090c14")
	_shell.material_override = shell_material
	_pivot.add_child(_shell)
	_body = MeshInstance3D.new()
	var body_material := StandardMaterial3D.new()
	body_material.vertex_color_use_as_albedo = true
	body_material.roughness = 0.42
	body_material.metallic = 0.22
	body_material.metallic_specular = 0.6
	body_material.rim_enabled = true
	body_material.rim = 0.5
	_body.material_override = body_material
	_body_standard = body_material
	_pivot.add_child(_body)
	_inner = MeshInstance3D.new()
	var inner_material := StandardMaterial3D.new()
	inner_material.rim_enabled = true
	inner_material.rim = 1.0
	inner_material.metallic_specular = 0.9
	inner_material.rim_tint = 0.8
	inner_material.roughness = 0.2
	inner_material.cull_mode = BaseMaterial3D.CULL_FRONT
	inner_material.vertex_color_use_as_albedo = true
	inner_material.vertex_color_is_srgb = true
	inner_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	inner_material.blend_mode = BaseMaterial3D.BLEND_MODE_PREMULT_ALPHA
	inner_material.render_priority = -1
	_inner.material_override = inner_material
	_inner_standard = inner_material
	_inner.visible = false
	_pivot.add_child(_inner)

func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED:
		_follow_visibility()

func _follow_visibility() -> void:
	## A die nobody can see draws nothing: a fight keeps every player's tray built and shows
	## one at a time, and a hidden tray's solids would otherwise each render a frame apiece.
	_seen = is_visible_in_tree()
	if _viewport != null and is_instance_valid(_viewport):
		if _seen:
			_touch()
		else:
			_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED

## Whether the view is on screen (`_follow_visibility`), and how many more frames the solid
## renders because something about it was just changed (`_touch`).
var _seen: bool = true
var _render_frames: int = 0
var _render_for: float = 0.0
## How often a solid that only sways at rest is rendered again, in seconds.
const SWAY_RENDER: float = 1.0 / 30.0

func _touch(frames: int = 2) -> void:
	## Something about the solid changed (its faces, its material, where it lies): it is
	## rendered for the next few frames whatever else it is doing.
	_render_frames = maxi(_render_frames, frames)
	if _seen and _viewport != null and is_instance_valid(_viewport):
		_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS

func _busy() -> bool:
	## Whether the solid is being moved by anything other than its sway at rest.
	return interactive or _spin_time <= spin_seconds or _running >= 0 or _pop_time < POP_SECONDS

func _steer_viewport(delta: float) -> void:
	## When the solid is rendered. Every die is a 3D pass of its own (five in the tray, one on
	## each creature's tag), which a phone feels, so one that is turning, popping or steered
	## renders every frame; one only swaying at rest renders thirty times a second, its sway
	## too slow for the difference to show; and one lying still renders once more and then
	## not at all, until something about it changes (`_touch`).
	if not _seen or _viewport == null or not is_instance_valid(_viewport):
		return
	if _busy() or _render_frames > 0:
		_render_frames = maxi(0, _render_frames - 1)
		_render_for = 0.0
		_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		return
	if live:
		_render_for += delta
		if _render_for >= SWAY_RENDER:
			_render_for = fmod(_render_for, SWAY_RENDER)
			_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
			return
	## Rendering once more turns the viewport off by itself once it has.
	if _viewport.render_target_update_mode == SubViewport.UPDATE_ALWAYS:
		_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE

func configure(new_die: Dictionary, new_roll: Dictionary, is_selected: bool, is_highlighted: bool, tint: Color) -> void:
	die = new_die
	roll = new_roll
	selected = is_selected
	highlighted = is_highlighted
	accent = tint
	var signature := "%s|%s|%s|%s" % [str(die.get("shape", "D6")), str(die.get("material", "")), _face_values(), str(die.get("pattern", ""))]
	if signature != _signature:
		_signature = signature
		_rebuild()
	_face_index = clampi(int(roll.get("face", 0)), 0, maxi(0, _frames.size() - 1))
	if bool(roll.get("flipped", false)) and _value_at(_face_index) != int(roll.get("value", 0)):
		## A shift lands on a real face and says which; an older one only said the number.
		var shifted_value: int = int(roll.get("value", 0))
		for index in range(_frames.size()):
			if _value_at(index) == shifted_value and _kind_at(index) == "plain":
				_face_index = index
				break
	var resting: int = _face_index
	var thrown: Array = roll.get("chain", []) if str(roll.get("kind", "plain")) == "exploding" else []
	if not thrown.is_empty():
		resting = clampi(int(thrown[thrown.size() - 1].get("face", resting)), 0, maxi(0, _frames.size() - 1))
	if _running >= 0 and _chain_face >= 0:
		_face_index = _chain_face
	else:
		_face_index = resting
	_target = _rest(_face_index)
	var token := "%s#%s#%s#%s" % [str(roll.get("die_id", "")), str(roll.get("rerolls", -1)), str(roll.get("face", -1)), str(roll.get("turn_tag", ""))]
	if bool(roll.get("flipped", false)):
		token += "#shift:%d" % int(roll.get("value", 0))
	if str(roll.get("kind", "plain")) == "tally":
		## A Tally face climbs as it is landed on, so the numeral cut into it is recut and the
		## solid turns over onto the new number rather than changing where it lies.
		token += "#" + str(roll.get("value", 0))
		_relabel(_face_index, DiceIcons.face_text(int(roll.get("value", 0)), "tally"))
	if interactive:
		if not _steered:
			_manual = _target
			_goal = _target
			_steered = true
		_roll_token = token
	elif token != _roll_token:
		_roll_token = token
		_chain = []
		_chain_face = -1
		_running = -1
		if not roll.is_empty():
			if not thrown.is_empty() and is_instance_valid(_pivot):
				## It lands on the face it was thrown onto, and the rest follow.
				_chain = thrown.duplicate()
				_chain_face = clampi(int(roll.get("face", 0)), 0, maxi(0, _frames.size() - 1))
				_running = int(roll.get("base", _value_at(_chain_face)))
				_face_index = _chain_face
				_target = _rest(_face_index)
			_start_spin()
		elif is_instance_valid(_pivot):
			_pivot.quaternion = _target
	elif _spin_time > spin_seconds and is_instance_valid(_pivot):
		_pivot.quaternion = _target
	_sync_readout()
	if is_instance_valid(_glow):
		_glow.queue_redraw()
	_touch()

func _sync_readout() -> void:
	## A d24 and up carries its numerals on faces too small to read, so the number it landed
	## on is written over the solid as well. It is not shown while the solid is still turning,
	## and never on a view the reader steers: there the face under the eye is the answer.
	if not is_instance_valid(_readout):
		return
	## An action die has no number to write: its faces carry moves.
	var wanted: bool = _frames.size() > READOUT_SIDES and not interactive and not _marked
	_readout.visible = wanted
	if not wanted:
		return
	var value: int = int(roll.get("value", _value_at(_face_index))) if not roll.is_empty() else _value_at(_face_index)
	if _running >= 0:
		value = _running
	_readout.text = str(value)
	_readout.add_theme_font_size_override("font_size", maxi(14, int(minf(size.x, size.y) * 0.42)))
	_readout.modulate.a = 1.0 if _spin_time > spin_seconds else 0.0

func settle_immediately() -> void:
	## Restored state already knows this face; do not replay a roll on reconnect.
	_spin_time = spin_seconds + 1.0
	_chain = []
	_chain_face = -1
	_running = -1
	if is_instance_valid(_pivot):
		_pivot.quaternion = _target
		_pivot.position = Vector3.ZERO
		_pivot.scale = Vector3.ONE
	_touch()

func enable_interaction() -> void:
	## Hands the solid to the reader: the roll no longer drives its orientation.
	interactive = true
	live = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_MOVE
	_spin_time = 99.0
	_sync_readout()
	_touch()

func running_total() -> int:
	## What the die has added up to so far while an exploding face is still being thrown
	## again, or -1 when it is not.
	return _running

func face_count() -> int:
	return _frames.size()

func face_value(index: int) -> int:
	return _value_at(index)

func orientation() -> Quaternion:
	## Where the reader has turned the solid. Interactive views only.
	return _manual

func focus_face(index: int) -> void:
	## Swings one physical face to the front. Ignored while the reader is dragging.
	if index < 0 or index >= _frames.size() or _dragging:
		return
	_goal = _orientation(index)

func _gui_input(event: InputEvent) -> void:
	if not interactive:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_dragging = event.pressed
		_goal = _manual
		accept_event()
	elif event is InputEventMouseMotion and _dragging:
		# Screen-space turn: pre-multiplying rotates about the camera's own axes.
		var yaw := Quaternion(Vector3.UP, event.relative.x * TURN_PER_PIXEL)
		var pitch := Quaternion(Vector3.RIGHT, event.relative.y * TURN_PER_PIXEL)
		_manual = (yaw * pitch * _manual).normalized()
		_goal = _manual
		accept_event()

func aims_at(index: int) -> bool:
	## True when the settled orientation turns that physical face toward the camera.
	if index < 0 or index >= _frames.size():
		return false
	var facing: Vector3 = _orientation(index) * Vector3(_frames[index].normal)
	return facing.normalized().dot(VIEW_DIRECTION.normalized()) > 0.999

func pop(strength: float = 1.0, tint: Color = Color.WHITE) -> void:
	## Counted: the solid hops and twists on the spot, a little larger for a moment, and a ring
	## of `tint` goes out from under it. Only a die at rest answers; one still in the air is
	## left to land.
	_pop_time = 0.0
	_pop_strength = clampf(strength, 0.2, 2.0)
	_pop_axis = Vector3(randf_range(-1.0, 1.0), randf_range(-0.35, 0.35), randf_range(-0.6, 0.6))
	_pop_axis = _pop_axis.normalized() if _pop_axis.length() > 0.1 else Vector3.RIGHT
	_pop_tint = tint
	if is_instance_valid(_glow):
		_glow.queue_redraw()

func set_highlight(on: bool) -> void:
	if highlighted == on:
		return
	highlighted = on
	if is_instance_valid(_glow):
		_glow.queue_redraw()

func _wear_material(palette: Dictionary) -> void:
	## What the die is made of, on the solid itself: glass goes see-through, crystal lights up
	## from inside, iron reads as metal, granite as stone. color is already the material.
	if _body_standard != null:
		_body.material_override = _body_standard
	if _inner_standard != null and _inner != null:
		_inner.material_override = _inner_standard
	var body_material: StandardMaterial3D = _body.material_override as StandardMaterial3D
	if body_material == null:
		return
	var worn: Dictionary = look_of(str(die.get("material", "")))
	var look: Dictionary = MARKED_LOOK if _marked else (worn if not worn.is_empty() else PLAIN_LOOK)
	## A plain die keeps the soft pastel it has always had (its colors read as linear); a die
	## made of something wears its material's true color.
	body_material.vertex_color_is_srgb = _marked or not worn.is_empty()
	body_material.metallic_specular = float(look.get("spec", 0.6))
	var streaked: bool = bool(look.get("streaks", false))
	body_material.roughness_texture = streak_texture() if streaked else null
	body_material.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
	var aniso: float = float(look.get("aniso", 0.0))
	body_material.anisotropy_enabled = aniso > 0.001
	body_material.anisotropy = aniso
	var alpha: float = float(look.get("alpha", 1.0))
	body_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA if alpha < 0.999 else BaseMaterial3D.TRANSPARENCY_DISABLED
	## A clear die (glass, crystal, diamond) is seen into: its near faces are a thin tint whose
	## highlights keep their full strength (premultiplied), and through them its far faces
	## show, lit, over the dark of its own shell, the way a clear die looks on a dark cloth.
	## (It does not show the page behind it: each die is drawn in a picture of its own and
	## laid over the page after, and a see-through picture only greys what is under it.)
	var clear: bool = bool(look.get("clear", false))
	body_material.blend_mode = BaseMaterial3D.BLEND_MODE_PREMULT_ALPHA if clear else BaseMaterial3D.BLEND_MODE_MIX
	if _inner != null:
		_inner.visible = clear
		## The far faces glow faintly in the die's own tint, brighter towards their edges
		## where light is trapped inside it.
		var depth: float = float(look.get("inner", 0.3))
		var tint: Color = Color(str(look.get("tint", "ffffff")))
		var inside: StandardMaterial3D = _inner.material_override as StandardMaterial3D
		inside.albedo_color = Color(tint.r * depth, tint.g * depth, tint.b * depth, depth)
		var inner_glow: float = float(look.get("inner_glow", 0.0))
		inside.emission_enabled = inner_glow > 0.001
		inside.emission = palette.body
		inside.emission_energy_multiplier = inner_glow
	## A clear die is premultiplied: its own color is weighed by how much of it there is, and
	## its highlights, added after, are not.
	body_material.albedo_color = Color(alpha, alpha, alpha, alpha) if clear else Color(1.0, 1.0, 1.0, alpha)
	body_material.roughness = float(look.get("roughness", 0.42))
	body_material.metallic = float(look.get("metallic", 0.22))
	var glow: float = float(look.get("glow", 0.0))
	body_material.emission_enabled = glow > 0.001
	body_material.emission = palette.body
	body_material.emission_energy_multiplier = glow * (alpha if clear else 1.0)
	var coat: float = float(look.get("coat", 0.0))
	body_material.clearcoat_enabled = coat > 0.001
	body_material.clearcoat = coat
	body_material.clearcoat_roughness = float(look.get("coat_rough", 0.1))
	body_material.rim = float(look.get("rim", 0.5))
	body_material.rim_tint = float(look.get("rim_tint", 0.5))
	var grain: String = str(look.get("grain", ""))
	body_material.normal_enabled = not grain.is_empty()
	body_material.normal_texture = grain_texture(grain) if not grain.is_empty() else null
	body_material.normal_scale = float(look.get("grain_depth", 1.0))
	var fleck: bool = bool(look.get("fleck", false))
	body_material.albedo_texture = fleck_texture() if fleck else null
	body_material.uv1_scale = Vector3.ONE * float(look.get("grain_scale", 1.0))
	var glint: float = float(look.get("glint", 1.0))
	if _environment != null:
		## A plain die mirrors nothing but the dark around it, as it always has.
		_environment.sky = studio(glint) if glint > 0.001 else null
		_environment.reflected_light_source = Environment.REFLECTION_SOURCE_SKY if glint > 0.001 else Environment.REFLECTION_SOURCE_BG
	if _shine != null:
		_shine.visible = glint > 0.001
		_shine.light_specular = SHINE_SPECULAR * float(look.get("shine", 1.0))
	if _key != null:
		## Under the flat camera a mirror face square to the key light goes white all over;
		## a glossy die takes its sun's highlight softer so a side face's number still reads.
		_key.light_specular = float(look.get("key_spec", 0.5))
	if look.has("cut") and not _marked:
		## A cut look draws the die with its own shaders in place of the two above.
		GemCut.dress(look, str(die.get("material", "")), _body, _inner)
	_touch()

# --- the studio a die mirrors, and the grooves cut into some ---------------------------------

## One studio for each strength of reflection and one set of grooves for every die in the
## game: a sky's reflections are worked out once, the first time a die wearing it is drawn,
## and shared from then on. The strength is the sky's own, not the environment's: the engine
## bakes whichever environment first draws a sky into its reflections, so a die that turned
## the environment's energy down would turn every die's reflection down with it.
static var _studios: Dictionary = {}
static var _studio_image: Texture2D = null
static var _grains: Dictionary = {}

static func studio(strength: float = 1.0) -> Sky:
	## A dark room lit by softboxes, as a small HDR panorama: a broad warm box up and to the
	## left where the key light stands, a cool strip to the right, a bar overhead and a dim
	## floor. Hard edges on purpose: a polished face shows a clean window of light, which is
	## what reads as shine at tray size.
	var key: int = roundi(strength * 100.0)
	if _studios.has(key):
		return _studios[key]
	if _studio_image == null:
		_studio_image = _studio_panorama()
	var panorama := PanoramaSkyMaterial.new()
	panorama.panorama = _studio_image
	panorama.filter = true
	panorama.energy_multiplier = strength
	var sky := Sky.new()
	sky.sky_material = panorama
	sky.radiance_size = Sky.RADIANCE_SIZE_128
	sky.process_mode = Sky.PROCESS_MODE_QUALITY
	_studios[key] = sky
	return sky

static func _studio_panorama() -> Texture2D:
	var width: int = 256
	var height: int = 128
	var image := Image.create_empty(width, height, false, Image.FORMAT_RGBH)
	for y in range(height):
		var v: float = float(y) / float(height - 1)
		## Overhead a little lighter than the floor, both nearly black.
		var base: Color = Color(0.05, 0.06, 0.085).lerp(Color(0.012, 0.012, 0.016), v)
		for x in range(width):
			## Behind the reader (u 0 and 1) a broad warm wall, bright up and to the left and
			## falling away down and to the right: what a face turned towards the camera
			## mirrors, so a metal face, and every tipped crystal face in it, reads as a
			## shade of bright metal rather than going black.
			var u: float = float(x) / float(width)
			var off: float = minf(u, 1.0 - u)
			var wall: float = clampf(1.0 - off / 0.3, 0.0, 1.0) * clampf(1.0 - absf(v - 0.5) / 0.32, 0.0, 1.0)
			if wall > 0.0:
				var side: float = (u if u < 0.5 else u - 1.0) / 0.3
				var lean: float = clampf(0.62 - 0.38 * side - 0.55 * (v - 0.5), 0.15, 1.2)
				base = base.lerp(Color(1.05, 0.95, 0.8) * lean * 0.5, smoothstep(0.0, 0.35, wall))
			image.set_pixel(x, y, base)
	## [centre u, centre v, half width, half height, color]: u runs round the horizon, v down.
	var boxes: Array = [
		[0.96, 0.36, 0.014, 0.03, Color(4.0, 3.7, 3.2)],
		[0.1, 0.55, 0.012, 0.12, Color(2.2, 2.6, 3.2)],
		[0.62, 0.3, 0.07, 0.11, Color(5.0, 4.6, 4.0)],
		[0.88, 0.38, 0.025, 0.2, Color(2.2, 2.8, 3.6)],
		[0.5, 0.06, 0.5, 0.035, Color(0.7, 0.7, 0.75)],
		[0.3, 0.42, 0.05, 0.08, Color(1.9, 1.8, 1.6)],
		[0.08, 0.36, 0.03, 0.14, Color(1.8, 2.2, 3.0)],
		[0.5, 0.72, 0.5, 0.05, Color(0.35, 0.3, 0.26)]]
	for box in boxes:
		var x0: int = int((float(box[0]) - float(box[2])) * width)
		var x1: int = int((float(box[0]) + float(box[2])) * width)
		var y0: int = clampi(int((float(box[1]) - float(box[3])) * height), 0, height - 1)
		var y1: int = clampi(int((float(box[1]) + float(box[3])) * height), 0, height - 1)
		for y in range(y0, y1 + 1):
			for x in range(x0, x1 + 1):
				image.set_pixel(posmod(x, width), y, box[4])
	return ImageTexture.create_from_image(image)

static var _fleck: Texture2D = null

static func fleck_texture() -> Texture2D:
	## Granite's grain: the body's color broken up by dark and pale flecks of feldspar and
	## mica, as a texture the face's own color is multiplied by.
	if _fleck != null:
		return _fleck
	var size: int = 128
	var image := Image.create_empty(size, size, false, Image.FORMAT_RGBA8)
	image.fill(Color(1.0, 1.0, 1.0))
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	for i in range(900):
		var at := Vector2i(rng.randi_range(0, size - 1), rng.randi_range(0, size - 1))
		var dark: bool = rng.randf() < 0.6
		var shade: float = rng.randf_range(0.35, 0.7)
		var tone: Color = Color(shade, shade * 0.97, shade * 0.94) if dark else Color(1.0, 0.93, 0.86)
		var reach: int = rng.randi_range(0, 2)
		for dy in range(-reach, reach + 1):
			for dx in range(-reach, reach + 1):
				if dx * dx + dy * dy <= reach * reach + 1:
					image.set_pixel(posmod(at.x + dx, size), posmod(at.y + dy, size), tone)
	image.generate_mipmaps()
	_fleck = ImageTexture.create_from_image(image)
	return _fleck

static func grain_texture(kind: String) -> Texture2D:
	## A normal map cut into every face, made once and shared:
	## "pyrite": a mosaic of crystal faces, each tipped its own way with sharp edges between
	##   them and fine striations across it, half running one way and half the other, the way
	##   a pyrite cube's faces are grooved. Every tipped face catches its own highlight.
	## "brushed": steel drawn one way: fine streaks of uneven depth and length, and a few
	##   stray scratches across them.
	## "facets": a gem's inner facets, broad and shallow, under its smooth clear coat.
	if _grains.has(kind):
		return _grains[kind]
	var size: int = 128
	var slopes: PackedVector2Array = PackedVector2Array()
	slopes.resize(size * size)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7171
	match kind:
		"pyrite", "facets":
			var grid: int = 4 if kind == "pyrite" else 3
			var tilt: float = 0.34 if kind == "pyrite" else 0.22
			var cell: float = float(size) / float(grid)
			var centres: Array = []
			var tilts: Array = []
			var across: Array = []
			for gy in range(grid):
				for gx in range(grid):
					centres.append(Vector2((float(gx) + rng.randf_range(0.2, 0.8)) * cell, (float(gy) + rng.randf_range(0.2, 0.8)) * cell))
					tilts.append(Vector2(rng.randf_range(-tilt, tilt), rng.randf_range(-tilt, tilt)))
					across.append(rng.randf() < 0.5)
			for y in range(size):
				for x in range(size):
					var best: int = 0
					var near: float = 1e9
					var gx0: int = int(float(x) / cell)
					var gy0: int = int(float(y) / cell)
					for oy in range(-1, 2):
						for ox in range(-1, 2):
							var cx: int = gx0 + ox
							var cy: int = gy0 + oy
							var index: int = posmod(cy, grid) * grid + posmod(cx, grid)
							var at: Vector2 = centres[index] + Vector2(float(cx - posmod(cx, grid)), float(cy - posmod(cy, grid))) * cell
							var d: float = at.distance_squared_to(Vector2(x, y))
							if d < near:
								near = d
								best = index
					var slope: Vector2 = tilts[best]
					if kind == "pyrite":
						## Striations three texels apart, a sharp up-and-down so each is a thin
						## bright line beside a thin dark one.
						var along: int = y if across[best] else x
						var wave: float = 0.16 if posmod(along + best, 3) == 0 else -0.08
						if across[best]:
							slope.y += wave
						else:
							slope.x += wave
					if kind == "pyrite":
						## Calm where the number sits: a face's middle is the middle of the
						## texture (its UVs centre there), so the crystal mosaic fades out under
						## the numeral and stays sharp towards the corners.
						var from_middle: float = Vector2(x, y).distance_to(Vector2(size, size) * 0.5) / float(size)
						slope *= smoothstep(0.1, 0.24, from_middle)
					slopes[y * size + x] = slope
		"brushed":
			var rows: Array = []
			var h: float = 0.0
			for y in range(size):
				h = clampf(h * 0.4 + rng.randf_range(-1.0, 1.0), -1.5, 1.5)
				rows.append(h)
			for y in range(size):
				var dy: float = (float(rows[posmod(y + 1, size)]) - float(rows[posmod(y - 1, size)])) * 0.11
				## Streaks fade in and out along their length.
				var phase: float = rng.randf() * TAU
				var reach: float = rng.randf_range(0.6, 2.5)
				for x in range(size):
					var fade: float = 0.55 + 0.45 * sin(phase + TAU * reach * float(x) / float(size))
					slopes[y * size + x] = Vector2(0.0, dy * fade)
			for _scratch in range(16):
				var from := Vector2(rng.randf_range(0, size), rng.randf_range(0, size))
				var angle: float = rng.randf_range(-0.7, 0.7) + (PI * 0.5 if rng.randf() < 0.3 else 0.0)
				var heading := Vector2.from_angle(angle)
				var cut: Vector2 = heading.orthogonal() * 0.35
				for step in range(rng.randi_range(14, 46)):
					var at: Vector2 = from + heading * float(step)
					var i: int = posmod(int(at.y), size) * size + posmod(int(at.x), size)
					slopes[i] = cut
	var bytes := PackedByteArray()
	bytes.resize(size * size * 3)
	for i in range(size * size):
		var normal := Vector3(-slopes[i].x, -slopes[i].y, 1.0).normalized()
		bytes[i * 3] = int(clampf(normal.x * 0.5 + 0.5, 0.0, 1.0) * 255.0)
		bytes[i * 3 + 1] = int(clampf(normal.y * 0.5 + 0.5, 0.0, 1.0) * 255.0)
		bytes[i * 3 + 2] = int(clampf(normal.z * 0.5 + 0.5, 0.0, 1.0) * 255.0)
	var image := Image.create_from_data(size, size, false, Image.FORMAT_RGB8, bytes)
	image.generate_mipmaps()
	var texture := ImageTexture.create_from_image(image)
	_grains[kind] = texture
	return texture

static func streak_texture() -> Texture2D:
	## Brushed steel's roughness: streaks a little glossier and a little duller than the
	## rest, so the drawn lines show in the light as well as in the relief.
	if _grains.has("streaks"):
		return _grains["streaks"]
	var size: int = 128
	var rng := RandomNumberGenerator.new()
	rng.seed = 9393
	var bytes := PackedByteArray()
	bytes.resize(size * size)
	for y in range(size):
		var base: float = rng.randf_range(0.48, 0.66)
		var phase: float = rng.randf() * TAU
		for x in range(size):
			bytes[y * size + x] = int(clampf(base + 0.08 * sin(phase + TAU * 1.5 * float(x) / float(size)), 0.0, 1.0) * 255.0)
	var image := Image.create_from_data(size, size, false, Image.FORMAT_L8, bytes)
	image.generate_mipmaps()
	var texture := ImageTexture.create_from_image(image)
	_grains["streaks"] = texture
	return texture

func _face_values() -> String:
	## Every face's number and its etching: a face etched where it stands (a carver's needle,
	## a creature's brand) keeps its number, and the solid still has to be recut to show it.
	## An action die's face also says its move's mark and kind: a face re-etched to another
	## move mid-fight is recut too.
	var values: Array = []
	for face in die.get("faces", []):
		var entry: String = ("%s:%s" % [str(face.get("value", 0)), str(face.get("kind", "plain"))]) if face is Dictionary else str(face)
		if face is Dictionary and face.has("mark"):
			entry += ":%s:%s" % [str(face.get("mark", "")), str(face.get("move_kind", ""))]
		values.append(entry)
	return ",".join(values)

static func is_marked(of_die: Dictionary) -> bool:
	## A creature's action die: its faces carry moves (each a mark) instead of numbers.
	for face in of_die.get("faces", []):
		if face is Dictionary and not str(face.get("mark", "")).is_empty():
			return true
	return false

static func _move_kind(face: Variant) -> String:
	## The kind of move a face makes ("kind" on a face is already its etching); a face that
	## does not say counts as a dud.
	var kind: String = str(face.get("move_kind", "dud")) if face is Dictionary else "dud"
	return kind if MOVE_TINTS.has(kind) else "dud"

static func move_tint(face: Variant, index: int) -> Color:
	## An action die's face color: its move's kind, every other face a shade lighter in turn
	## so neighbours of one kind still part at the edge.
	return (MOVE_TINTS[_move_kind(face)] as Color).lightened(0.06 * float(index % 3))

static func mark_ink(face: Variant) -> Color:
	return DUD_INK if _move_kind(face) == "dud" else MARK_INK

func _shape() -> String:
	var declared := str(die.get("shape", "")).to_upper()
	if declared.begins_with("D") and declared.substr(1).is_valid_int():
		return declared
	return Geometry.shape_for_sides(die.get("faces", []).size())

func _palette() -> Dictionary:
	return DiceIcons.die_palette(die)

func _rebuild() -> void:
	var shape := _shape()
	var built := Geometry.solid(shape)
	_frames = built.frames
	var palette := _palette()
	## A look may paint the solid a shade of its own (the icon keeps the palette's).
	var worn: Dictionary = look_of(str(die.get("material", "")))
	var own_body: String = str(worn.get("body", ""))
	if own_body.is_valid_html_color():
		palette = {"body": Color(own_body), "edge": palette.edge}
	var own_edge: String = str(worn.get("edge", ""))
	if own_edge.is_valid_html_color():
		palette = {"body": palette.body, "edge": Color(own_edge)}
	var play: Array = PLAY_OF_COLOR if bool(worn.get("play", false)) else []
	var faces: Array = die.get("faces", [])
	_marked = is_marked(die)
	## Whether it bleeds is the die's, not the renderer's: a headless fight keeps it too.
	_bleeds = bool(worn.get("bleeds", false)) and not _marked
	var colors := PackedColorArray()
	for index in range(_frames.size()):
		if _marked:
			colors.append(move_tint(faces[index] if index < faces.size() else null, index))
			continue
		var value := _value_at(index)
		var shade: float = 0.06 * float(index % 3) - 0.05
		var tone: Color = palette.body.lightened(maxf(shade, 0.0)) if shade >= 0.0 else palette.body.darkened(-shade)
		if not play.is_empty():
			## An opal's play of color: each face flashes a different pastel.
			tone = tone.lerp(play[(index * 3 + index / 4) % play.size()], 0.34)
		if faces.size() > 0 and value != _nominal(index):
			tone = tone.lerp(Color("ffd166"), 0.35)
		var kind: String = _kind_at(index)
		if kind != "plain":
			tone = tone.lerp(DiceIcons.face_kind_tint(kind), 0.55)
		colors.append(tone)
	# Rims and crystal tips are part of the mesh, but never carry a face value.
	for _i in range(_frames.size(), built.faces.size()):
		colors.append(palette.edge.lightened(0.12))
	if headless():
		return
	_wear_material(palette)
	var mesh := Geometry.mesh(shape, colors)
	_shell.mesh = mesh
	## A cut look is drawn on the same solid fanned out from each face's middle.
	var cut_mesh: ArrayMesh = GemCut.mesh(shape, colors) if worn.has("cut") and not _marked else mesh
	_body.mesh = cut_mesh
	_inner.mesh = cut_mesh
	for label in _labels:
		if is_instance_valid(label):
			label.queue_free()
	_labels.clear()
	for sprite in _marks:
		if is_instance_valid(sprite):
			sprite.queue_free()
	_marks.clear()
	if _marked:
		_engrave(faces)
		return
	var numeral: Color = Color("15181f") if palette.body.get_luminance() > 0.45 else Color("f4f7fb")
	## A clear die's numbers are white, ringed dark, whatever shows behind them; a busy face
	## (pyrite) has its numbers cut heavier.
	var look: Dictionary = worn
	var ink: String = str(look.get("ink", ""))
	## `ring`: an opaque look (a blood under review) writes its numbers as a clear die does.
	var ringed: bool = bool(look.get("clear", false)) or bool(look.get("ring", false))
	if ringed:
		numeral = Color("f8fbff")
	for index in range(_frames.size()):
		var frame: Dictionary = _frames[index]
		var label := Label3D.new()
		label.text = DiceIcons.face_text(_value_at(index), _kind_at(index))
		label.font_size = 96
		label.outline_size = 0
		label.modulate = numeral
		if ringed:
			label.outline_size = int(look.get("ring_size", 14))
			label.outline_modulate = Color(0.03, 0.05, 0.09, 0.9)
			## The ring is drawn after the see-through skin, then the numeral over it: by
			## default a Label3D's outline goes down first (-1) and a milky skin (an opal)
			## covered it, leaving white numbers on white.
			label.outline_render_priority = 1
			label.render_priority = 2
		elif ink == "bold":
			label.outline_size = 9
			label.outline_modulate = numeral
		label.billboard = BaseMaterial3D.BILLBOARD_DISABLED
		label.double_sided = false
		label.shaded = false
		label.no_depth_test = false
		label.alpha_cut = Label3D.ALPHA_CUT_DISCARD
		label.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		_fit_label(label, frame)
		label.transform = Transform3D(Basis(frame.right, frame.up, frame.normal), frame.centre + frame.normal * 0.006)
		_pivot.add_child(label)
		_labels.append(label)

func _engrave(faces: Array) -> void:
	## Each face's mark cut into it where a numeral would be: the mark in ivory (slate on a dud)
	## over a half-dark copy a hair down and right, so it reads as sunk into the face. A
	## triangle has less room round its middle than a square, so its mark is a little smaller.
	for index in range(mini(_frames.size(), faces.size())):
		var face: Variant = faces[index]
		if not face is Dictionary or str(face.get("mark", "")).is_empty():
			continue
		var texture: Texture2D = FaceMarks.texture(str(face.mark))
		var frame: Dictionary = _frames[index]
		var reach: float = float(frame.inradius)
		var across: float = reach * (1.55 if int(frame.get("sides", 4)) == 3 else 1.7)
		var centre: Vector3 = frame.centre
		var shadow_at: Vector3 = centre + Vector3(frame.normal) * 0.006 - Vector3(frame.up) * reach * 0.05 + Vector3(frame.right) * reach * 0.04
		_marks.append(_mark_sprite(texture, MARK_SHADOW, across, frame, shadow_at))
		_marks.append(_mark_sprite(texture, mark_ink(face), across, frame, centre + Vector3(frame.normal) * 0.008))

func _mark_sprite(texture: Texture2D, tint: Color, across: float, frame: Dictionary, at: Vector3) -> Sprite3D:
	var sprite := Sprite3D.new()
	sprite.texture = texture
	sprite.modulate = tint
	sprite.pixel_size = across / float(texture.get_width())
	sprite.shaded = false
	sprite.double_sided = false
	## The mark itself is cut clean; its shadow is blended, being see-through.
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD if tint.a >= 1.0 else SpriteBase3D.ALPHA_CUT_DISABLED
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	sprite.transform = Transform3D(Basis(frame.right, frame.up, frame.normal), at)
	_pivot.add_child(sprite)
	return sprite

func _fit_label(label: Label3D, frame: Dictionary) -> void:
	## Sized to its face for however many characters it shows.
	var digits := maxi(1, label.text.length())
	var span := 0.58 * float(digits) + 0.42
	var grow: float = (D20_NUMERAL_PHONE if DeepUi.phone else D20_NUMERAL) if _shape() == "D20" else 1.0
	label.pixel_size = float(frame.inradius) * 1.5 / (96.0 * span) * grow

func _relabel(index: int, text: String) -> void:
	## One face's text changed after the solid was built (a mirror copying a new number).
	if index < 0 or index >= _labels.size() or index >= _frames.size():
		return
	var label: Label3D = _labels[index]
	if not is_instance_valid(label) or label.text == text:
		return
	label.text = text
	_fit_label(label, _frames[index])
	_touch()

func _kind_at(index: int) -> String:
	var faces: Array = die.get("faces", [])
	if index < faces.size() and faces[index] is Dictionary:
		return str(faces[index].get("kind", "plain"))
	return "plain"

func _value_at(index: int) -> int:
	var faces: Array = die.get("faces", [])
	if index < faces.size():
		var face: Variant = faces[index]
		return int(face.get("value", index + 1)) if face is Dictionary else int(face)
	return index + 1

func _nominal(index: int) -> int:
	return index + 1

static func tilt_for(shape: String) -> Vector3:
	## The slight turn a die of `shape` rests at in the tray and in its picture.
	return OCTA_TILT if shape == "D8" else TILT

func _rest(index: int) -> Quaternion:
	return Quaternion.from_euler(tilt_for(_shape())) * _orientation(index) if tilt else _orientation(index)

func _orientation(index: int) -> Quaternion:
	if index < 0 or index >= _frames.size():
		return Quaternion.IDENTITY
	var frame: Dictionary = _frames[index]
	var aim := VIEW_DIRECTION.normalized()
	var swing := Quaternion(Vector3(frame.normal).normalized(), aim)
	var desired := (Vector3.UP - aim * aim.dot(Vector3.UP)).normalized()
	var current := (swing * Vector3(frame.up)).normalized()
	var angle := atan2(current.cross(desired).dot(aim), current.dot(desired))
	return Quaternion(aim, angle) * swing

func _start_spin() -> void:
	if not is_instance_valid(_pivot) or interactive:
		return
	_spin_time = 0.0
	## Each solid tumbles and lands on its own, a little apart from its neighbours, so five
	## dice sound like five dice and not one. A tray out of sight lands in silence.
	if is_visible_in_tree() and hush > 0.0:
		DeepAudio.play("die_tumble", {"volume": 0.45 * hush, "gap": 0.0, "delay": randf() * 0.05})
		DeepAudio.play("die_settle", {"volume": 0.55 * hush, "gap": 0.0, "delay": spin_seconds * randf_range(0.82, 0.98)})
	_spin_from = Quaternion(Vector3(0.4, 1.0, 0.25).normalized(), randf() * TAU)
	_spin_axis = Vector3(randf_range(-1.0, 1.0), randf_range(0.4, 1.0), randf_range(-1.0, 1.0)).normalized()
	_spin_turns = randf_range(1.6, 2.6)

func _process(delta: float) -> void:
	_clock += delta
	if _fx_layer != null:
		## A blood effect plays out on its own layer, on the fight's clock (hurrying the turn
		## hurries it), and the layer goes when it is done.
		_fx_time += delta
		if not BloodFx.active(_fx, _fx_time):
			_end_fx()
		else:
			_fx_layer.queue_redraw()
			if is_instance_valid(_body) and _body.mesh != null:
				_body.set_instance_shader_parameter("pulse", BloodFx.pulse(_fx, _fx_time))
				_touch()
	if not is_instance_valid(_pivot):
		return
	if interactive:
		if not _dragging:
			_manual = _manual.slerp(_goal, clampf(delta * 9.0, 0.0, 1.0)).normalized()
		_pivot.quaternion = _manual
		_pivot.position = Vector3.ZERO
		_pivot.scale = Vector3.ONE
		return
	if is_instance_valid(_readout) and _readout.visible:
		## Written on only once the solid has stopped: a number over a tumbling die would give
		## the roll away before it landed.
		var want: float = 1.0 if _spin_time > spin_seconds else 0.0
		_readout.modulate.a = move_toward(_readout.modulate.a, want, delta * 7.0)
	if _spin_time <= spin_seconds:
		_spin_time += delta
		var t := clampf(_spin_time / spin_seconds, 0.0, 1.0)
		var eased := smoothstep(0.55, 1.0, t) if suspense else 1.0 - pow(1.0 - t, 3.0)
		var settled := _spin_from.slerp(_target, eased)
		_pivot.quaternion = Quaternion(_spin_axis, _spin_turns * TAU * (1.0 - eased) + (TAU * 3.0 * t * (1.0 - eased) if suspense else 0.0)) * settled
		_pivot.position = Vector3(0, sin(PI * t) * 0.34, 0)
		var squash := 1.0 + 0.16 * sin(PI * clampf((t - 0.82) / 0.18, 0.0, 1.0))
		_pivot.scale = Vector3(squash, 2.0 - squash, squash) * (1.0 + 0.16 * suspense_scale * sin(PI * t * 0.9) if suspense else 1.0)
		if t >= 1.0:
			_pivot.position = Vector3.ZERO
			_pivot.scale = Vector3.ONE
			_pivot.quaternion = _target
			if _running >= 0:
				chain_stepped.emit(_running)
				_sync_readout()
				_chain_wait = 0.22
	elif _running >= 0:
		_throw_again(delta)
	elif live:
		var hop: float = 0.0
		var twist := Quaternion.IDENTITY
		var swell: float = 1.0
		if _pop_time < POP_SECONDS:
			## Up and down again in the first half, a twist that swings back through rest and
			## dies away, and a swell that rings the same way: a die nudged by a finger.
			_pop_time += delta
			var t: float = clampf(_pop_time / POP_SECONDS, 0.0, 1.0)
			var ring: float = exp(-4.0 * t)
			hop = sin(PI * clampf(t * 2.2, 0.0, 1.0)) * 0.3 * _pop_strength
			twist = Quaternion(_pop_axis, sin(t * TAU * 1.6) * ring * 0.55 * _pop_strength)
			swell = 1.0 + 0.2 * _pop_strength * ring * cos(t * TAU * 2.0)
			## Done: one last redraw takes the ring away.
			if _pop_time >= POP_SECONDS and is_instance_valid(_glow):
				_glow.queue_redraw()
		_pivot.position = Vector3(0, sin(_clock * 1.7) * 0.045 + hop, 0)
		_pivot.quaternion = twist * Quaternion(Vector3.UP, sin(_clock * 0.9) * 0.07) * _target
		_pivot.scale = Vector3.ONE * swell
	if is_instance_valid(_glow) and (selected or highlighted or _pop_time < POP_SECONDS):
		_glow.queue_redraw()
	_steer_viewport(delta)

func _throw_again(delta: float) -> void:
	## The die has landed with throws still owed: after a beat it is picked up and thrown onto
	## the next face, and what it shows is added to the total once it has stopped.
	_chain_wait -= delta
	if _chain_wait > 0.0:
		return
	if _chain.is_empty():
		_running = -1
		_chain_face = -1
		return
	var next: Dictionary = _chain.pop_front()
	_chain_face = clampi(int(next.get("face", 0)), 0, maxi(0, _frames.size() - 1))
	_running += int(next.get("value", 0))
	if _chain.is_empty():
		## The last landing reports the figure the rules settled on, which a cap may have trimmed.
		_running = int(roll.get("value", _running))
	_face_index = _chain_face
	_target = _rest(_face_index)
	_start_spin()

func blood_reroll(target: Vector2) -> void:
	## This die bleeds and was thrown again, its owner paying for it in health: blood runs from
	## it to `target` (their health ring, on the canvas). Only a die on screen plays it.
	if _bleeds and is_visible_in_tree():
		_play_fx("stream", target)

func blood_fed(source: Vector2) -> void:
	## Something died and this die fed on it (its face climbs): a thread of blood runs from
	## `source` (where the creature fell, on the canvas) into it. Only a die on screen plays it.
	if _bleeds and is_visible_in_tree():
		_play_fx("thread", source)

func bleeding() -> bool:
	## Whether a blood effect is playing (its layer is up).
	return _fx_layer != null

func _play_fx(kind: String, point: Vector2) -> void:
	## A second effect while one plays takes its place on the same layer.
	_fx = kind
	_fx_time = 0.0
	_fx_seed = randi()
	_fx_point = point
	if _fx_layer == null:
		_fx_layer = Control.new()
		_fx_layer.top_level = true
		_fx_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_fx_layer.z_index = 2
		_fx_layer.draw.connect(func() -> void:
			if BloodFx.active(_fx, _fx_time):
				BloodFx.draw_travel(_fx_layer, _fx, _fx_time, _fx_seed, get_global_rect(), _fx_point))
		add_child(_fx_layer)
	_fx_layer.position = Vector2.ZERO
	_fx_layer.size = get_viewport_rect().size

func _end_fx() -> void:
	_fx = ""
	if _fx_layer != null:
		_fx_layer.queue_free()
		_fx_layer = null
	if is_instance_valid(_body) and _body.mesh != null:
		_body.set_instance_shader_parameter("pulse", 0.0)
		_touch()

func _draw_glow(target: Control) -> void:
	var centre := target.size * 0.5
	var radius := minf(target.size.x, target.size.y) * 0.46
	if headless():
		# Fallback presentation when no renderer is available.
		var silhouette := PackedVector2Array()
		var sides := clampi(die.get("faces", []).size(), 3, 12)
		for i in sides:
			silhouette.append(centre + Vector2.from_angle(-PI * 0.5 + TAU * float(i) / float(sides)) * radius)
		target.draw_colored_polygon(silhouette, _palette().body)
	if highlighted:
		## Lit, not shadowed: a 16% fill of the accent over the dock's near-black panel came out
		## a muddy olive disc that read as a shadow under the dice; a crisp ring of the accent
		## over a barely-there fill points the die out instead.
		target.draw_circle(centre, radius * 1.16, Color(accent, 0.06))
		target.draw_arc(centre, radius * 1.16, 0.0, TAU, 48, Color(accent, 0.7), 2.0, true)
	if _pop_time < POP_SECONDS:
		var t: float = clampf(_pop_time / POP_SECONDS, 0.0, 1.0)
		var fade: float = 1.0 - t
		target.draw_circle(centre, radius * 1.05, Color(_pop_tint, 0.2 * fade * fade))
		target.draw_arc(centre, radius * lerpf(0.95, 1.3, sqrt(t)), 0.0, TAU, 48, Color(_pop_tint, 0.85 * fade), 1.0 + 2.5 * fade, true)
	if selected:
		var pulse := 0.55 + 0.25 * sin(_clock * 4.2)
		target.draw_arc(centre, radius * 1.06, 0.0, TAU, 48, Color(accent, pulse), 2.5, true)
		for i in 4:
			var angle := _clock * 1.1 + TAU * float(i) / 4.0
			target.draw_circle(centre + Vector2.from_angle(angle) * radius * 1.06, 2.6, Color(accent, pulse))
