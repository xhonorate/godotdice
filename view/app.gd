extends Control
## The application shell: owns the profile, the settings, the session and the screens.

const HomeScreen = preload("res://view/home/home_screen.gd")
const DescentScreen = preload("res://view/run/descent_screen.gd")
const Thumbs = preload("res://view/gems/thumbs.gd")
const Inspector = preload("res://view/inspect/inspector.gd")
const GameMenu = preload("res://view/menu/game_menu.gd")
const BattleScreen = preload("res://view/battle/battle_screen.gd")
const CameraRig = preload("res://view/battle/camera_rig.gd")
const ScreenFx = preload("res://view/battle/screen_fx.gd")

var saves: DeepSaveStore
var settings: Dictionary = {}
var profile: Dictionary = {}
var session: DeepSession
var home: Control
var descent: Control
var menu: CanvasLayer
var _toasts: VBoxContainer

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = DeepUi.theme()
	var backdrop := ColorRect.new()
	backdrop.color = DeepUi.INK
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backdrop)
	saves = DeepSaveStore.new()
	settings = saves.load_settings()
	DeepAudio.start(self, settings)
	profile = saves.load_profile()
	if profile.is_empty():
		profile = DeepProfile.new_profile(str(settings.get("player_name", "Lapidary")))
		saves.save_profile(profile)
	elif profile.has("settings") or not profile.has("characters"):
		## A profile from before characters: its settings become characters, its vault stays.
		profile = DeepProfile.migrate(profile)
		saves.save_profile(profile)
	session = DeepSession.new()
	session.saves = saves
	session.speed = float(settings.get("speed", 1.0))
	add_child(session)
	session.lobby_changed.connect(func(_lobby: Dictionary) -> void: _refresh_home())
	session.status_changed.connect(func(_status: String) -> void: _refresh_home())
	session.run_started.connect(_on_run_started)
	session.run_event.connect(_on_run_event)
	session.run_ended.connect(_on_run_ended)
	session.refused.connect(func(message: String) -> void: toast(message, DeepUi.BAD))
	session.error.connect(func(message: String) -> void: toast(message, DeepUi.BAD))
	home = HomeScreen.new()
	home.depart_requested.connect(_depart)
	home.member_changed.connect(func(fields: Dictionary) -> void: session.update_member(fields))
	home.mine_chosen.connect(func(mine: String) -> void: session.choose_mine(mine))
	home.host_requested.connect(_host)
	home.join_requested.connect(_join)
	home.profile_changed.connect(_profile_changed)
	home.menu_requested.connect(open_menu)
	add_child(home)
	descent = DescentScreen.new()
	descent.command.connect(func(cmd: Dictionary) -> void: session.send(cmd))
	descent.home_requested.connect(_back_home)
	descent.menu_requested.connect(open_menu)
	descent.visible = false
	add_child(descent)
	menu = GameMenu.new()
	menu.settings_changed.connect(_apply_settings)
	menu.closed.connect(_menu_closed)
	menu.abandon_requested.connect(func() -> void: session.send({"kind": "abandon"}))
	menu.leave_requested.connect(_leave_party)
	menu.quit_requested.connect(_quit)
	add_child(menu)
	_apply_settings(true)
	_toasts = VBoxContainer.new()
	_toasts.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM, Control.PRESET_MODE_MINSIZE, 40)
	_toasts.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_toasts.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_toasts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toasts.alignment = BoxContainer.ALIGNMENT_CENTER
	_toasts.add_theme_constant_override("separation", 6)
	_toasts.z_index = 100
	add_child(_toasts)
	session.start_local(member())
	var checkpoint: Dictionary = saves.load_checkpoint()
	if bool(checkpoint.get("ok", false)):
		session.resume_run(checkpoint.run, checkpoint.lobby)
	else:
		_refresh_home()
	_prewarm.call_deferred()

func _prewarm() -> void:
	## The first stone or die ever photographed pays for compiling everything a stone is
	## drawn with. Paying it now, while the workshop is being looked at, keeps it out of the
	## first fight, whose rail shows these very stones and dice.
	for _i in range(3):
		await get_tree().process_frame
	var loadout: Dictionary = member()
	for stone in loadout.rail:
		if stone is Dictionary:
			Thumbs.request(Thumbs.gem_key(stone), "gem", {"stone": stone}, func(_texture: Texture2D) -> void: pass)
	for die in loadout.dice:
		Thumbs.request(Thumbs.die_key(die, 0), "die", {"die": die, "face": 0}, func(_texture: Texture2D) -> void: pass)

func member() -> Dictionary:
	var character_key: String = str(profile.get("current_character", DeepContent.starter_character()))
	var loadout: Dictionary = DeepProfile.loadout(profile, character_key)
	return {"name": str(profile.get("name", "Lapidary")), "character": character_key, "rail": loadout.rail, "dice": loadout.dice, "id": str(profile.get("id", ""))}

func _refresh_home() -> void:
	if home == null:
		return
	home.refresh(profile, session.lobby, session.status, session.is_host, session.local_id, session.can_start(), settings)

func _profile_changed() -> void:
	saves.save_profile(profile)
	var loadout: Dictionary = member()
	session.update_member({"character": loadout.character, "rail": loadout.rail, "dice": loadout.dice})
	_refresh_home()

func _depart(seed_value: int) -> void:
	var loadout: Dictionary = member()
	session.update_member({"character": loadout.character, "rail": loadout.rail, "dice": loadout.dice})
	var result: Dictionary = session.start_run(seed_value)
	if not bool(result.get("ok", false)):
		toast(str(result.get("error", "")), DeepUi.BAD)

func _host(port: int) -> void:
	var result: Dictionary = session.host_lan(member(), port)
	if not bool(result.get("ok", false)):
		toast(str(result.get("error", "")), DeepUi.BAD)
	_refresh_home()

func _join(address: String, port: int) -> void:
	settings.last_address = address
	saves.save_settings(settings)
	var result: Dictionary = session.join_lan(address, member(), port)
	if not bool(result.get("ok", false)):
		toast(str(result.get("error", "")), DeepUi.BAD)
	_refresh_home()

func _on_run_started(state: Dictionary) -> void:
	descent.bind(session.local_id, session.forecast)
	descent.show_state(state)
	home.visible = false
	descent.visible = true

func _on_run_event(event: Dictionary) -> void:
	descent.handle(event)
	descent.show_state(session.run)

func _on_run_ended(results: Dictionary) -> void:
	var applied: Dictionary = DeepProfile.apply_result(profile, results, session.local_id)
	saves.save_profile(profile)
	if not applied.get("unlocked", []).is_empty():
		DeepAudio.play("unlock")
	for unlocked in applied.get("unlocked", []):
		if unlocked.has("character"):
			var character: Dictionary = DeepContent.character(str(unlocked.character))
			var title: String = DeepContent.character_title(str(unlocked.character))
			toast("Unlocked: %s" % title, DeepUi.ACCENT, "person")
			Inspector.announce("A new lapidary", "%s joins the workshop.\n\n%s\n\n%s: %s\nBirthstone: %s" % [title, str(character.get("text", "")),
				str(character.get("passive", {}).get("name", "Passive")), str(character.get("passive", {}).get("text", "")), str(character.get("birthstone", {}).get("name", ""))], "person", DeepUi.ACCENT_HI)
		if unlocked.has("mine"):
			var mine: Dictionary = DeepContent.mine(str(unlocked.mine))
			toast("Unlocked: %s" % str(mine.get("name", "")), DeepUi.ACCENT, "pick")
			Inspector.announce("A new mine", "%s is open.\n\n%s" % [str(mine.get("name", "")), str(mine.get("text", ""))], "pick", DeepUi.ACCENT_HI)
	descent.show_state(session.run)

func _back_home() -> void:
	session.leave_run()
	descent.visible = false
	home.visible = true
	home.open("appraise" if not profile.get("tray", []).is_empty() else "map")
	_refresh_home()

func toast(text: String, color: Color, glyph: String = "") -> void:
	DeepAudio.play("toast_bad" if color == DeepUi.BAD else "toast", {"volume": 0.7})
	while _toasts.get_child_count() >= 3:
		var oldest: Node = _toasts.get_child(0)
		_toasts.remove_child(oldest)
		oldest.queue_free()
	var box := PanelContainer.new()
	var style := DeepUi.raised(Color(0.04, 0.05, 0.07, 0.94), Color(color, 0.6), 18, 8, 0.5)
	style.content_margin_left = 14
	style.content_margin_right = 16
	box.add_theme_stylebox_override("panel", style)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toasts.add_child(box)
	var row := DeepUi.hbox(box, 8)
	if glyph.is_empty():
		glyph = "cross_out" if color == DeepUi.BAD else "spark"
	DeepUi.icon(row, glyph, 18, color)
	DeepUi.label(row, text, 15, color)
	DeepUi.pop_in(box, 0.0, 0.8)
	var tween := box.create_tween()
	tween.tween_property(box, "modulate:a", 0.0, 0.6).set_delay(2.6)
	tween.tween_callback(box.queue_free)

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	match event.keycode:
		KEY_F:
			session.speed = 4.0 if session.speed < 2.0 else maxf(1.0, float(settings.get("speed", 1.0)))
			DeepAudio.play("ui_toggle")
			toast("Speed ×%d" % int(session.speed), DeepUi.MUTED, "hourglass")
		KEY_ESCAPE:
			if not Inspector.is_open():
				open_menu()
				get_viewport().set_input_as_handled()

# --- the menu and the settings -----------------------------------------------------------------

func open_menu() -> void:
	if menu.is_open():
		return
	var in_run: bool = session.in_run() and descent.visible
	var solo: bool = session.status == "local"
	menu.open(settings, {"in_run": in_run, "host": session.is_host, "solo": solo, "phase": str(session.run.get("phase", "")),
		"depth": int(session.run.get("depth", 0)), "mine": str(DeepContent.mine(str(session.run.get("mine", ""))).get("name", "The mine"))})
	## Alone, the dig waits for you; with a party it cannot.
	if in_run and solo:
		session.paused = true

func _menu_closed() -> void:
	session.paused = false
	saves.save_settings(settings)

func _apply_settings(starting: bool = false) -> void:
	## Take up the settings: at start, and whenever the menu changes one.
	DeepAudio.levels(settings)
	CameraRig.comfort = clampf(float(settings.get("shake", 1.0)), 0.0, 1.0)
	ScreenFx.calm = bool(settings.get("reduced_motion", false))
	BattleScreen.quality_pref = int(settings.get("quality", 0))
	session.speed = maxf(1.0, float(settings.get("speed", 1.0)))
	descent.apply_quality()
	if DisplayServer.get_name() == "headless":
		return
	var window: Window = get_window()
	var fullscreen: bool = bool(settings.get("fullscreen", false))
	var is_full: bool = window.mode in [Window.MODE_FULLSCREEN, Window.MODE_EXCLUSIVE_FULLSCREEN]
	if fullscreen != is_full and (not starting or fullscreen):
		window.mode = Window.MODE_FULLSCREEN if fullscreen else Window.MODE_WINDOWED
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if bool(settings.get("vsync", true)) else DisplayServer.VSYNC_DISABLED)

func _leave_party() -> void:
	## A guest walking away: back to a workshop of their own.
	session.start_local(member())
	descent.visible = false
	home.visible = true
	home.open("map")
	_refresh_home()

func _quit() -> void:
	saves.save_settings(settings)
	get_tree().quit()
