extends SceneTree
## Render every die, or stress a bowl of high-sided dice:
## godot --path . --script tools/dice_gallery.gd -- build/dice.png [D100 D100 D100 D100 D100]
## Uses the actual live views, then measures frames with rolling dice after warm-up.

const DiceView = preload("res://view/dice/dice_view.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	if DiceView.headless():
		printerr("The dice gallery needs a graphical display. Run tests/test_dice_shapes.gd for headless geometry checks.")
		quit(1)
		return
	var args := OS.get_cmdline_user_args()
	var out := str(args[0]) if args.size() > 0 else "build/dice.png"
	var shapes: Array = Array(args.slice(1)) if args.size() > 1 else DeepDice.TIERS
	root.size = Vector2i(1500, 960)
	root.content_scale_size = Vector2i(1500, 960)
	var background := ColorRect.new()
	background.color = Color("151923")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(background)
	var heading := Label.new()
	heading.text = "DEEP CUT  /  DICE"
	heading.position = Vector2(30, 15)
	heading.add_theme_font_size_override("font_size", 28)
	root.add_child(heading)
	var views: Array = []
	for i in shapes.size():
		var shape := str(shapes[i])
		var die := DeepDice.make(shape, DeepContent.die(shape), "gallery%d" % i)
		var count := int(DeepDice.SHAPES[shape])
		var cell := Control.new()
		cell.position = Vector2(20 + (i % 5) * 295, 60 + (i / 5) * 295)
		cell.size = Vector2(275, 280)
		root.add_child(cell)
		var view := DiceView.new()
		view.position = Vector2(10, 0)
		view.size = Vector2(255, 245)
		view.live = false
		cell.add_child(view)
		view.configure(die, {"face": count - 1, "value": count, "die_id": die.id}, false, false, Color.WHITE)
		view.settle_immediately()
		# Keep the high face legible while revealing the silhouette and adjacent facets.
		view._pivot.quaternion = Quaternion(Vector3.UP, 0.3) * Quaternion(Vector3.RIGHT, -0.2) * view._target
		views.append(view)
		var caption := Label.new()
		caption.text = "%s  ·  %d faces" % [shape, count]
		caption.position = Vector2(0, 248)
		caption.size.x = 275
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		caption.add_theme_font_size_override("font_size", 20)
		cell.add_child(caption)
	await create_timer(2.0).timeout
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out.get_base_dir()))
	var error := root.get_texture().get_image().save_png(out)
	print("saved %s (%s)" % [out, error_string(error)])
	for view in views:
		assert(view._labels.size() == view.face_count(), "Only playable faces have numerals")
		view.spin_seconds = 20.0
		view._start_spin()
	var start := Time.get_ticks_usec()
	for _i in 180:
		await process_frame
	var ms := float(Time.get_ticks_usec() - start) / 180000.0
	print("%d live rotating dice: %.2f ms/frame (%.1f fps), %d draw calls" % [views.size(), ms, 1000.0 / ms, int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))])
	quit(0 if error == OK else 1)
