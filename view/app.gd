extends Control
## The application shell: owns the profile, the settings, the session and the screens.

const HomeScreen = preload("res://view/home/home_screen.gd")
const DescentScreen = preload("res://view/run/descent_screen.gd")

var saves: DeepSaveStore
var settings: Dictionary = {}
var profile: Dictionary = {}
var session: DeepSession
var home: Control
var descent: Control
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
	profile = saves.load_profile()
	if profile.is_empty():
		profile = DeepProfile.new_profile(str(settings.get("player_name", "Lapidary")))
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
	add_child(home)
	descent = DescentScreen.new()
	descent.command.connect(func(cmd: Dictionary) -> void: session.send(cmd))
	descent.home_requested.connect(_back_home)
	descent.visible = false
	add_child(descent)
	_toasts = VBoxContainer.new()
	_toasts.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM, Control.PRESET_MODE_MINSIZE, 40)
	_toasts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toasts.alignment = BoxContainer.ALIGNMENT_CENTER
	_toasts.z_index = 100
	add_child(_toasts)
	session.start_local(member())
	var checkpoint: Dictionary = saves.load_checkpoint()
	if bool(checkpoint.get("ok", false)):
		session.resume_run(checkpoint.run, checkpoint.lobby)
	else:
		_refresh_home()

func member() -> Dictionary:
	var setting_key: String = str(profile.get("current_setting", DeepContent.starter_setting()))
	var loadout: Dictionary = DeepProfile.loadout(profile, setting_key)
	return {"name": str(profile.get("name", "Lapidary")), "setting": setting_key, "rail": loadout.rail, "dice": loadout.dice, "id": str(profile.get("id", ""))}

func _refresh_home() -> void:
	if home == null:
		return
	home.refresh(profile, session.lobby, session.status, session.is_host, session.local_id, session.can_start(), settings)

func _profile_changed() -> void:
	saves.save_profile(profile)
	var loadout: Dictionary = member()
	session.update_member({"setting": loadout.setting, "rail": loadout.rail, "dice": loadout.dice})
	_refresh_home()

func _depart(seed_value: int) -> void:
	var loadout: Dictionary = member()
	session.update_member({"setting": loadout.setting, "rail": loadout.rail, "dice": loadout.dice})
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
	for unlocked in applied.get("unlocked", []):
		if unlocked.has("setting"):
			toast("Unlocked: the %s" % str(DeepContent.setting(str(unlocked.setting)).get("name", "")), DeepUi.ACCENT)
		if unlocked.has("mine"):
			toast("Unlocked: %s" % str(DeepContent.mine(str(unlocked.mine)).get("name", "")), DeepUi.ACCENT)
	descent.show_state(session.run)

func _back_home() -> void:
	session.leave_run()
	descent.visible = false
	home.visible = true
	home.open("appraise" if not profile.get("tray", []).is_empty() else "map")
	_refresh_home()

func toast(text: String, color: Color) -> void:
	var label := DeepUi.label(_toasts, text, 15, color, HORIZONTAL_ALIGNMENT_CENTER)
	label.add_theme_color_override("font_outline_color", DeepUi.INK)
	label.add_theme_constant_override("outline_size", 4)
	var tween := create_tween()
	tween.tween_property(label, "modulate:a", 0.0, 0.6).set_delay(2.6)
	tween.tween_callback(label.queue_free)

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F:
		session.speed = 4.0 if session.speed < 2.0 else 1.0
		toast("Speed ×%d" % int(session.speed), DeepUi.MUTED)
