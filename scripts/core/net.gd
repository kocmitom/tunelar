extends Node
## LAN lobby: joins the lobby found on the LAN or hosts one, then exchanges per-tick inputs for lockstep matches.
## Every PC runs the same simulation; a tick only advances once the inputs of all slots for it arrived.

signal lobby_changed

const DISCOVERY_PORT := 47801
const GAME_PORT := 47802
const MAX_PLAYERS := 6
const SEARCH_TIME := 1.5
const BROADCAST_INTERVAL := 1.0
const INPUT_DELAY := 2
const IDLE := {"move": Vector2.ZERO, "fire": false}
const GAME_SCENE := "res://scenes/ui/viewport_grid.tscn"
const LOBBY_SCENE := "res://scenes/ui/lobby.tscn"

var version: String = ProjectSettings.get_setting("application/config/version")
var token := randi()
var player_name := OS.get_environment("USERNAME")
var status := "Searching..."
# players[peer_id] = names of that PC's local players.
var players := {}
var local_count := 1
var is_host := false
var in_match := false
var match_seed := 0
# Index into GameManager.MAP_SIZE_NAMES, set by the host for the whole lobby.
var map_size := 1
# One entry per slot, so a PC with two players appears twice.
var slot_peers: Array[int] = []
# Player name per slot, fixed at the match start.
var slot_names: Array = []
var local_slots: Array[int] = []
var sent_tick := 0
# inputs[tick][slot] = {"move": Vector2, "fire": bool}, null until received.
var inputs := {}
var gone_slots := {}
var udp := PacketPeerUDP.new()
var peer: ENetMultiplayerPeer
var search_timer := SEARCH_TIME
var broadcast_timer := 0.0


func _ready() -> void:
	set_process(false)


# Called by every lobby load; only the first call sets up the network.
func start() -> void:
	if is_processing():
		return
	udp.set_broadcast_enabled(true)
	udp.bind(DISCOVERY_PORT)
	udp.set_dest_address("255.255.255.255", DISCOVERY_PORT)
	multiplayer.connected_to_server.connect(_on_connected)
	multiplayer.connection_failed.connect(_leave)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	set_process(true)


func _process(delta: float) -> void:
	while udp.get_available_packet_count() > 0:
		var parts := udp.get_packet().get_string_from_utf8().split(" ")
		var ip := udp.get_packet_ip()
		if parts.size() != 3 or parts[0] != "tunneler" or parts[1] != version or parts[2].to_int() == token:
			continue
		# Two PCs that started together both host; the one with the higher token gives up its empty lobby.
		if peer == null or (is_host and players.size() == 1 and parts[2].to_int() < token):
			_join(ip)

	if peer == null:
		search_timer -= delta
		if search_timer <= 0.0:
			_host()
	elif is_host and not in_match:
		broadcast_timer -= delta
		if broadcast_timer <= 0.0:
			broadcast_timer = BROADCAST_INTERVAL
			udp.put_packet(("tunneler %s %d" % [version, token]).to_utf8_buffer())


func _host() -> void:
	peer = ENetMultiplayerPeer.new()
	# The port is taken when another instance already hosts on this PC.
	if peer.create_server(GAME_PORT, MAX_PLAYERS - 1) != OK:
		_join("127.0.0.1")
		return
	multiplayer.multiplayer_peer = peer
	is_host = true
	players = {1: _names(player_name, local_count)}
	_set_status("Hosting lobby")


func _join(ip: String) -> void:
	_leave()
	peer = ENetMultiplayerPeer.new()
	peer.create_client(ip, GAME_PORT)
	multiplayer.multiplayer_peer = peer
	_set_status("Joining lobby...")


func _leave() -> void:
	if peer:
		peer.close()
	multiplayer.multiplayer_peer = null
	peer = null
	is_host = false
	players = {}
	search_timer = SEARCH_TIME
	_set_status("Searching...")


func _set_status(text: String) -> void:
	status = text
	lobby_changed.emit()


func _on_connected() -> void:
	_set_status("Joined lobby")
	_register.rpc_id(1, player_name, local_count)


func _on_server_disconnected() -> void:
	if not in_match:
		_leave()


func _on_peer_disconnected(id: int) -> void:
	if in_match:
		for slot in slot_peers.size():
			if slot_peers[slot] == id:
				gone_slots[slot] = true
	if is_host:
		players.erase(id)
		_set_players.rpc(players, map_size)


func add_local_player() -> void:
	_register.rpc_id(1, player_name, local_count + 1)


func remove_local_player() -> void:
	_register.rpc_id(1, player_name, local_count - 1)


# Joining and adding/removing local players; the host keeps the lobby at MAX_PLAYERS.
@rpc("any_peer", "call_local", "reliable")
func _register(new_name: String, count: int) -> void:
	var sender := multiplayer.get_remote_sender_id()
	var others: int = slot_order(players).size() - players.get(sender, []).size()
	players[sender] = _names(new_name, mini(maxi(count, 1), MAX_PLAYERS - others))
	_set_players.rpc(players, map_size)


func set_map_size(index: int) -> void:
	_request_map_size.rpc_id(1, index)


@rpc("any_peer", "call_local", "reliable")
func _request_map_size(index: int) -> void:
	map_size = index
	_set_players.rpc(players, map_size)


# Reliable and ahead of _start_match, so every PC starts with the same map size.
@rpc("authority", "call_local", "reliable")
func _set_players(list: Dictionary, size: int) -> void:
	players = list
	map_size = size
	var own: Array = players.get(multiplayer.get_unique_id(), [])
	if not own.is_empty():
		local_count = own.size()
	lobby_changed.emit()


static func _names(base: String, count: int) -> Array:
	var names := []
	for i in count:
		names.append(base if i == 0 else "%s %d" % [base, i + 1])
	return names


# Slots in match order: peers ascending, then each PC's local players.
static func slot_order(list: Dictionary) -> Array[int]:
	var order: Array[int] = []
	var ids := list.keys()
	ids.sort()
	for id in ids:
		for i in list[id].size():
			order.append(id)
	return order


# Player names in slot_order.
static func slot_name_order(list: Dictionary) -> Array:
	var names := []
	var ids := list.keys()
	ids.sort()
	for id in ids:
		names.append_array(list[id])
	return names


func request_start() -> void:
	_request_start.rpc_id(1)


@rpc("any_peer", "call_local", "reliable")
func _request_start() -> void:
	var order := slot_order(players)
	if in_match or order.size() < 2:
		return
	peer.refuse_new_connections = true
	_start_match.rpc(randi(), order, slot_name_order(players))


@rpc("authority", "call_local", "reliable")
func _start_match(new_seed: int, order: Array, names: Array) -> void:
	match_seed = new_seed
	slot_peers.assign(order)
	slot_names = names
	local_slots.clear()
	for slot in slot_peers.size():
		if slot_peers[slot] == multiplayer.get_unique_id():
			local_slots.append(slot)
	reset_inputs()
	in_match = true
	get_tree().change_scene_to_file(GAME_SCENE)


# Anyone can send everyone back to the lobby. Without a host (it left, or a local game) only this PC goes back.
func request_lobby() -> void:
	if peer == null or peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
		_leave()
		_back_to_lobby()
		return
	_request_lobby.rpc_id(1)


@rpc("any_peer", "call_local", "reliable")
func _request_lobby() -> void:
	if not in_match:
		return
	peer.refuse_new_connections = false
	_back_to_lobby.rpc()


@rpc("authority", "call_local", "reliable")
func _back_to_lobby() -> void:
	in_match = false
	get_tree().change_scene_to_file(LOBBY_SCENE)


# The first INPUT_DELAY ticks are idle, so every PC can run them before any input arrives.
func reset_inputs() -> void:
	inputs.clear()
	gone_slots.clear()
	sent_tick = INPUT_DELAY
	for tick in range(1, INPUT_DELAY + 1):
		for slot in slot_peers.size():
			_store(tick, slot, IDLE)


# local_inputs[k] belongs to local_slots[k].
func send_input(tick: int, local_inputs: Array[Dictionary]) -> void:
	sent_tick = tick
	for k in local_slots.size():
		_receive_input.rpc(tick, local_slots[k], local_inputs[k]["move"], local_inputs[k]["fire"])


@rpc("any_peer", "call_local", "reliable")
func _receive_input(tick: int, slot: int, move: Vector2, fire: bool) -> void:
	_store(tick, slot, {"move": move, "fire": fire})


func _store(tick: int, slot: int, input: Dictionary) -> void:
	if not inputs.has(tick):
		var row := []
		row.resize(slot_peers.size())
		inputs[tick] = row
	inputs[tick][slot] = input


# All slots' inputs for the tick, or [] while some are still missing. Disconnected slots stay idle.
func take_inputs(tick: int) -> Array[Dictionary]:
	var row: Array = inputs.get(tick, [])
	var result: Array[Dictionary] = []
	for slot in slot_peers.size():
		var input = row[slot] if slot < row.size() else null
		if input == null:
			if not gone_slots.has(slot):
				return []
			input = IDLE
		result.append(input)
	inputs.erase(tick)
	return result
