class_name SteamMessagesTransport
extends Node
## The release transport: a Steam lobby says who is in the party, Steam Networking Messages
## carry the packets. Friends find the lobby through the overlay's invite list, the friends
## list or its ID; only its members are listened to. Packets go reliable and in order on
## one channel, and one too big for a Steam message is cut into parts and put back together
## on arrival, so the session never learns which transport it is talking to.
##
## Steam comes up with the game (`initialize_on_startup`), before the renderer, which is what
## lets the overlay hook it. If the client was not running then, the first Host or Join
## brings it up instead: lobbies work, the overlay waits for a restart.
##
## GodotSteam GDExtension 4.22.1, Steamworks 1.65. Steam IDs travel as decimal strings.

signal packet_received(peer_id: String, bytes: PackedByteArray)
signal peer_connected(peer_id: String)
signal peer_disconnected(peer_id: String)
signal connected
signal failed(message: String)
signal lobby_created(lobby_id: String)

const Codec = preload("res://net/packet_codec.gd")
const APP_ID_SETTING: String = "steam/initialization/app_data/app_id"
const CHANNEL: int = 0
## k_nSteamNetworkingSend_Reliable | k_nSteamNetworkingSend_AutoRestartBrokenSession.
const SEND_FLAGS: int = 8 | 32
const LOBBY_FRIENDS_ONLY: int = 1
const MAX_MEMBERS: int = 4
const RESULT_OK: int = 1
const CHAT_ENTERED: int = 1
## Steam refuses a message over 512 KiB, and a run's opening state can outgrow that.
const PART_BYTES: int = 256 * 1024
## Every message starts with one byte: the whole packet, a part with more to come, the last part.
const WHOLE: int = 0
const PART: int = 1
const LAST: int = 2
const REQUIRED: Array = ["steamInitEx", "get_steam_init_result", "getSteamID", "loggedOn", "run_callbacks", "createLobby", "joinLobby", "leaveLobby",
	"getLobbyOwner", "getNumLobbyMembers", "getLobbyMemberByIndex", "sendMessageToUser", "receiveMessagesOnChannel", "acceptSessionWithUser",
	"closeSessionWithUser", "isOverlayEnabled", "activateGameOverlayInviteDialog"]

static var _started: bool = false
static var _pumped_frame: int = -1

var steam: Object = null
var local_id: String = ""
var lobby_id: String = ""
## Who the session sends its commands to: the lobby's owner, as it was when we walked in.
var host_peer_id: String = ""
var members: Dictionary = {}
var _hosting: bool = false
var _wanted: String = ""
var _parts: Dictionary = {}

# --- Steam itself -------------------------------------------------------------------------------

static func singleton() -> Object:
	return Engine.get_singleton("Steam") if Engine.has_singleton("Steam") else null

static func start() -> Dictionary:
	## Steam, up and running: already, from startup, or now.
	if _started:
		return {"ok": true}
	var api: Object = singleton()
	if api == null:
		return {"ok": false, "error": "Steam is not part of this build. LAN play still works."}
	for method in REQUIRED:
		if not api.has_method(method):
			return {"ok": false, "error": "This build's Steam extension is not GodotSteam 4.22; Steam play is off."}
	var result: Dictionary = api.call("get_steam_init_result")
	if int(result.get("status", -1)) != 0:
		result = api.call("steamInitEx", int(ProjectSettings.get_setting(APP_ID_SETTING, 480)), false)
	if int(result.get("status", -1)) != 0:
		return {"ok": false, "error": "Steam did not start (%s). Open the Steam client, or play over LAN." % str(result.get("verbal", "no answer"))}
	_started = true
	return {"ok": true}

static func live() -> Object:
	## The Steam singleton if Steam is up, without trying to bring it up.
	if not _started:
		var api: Object = singleton()
		if api == null or not api.has_method("get_steam_init_result") or int(api.call("get_steam_init_result").get("status", -1)) != 0:
			return null
		_started = true
	return singleton()

static func pump() -> void:
	## Steam's callbacks become GodotSteam's signals: once a frame, whoever asks first.
	if not _started or Engine.get_process_frames() == _pumped_frame:
		return
	_pumped_frame = Engine.get_process_frames()
	singleton().call("run_callbacks")

static func launch_lobby(args: PackedStringArray) -> String:
	## A friend's invitation accepted while the game was closed: Steam starts it with
	## `+connect_lobby <id>`.
	var index: int = args.find("+connect_lobby")
	if index >= 0 and index + 1 < args.size() and args[index + 1].is_valid_int():
		return args[index + 1]
	return ""

# --- one party ----------------------------------------------------------------------------------

func initialize(stand_in: Object = null) -> Dictionary:
	## Tests hand in a stand-in for the singleton; the game uses Steam itself.
	if stand_in == null:
		var started: Dictionary = start()
		if not bool(started.get("ok", false)):
			return started
	var api: Object = stand_in if stand_in != null else singleton()
	if not bool(api.call("loggedOn")):
		return {"ok": false, "error": "Steam is offline. Go online in the Steam client, or play over LAN."}
	steam = api
	local_id = str(steam.call("getSteamID"))
	for pair in _listening():
		if steam.has_signal(pair[0]) and not steam.is_connected(pair[0], pair[1]):
			steam.connect(pair[0], pair[1])
	return {"ok": true, "player_id": local_id}

func _listening() -> Array:
	return [["lobby_created", _on_lobby_created], ["lobby_joined", _on_lobby_joined], ["lobby_chat_update", _on_lobby_chat_update],
		["network_messages_session_request", _on_session_request], ["network_messages_session_failed", _on_session_failed]]

func host() -> void:
	_hosting = true
	host_peer_id = local_id
	steam.call("createLobby", LOBBY_FRIENDS_ONLY, MAX_MEMBERS)

func join(id: String) -> void:
	if not id.is_valid_int() or int(id) <= 0:
		failed.emit("That is not a Steam lobby ID.")
		return
	_hosting = false
	_wanted = id
	steam.call("joinLobby", int(id))

func invite_friends() -> bool:
	## The overlay's invite list. Without the overlay, the lobby ID is the invitation.
	if steam == null or lobby_id.is_empty() or not bool(steam.call("isOverlayEnabled")):
		return false
	steam.call("activateGameOverlayInviteDialog", int(lobby_id))
	return true

func send(peer_id: String, bytes: PackedByteArray) -> Error:
	if steam == null or not peer_id.is_valid_int() or bytes.is_empty():
		return ERR_UNAVAILABLE
	var offset: int = 0
	while offset < bytes.size():
		var end: int = mini(offset + PART_BYTES, bytes.size())
		var tag: int = WHOLE if offset == 0 and end == bytes.size() else (LAST if end == bytes.size() else PART)
		var message := PackedByteArray([tag])
		message.append_array(bytes.slice(offset, end))
		if int(steam.call("sendMessageToUser", int(peer_id), message, SEND_FLAGS, CHANNEL)) != RESULT_OK:
			return ERR_CONNECTION_ERROR
		offset = end
	return OK

func _process(_delta: float) -> void:
	pump()
	poll()

func poll() -> void:
	## Everything waiting from the party, parts put back together.
	if steam == null:
		return
	var messages: Array = steam.call("receiveMessagesOnChannel", CHANNEL, 128)
	for message in messages:
		var sender: String = str(message.get("identity", ""))
		if not members.has(sender):
			_refresh_members()
			if not members.has(sender):
				continue
		var payload: PackedByteArray = message.get("payload", PackedByteArray())
		if payload.is_empty():
			continue
		var tag: int = payload[0]
		var body: PackedByteArray = payload.slice(1)
		if tag == WHOLE:
			_parts.erase(sender)
			packet_received.emit(sender, body)
			continue
		var so_far: PackedByteArray = _parts.get(sender, PackedByteArray())
		so_far.append_array(body)
		if tag not in [PART, LAST] or so_far.size() > Codec.MAX_PACKET_BYTES:
			_parts.erase(sender)
		elif tag == LAST:
			_parts.erase(sender)
			packet_received.emit(sender, so_far)
		else:
			_parts[sender] = so_far

func _refresh_members() -> void:
	members.clear()
	if steam == null or lobby_id.is_empty():
		return
	for index in int(steam.call("getNumLobbyMembers", int(lobby_id))):
		members[str(steam.call("getLobbyMemberByIndex", int(lobby_id), index))] = true

func _on_lobby_created(result: int, id: int) -> void:
	if not _hosting or not lobby_id.is_empty():
		return
	if result != RESULT_OK:
		failed.emit("Steam could not open a lobby (%s)." % ("no connection to Steam" if result == 3 else "result %d" % result))
		return
	lobby_id = str(id)
	_refresh_members()
	lobby_created.emit(lobby_id)

func _on_lobby_joined(id: int, _permissions: int, _locked: bool, response: int) -> void:
	## Steam says this for the lobby we made as well as the one we asked into.
	if _hosting:
		if str(id) == lobby_id:
			_refresh_members()
		return
	if str(id) != _wanted or not lobby_id.is_empty():
		return
	if response != RESULT_OK:
		failed.emit(_refusal(response))
		return
	lobby_id = str(id)
	host_peer_id = str(steam.call("getLobbyOwner", id))
	_refresh_members()
	connected.emit()

func _refusal(response: int) -> String:
	match response:
		2: return "That Steam lobby is gone."
		4: return "That Steam lobby is full."
		3, 6, 7, 10, 11: return "Steam will not let you into that lobby."
	return "Steam could not join that lobby (response %d)." % response

func _on_lobby_chat_update(id: int, changed: int, _making_change: int, change: int) -> void:
	## Lobby membership is who is here: Steam notices a crashed client and says so.
	if str(id) != lobby_id or str(changed) == local_id:
		return
	_refresh_members()
	if change & CHAT_ENTERED:
		peer_connected.emit(str(changed))
	else:
		_parts.erase(str(changed))
		steam.call("closeSessionWithUser", changed)
		peer_disconnected.emit(str(changed))

func _on_session_request(remote_id: int) -> void:
	_refresh_members()
	if members.has(str(remote_id)):
		steam.call("acceptSessionWithUser", remote_id)

func _on_session_failed(_reason: int, remote_id: int, _state: int, _debug: String) -> void:
	## A dropped connection to someone still in the lobby restarts on the next send; the
	## session notices the gap in revisions and asks for the whole state.
	_parts.erase(str(remote_id))
	_refresh_members()
	if not members.has(str(remote_id)):
		peer_disconnected.emit(str(remote_id))

func disconnect_peer(peer_id: String) -> void:
	if steam != null and peer_id.is_valid_int():
		steam.call("closeSessionWithUser", int(peer_id))

func close() -> void:
	## Leaves the lobby and stops listening; safe to call twice.
	if steam == null:
		return
	for id in members:
		if id != local_id:
			steam.call("closeSessionWithUser", int(id))
	if not lobby_id.is_empty():
		steam.call("leaveLobby", int(lobby_id))
	for pair in _listening():
		if steam.has_signal(pair[0]) and steam.is_connected(pair[0], pair[1]):
			steam.disconnect(pair[0], pair[1])
	steam = null
	lobby_id = ""
	members.clear()
	_parts.clear()

func _exit_tree() -> void:
	close()
