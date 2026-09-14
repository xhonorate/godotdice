extends Control
## A gem drawn flat: its girdle outline, a ring of shaded facets round the table, and the
## skill's emblem in the middle. It is the cheap twin of `gem_view.gd` for places that show
## many gems at once — the gem sack, a mine's pool, a tray of sockets being dragged about —
## where a live 3D camera per stone costs more than the screen can spare.
##
## It reads the same four properties the solid does, so the two agree at a glance: Colour
## is the outline and hue, Carat the size, Cut how true the girdle is, Clarity how clean
## and bright the body is. It draws itself once and redraws only when told something new.
##
## `state` changes what may be shown. "owned" and "seen" are named gems (a seen one is
## drawn pale); "sealed" is an unappraised stone, shape and hue but no emblem; "unseen" is
## a black silhouette and a question mark, and says nothing about which gem it is.

const GemMesh = preload("res://scripts/ui/gem_mesh.gd")
const GemIcons = preload("res://scripts/ui/gem_icons.gd")
const Catalog = preload("res://scripts/core/catalog.gd")

## The direction the light comes from, in screen space: over the reader's left shoulder.
const LIGHT := Vector2(-0.55, -0.83)

var gem: Dictionary = {}
var state := "owned"
## Whether Carat changes the drawn size. A tray of sockets wants every stone to fit its
## setting; the sack wants a heavy stone to look heavy.
var sized := true
var glow := 0.0

static func make(gem_data: Dictionary, edge: float, badge_state := "") -> Control:
	var badge := new()
	badge.custom_minimum_size = Vector2(edge, edge)
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.configure(gem_data, badge_state)
	return badge

func configure(gem_data: Dictionary, badge_state := "") -> void:
	gem = gem_data
	if badge_state.is_empty():
		badge_state = "sealed" if gem.has("appraised") and not bool(gem.appraised) else "owned"
	state = badge_state
	queue_redraw()

func _color_key() -> String:
	return Catalog.gem_color(Catalog.canonical_key(str(gem.get("key", ""))))

func _draw() -> void:
	if gem.is_empty():
		return
	var centre := size * 0.5
	var reach := minf(size.x, size.y) * 0.5
	var span := 0.86
	if sized and state in ["owned", "sealed"]:
		# Heavier reads as bigger, but gently: a Carat 1 stone still fills most of its setting.
		var weight := float(clampi(int(gem.get("carat", 1)), 1, 24) - 1) / 23.0
		span *= 0.84 + 0.24 * pow(weight, 0.7)
	var radius := reach * span
	var color_key := _color_key()
	var outline := PackedVector2Array()
	var source := GemMesh.girdle(gem) if state in ["owned", "sealed"] else GemMesh.silhouette(color_key)
	for point in source:
		# The solid is built y-up; the screen is y-down.
		outline.append(centre + Vector2(point.x, -point.y) * radius)
	if outline.size() < 3:
		return
	if state == "unseen":
		draw_colored_polygon(outline, Color(0.02, 0.03, 0.05, 0.92))
		draw_polyline(_closed(outline), Color(1, 1, 1, 0.16), 1.5, true)
		var font := get_theme_default_font()
		var font_size := int(radius * 0.9)
		var mark := font.get_string_size("?", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
		draw_string(font, centre + Vector2(-mark.x * 0.5, mark.y * 0.32), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(1, 1, 1, 0.35))
		return
	var clarity := int(gem.get("clarity", 3)) if state != "seen" else 3
	var body := GemMesh.body_colour(color_key, clarity)
	var brilliance := GemMesh.brilliance(clarity)
	var pale := state == "seen"
	if glow > 0.0:
		for ring in range(6, 0, -1):
			var t := float(ring) / 6.0
			draw_circle(centre, radius * (1.0 + 0.45 * t), Color(body.lightened(0.3), 0.07 * glow * (1.0 - t)))
	# The glow a clean stone throws on what it sits on.
	if not pale and brilliance > 0.2:
		for ring in range(5, 0, -1):
			var t := float(ring) / 5.0
			draw_circle(centre, radius * (0.9 + 0.3 * t), Color(body, 0.035 * brilliance * (1.0 - t)))
	draw_colored_polygon(outline, body.darkened(0.35))
	var table_span := GemMesh.table_span(int(gem.get("cut", 3)), str(GemMesh.CUTS.get(color_key, "round")))
	var table := PackedVector2Array()
	for point in outline:
		table.append(centre + (point - centre) * table_span)
	var count := outline.size()
	for index in count:
		var a := outline[index]
		var b := outline[(index + 1) % count]
		var c := table[(index + 1) % count]
		var d := table[index]
		var middle := ((a + b) * 0.5 - centre).normalized()
		var lit := clampf(middle.dot(LIGHT) * 0.5 + 0.5, 0.0, 1.0)
		var tone := body.darkened(0.30 - 0.30 * lit).lightened(0.32 * lit * (0.5 + 0.5 * brilliance))
		draw_colored_polygon(PackedVector2Array([a, b, c, d]), tone)
	draw_colored_polygon(table, body.lightened(0.10 + 0.14 * brilliance))
	# The table catches the light across the side facing it: a fan of wedges from the middle,
	# which stays a valid shape however the girdle has been miscut.
	for index in count:
		var a := table[index]
		var b := table[(index + 1) % count]
		if ((a + b) * 0.5 - centre).dot(LIGHT) > 0.0:
			draw_colored_polygon(PackedVector2Array([centre, a, b]), Color(1, 1, 1, 0.10 + 0.12 * brilliance))
	draw_polyline(_closed(outline), body.darkened(0.6), maxf(1.0, radius * 0.05), true)
	draw_polyline(_closed(table), Color(1, 1, 1, 0.18 + 0.2 * brilliance), maxf(1.0, radius * 0.025), true)
	if state != "sealed":
		var emblem := GemIcons.emblem(Catalog.canonical_key(str(gem.get("key", ""))))
		var edge := radius * 0.78
		var texture := GemIcons.texture(emblem, int(clampf(edge, 12.0, 96.0)))
		draw_texture_rect(texture, Rect2(centre - Vector2(edge, edge) * 0.5, Vector2(edge, edge)), false, Color(body.darkened(0.72), 0.78))
	if brilliance >= 0.74 and not pale:
		_star(centre + Vector2(-0.34, -0.40) * radius, radius * 0.22, Color(1, 1, 1, 0.85))
	if pale:
		draw_colored_polygon(outline, Color(0.08, 0.1, 0.14, 0.55))

func _closed(points: PackedVector2Array) -> PackedVector2Array:
	var closed := points.duplicate()
	closed.append(points[0])
	return closed

func _star(at: Vector2, reach: float, tone: Color) -> void:
	draw_line(at - Vector2(reach, 0), at + Vector2(reach, 0), tone, maxf(1.0, reach * 0.18), true)
	draw_line(at - Vector2(0, reach), at + Vector2(0, reach), tone, maxf(1.0, reach * 0.18), true)
	draw_circle(at, reach * 0.18, tone)
