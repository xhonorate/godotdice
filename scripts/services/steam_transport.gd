class_name SteamMessagesTransport
extends Node

## GodotSteam GDExtension 4.22.1, Steamworks 1.65. IDs remain decimal strings.
signal packet_received(peer_id: String, bytes: PackedByteArray)
signal peer_connected(peer_id: String)
signal peer_disconnected(peer_id: String)
signal connected
signal failed(message: String)
signal lobby_created(lobby_id: String)
signal lobby_entered(lobby_id: String, host_id: String)
signal invite_received(lobby_id: String)

const CHANNEL := 0
const SEND_RELIABLE := 8
const APP_ID_SETTING := "steam/initialization/app_data/app_id"
var steam: Object
var available := false
var local_id := ""
var lobby_id := ""
var expected_members := {}
var reserved_members := {}
var _creating := false

func initialize() -> Dictionary:
	if available:
		return {"ok": true}
	if not Engine.has_singleton("Steam"):
		return {"ok": false, "error": "Steam integration is unavailable. Offline and LAN play are available."}
	steam = Engine.get_singleton("Steam")
	for method in ["steamInitEx", "sendMessageToUser", "receiveMessagesOnChannel", "createLobby", "run_callbacks"]:
		if not steam.has_method(method):
			return {"ok": false, "error": "The installed Steam extension is incompatible. This build requires GodotSteam 4.22.1."}
	var app_id := int(ProjectSettings.get_setting(APP_ID_SETTING, 480))
	var initialized: Dictionary = steam.call("steamInitEx", app_id, false)
	if int(initialized.get("status", -1)) != 0:
		return {"ok": false, "error": "Steam could not initialize: %s. Start the Steam client, or choose offline/LAN play." % initialized.get("verbal", "unknown error")}
	local_id = str(steam.call("getSteamID"))
	available = true
	_connect("lobby_created", _on_lobby_created)
	_connect("lobby_joined", _on_lobby_joined)
	_connect("lobby_chat_update", _on_lobby_chat_update)
	_connect("network_messages_session_request", _on_session_request)
	_connect("network_messages_session_failed", _on_session_failed)
	_connect("join_requested", _on_join_requested)
	return {"ok": true, "player_id": local_id}

func _connect(signal_name: String, callback: Callable) -> void:
	if steam.has_signal(signal_name) and not steam.is_connected(signal_name, callback):
		steam.connect(signal_name, callback)

func host() -> void:
	_creating = true
	steam.call("createLobby", 1, 4) # friends only

func join(id: String) -> void:
	if not id.is_valid_int() or int(id) <= 0:
		failed.emit("Enter a valid Steam lobby ID.")
		return
	_creating = false
	steam.call("joinLobby", int(id))

func send(peer_id: String, bytes: PackedByteArray) -> Error:
	if not available or not peer_id.is_valid_int():
		return ERR_UNAVAILABLE
	var result := int(steam.call("sendMessageToUser", int(peer_id), bytes, SEND_RELIABLE, CHANNEL))
	return OK if result == 1 else ERR_CONNECTION_ERROR

func set_metadata(metadata: Dictionary) -> void:
	if not available or lobby_id.is_empty():
		return
	for key in metadata:
		steam.call("setLobbyData", int(lobby_id), str(key), str(metadata[key]))

func set_joinable(value: bool) -> void:
	if available and not lobby_id.is_empty():
		steam.call("setLobbyJoinable", int(lobby_id), value)

func invite_friends() -> void:
	if available and not lobby_id.is_empty():
		steam.call("activateGameOverlayInviteDialog", int(lobby_id))

func _process(_delta: float) -> void:
	if not available:
		return
	steam.call("run_callbacks")
	var messages: Array = steam.call("receiveMessagesOnChannel", CHANNEL, 128)
	for message in messages:
		var sender := str(message.get("identity", ""))
		if not expected_members.has(sender) and not reserved_members.has(sender):
			continue
		var payload: PackedByteArray = message.get("payload", PackedByteArray())
		packet_received.emit(sender, payload)

func _on_lobby_created(result: int, id: int) -> void:
	if result != 1:
		failed.emit("Steam could not create the lobby (error %d)." % result)
		return
	lobby_id = str(id)
	_refresh_members()
	lobby_created.emit(lobby_id)

func _on_lobby_joined(id: int, _permissions: int, _locked: bool, response: int) -> void:
	if response != 1:
		failed.emit("Steam could not join that lobby (error %d)." % response)
		return
	lobby_id = str(id)
	_refresh_members()
	if not _creating:
		lobby_entered.emit(lobby_id, str(steam.call("getLobbyOwner", id)))
	connected.emit()

func _refresh_members() -> void:
	expected_members.clear()
	if lobby_id.is_empty():
		return
	var count := int(steam.call("getNumLobbyMembers", int(lobby_id)))
	for index in count:
		expected_members[str(steam.call("getLobbyMemberByIndex", int(lobby_id), index))] = true

func _on_lobby_chat_update(id: int, changed: int, _making_change: int, change: int) -> void:
	if str(id) != lobby_id:
		return
	_refresh_members()
	if change & 1:
		peer_connected.emit(str(changed))
	else:
		peer_disconnected.emit(str(changed))

func _on_session_request(remote_id: int) -> void:
	_refresh_members()
	var id := str(remote_id)
	if expected_members.has(id) or reserved_members.has(id):
		steam.call("acceptSessionWithUser", remote_id)

func _on_session_failed(_reason: int, remote_id: int, _connection_state: int, _debug_message: String) -> void:
	peer_disconnected.emit(str(remote_id))

func _on_join_requested(id: int, _friend_id: int) -> void:
	invite_received.emit(str(id))

func disconnect_peer(peer_id: String) -> void:
	if available and peer_id.is_valid_int():
		steam.call("closeSessionWithUser", int(peer_id))

func close() -> void:
	if available:
		for id in expected_members:
			if id != local_id:
				steam.call("closeSessionWithUser", int(id))
		if not lobby_id.is_empty():
			steam.call("leaveLobby", int(lobby_id))
	lobby_id = ""
	expected_members.clear()
	reserved_members.clear()

func _exit_tree() -> void:
	close()
