extends RefCounted
## The mark of a Flawless line at work: the small star from a gem's card, flaring in its gold over
## the gem as the line does something the gem alone would not have. It says "this is the bonus",
## so what comes next (a second blow, a ×2 on the count, a Resonance flying up) reads as the line's.

const ScreenFx = preload("res://view/battle/screen_fx.gd")

static func tone() -> Color:
	return DeepUi.tier_color("PEERLESS")

static func sparkle(parent: Control, at: Vector2, size: float = 1.0) -> void:
	## A flare at this point on screen. Over in under half a second, and it holds nothing up: the
	## rules reserve any time the line needs (`DeepBattle.FLAWLESS_BEAT`), so a faster fight, which
	## plays everything on a faster clock, only makes this quicker.
	if parent == null or not parent.is_inside_tree() or not at.is_finite():
		return
	var gold: Color = tone()
	var glow := Sprite2D.new()
	glow.texture = DeepUi.glow_texture()
	glow.modulate = Color(gold.lightened(0.2), 0.95)
	var additive := CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	glow.material = additive
	glow.z_index = 46
	parent.add_child(glow)
	glow.global_position = at
	var wide: float = 104.0 * size / maxf(1.0, float(glow.texture.get_width()))
	glow.scale = Vector2.ONE * wide * 0.35
	var bloom := glow.create_tween().set_parallel(true)
	bloom.tween_property(glow, "scale", Vector2.ONE * wide * 1.25, 0.34).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	bloom.tween_property(glow, "modulate:a", 0.0, 0.3).set_delay(0.08)
	bloom.chain().tween_callback(glow.queue_free)
	var star := DeepUi.icon(parent, "star", 40.0 * size, gold.lightened(0.28))
	star.mouse_filter = Control.MOUSE_FILTER_IGNORE
	star.z_index = 47
	star.size = star.custom_minimum_size
	star.pivot_offset = star.size * 0.5
	star.global_position = at - star.size * 0.5
	star.scale = Vector2.ONE * 0.2
	star.rotation = -0.5
	var turn := star.create_tween().set_parallel(true)
	turn.tween_property(star, "scale", Vector2.ONE * 1.2, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	turn.tween_property(star, "rotation", 0.35, 0.42).set_trans(Tween.TRANS_SINE)
	turn.tween_property(star, "scale", Vector2.ONE * 0.5, 0.2).set_delay(0.22)
	turn.tween_property(star, "modulate:a", 0.0, 0.2).set_delay(0.22)
	turn.chain().tween_callback(star.queue_free)
	var inside: Vector2 = at - parent.get_global_rect().position
	DeepUi.burst(parent, inside, gold, 6 if ScreenFx.calm else 18, 150.0 * size, 0.45, 4.0, 46)

static func mote(parent: Control, from: Vector2, to: Vector2, seconds: float, landed: Callable) -> void:
	## One star thrown from a gem to where it counts, along a little bow, the count ticking as it lands.
	if parent == null or not parent.is_inside_tree() or not from.is_finite() or not to.is_finite():
		landed.call()
		return
	var star := DeepUi.icon(parent, "star", 20.0, tone().lightened(0.2))
	star.mouse_filter = Control.MOUSE_FILTER_IGNORE
	star.z_index = 46
	star.size = star.custom_minimum_size
	star.pivot_offset = star.size * 0.5
	var half: Vector2 = star.size * 0.5
	var bend: Vector2 = (from + to) * 0.5 + Vector2(randf_range(-50.0, 50.0), randf_range(-90.0, -40.0))
	star.global_position = from - half
	var tween := star.create_tween()
	tween.tween_method(func(t: float) -> void:
		var eased: float = t * t * (3.0 - 2.0 * t)
		star.global_position = from.lerp(bend, eased).lerp(bend.lerp(to, eased), eased) - half
		star.rotation = t * 5.0
		star.scale = Vector2.ONE * lerpf(1.15, 0.6, t), 0.0, 1.0, maxf(0.05, seconds))
	tween.tween_callback(landed)
	tween.tween_callback(star.queue_free)
