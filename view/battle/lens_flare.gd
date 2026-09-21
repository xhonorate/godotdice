extends Control
## Lens flares over the chamber: every bright light the camera can see throws a bloom, a
## horizontal streak and a chain of ghosts through the middle of the screen, the way light
## behaves in a real lens. Drawn additively in 2D over the 3D view, so it costs a few quads.
##
## Sources are the chamber's standing lights and the effects' passing ones. A source fades as
## it nears the edge of the frame or turns away from the view, so flares swim as the camera
## breathes rather than switching on and off.

var camera: Camera3D = null
var viewport: SubViewport = null
var sources: Array = []
var transient: Array = []
var strength: float = 1.0

const GHOSTS: Array = [[-0.35, 0.10, 0.10], [0.25, 0.05, 0.16], [0.55, 0.07, 0.06], [0.9, 0.12, 0.22], [1.25, 0.05, 0.1], [1.6, 0.09, 0.3]]

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = add

func _process(_delta: float) -> void:
	if is_visible_in_tree():
		queue_redraw()

func _screen(point: Vector3) -> Dictionary:
	if camera == null or viewport == null or camera.is_position_behind(point):
		return {}
	var at: Vector2 = camera.unproject_position(point)
	var span := Vector2(viewport.size)
	if span.x <= 0.0 or span.y <= 0.0:
		return {}
	var uv := at / span
	var facing: float = (-camera.global_transform.basis.z).dot((point - camera.global_position).normalized())
	var edge: float = minf(minf(uv.x, 1.0 - uv.x), minf(uv.y, 1.0 - uv.y))
	var seen: float = clampf(edge * 5.0 + 0.15, 0.0, 1.0) * clampf((facing - 0.5) * 3.0, 0.0, 1.0)
	return {"at": uv * size, "seen": seen}

func _draw() -> void:
	if camera == null or strength <= 0.0:
		return
	var glow: Texture2D = DeepUi.glow_texture()
	var centre: Vector2 = size * 0.5
	var entries: Array = []
	for source in sources:
		var node: Node3D = source.get("node", null)
		if node == null or not is_instance_valid(node) or not node.is_visible_in_tree():
			continue
		var energy: float = 1.0
		if node is Light3D:
			energy = clampf((node as Light3D).light_energy / 3.0, 0.2, 1.6)
		entries.append({"point": node.global_position, "colour": source.colour, "strength": float(source.strength) * energy * 0.6, "size": float(source.get("size", 1.0)), "ghosts": false})
	for flare in transient:
		var life: float = maxf(0.01, float(flare.life))
		var fade: float = 1.0 - float(flare.age) / life
		entries.append({"point": flare.position, "colour": flare.colour, "strength": float(flare.strength) * fade * fade, "size": float(flare.size), "ghosts": true})
	var unit: float = size.y / 900.0
	## Ghosts are costly to the eye: only the brightest passing flash throws them.
	var ghost_budget: int = 1
	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.strength) > float(b.strength))
	for entry in entries:
		var seen: Dictionary = _screen(entry.point)
		if seen.is_empty() or float(seen.seen) <= 0.01:
			continue
		var power: float = float(entry.strength) * float(seen.seen) * strength
		var at: Vector2 = seen.at
		var colour: Color = entry.colour
		var scale: float = float(entry.size) * unit
		## The bloom itself and a hot core.
		var bloom: float = 120.0 * scale * (0.6 + 0.4 * power)
		draw_texture_rect(glow, Rect2(at - Vector2(bloom, bloom) * 0.5, Vector2(bloom, bloom)), false, Color(colour, 0.22 * power))
		var core: float = 38.0 * scale
		draw_texture_rect(glow, Rect2(at - Vector2(core, core) * 0.5, Vector2(core, core)), false, Color(colour.lightened(0.6), 0.55 * power))
		## Anamorphic streak.
		var streak := Vector2(520.0 * scale * power, 9.0 * scale)
		draw_texture_rect(glow, Rect2(at - streak * 0.5, streak), false, Color(colour.lightened(0.3), 0.22 * power))
		## Ghosts along the line through the centre of the lens.
		if not bool(entry.ghosts) or ghost_budget <= 0 or power < 0.3:
			continue
		ghost_budget -= 1
		var axis: Vector2 = centre - at
		for ghost in GHOSTS:
			var place: Vector2 = at + axis * float(ghost[0]) * 2.0
			var radius: float = size.y * float(ghost[2]) * 0.3 * (0.7 + 0.3 * float(entry.size))
			var alpha: float = float(ghost[1]) * power * 0.5
			var tint: Color = colour.lerp(Color(0.6, 0.8, 1.0), 0.3 * float(ghost[0]))
			if int(float(ghost[0]) * 10.0) % 2 == 0:
				draw_texture_rect(glow, Rect2(place - Vector2(radius, radius), Vector2(radius, radius) * 2.0), false, Color(tint, alpha))
			else:
				var hexagon := PackedVector2Array()
				for i in range(6):
					var angle: float = TAU * float(i) / 6.0 + 0.3
					hexagon.append(place + Vector2(cos(angle), sin(angle)) * radius * 0.6)
				draw_colored_polygon(hexagon, Color(tint, alpha * 0.45))
