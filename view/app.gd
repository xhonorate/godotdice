extends Control
## The application shell: owns the profile, the settings, the session and the screens.

const HomeScreen = preload("res://view/home/home_screen.gd")
const DescentScreen = preload("res://view/run/descent_screen.gd")
const Thumbs = preload("res://view/gems/thumbs.gd")
const GemMesh = preload("res://view/gems/gem_mesh.gd")
const Inspector = preload("res://view/inspect/inspector.gd")
const GameMenu = preload("res://view/menu/game_menu.gd")
const MineStage = preload("res://view/run/mine_stage.gd")
const CameraRig = preload("res://view/battle/camera_rig.gd")
const ScreenFx = preload("res://view/battle/screen_fx.gd")
const Looks = preload("res://view/battle/looks.gd")

var saves: DeepSaveStore
var settings: Dictionary = {}
var profile: Dictionary = {}
var session: DeepSession
var home: Control
var descent: Control
var menu: CanvasLayer
var _toasts: VBoxContainer
## How this lapidary reached the party they are in as a guest ({kind, address, port} or
## {kind, lobby}): the way back to its run if the game closes under them (`_offer_rejoin`).
var _joined: Dictionary = {}
## How long the fight has been won, in fight time, so the rail running out waits for the blow that won it.
var _won_for: float = 0.0
const WON_BEAT: float = 1.6

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	## Every stone's etch is worked out in the background before anyone opens the vault.
	if not Thumbs.headless():
		GemMesh.warm_etches()
	theme = DeepUi.theme()
	var backdrop := ColorRect.new()
	backdrop.color = DeepUi.INK
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backdrop)
	saves = DeepSaveStore.new()
	settings = saves.load_settings()
	DeepAudio.start(self, settings)
	DeepMusic.start(self, settings)
	profile = saves.load_profile()
	if profile.is_empty():
		profile = DeepProfile.new_profile(str(settings.get("player_name", DeepProfile.DEFAULT_NAME)))
		saves.save_profile(profile)
	elif profile.has("settings") or not profile.has("characters"):
		## A profile from before characters: its settings become characters, its vault stays.
		profile = DeepProfile.migrate(profile)
		saves.save_profile(profile)
	var upgraded: bool = DeepProfile.upgrade(profile)
	if DeepProfile.tidy(profile) or upgraded or DeepEconomy.roll_day(profile):
		saves.save_profile(profile)
	Inspector.vault = profile.get("vault", {})
	session = DeepSession.new()
	session.saves = saves
	session.speed = float(settings.get("speed", 1.0))
	add_child(session)
	session.lobby_changed.connect(func(_lobby: Dictionary) -> void: _refresh_home())
	session.status_changed.connect(func(_status: String) -> void: _refresh_home())
	session.run_started.connect(_on_run_started)
	session.run_event.connect(_on_run_event)
	session.run_ended.connect(_on_run_ended)
	session.refused.connect(func(message: String) -> void:
		toast(message, DeepUi.BAD)
		if descent != null and descent.visible:
			descent.refused())
	session.error.connect(func(message: String) -> void: toast(message, DeepUi.BAD))
	session.invited.connect(_on_invited)
	session.claimed.connect(_on_claimed)
	session.removed.connect(func(message: String) -> void:
		toast(message, DeepUi.MUTED, "party")
		_leave_party.call_deferred())
	home = HomeScreen.new()
	home.depart_requested.connect(_depart)
	home.member_changed.connect(func(fields: Dictionary) -> void: session.update_member(fields))
	home.mine_chosen.connect(func(mine: String) -> void: session.choose_mine(mine))
	home.host_requested.connect(_host)
	home.join_requested.connect(_join)
	home.steam_host_requested.connect(_host_steam)
	home.steam_join_requested.connect(_join_steam)
	home.invite_requested.connect(_invite)
	home.kick_requested.connect(func(id: String) -> void:
		if session.kick(id):
			toast("They are back in their own workshop.", DeepUi.MUTED, "party"))
	home.leave_party_requested.connect(_leave_party)
	home.profile_changed.connect(_profile_changed)
	home.menu_requested.connect(open_menu)
	home.player_name_requested.connect(_edit_player_name)
	add_child(home)
	descent = DescentScreen.new()
	descent.command.connect(func(cmd: Dictionary) -> void: session.send(cmd))
	descent.home_requested.connect(_back_home)
	descent.menu_requested.connect(open_menu)
	descent.visible = false
	add_child(descent)
	menu = GameMenu.new()
	menu.settings_changed.connect(_apply_settings)
	menu.player_name_changed.connect(_rename_player)
	menu.closed.connect(_menu_closed)
	menu.abandon_requested.connect(func() -> void: session.send({"kind": "abandon"}))
	menu.leave_requested.connect(_leave_party)
	menu.join_requested.connect(_join_steam)
	menu.rejoin_requested.connect(_rejoin)
	menu.rejoin_declined.connect(_forget_party_run)
	menu.quit_requested.connect(_quit)
	menu.reopen_requested.connect(_reopen)
	menu.invite_requested.connect(_invite)
	## The menu's word on the party follows the line as it opens and as the party comes back.
	session.status_changed.connect(func(_status: String) -> void:
		if menu.is_open():
			menu.reshow(_menu_context()))
	session.run_event.connect(func(event: Dictionary) -> void:
		if menu.is_open() and str(event.get("kind", "")) == "presence":
			menu.reshow(_menu_context()))
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
	## Started by Steam to answer a friend's invitation.
	var invited_to: String = SteamMessagesTransport.launch_lobby(OS.get_cmdline_args() + OS.get_cmdline_user_args())
	if not invited_to.is_empty():
		_on_invited.call_deferred(invited_to)
	elif not bool(checkpoint.get("ok", false)) and not settings.get("party_run", {}).is_empty():
		_offer_rejoin.call_deferred()

func _prewarm() -> void:
	## The first stone or die ever photographed pays for compiling everything a stone is
	## drawn with. Paying it now, while the workshop is being looked at, keeps it out of the
	## first fight, whose rail shows these very stones and dice.
	for _i in range(3):
		await get_tree().process_frame
	descent.warm_up()
	var loadout: Dictionary = member()
	for stone in loadout.rail:
		if stone is Dictionary:
			Thumbs.request(Thumbs.gem_key(stone), "gem", {"stone": stone}, func(_texture: Texture2D) -> void: pass)
	for die in loadout.dice:
		Thumbs.request(Thumbs.die_key(die, 0), "die", {"die": die, "face": 0}, func(_texture: Texture2D) -> void: pass)

func member() -> Dictionary:
	var character_key: String = str(profile.get("current_character", DeepContent.starter_character()))
	var loadout: Dictionary = DeepProfile.loadout(profile, character_key)
	## The last run's depth and ending decide the Grubstake: a lapidary who fell early is
	## shown mercy.
	var history: Array = profile.get("history", [])
	var last: Dictionary = history[history.size() - 1] if not history.is_empty() else {}
	return {"name": str(profile.get("name", DeepProfile.DEFAULT_NAME)), "character": character_key, "rail": loadout.rail, "dice": loadout.dice, "id": str(profile.get("id", "")),
		"last_depth": int(last.get("depth", 0)), "last_outcome": str(last.get("outcome", "")),
		"gold": int(profile.get("gold", 0)), "insured": bool(profile.get("outfit", {}).get("insure", false)), "sockets": DeepProfile.open_sockets(profile, character_key)}

func _kit(loadout: Dictionary) -> Dictionary:
	## What the lobby is told whenever the profile changes: who goes down, wearing what, and
	## whether they can pay their own way.
	var fields: Dictionary = {}
	for key in ["character", "rail", "dice", "gold", "insured", "sockets"]:
		fields[key] = loadout[key]
	return fields

func _refresh_home() -> void:
	if home == null:
		return
	## A workshop left open past midnight (UTC) turns over to the new day's commissions.
	if DeepEconomy.roll_day(profile):
		saves.save_profile(profile)
	home.refresh(profile, session.lobby, session.status, session.is_host, session.local_id, session.can_start(), settings, session.invite_code)

func _profile_changed() -> void:
	saves.save_profile(profile)
	Inspector.vault = profile.get("vault", {})
	session.update_member(_kit(member()))
	_refresh_home()

func _depart(seed_value: int) -> void:
	session.update_member(_kit(member()))
	var result: Dictionary = session.start_run(seed_value)
	if not bool(result.get("ok", false)):
		toast(str(result.get("error", "")), DeepUi.BAD)

func _host(port: int) -> void:
	_joined = {}
	var result: Dictionary = session.host_lan(member(), port)
	if not bool(result.get("ok", false)):
		toast(str(result.get("error", "")), DeepUi.BAD)
	_refresh_home()

func _join(address: String, port: int) -> void:
	settings.last_address = address
	saves.save_settings(settings)
	_joined = {"kind": "lan", "address": address, "port": port}
	var result: Dictionary = session.join_lan(address, member(), port)
	if not bool(result.get("ok", false)):
		toast(str(result.get("error", "")), DeepUi.BAD)
	_refresh_home()

func _host_steam() -> void:
	_joined = {}
	var result: Dictionary = session.host_steam(member())
	if not bool(result.get("ok", false)):
		toast(str(result.get("error", "")), DeepUi.BAD)
	_refresh_home()

func _join_steam(lobby_id: String) -> void:
	var result: Dictionary = session.join_steam(lobby_id, member())
	if not bool(result.get("ok", false)):
		toast(str(result.get("error", "")), DeepUi.BAD)
		return
	_joined = {"kind": "steam", "lobby": lobby_id.strip_edges()}
	descent.visible = false
	home.visible = true
	home.open("map")
	_refresh_home()

func _invite() -> void:
	## Without the overlay (a run from the editor, or Steam started after the game), the
	## lobby ID on the clipboard is the invitation.
	if session.invite_friends():
		return
	DisplayServer.clipboard_set(session.invite_code)
	toast("No Steam overlay: the lobby ID is on your clipboard for a friend to paste into Join.", DeepUi.MUTED, "copy")

func _on_invited(lobby_id: String) -> void:
	## A Steam invitation accepted. From the workshop it simply joins; from a run it asks first.
	if session.in_run() and descent.visible:
		open_menu()
		menu.ask_to_join(lobby_id)
	else:
		_join_steam(lobby_id)

func _on_run_started(state: Dictionary) -> void:
	## Each lapidary pays their own way down, once, as the run reaches them.
	var paid: Dictionary = DeepEconomy.charge_departure(profile, state, session.local_id)
	if not paid.is_empty():
		saves.save_profile(profile)
		if int(paid.get("paid", 0)) > 0:
			toast("Paid %d gold for the way down" % int(paid.paid), DeepUi.ACCENT, "coin")
	descent.bind(session.local_id, session.forecast)
	descent.show_state(state)
	home.visible = false
	descent.visible = true
	## A guest's run is noted with the way back to it, so a game that closes under them can
	## offer to rejoin when it starts again.
	if not session.is_host and not _joined.is_empty():
		var host: Dictionary = session.lobby.get("members", {}).get(str(session.lobby.get("host", "")), {})
		var record: Dictionary = _joined.duplicate()
		record.merge({"host": str(host.get("name", "")), "mine": str(state.get("mine", ""))}, true)
		if settings.get("party_run", {}) != record:
			settings.party_run = record
			saves.save_settings(settings)

func _on_run_event(event: Dictionary) -> void:
	descent.handle(event)
	descent.show_state(session.run)

func _process(delta: float) -> void:
	if DeepMusic.service() != null:
		## The music follows the party: the workshop, or the mine they are in and what is
		## happening there. The mine picked on the map is written before anyone descends.
		var run: Dictionary = session.run if session.in_run() and descent.visible else {}
		DeepMusic.follow(DeepMusic.where_now(run, str(session.lobby.get("mine", ""))))
	## A locked-in turn plays at the fight speed, bolts, numbers and all; everything else,
	## planning included, runs at 1×.
	var resolving: bool = session.in_run() and DeepDescent.in_battle(session.run) and str(DeepDescent.battle(session.run).get("phase", "")) == "resolving"
	## The host's clock paces every step of a turn, so a guest plays it at the host's speed.
	var pace: float = session.speed if session.is_host else session.host_speed
	var want: float = clampf(pace, 1.0, 8.0) if resolving and not session.paused else 1.0
	## With the last creature down, what is left of the rail runs out at three times the pace.
	## It waits out a beat first: the blow that won the fight (a gem landing twenty times over)
	## is still being thrown when the state says everything is dead, and speeding that up
	## turned the finisher into a blur.
	if resolving and not session.paused and DeepBattle.living(DeepDescent.battle(session.run).get("enemies", [])).is_empty():
		_won_for += delta
		if _won_for > WON_BEAT:
			want = clampf(want * 3.0, 3.0, 8.0)
	else:
		_won_for = 0.0
	## A heavy blow holds the clock for a beat; the last one of a fight runs in slow motion.
	## Whatever speed the fight is played at, a held beat is held.
	var warp: float = ScreenFx.time_warp()
	if warp < 1.0:
		want = minf(want, warp)
	if not is_equal_approx(Engine.time_scale, want):
		Engine.time_scale = want

func _exit_tree() -> void:
	Engine.time_scale = 1.0
	GemMesh.finish_warm()

func _on_run_ended(results: Dictionary) -> void:
	_forget_party_run()
	_take_home(results, session.local_id)
	descent.show_state(session.run)

func _on_claimed(results: Dictionary, player_id: String) -> void:
	## A share of a run this lapidary dropped out of and was not back for the end of, kept by
	## its host until they came back. Taken once: the history knows every run it was handed.
	var run_id: String = str(results.get("run_id", ""))
	if run_id.is_empty() or profile.get("history", []).any(func(h: Dictionary) -> bool: return str(h.get("run_id", "")) == run_id):
		return
	var applied: Dictionary = _take_home(results, player_id)
	## A share of nothing is not worth a word.
	if not applied.get("tray", []).is_empty():
		toast("Your share of a run you dropped out of: %s for the tray." % DeepUi.plural(applied.get("tray", []).size(), "stone"), DeepUi.ACCENT, "bag")
	_refresh_home()

func _take_home(results: Dictionary, player_id: String) -> Dictionary:
	## What a run brought this lapidary, into the profile and said aloud.
	var applied: Dictionary = DeepProfile.apply_result(profile, results, player_id)
	saves.save_profile(profile)
	Inspector.vault = profile.get("vault", {})
	if not applied.get("unlocked", []).is_empty():
		DeepAudio.play("unlock")
	for unlocked in applied.get("unlocked", []):
		if unlocked.has("character"):
			var character: Dictionary = DeepContent.character(str(unlocked.character))
			var title: String = DeepContent.character_title(str(unlocked.character))
			toast("Unlocked: %s" % title, DeepUi.ACCENT, "person")
			Inspector.lapidary(str(unlocked.character))
		if unlocked.has("mine"):
			var mine: Dictionary = DeepContent.mine(str(unlocked.mine))
			toast("Unlocked: %s" % str(mine.get("name", "")), DeepUi.ACCENT, "pick")
			Inspector.announce("A new mine", "%s is open.\n\n%s" % [str(mine.get("name", "")), str(mine.get("text", ""))], "pick", DeepUi.ACCENT_HI)
	for purse in applied.get("purses", []):
		toast("First conquest of %s: +%d gold" % [DeepContent.mine_name(str(purse.mine)), int(purse.gold)], DeepUi.ACCENT, "crown")
	return applied

func _back_home() -> void:
	session.leave_run()
	## The run changed the purse (the fare, the assayer): the party hears what is in it now.
	session.update_member(_kit(member()))
	descent.visible = false
	home.visible = true
	home.open("appraise" if not profile.get("tray", []).is_empty() else "map")
	_refresh_home()

func toast(text: String, color: Color, glyph: String = "") -> void:
	if glyph.is_empty():
		glyph = "cross_out" if color == DeepUi.BAD else "spark"
	## Down the mine the run's own toasts know where the bar along the bottom is.
	if descent != null and descent.visible:
		descent.toast(text, color, glyph)
		return
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
			if not session.is_host and session.in_party():
				toast("In a party, fights play at the host's speed.", DeepUi.MUTED, "hourglass")
				return
			session.speed = 4.0 if session.speed < 2.0 else maxf(1.0, float(settings.get("speed", 1.0)))
			DeepAudio.play("ui_toggle")
			toast("Speed ×%d" % int(session.speed), DeepUi.MUTED, "hourglass")
		KEY_ESCAPE:
			if not Inspector.is_open():
				open_menu()
				get_viewport().set_input_as_handled()

# --- the menu and the settings -----------------------------------------------------------------

func _edit_player_name() -> void:
	open_menu()
	menu.edit_player_name()

func _rename_player(value: String) -> void:
	var player_name: String = value.strip_edges().left(DeepProfile.NAME_LIMIT)
	if player_name.is_empty():
		return
	profile.name = player_name
	settings.player_name = player_name
	saves.save_profile(profile)
	saves.save_settings(settings)
	session.update_member({"name": player_name})
	_refresh_home()

func open_menu() -> void:
	if menu.is_open():
		return
	var context: Dictionary = _menu_context()
	menu.open(settings, context)
	## Alone, the dig waits for you; with a party it cannot.
	if bool(context.in_run) and bool(context.solo):
		session.paused = true

func _menu_context() -> Dictionary:
	var in_run: bool = session.in_run() and descent.visible
	var context: Dictionary = {"in_run": in_run, "host": session.is_host, "solo": session.status == "local", "phase": str(session.run.get("phase", "")),
		"depth": int(session.run.get("depth", 0)), "mine": str(DeepContent.mine(str(session.run.get("mine", ""))).get("name", "The mine")),
		"player_name": str(profile.get("name", DeepProfile.DEFAULT_NAME))}
	## The host of a run with a party in it: who is away, and how they get back to it.
	if in_run and session.is_host and session.run.get("players", []).size() > 1:
		context.party = {"status": session.status, "invite_code": session.invite_code, "away": session.away(),
			"lan": DeepSession.lan_address() if session.status == "hosting" and session.invite_code.is_empty() else ""}
	return context

func _reopen(kind: String) -> void:
	## A party run picked up again from its checkpoint, opened for the party to come back to.
	var result: Dictionary = session.reopen(kind)
	if not bool(result.get("ok", false)):
		toast(str(result.get("error", "")), DeepUi.BAD)
	else:
		## A party can be playing behind the menu now, so the dig no longer waits on it.
		session.paused = false
	menu.reshow(_menu_context())

func _menu_closed() -> void:
	session.paused = false
	saves.save_settings(settings)

func _apply_settings(starting: bool = false) -> void:
	## Take up the settings: at start, and whenever the menu changes one.
	DeepAudio.levels(settings)
	DeepMusic.levels(settings)
	CameraRig.comfort = clampf(float(settings.get("shake", 1.0)), 0.0, 1.0)
	ScreenFx.calm = bool(settings.get("reduced_motion", false))
	MineStage.quality_pref = int(settings.get("quality", 0))
	## The ink the rock is drawn in, and the one pass a weak machine can drop.
	Looks.pref = Looks.HOUSE if bool(settings.get("outlines", true)) else "off"
	session.speed = maxf(1.0, float(settings.get("speed", 1.0)))
	descent.apply_quality()
	descent.apply_look()
	if DisplayServer.get_name() == "headless":
		return
	var window: Window = get_window()
	var fullscreen: bool = bool(settings.get("fullscreen", false))
	var is_full: bool = window.mode in [Window.MODE_FULLSCREEN, Window.MODE_EXCLUSIVE_FULLSCREEN]
	if fullscreen != is_full and (not starting or fullscreen):
		window.mode = Window.MODE_FULLSCREEN if fullscreen else Window.MODE_WINDOWED
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if bool(settings.get("vsync", true)) else DisplayServer.VSYNC_DISABLED)

func _leave_party() -> void:
	## Walking away, as a guest or by closing a party you host: back to a workshop of your own.
	session.leave_party()
	_joined = {}
	_forget_party_run()
	session.start_local(member())
	descent.visible = false
	home.visible = true
	home.open("map")
	_refresh_home()

func _offer_rejoin() -> void:
	## A guest whose game closed in the middle of a party run is asked, as the game starts,
	## whether to go back to it.
	var record: Dictionary = settings.get("party_run", {})
	if record.is_empty() or session.in_run() or menu.is_open():
		return
	open_menu()
	menu.ask_to_rejoin(record)

func _rejoin(record: Dictionary) -> void:
	## Asked once: the run is noted again if it takes this lapidary back.
	_forget_party_run()
	if str(record.get("kind", "")) == "steam":
		_join_steam(str(record.get("lobby", "")))
	else:
		_join(str(record.get("address", "")), int(record.get("port", DeepSession.DEFAULT_PORT)))

func _forget_party_run() -> void:
	if not settings.get("party_run", {}).is_empty():
		settings.party_run = {}
		saves.save_settings(settings)

func _quit() -> void:
	saves.save_settings(settings)
	get_tree().quit()
