class_name CrystalCreature
extends Node3D
## Shared presentation for the editable scenes in view/creatures/scenes.
## Combat state stays in sim/; the battle and inspector both spawn through make().

const Part = preload("res://view/creatures/creature_part.gd")
## Every creature with a scene of its own. The deeper mines' creatures are baked from the
## recipes in tools/creature_recipes by tools/creature_bake.gd; the Quarry's first eight
## were saved from the old procedural builder.
const SCENE_DIR: String = "res://view/creatures/scenes/"
const SCENE_KEYS: Array = ["CAVE_TICK", "SILT_SLIME", "QUARTZ_GOLEM", "MAGPIE", "LANTERN_MOTH", "VEIN_WRAITH", "CLOUDER", "GLASS_WYRM",
	"THE_FOREMAN", "THE_REGENT", "THE_DRILL", "RAIL_RAT", "PIT_MOLE",
	"SEEP_EEL", "DROWNED_MINER", "LAMPREY_KNOT", "CAVE_CRAYFISH", "THE_LOCKKEEPER", "THE_DROWNED_CHOIR", "THE_UNDERTOW",
	"ECHO_SPRITE", "LENS_BEETLE", "REFRACTOR", "THE_GLAZIER", "THE_KALEIDOSCOPE", "THE_PRISMARCH", "PRISM",
	"CAP_SHAMBLER", "MYCEL_WEAVER", "PUFFBALL", "ROOT_HORROR", "THE_GARDENER", "THE_SPORE_MOTHER", "THE_HEARTROT", "TENDRIL",
	"SALAMANDER", "SLAG_HOUND", "FORGE_IMP", "EMBER_CRAWLER", "THE_SMELTER", "THE_ANVIL_KNIGHT", "THE_KILN_WYRM",
	"HOARD_MIMIC", "CROUPIER_CRAB", "CRYSTAL_HYDRA", "THE_ASSAYER", "THE_COLLECTOR", "THE_HOLLOW_CROWN",
	"VOID_ECHO", "NULL_SHADE", "RIFTLING_SWARM", "ENTROPY_EYE", "THE_UNMADE"]
static var SCENE_PATHS: Dictionary = _scene_paths()
static func _scene_paths() -> Dictionary:
	var out: Dictionary = {}
	for key in SCENE_KEYS:
		out[key] = SCENE_DIR + str(key).to_lower() + ".tscn"
	for key in VARIANTS:
		out[key] = SCENE_DIR + str(VARIANTS[key].of).to_lower() + ".tscn"
	return out
## A variant is an earlier creature in another mine's colours: the same scene, recoloured.
## `tint` is the body, `accent` the glowing details (where the scene has an accent material).
const VARIANTS: Dictionary = {
	"PRISM_GOLEM": {"of": "QUARTZ_GOLEM", "tint": "9b8cff", "accent": "e0d8ff"},
	"SHARD_WYRM": {"of": "GLASS_WYRM", "tint": "ff8ad0", "accent": "ffd0ea"},
	"GLINT_MAGPIE": {"of": "MAGPIE", "tint": "d8dce8", "accent": "fff2a8"},
	"WILL_O_WISP": {"of": "LANTERN_MOTH", "tint": "8ad0ff", "accent": "e0f6ff"},
	"SPORE_SLIME": {"of": "SILT_SLIME", "tint": "b8c84a", "accent": "e8ff8a"},
	"MYCEL_WRAITH": {"of": "VEIN_WRAITH", "tint": "58b05a", "accent": "c8ff6a"},
	"FIRE_TICK": {"of": "CAVE_TICK", "tint": "e8622a", "accent": "ffd06a"},
	"CINDER_MOTH": {"of": "LANTERN_MOTH", "tint": "ff8a3a", "accent": "ffe08a"},
	"GILDED_MAGPIE": {"of": "MAGPIE", "tint": "ffd04a", "accent": "fff6c0"},
	"GEODE_GOLEM": {"of": "QUARTZ_GOLEM", "tint": "b070e0", "accent": "e8c8ff"},
	"AMETHYST_WYRM": {"of": "GLASS_WYRM", "tint": "9b5ad8", "accent": "d8b0ff"},
}
const FALLBACK_SCENE: String = "res://view/creatures/scenes/crystal_cluster.tscn"
## The ghostly palette a Void Echo wears over whatever it copies.
const ECHO_TINT := Color("8b7dff")
const TINTS: Array = ["9a7dff", "4fd6b8", "ff8a4a", "5a8cff", "ffc23a", "c860ff", "58d878", "ff5a7a", "7ac8ff", "ffd45a"]

# Paths avoid a preload cycle with the scenes' root script. Keep each PackedScene loaded
# so repeated spawns instantiate the same template without reading it from disk again.
static var _scenes: Dictionary = {}
## Scenes asked for ahead of time and still being read on a worker thread.
static var _requested: Dictionary = {}

@export var key: String = ""
@export var warden: bool = false
@export_enum("cluster", "low", "blob", "stack", "spikes", "wings", "shards", "puff", "long", "tower") var style: String = "cluster"
@export var sway: float = 1.0
@export var body_material: StandardMaterial3D
@export var core_material: StandardMaterial3D
## An optional third material for the parts that glow hardest: a lamp, a fire, an eye.
@export var accent_material: StandardMaterial3D
## The unmodified color to use when switching between normal and Warden variants.
@export var normal_tint: Color = Color.WHITE
@export var normal_accent: Color = Color.WHITE

var tint: Color:
	get: return _hue if _white > 0.0 else body_material.emission
var anchor: Vector3:
	get: return (get_node("Anchor") as Marker3D).position * scale
var rest_position: Vector3 = Vector3.ZERO
var _body: Node3D
var _body_rest: Transform3D
var _parts: Array[Part] = []
var _clock: float = 0.0
var _light: OmniLight3D
var _ring: MeshInstance3D
var _ring_material: StandardMaterial3D
var _ring_rest_scale: Vector3
var _shadow: MeshInstance3D
var _targeted: bool = false
var _hovered: bool = false
var _recoil := Vector3.ZERO
var _squash: float = 0.0
var _rear: float = 0.0
var _glow_boost: float = 0.0
var _dying: bool = false
var _base_emission: float
var _base_core_emission: float
var _base_accent_emission: float = 2.2
var _base_light_energy: float
var _halo: MeshInstance3D
var _halo_material: StandardMaterial3D
var _halo_want: float = 0.0
var _charging: float = 0.0
var _buried: float = 0.0
var _buried_want: float = 0.0
var _ghost: bool = false
## A blow turns the body's light white for an instant before its own colour comes back. Its
## own colour is kept here while it does, so `tint` never reads the flash.
var _white: float = 0.0
var _hue: Color = Color.WHITE

static func _path_for(looks: String) -> String:
	var path: String = str(SCENE_PATHS.get(looks, FALLBACK_SCENE))
	return path if ResourceLoader.exists(path) else FALLBACK_SCENE

static func preload_scenes(foes: Array) -> void:
	## Starts reading these creatures' scenes on a worker thread: a fight down the tunnel the
	## party has just taken. Parsing one cost a few milliseconds each on the frame the fight
	## began, on top of everything else that frame has to do.
	for foe in foes:
		var echo_of: String = str(foe.get("echo_of", "")) if foe is Dictionary else ""
		var key: String = str(foe.get("key", "")) if foe is Dictionary else str(foe)
		var path: String = _path_for(echo_of if not echo_of.is_empty() else key)
		if _scenes.has(path) or _requested.has(path):
			continue
		if ResourceLoader.load_threaded_request(path, "PackedScene") == OK:
			_requested[path] = true

static func _scene(path: String) -> PackedScene:
	if not _scenes.has(path):
		var made: PackedScene = null
		if _requested.has(path):
			_requested.erase(path)
			made = ResourceLoader.load_threaded_get(path) as PackedScene
		_scenes[path] = made if made != null else load(path) as PackedScene
	return _scenes[path]

static func make(creature_key: String, is_warden: bool = false, echo_of: String = "") -> CrystalCreature:
	## A creature by key. A variant spawns its base scene in its own colours; a Void Echo
	## spawns the scene of whatever it copies, in the Rift's light.
	var looks: String = echo_of if not echo_of.is_empty() else creature_key
	var path: String = _path_for(looks)
	var creature := _scene(path).instantiate() as CrystalCreature
	creature.key = creature_key
	if path == FALLBACK_SCENE:
		creature.normal_tint = Color(str(TINTS[absi(creature_key.hash()) % TINTS.size()]))
		creature._apply_palette(creature.normal_tint)
	elif VARIANTS.has(looks):
		creature.normal_tint = Color(str(VARIANTS[looks].tint))
		creature.normal_accent = Color(str(VARIANTS[looks].get("accent", VARIANTS[looks].tint)))
		creature._apply_palette(creature.normal_tint, creature.normal_accent)
	creature._configure_warden(is_warden)
	creature._prepare()
	if not echo_of.is_empty():
		creature.ghost()
	return creature

func _ready() -> void:
	_prepare()
	rest_position = position

func _prepare() -> void:
	if _body != null:
		return
	_body = get_node("Body") as Node3D
	_body_rest = _body.transform
	_light = get_node("Glow") as OmniLight3D
	_shadow = get_node("Shadow") as MeshInstance3D
	_ring = get_node("TargetRing") as MeshInstance3D
	_ring_material = _ring.material_override as StandardMaterial3D
	_ring_rest_scale = _ring.scale
	_base_emission = body_material.emission_energy_multiplier
	_base_core_emission = core_material.emission_energy_multiplier
	if accent_material != null:
		_base_accent_emission = accent_material.emission_energy_multiplier
	_base_light_energy = _light.light_energy
	_collect_parts(_body)
	## The halo under it that says what colour it has turned away, hidden until it does.
	_halo = MeshInstance3D.new()
	_halo.mesh = _ring.mesh
	_halo_material = StandardMaterial3D.new()
	_halo_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_halo_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_halo_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_halo_material.albedo_color = Color(1, 1, 1, 0)
	_halo_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_halo.material_override = _halo_material
	_halo.position = Vector3(0, 0.08, 0)
	_halo.scale = _ring_rest_scale * 1.25
	_halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_halo)

func _collect_parts(parent: Node) -> void:
	for child in parent.get_children():
		if child is Part:
			child.capture_pose()
			_parts.append(child)
		_collect_parts(child)

func _configure_warden(is_warden: bool) -> void:
	# Scenes already carry their usual variant, including its scale, light and materials.
	# Only override them when a caller explicitly requests the other variant.
	if warden == is_warden:
		return
	scale *= 1.5 if is_warden else 1.0 / 1.5
	warden = is_warden
	_apply_palette(normal_tint.lerp(Color("ff5a4a"), 0.35) if warden else normal_tint, normal_accent)
	body_material.emission_energy_multiplier = 0.4 if warden else 0.22
	var glow := get_node("Glow") as OmniLight3D
	glow.light_energy = 2.6 if warden else 1.4
	glow.omni_range = 5.0 if warden else 3.2

func _apply_palette(color: Color, accent: Color = Color(0, 0, 0, 0)) -> void:
	body_material.albedo_color = color.darkened(0.25)
	body_material.emission = color
	core_material.albedo_color = color.darkened(0.6)
	core_material.emission = color.lightened(0.2)
	if accent_material != null and accent.a > 0.0:
		accent_material.albedo_color = accent.darkened(0.2)
		accent_material.emission = accent
	(get_node("Glow") as OmniLight3D).light_color = color

func ghost() -> void:
	## A Void Echo: the copied creature seen through the Rift, violet and half there.
	_ghost = true
	normal_tint = ECHO_TINT
	_apply_palette(ECHO_TINT, ECHO_TINT.lightened(0.4))
	for material in [body_material, core_material, accent_material]:
		if material == null:
			continue
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.albedo_color = Color(material.albedo_color, 0.55)
		material.rim_enabled = true
		material.rim = 1.0
		material.rim_tint = 0.6
	(get_node("Glow") as OmniLight3D).light_color = ECHO_TINT

func set_adapt(color: Color) -> void:
	## It has turned a colour away (or is mirroring it): a halo of that colour under it.
	_halo_material.albedo_color = Color(color, _halo_material.albedo_color.a)
	_halo_want = 0.9 if color.a > 0.0 else 0.0

func clear_adapt() -> void:
	_halo_want = 0.0

func set_charging(on: bool) -> void:
	## Winding up a blow: it gathers light, brighter the longer it holds.
	_charging = 1.0 if on else 0.0

func burrow(down: bool) -> void:
	## Under the floor and out of reach, or back up out of it. The body sinks, the light
	## dims and the shadow is all that marks the spot.
	_buried_want = 1.0 if down else 0.0

func flee(seconds: float = 0.7) -> void:
	## Off into the dark with what it took: up and away, shrinking, then gone.
	if _dying:
		return
	_dying = true
	var tween := create_tween()
	tween.tween_property(_body, "position", _body_rest.origin + Vector3(randf_range(-1.5, 1.5), 3.5, -2.0), seconds).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(_body, "scale", _body_rest.basis.get_scale() * 0.2, seconds).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(_light, "light_energy", 0.0, seconds)
	tween.parallel().tween_property(_shadow, "transparency", 1.0, seconds * 0.6)
	tween.tween_callback(queue_free)

# --- what the screen asks for ------------------------------------------------------------

func centre() -> Vector3:
	## Where blows land: the middle of the body, in world space.
	return global_position + Vector3(0, anchor.y * 0.45, 0.2)

func flash(strength: float = 2.4) -> void:
	## A hit: the whole creature blazes and settles.
	_glow_boost = maxf(_glow_boost, strength)

func hit(strength: float = 1.0) -> void:
	## Reels from a blow: knocked back, squashed, lit up white for an instant.
	flash(2.0 + strength * 2.0)
	if _white <= 0.0:
		_hue = body_material.emission
	_white = clampf(0.55 + strength * 0.35, 0.0, 1.0)
	_recoil = Vector3(randf_range(-0.12, 0.12), 0.0, -0.35 - 0.35 * strength)
	_squash = 0.25 * clampf(strength, 0.3, 1.5)

func lunge(toward: Vector3, seconds: float = 0.5) -> void:
	## Rears back, then strikes at the party and returns to its mark.
	var tween := create_tween()
	tween.tween_property(self, "_rear", 1.0, seconds * 0.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "_rear", -1.0, seconds * 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.tween_property(self, "_rear", 0.0, seconds * 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_glow_boost = maxf(_glow_boost, 1.5)

func channel(seconds: float = 0.6) -> void:
	## Gathers itself and releases a ward or buff, without lunging at the players.
	var tween := create_tween()
	tween.tween_property(self, "_rear", 0.6, seconds * 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "_rear", 0.0, seconds * 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_glow_boost = maxf(_glow_boost, 2.0)

func spawn(delay: float = 0.0) -> void:
	## Rises out of the rock.
	_body.position = _body_rest.origin + Vector3(0, -2.5 * (anchor.y / 2.0), 0)
	_body.scale = _body_rest.basis.get_scale() * 0.3
	_light.light_energy = 0.0
	var energy: float = _base_light_energy
	var tween := create_tween().set_parallel(true)
	tween.tween_property(_body, "position", _body_rest.origin, 0.7).set_delay(delay).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(_body, "scale", _body_rest.basis.get_scale(), 0.6).set_delay(delay).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(_light, "light_energy", energy, 0.8).set_delay(delay)
	_glow_boost = 3.0

func set_targeted(on: bool) -> void:
	if _targeted == on:
		return
	_targeted = on

func set_hovered(on: bool) -> void:
	_hovered = on

func die() -> void:
	## Swells with light, then collapses into itself and is gone. The shards are thrown by
	## the screen, which knows where the camera is.
	if _dying:
		return
	_dying = true
	_glow_boost = 5.0
	var tween := create_tween()
	tween.tween_property(_body, "scale", _body_rest.basis.get_scale() * 1.25, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(_body, "scale", _body_rest.basis.get_scale() * 0.05, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(_body, "rotation:y", _body_rest.basis.orthonormalized().get_euler().y + PI * 1.5, 0.3)
	tween.parallel().tween_property(_light, "light_energy", 0.0, 0.3)
	tween.parallel().tween_property(_shadow, "transparency", 1.0, 0.3)
	tween.tween_callback(queue_free)

func _process(delta: float) -> void:
	_clock += delta
	if _body == null:
		return
	## Breathing: the whole creature rises and falls a little, faster for the light ones.
	var breathe: float = sin(_clock * sway)
	_recoil = _recoil.lerp(Vector3.ZERO, clampf(delta * 7.0, 0.0, 1.0))
	_squash = lerpf(_squash, 0.0, clampf(delta * 8.0, 0.0, 1.0))
	var rear := Vector3(0, 0.12 * maxf(_rear, 0.0), -0.5 * _rear) if _rear >= 0.0 else Vector3(0, 0, 1.6 * -_rear)
	position = rest_position + Vector3(0, breathe * 0.05, 0) + _recoil + rear
	var squish: float = _squash * sin(_clock * 30.0) + (0.05 * breathe if style == "blob" else 0.0)
	if not _dying:
		_body.scale = _body_rest.basis.get_scale() * Vector3(1.0 + squish * 0.5, 1.0 - squish, 1.0 + squish * 0.5)
		_body.rotation.x = _body_rest.basis.orthonormalized().get_euler().x - 0.22 * maxf(_rear, 0.0) + 0.3 * minf(_rear, 0.0) * -1.0
	for part in _parts:
		part.animate(_clock, style)
	## The heartbeat of its glow, flaring on every blow.
	_glow_boost = move_toward(_glow_boost, 0.0, delta * 5.0)
	if _white > 0.0:
		_white = move_toward(_white, 0.0, delta * 7.0)
		body_material.emission = _hue.lerp(Color.WHITE, _white * 0.85) if _white > 0.0 else _hue
	var heartbeat: float = pow(maxf(0.0, sin(_clock * 2.2)), 8.0) * 0.4
	## Charging: a swelling pulse on top of the heartbeat.
	var charge: float = _charging * (0.8 + 0.8 * pow(maxf(0.0, sin(_clock * 4.0)), 2.0))
	body_material.emission_energy_multiplier = _base_emission + heartbeat + _glow_boost + charge * 0.5
	core_material.emission_energy_multiplier = _base_core_emission + heartbeat * 2.0 + _glow_boost * 0.6 + charge * 1.5
	if accent_material != null:
		accent_material.emission_energy_multiplier = _base_accent_emission + heartbeat * 1.5 + _glow_boost * 0.8 + charge * 2.0
	## Burrowed: the body sinks out of sight and the light goes with it.
	_buried = move_toward(_buried, _buried_want, delta * 2.2)
	if not _dying:
		_body.position = _body_rest.origin + Vector3(0, -(anchor.y / maxf(0.01, scale.y) + 0.6) * _buried, 0)
	if _light != null and not _dying and _body.scale.x > _body_rest.basis.get_scale().x * 0.95:
		_light.light_energy = (_base_light_energy * (1.0 + heartbeat) + _glow_boost * 1.2 + charge * 1.5) * (1.0 - _buried)
	## The adapt halo: a slow counter-turning ring in the colour it has turned away.
	if _halo != null:
		_halo_material.albedo_color.a = move_toward(_halo_material.albedo_color.a, _halo_want * (1.0 - _buried), delta * 3.0)
		_halo.rotation.y -= delta * 1.1
		_halo.scale = _ring_rest_scale * (1.25 + 0.06 * sin(_clock * 3.0))
	## The ring under it when it is the target: turning slowly, brighter on hover.
	var want: float = (0.85 if _targeted else 0.0) + (0.35 if _hovered else 0.0)
	_ring_material.albedo_color.a = move_toward(_ring_material.albedo_color.a, minf(want, 1.0), delta * 4.0)
	_ring.rotation.y += delta * 0.8
	_ring.scale = _ring_rest_scale * (1.0 + 0.04 * sin(_clock * 4.0))
