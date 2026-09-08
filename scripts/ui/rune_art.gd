extends Control
## Code-native placeholder illustrations. All paths remain editable and asset-free.

@export var kind := "gem"
@export var tint := Color("d6ac67")
@export var ornament_seed := 0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)

func _draw() -> void:
	var c := size / 2.0
	var r := minf(size.x, size.y) * 0.38
	if kind == "background":
		for x in range(0, int(size.x) + 80, 80):
			draw_line(Vector2(x, 0), Vector2(x - size.y * 0.4, size.y), Color(0.65, 0.52, 0.32, 0.025), 1)
		for i in range(36):
			var p := Vector2(fposmod(float(i * 173 + 31), size.x), fposmod(float(i * 239 + 57), size.y))
			draw_circle(p, 1.3 if i % 4 else 2.0, Color(0.83, 0.67, 0.41, 0.12))
		return
	if kind == "gem":
		var points := PackedVector2Array([c + Vector2(0, -r), c + Vector2(r * 0.8, -r * 0.25), c + Vector2(r * 0.52, r * 0.62), c + Vector2(0, r), c + Vector2(-r * 0.52, r * 0.62), c + Vector2(-r * 0.8, -r * 0.25)])
		draw_colored_polygon(points, Color(tint, 0.14))
		for i in range(points.size()):
			draw_line(points[i], points[(i + 1) % points.size()], tint, 2, true)
			draw_line(points[i], c, Color(tint, 0.6), 1, true)
		draw_circle(c, r * 0.16, tint)
		return
	if kind == "die":
		var poly := PackedVector2Array()
		for i in range(6):
			poly.append(c + Vector2.from_angle(PI / 3.0 * i - PI / 6.0) * r)
		draw_colored_polygon(poly, Color(tint, 0.09))
		for i in range(6):
			draw_line(poly[i], poly[(i + 1) % 6], tint, 2, true)
		draw_line(poly[0], c, Color(tint, 0.5), 1)
		draw_line(poly[2], c, Color(tint, 0.5), 1)
		draw_line(poly[4], c, Color(tint, 0.5), 1)
		return
	draw_arc(c, r * 1.08, 0, TAU, 64, Color(tint, 0.24), 1, true)
	draw_arc(c, r * 0.97, PI * 0.16, PI * 0.84, 20, Color(tint, 0.55), 2, true)
	draw_arc(c, r * 0.97, PI * 1.16, PI * 1.84, 20, Color(tint, 0.55), 2, true)
	if kind.to_lower().contains("slime"):
		var shape := PackedVector2Array()
		for i in range(25):
			var a := PI + PI * float(i) / 24.0
			shape.append(c + Vector2(cos(a) * r * 0.8, sin(a) * r * 0.55 + r * 0.4))
		shape.append(c + Vector2(r * 0.7, r * 0.65))
		shape.append(c + Vector2(-r * 0.7, r * 0.65))
		draw_colored_polygon(shape, Color(tint, 0.6))
		draw_circle(c + Vector2(-r * 0.22, r * 0.16), r * 0.055, Color("0c141c"))
		draw_circle(c + Vector2(r * 0.22, r * 0.16), r * 0.055, Color("0c141c"))
		if kind.to_lower().contains("king"):
			draw_colored_polygon(PackedVector2Array([c + Vector2(-r * 0.4, -r * 0.25), c + Vector2(-r * 0.45, -r * 0.68), c + Vector2(-r * 0.18, -r * 0.48), c + Vector2(0, -r * 0.8), c + Vector2(r * 0.18, -r * 0.48), c + Vector2(r * 0.45, -r * 0.68), c + Vector2(r * 0.4, -r * 0.25)]), Color("d6ac67"))
	else:
		var silhouette := PackedVector2Array([c + Vector2(0, -r * 0.84), c + Vector2(r * 0.37, -r * 0.45), c + Vector2(r * 0.25, -r * 0.02), c + Vector2(r * 0.62, r * 0.4), c + Vector2(r * 0.72, r * 0.73), c + Vector2(-r * 0.72, r * 0.73), c + Vector2(-r * 0.62, r * 0.4), c + Vector2(-r * 0.25, -r * 0.02), c + Vector2(-r * 0.37, -r * 0.45)])
		draw_colored_polygon(silhouette, Color(tint, 0.25))
		for i in range(silhouette.size()):
			draw_line(silhouette[i], silhouette[(i + 1) % silhouette.size()], Color(tint, 0.72), 1, true)
		draw_line(c + Vector2(-r * 0.2, -r * 0.26), c + Vector2(r * 0.2, -r * 0.26), tint, 3, true)
		draw_line(c + Vector2(0, -r * 0.08), c + Vector2(0, r * 0.62), Color(tint, 0.6), 1, true)
		if kind.to_lower().contains("kait"):
			draw_line(c + Vector2(-r * 0.7, r * 0.52), c + Vector2(r * 0.75, -r * 0.65), tint, 3, true)
		elif kind.to_lower().contains("max") or kind.to_lower().contains("wisp"):
			draw_circle(c + Vector2(r * 0.58, -r * 0.18), r * 0.14, tint)
			draw_arc(c + Vector2(r * 0.58, -r * 0.18), r * 0.25, 0, TAU, 24, Color(tint, 0.4), 1)
		else:
			draw_colored_polygon(PackedVector2Array([c + Vector2(-r * 0.65, r * 0.05), c + Vector2(-r * 0.22, r * 0.05), c + Vector2(-r * 0.25, r * 0.45), c + Vector2(-r * 0.45, r * 0.66), c + Vector2(-r * 0.66, r * 0.45)]), Color(tint, 0.55))
