class_name DevelopmentTransport
extends Node

signal packet_received(peer_id: String, bytes: PackedByteArray)
signal peer_connected(peer_id: String)
signal peer_disconnected(peer_id: String)
signal connected
signal failed(message: String)

const CONNECT_TIMEOUT_MS := 15000

var peer: ENetMultiplayerPeer
var is_server := false
var _was_connected := false
var _connect_started := 0
## The peers ENet still has, by id: a kicked guest usually hangs up before the host lets go of it.
var _live: Dictionary = {}
## A host given by name, being looked up off the main thread: the lookup, and the port to join on.
var _resolving: int = IP.RESOLVER_INVALID_ID
var _resolving_port: int = 0

static func connect_timed_out(was_connected: bool, started_ms: int, now_ms: int) -> bool:
	## Only a connection still being made can time out; one that is up stays up, however long
	## the party plays.
	return not was_connected and now_ms - started_ms > CONNECT_TIMEOUT_MS

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
	## An address that is no address at all is turned away here rather than by ENet, which
	## logs an engine error before it gives up on it. The session says why to the player.
	address = address.strip_edges()
	if address.is_empty():
		return ERR_CANT_RESOLVE
	_connect_started = Time.get_ticks_msec()
	if not address.is_valid_ip_address():
		## A name is looked up in the background, so the game does not freeze while it is; the
		## line is opened once it is found (see `_process`), and `failed` says if it is not.
		_resolving = IP.resolve_hostname_queue_item(address)
		if _resolving == IP.RESOLVER_INVALID_ID:
			return ERR_CANT_RESOLVE
		_resolving_port = port
		return OK
	return _open(address, port)

func _open(address: String, port: int) -> Error:
	peer = ENetMultiplayerPeer.new()
	var result := peer.create_client(address, port, 1)
	if result != OK:
		peer = null
		return result
	_bind()
	return OK

func _poll_lookup() -> void:
	var status := IP.get_resolve_item_status(_resolving)
	if status == IP.RESOLVER_STATUS_WAITING:
		if connect_timed_out(false, _connect_started, Time.get_ticks_msec()):
			_drop_lookup()
			failed.emit("Connection timed out. Check the host address and UDP port.")
		return
	var found: String = IP.get_resolve_item_address(_resolving) if status == IP.RESOLVER_STATUS_DONE else ""
	_drop_lookup()
	if found.is_empty() or _open(found, _resolving_port) != OK:
		failed.emit("Could not find that host. Check its address.")

func _drop_lookup() -> void:
	if _resolving != IP.RESOLVER_INVALID_ID:
		IP.erase_resolve_item(_resolving)
	_resolving = IP.RESOLVER_INVALID_ID

func _bind() -> void:
	peer.peer_connected.connect(func(id: int):
		_live[id] = true
		peer_connected.emit(str(id)))
	peer.peer_disconnected.connect(func(id: int):
		_live.erase(id)
		peer_disconnected.emit(str(id)))
	peer.transfer_mode = MultiplayerPeer.TRANSFER_MODE_RELIABLE
	peer.transfer_channel = 0
	# Raw packets only; never expose RPCs or Variant object decoding to peers.
	peer.refuse_new_connections = false

func _process(_delta: float) -> void:
	if _resolving != IP.RESOLVER_INVALID_ID:
		_poll_lookup()
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
		elif connect_timed_out(_was_connected, _connect_started, Time.get_ticks_msec()):
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
	## Told it was kicked, a guest hangs up on its own, and by the time the host's moment of
	## grace is over ENet has already let it go: asking it to drop a peer it no longer has is
	## an engine error.
	if peer != null and _live.has(int(peer_id)):
		peer.disconnect_peer(int(peer_id))

func close() -> void:
	_drop_lookup()
	if peer != null:
		## Closing throws away whatever is still queued, and the last thing queued is usually
		## the one worth hearing: the host closing the party, a guest saying goodbye.
		## A connection that has already dropped has no host left to flush, and asking for it
		## is an engine error.
		if peer.get_connection_status() != MultiplayerPeer.CONNECTION_DISCONNECTED and peer.host != null:
			peer.host.flush()
		peer.close()
	peer = null
	is_server = false
	_was_connected = false
	_live.clear()

func _exit_tree() -> void:
	close()
