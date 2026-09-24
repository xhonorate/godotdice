class_name CrystalCreature
extends Node3D
## Shared presentation for the editable scenes in view/creatures/scenes.
## Combat state stays in sim/; the battle and inspector both spawn through make().

const Part = preload("res://view/creatures/creature_part.gd")
const SCENE_PATHS: Dictionary = {
	"CAVE_TICK": "res://view/creatures/scenes/cave_tick.tscn",
	"SILT_SLIME": "res://view/creatures/scenes/silt_slime.tscn",
	"QUARTZ_GOLEM": "res://view/creatures/scenes/quartz_golem.tscn",
	"MAGPIE": "res://view/creatures/scenes/magpie.tscn",
	"LANTERN_MOTH": "res://view/creatures/scenes/lantern_moth.tscn",
	"VEIN_WRAITH": "res://view/creatures/scenes/vein_wraith.tscn",
	"CLOUDER": "res://view/creatures/scenes/clouder.tscn",
	"GLASS_WYRM": "res://view/creatures/scenes/glass_wyrm.tscn",
	"THE_FOREMAN": "res://view/creatures/scenes/the_foreman.tscn",
	"THE_REGENT": "res://view/creatures/scenes/the_regent.tscn",
	"THE_DRILL": "res://view/creatures/scenes/the_drill.tscn",
}
const FALLBACK_SCENE: String = "res://view/creatures/scenes/crystal_cluster.tscn"
const TINTS: Array = ["9a7dff", "4fd6b8", "ff8a4a", "5a8cff", "ffc23a", "c860ff", "58d878", "ff5a7a", "7ac8ff", "ffd45a"]

# Paths avoid a preload cycle with the scenes' root script. Keep each PackedScene loaded
# so repeated spawns instantiate the same template without reading it from disk again.
static var _scenes: Dictionary = {}

@export var key: String = ""
@export var warden: bool = false
@export_enum("cluster", "low", "blob", "stack", "spikes", "wings", "shards", "puff", "long", "tower") var style: String = "cluster"
@export var sway: float = 1.0
@export var body_material: StandardMaterial3D
@export var core_material: StandardMaterial3D
## The unmodified color to use when switching between normal and Warden variants.
@export var normal_tint: Color = Color.WHITE

var tint: Color:
	get: return body_material.emission
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
var _base_light_energy: float

static func make(creature_key: String, is_warden: bool = false) -> CrystalCreature:
	var path: String = str(SCENE_PATHS.get(creature_key, FALLBACK_SCENE))
	if not _scenes.has(path):
		_scenes[path] = load(path) as PackedScene
	var creature := (_scenes[path] as PackedScene).instantiate() as CrystalCreature
	creature.key = creature_key
	if path == FALLBACK_SCENE:
		creature.normal_tint = Color(str(TINTS[absi(creature_key.hash()) % TINTS.size()]))
		creature._apply_palette(creature.normal_tint)
	creature._configure_warden(is_warden)
	creature._prepare()
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
	_base_light_energy = _light.light_energy
	_collect_parts(_body)

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
	_apply_palette(normal_tint.lerp(Color("ff5a4a"), 0.35) if warden else normal_tint)
	body_material.emission_energy_multiplier = 0.4 if warden else 0.22
	var glow := get_node("Glow") as OmniLight3D
	glow.light_energy = 2.6 if warden else 1.4
	glow.omni_range = 5.0 if warden else 3.2

func _apply_palette(color: Color) -> void:
	body_material.albedo_color = color.darkened(0.25)
	body_material.emission = color
	core_material.albedo_color = color.darkened(0.6)
	core_material.emission = color.lightened(0.2)
	(get_node("Glow") as OmniLight3D).light_color = color

# --- what the screen asks for ------------------------------------------------------------

func centre() -> Vector3:
	## Where blows land: the middle of the body, in world space.
	return global_position + Vector3(0, anchor.y * 0.45, 0.2)

func flash(strength: float = 2.4) -> void:
	## A hit: the whole creature blazes and settles.
	_glow_boost = maxf(_glow_boost, strength)

func hit(strength: float = 1.0) -> void:
	## Reels from a blow: knocked back, squashed, lit up.
	flash(2.0 + strength * 2.0)
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
	var heartbeat: float = pow(maxf(0.0, sin(_clock * 2.2)), 8.0) * 0.4
	body_material.emission_energy_multiplier = _base_emission + heartbeat + _glow_boost
	core_material.emission_energy_multiplier = _base_core_emission + heartbeat * 2.0 + _glow_boost * 0.6
	if _light != null and not _dying and _body.scale.x > _body_rest.basis.get_scale().x * 0.95:
		_light.light_energy = _base_light_energy * (1.0 + heartbeat) + _glow_boost * 1.2
	## The ring under it when it is the target: turning slowly, brighter on hover.
	var want: float = (0.85 if _targeted else 0.0) + (0.35 if _hovered else 0.0)
	_ring_material.albedo_color.a = move_toward(_ring_material.albedo_color.a, minf(want, 1.0), delta * 4.0)
	_ring.rotation.y += delta * 0.8
	_ring.scale = _ring_rest_scale * (1.0 + 0.04 * sin(_clock * 4.0))
