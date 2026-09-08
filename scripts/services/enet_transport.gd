class_name DevelopmentTransport
extends Node

signal packet_received(peer_id: String, bytes: PackedByteArray)
signal peer_connected(peer_id: String)
signal peer_disconnected(peer_id: String)
signal connected
signal failed(message: String)

var peer: ENetMultiplayerPeer
var is_server := false
var _was_connected := false
var _connect_started := 0

func host(port: int = 24567) -> Error:
	close()
	peer = ENetMultiplayerPeer.new()
	var result := peer.create_server(port, 3, 1)
	if result != OK:
		peer = null
		return result
	is_server = true
	_bind()
	return OK

func join(address: String, port: int = 24567) -> Error:
	close()
	peer = ENetMultiplayerPeer.new()
	var result := peer.create_client(address, port, 1)
	if result != OK:
		peer = null
		return result
	_connect_started = Time.get_ticks_msec()
	_bind()
	return OK

func _bind() -> void:
	peer.peer_connected.connect(func(id: int): peer_connected.emit(str(id)))
	peer.peer_disconnected.connect(func(id: int): peer_disconnected.emit(str(id)))
	peer.transfer_mode = MultiplayerPeer.TRANSFER_MODE_RELIABLE
	peer.transfer_channel = 0
	# Raw packets only; never expose RPCs or Variant object decoding to peers.
	peer.refuse_new_connections = false

func _process(_delta: float) -> void:
	if peer == null:
		return
	peer.poll()
	var status := peer.get_connection_status()
	if not is_server:
		if status == MultiplayerPeer.CONNECTION_CONNECTED and not _was_connected:
			_was_connected = true
			connected.emit()
		elif status == MultiplayerPeer.CONNECTION_DISCONNECTED:
			if _was_connected:
				peer_disconnected.emit("1")
			else:
				failed.emit("Could not connect to that host. Check its address and UDP port.")
			close()
			return
		elif Time.get_ticks_msec() - _connect_started > 15000:
			failed.emit("Connection timed out. Check the host address and UDP port.")
			close()
			return
	var budget := 128
	while peer != null and peer.get_available_packet_count() > 0 and budget > 0:
		var sender := str(peer.get_packet_peer())
		var bytes := peer.get_packet()
		packet_received.emit(sender, bytes)
		budget -= 1

func send(peer_id: String, bytes: PackedByteArray) -> Error:
	if peer == null or peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
		return ERR_UNAVAILABLE
	var endpoint := peer.get_peer(int(peer_id))
	if endpoint == null or endpoint.get_state() != ENetPacketPeer.STATE_CONNECTED:
		return ERR_UNAVAILABLE
	peer.set_target_peer(int(peer_id))
	return peer.put_packet(bytes)

func disconnect_peer(peer_id: String) -> void:
	if peer != null:
		peer.disconnect_peer(int(peer_id))

func close() -> void:
	if peer != null:
		peer.close()
	peer = null
	is_server = false
	_was_connected = false

func _exit_tree() -> void:
	close()
