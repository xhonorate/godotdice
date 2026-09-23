class_name CrystalCreature
extends Node3D
## A creature of the rock, built from low-poly crystal primitives in the stones' own light.
## Every creature is one of a few silhouettes with a tint hashed from its key, so the same
## creature always looks the same and no two kinds look alike.
##
## It is never still: it breathes, its parts move on their own (wings beat, shards orbit,
## a slime wobbles), its core glows with a heartbeat and throws its color on the floor. It
## rises out of the ground when a fight begins, rears back before it strikes, reels when
## hit, and bursts apart when it dies. The screen decides when; this decides how.

const Lowpoly = preload("res://view/battle/lowpoly.gd")

const STYLES: Dictionary = {"CAVE_TICK": "low", "SILT_SLIME": "blob", "QUARTZ_GOLEM": "stack", "MAGPIE": "spikes",
	"LANTERN_MOTH": "wings", "VEIN_WRAITH": "shards", "CLOUDER": "puff", "GLASS_WYRM": "long",
	"THE_FOREMAN": "tower", "THE_REGENT": "tower", "THE_DRILL": "tower"}
const TINTS: Array = ["9a7dff", "4fd6b8", "ff8a4a", "5a8cff", "ffc23a", "c860ff", "58d878", "ff5a7a", "7ac8ff", "ffd45a"]

var key: String = ""
var tint: Color = Color.WHITE
var warden: bool = false
var style: String = "cluster"
var body_material: StandardMaterial3D
var core_material: StandardMaterial3D
var anchor: Vector3 = Vector3(0, 1.6, 0)
var rest_position: Vector3 = Vector3.ZERO
var _body: Node3D
var _parts: Array = []
var _clock: float = 0.0
var _sway: float = 1.0
var _light: OmniLight3D
var _ring: MeshInstance3D
var _ring_material: StandardMaterial3D
var _shadow: MeshInstance3D
var _targeted: bool = false
var _hovered: bool = false
var _recoil := Vector3.ZERO
var _squash: float = 0.0
var _rear: float = 0.0
var _glow_boost: float = 0.0
var _dying: bool = false
var _base_emission: float = 0.3

static func make(creature_key: String, is_warden: bool = false) -> CrystalCreature:
	var creature := CrystalCreature.new()
	creature.key = creature_key
	creature.build(is_warden)
	return creature

func build(is_warden: bool) -> void:
	warden = is_warden
	var seed_value: int = key.hash()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	tint = Color(str(TINTS[absi(seed_value) % TINTS.size()]))
	if warden:
		tint = tint.lerp(Color("ff5a4a"), 0.35)
	body_material = StandardMaterial3D.new()
	body_material.albedo_color = tint.darkened(0.25)
	body_material.roughness = 0.18
	body_material.metallic = 0.25
	body_material.metallic_specular = 0.9
	body_material.emission_enabled = true
	body_material.emission = tint
	_base_emission = 0.22 if not warden else 0.4
	body_material.emission_energy_multiplier = _base_emission
	## A bright rim so the silhouette reads against fog and dark rock alike.
	body_material.rim_enabled = true
	body_material.rim = 1.0
	body_material.rim_tint = 0.3
	body_material.vertex_color_use_as_albedo = true
	core_material = StandardMaterial3D.new()
	core_material.albedo_color = tint.darkened(0.6)
	core_material.roughness = 0.7
	core_material.emission_enabled = true
	core_material.emission = tint.lightened(0.2)
	core_material.emission_energy_multiplier = 1.4
	_body = Node3D.new()
	add_child(_body)
	style = str(STYLES.get(key, "cluster"))
	var scale_all: float = 1.5 if warden else 1.0
	match style:
		"low":
			_core(Vector3(0, 0.3, 0), 0.45, Vector3(1.4, 0.55, 1.0))
			for i in range(6):
				_crystal(rng, Vector3(rng.randf_range(-0.5, 0.5), 0.4, rng.randf_range(-0.3, 0.3)), rng.randf_range(0.3, 0.7), 0.09, Vector3(rng.randf_range(-45, 45), 0, rng.randf_range(-45, 45)))
			for side in [-1.0, 1.0]:
				for leg in range(3):
					_crystal(rng, Vector3(side * 0.55, 0.25, -0.3 + 0.3 * leg), 0.5, 0.04, Vector3(0, 0, side * 70.0 + rng.randf_range(-10, 10)))
			anchor = Vector3(0, 1.2, 0)
			_sway = 3.0
		"blob":
			_core(Vector3(0, 0.5, 0), 0.62, Vector3(1.35, 0.85, 1.2))
			_core(Vector3(0.28, 0.85, 0.1), 0.34, Vector3(1.0, 0.8, 1.0))
			_core(Vector3(-0.3, 0.7, 0.15), 0.24, Vector3(1.0, 0.9, 1.0))
			for i in range(4):
				_crystal(rng, Vector3(rng.randf_range(-0.4, 0.4), 0.7, rng.randf_range(-0.2, 0.2)), rng.randf_range(0.2, 0.4), 0.06, Vector3(rng.randf_range(-30, 30), 0, rng.randf_range(-30, 30)))
			_sway = 2.2
			anchor = Vector3(0, 1.6, 0)
		"stack":
			for i in range(4):
				_block(rng, Vector3(rng.randf_range(-0.12, 0.12), 0.35 + float(i) * 0.62, 0), Vector3(1.1 - float(i) * 0.15, 0.55, 0.9 - float(i) * 0.1), rng.randf_range(-12, 12))
			_core(Vector3(0, 1.6, 0.42), 0.14, Vector3.ONE)
			_crystal(rng, Vector3(0, 2.75, 0), 0.5, 0.14, Vector3.ZERO)
			anchor = Vector3(0, 3.5, 0)
			_sway = 0.5
		"spikes":
			_core(Vector3(0, 0.95, 0), 0.34, Vector3.ONE)
			for i in range(9):
				_crystal(rng, Vector3(rng.randf_range(-0.25, 0.25), 0.95, rng.randf_range(-0.25, 0.25)), rng.randf_range(0.8, 1.5), 0.06, Vector3(rng.randf_range(-70, 70), 0, rng.randf_range(-70, 70)))
			anchor = Vector3(0, 2.5, 0)
			_sway = 3.0
		"wings":
			_core(Vector3(0, 1.25, 0), 0.22, Vector3(0.7, 1.6, 0.7))
			_core(Vector3(0, 1.75, 0.05), 0.16, Vector3.ONE)
			_wing(Vector3(-0.2, 1.35, 0), -1.0)
			_wing(Vector3(0.2, 1.35, 0), 1.0)
			anchor = Vector3(0, 2.4, 0)
			_sway = 4.0
		"shards":
			for i in range(9):
				_crystal(rng, Vector3(rng.randf_range(-0.6, 0.6), rng.randf_range(0.3, 1.5), rng.randf_range(-0.4, 0.4)), rng.randf_range(0.5, 1.1), 0.08, Vector3(rng.randf_range(-70, 70), rng.randf_range(0, 360), rng.randf_range(-70, 70)))
			_core(Vector3(0, 1.0, 0), 0.2, Vector3.ONE)
			anchor = Vector3(0, 2.3, 0)
			_sway = 1.6
		"puff":
			for i in range(6):
				_core(Vector3(rng.randf_range(-0.45, 0.45), 0.9 + rng.randf_range(-0.3, 0.3), rng.randf_range(-0.3, 0.3)), rng.randf_range(0.32, 0.55), Vector3.ONE)
			anchor = Vector3(0, 2.0, 0)
			_sway = 1.2
		"long":
			for i in range(7):
				var t: float = float(i) / 6.0
				_core(Vector3(lerpf(-1.5, 1.5, t), 0.5 + sin(t * PI) * 0.7, 0), 0.42 - t * 0.14, Vector3.ONE)
			_crystal(rng, Vector3(-1.5, 1.2, 0), 0.6, 0.12, Vector3(0, 0, 30))
			_crystal(rng, Vector3(-1.35, 1.1, 0.2), 0.45, 0.1, Vector3(20, 0, 50))
			anchor = Vector3(0, 2.2, 0)
			_sway = 0.8
		"tower":
			_block(rng, Vector3(0, 0.6, 0), Vector3(1.8, 1.2, 1.4), 0)
			_block(rng, Vector3(0, 1.7, 0), Vector3(1.3, 1.0, 1.0), 8)
			_core(Vector3(0, 1.7, 0.52), 0.22, Vector3(1.0, 1.0, 0.6))
			for i in range(7):
				_crystal(rng, Vector3(rng.randf_range(-0.6, 0.6), 2.3, rng.randf_range(-0.4, 0.4)), rng.randf_range(0.8, 1.7), 0.16, Vector3(rng.randf_range(-25, 25), 0, rng.randf_range(-25, 25)))
			anchor = Vector3(0, 4.4, 0)
			_sway = 0.4
		_:
			_core(Vector3(0, 0.5, 0), 0.5, Vector3.ONE)
			for i in range(6):
				_crystal(rng, Vector3(rng.randf_range(-0.4, 0.4), 0.6, rng.randf_range(-0.4, 0.4)), rng.randf_range(0.6, 1.2), 0.12, Vector3(rng.randf_range(-45, 45), 0, rng.randf_range(-45, 45)))
			anchor = Vector3(0, 2.0, 0)
	scale = Vector3.ONE * scale_all
	anchor *= scale_all
	## Its own light, thrown on the floor around it.
	_light = OmniLight3D.new()
	_light.light_color = tint
	_light.light_energy = 1.4 if not warden else 2.6
	_light.omni_range = 3.2 if not warden else 5.0
	_light.light_volumetric_fog_energy = 1.5
	_light.position = Vector3(0, anchor.y / scale_all * 0.45, 0.4)
	add_child(_light)
	## A soft shadow pooled beneath it, so it stands on the floor rather than floats over it.
	_shadow = MeshInstance3D.new()
	var disc := QuadMesh.new()
	disc.size = Vector2(2.2, 2.2) if style != "long" else Vector2(4.2, 2.2)
	disc.orientation = PlaneMesh.FACE_Y
	var dark := StandardMaterial3D.new()
	dark.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dark.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dark.albedo_texture = DeepUi.glow_texture()
	dark.albedo_color = Color(0, 0, 0, 0.75)
	dark.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	disc.material = dark
	_shadow.mesh = disc
	_shadow.position = Vector3(0, 0.03, 0)
	_shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_shadow)
	## The target ring, hidden until the party picks this creature.
	_ring = MeshInstance3D.new()
	_ring.mesh = Lowpoly.ring(1.15 if style != "long" else 1.9, 0.09, 40)
	_ring_material = StandardMaterial3D.new()
	_ring_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ring_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_ring_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_ring_material.albedo_color = Color(DeepUi.ACCENT, 0.0)
	_ring_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_ring.material_override = _ring_material
	_ring.position = Vector3(0, 0.05, 0)
	_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_ring)

func _holder(at: Vector3, tilt: Vector3) -> Node3D:
	var holder := Node3D.new()
	holder.position = at
	holder.rotation_degrees = tilt
	_body.add_child(holder)
	_parts.append({"node": holder, "base_pos": at, "base_rot": holder.rotation, "phase": float(_parts.size()) * 0.9, "kind": "part"})
	return holder

func _crystal(rng: RandomNumberGenerator, at: Vector3, height: float, radius: float, tilt: Vector3) -> void:
	var holder := _holder(at, tilt)
	var body := MeshInstance3D.new()
	body.mesh = Lowpoly.crystal(rng, Color.WHITE, radius, height + radius * 1.6)
	body.material_override = body_material
	holder.add_child(body)
	_parts[_parts.size() - 1].kind = "crystal"

func _core(at: Vector3, radius: float, stretch: Vector3) -> void:
	var holder := _holder(at, Vector3.ZERO)
	var node := MeshInstance3D.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = key.hash() + _parts.size()
	node.mesh = Lowpoly.rock(rng, Color.WHITE, 0.12)
	node.material_override = core_material
	node.scale = stretch * radius
	holder.add_child(node)
	_parts[_parts.size() - 1].kind = "core"

func _block(rng: RandomNumberGenerator, at: Vector3, size: Vector3, yaw: float) -> void:
	var holder := _holder(at, Vector3(0, yaw, 0))
	var node := MeshInstance3D.new()
	node.mesh = Lowpoly.slab(size, Color.WHITE, rng, 0.06)
	node.material_override = body_material
	holder.add_child(node)
	_parts[_parts.size() - 1].kind = "block"

func _wing(at: Vector3, side: float) -> void:
	var holder := _holder(at, Vector3.ZERO)
	var node := MeshInstance3D.new()
	var prism := PrismMesh.new()
	prism.size = Vector3(1.2, 1.0, 0.04)
	node.mesh = prism
	node.material_override = body_material
	node.position = Vector3(side * 0.6, 0.0, 0.0)
	node.rotation_degrees = Vector3(0, 0, 18.0 * side)
	holder.add_child(node)
	_parts[_parts.size() - 1].kind = "wing"
	_parts[_parts.size() - 1].side = side

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

func spawn(delay: float = 0.0) -> void:
	## Rises out of the rock.
	_body.position = Vector3(0, -2.5 * (anchor.y / 2.0), 0)
	_body.scale = Vector3.ONE * 0.3
	_light.light_energy = 0.0
	var energy: float = 1.4 if not warden else 2.6
	var tween := create_tween().set_parallel(true)
	tween.tween_property(_body, "position", Vector3.ZERO, 0.7).set_delay(delay).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(_body, "scale", Vector3.ONE, 0.6).set_delay(delay).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
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
	tween.tween_property(_body, "scale", Vector3.ONE * 1.25, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(_body, "scale", Vector3(0.05, 0.05, 0.05), 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(_body, "rotation:y", PI * 1.5, 0.3)
	tween.parallel().tween_property(_light, "light_energy", 0.0, 0.3)
	tween.parallel().tween_property(_shadow, "transparency", 1.0, 0.3)
	tween.tween_callback(queue_free)

func _process(delta: float) -> void:
	_clock += delta
	if _body == null:
		return
	## Breathing: the whole creature rises and falls a little, faster for the light ones.
	var breathe: float = sin(_clock * _sway)
	_recoil = _recoil.lerp(Vector3.ZERO, clampf(delta * 7.0, 0.0, 1.0))
	_squash = lerpf(_squash, 0.0, clampf(delta * 8.0, 0.0, 1.0))
	var rear := Vector3(0, 0.12 * maxf(_rear, 0.0), -0.5 * _rear) if _rear >= 0.0 else Vector3(0, 0, 1.6 * -_rear)
	position = rest_position + Vector3(0, breathe * 0.05, 0) + _recoil + rear
	var squish: float = _squash * sin(_clock * 30.0) + (0.05 * breathe if style == "blob" else 0.0)
	if not _dying:
		_body.scale = Vector3(1.0 + squish * 0.5, 1.0 - squish, 1.0 + squish * 0.5)
		_body.rotation.x = -0.22 * maxf(_rear, 0.0) + 0.3 * minf(_rear, 0.0) * -1.0
	## Each part keeps its own time.
	for part in _parts:
		var node: Node3D = part.node
		var phase: float = float(part.phase)
		match str(part.kind):
			"wing":
				var beat: float = sin(_clock * 11.0 + phase) * 0.55
				node.rotation = part.base_rot + Vector3(0, 0, beat * float(part.get("side", 1.0)))
			"crystal":
				node.rotation = part.base_rot + Vector3(sin(_clock * 1.3 + phase) * 0.05, 0, cos(_clock * 1.1 + phase) * 0.05)
				if style == "shards":
					var orbit: float = _clock * 0.6 + phase
					node.position = part.base_pos.rotated(Vector3.UP, sin(orbit) * 0.4) + Vector3(0, sin(_clock * 1.7 + phase) * 0.08, 0)
			"core":
				var pulse: float = 1.0 + 0.06 * sin(_clock * (2.4 if style != "puff" else 1.3) + phase)
				node.scale = Vector3.ONE * pulse
				if style == "long":
					node.position = part.base_pos + Vector3(0, sin(_clock * 2.0 - part.base_pos.x * 1.4) * 0.12, 0)
			"block":
				node.rotation = part.base_rot + Vector3(0, sin(_clock * 0.7 + phase) * 0.06, 0)
	## The heartbeat of its glow, flaring on every blow.
	_glow_boost = move_toward(_glow_boost, 0.0, delta * 5.0)
	var heartbeat: float = pow(maxf(0.0, sin(_clock * 2.2)), 8.0) * 0.4
	body_material.emission_energy_multiplier = _base_emission + heartbeat + _glow_boost
	core_material.emission_energy_multiplier = 1.4 + heartbeat * 2.0 + _glow_boost * 0.6
	if _light != null and not _dying and _body.scale.x > 0.95:
		_light.light_energy = (1.4 if not warden else 2.6) * (1.0 + heartbeat) + _glow_boost * 1.2
	## The ring under it when it is the target: turning slowly, brighter on hover.
	var want: float = (0.85 if _targeted else 0.0) + (0.35 if _hovered else 0.0)
	_ring_material.albedo_color.a = move_toward(_ring_material.albedo_color.a, minf(want, 1.0), delta * 4.0)
	_ring.rotation.y += delta * 0.8
	_ring.scale = Vector3.ONE * (1.0 + 0.04 * sin(_clock * 4.0))
