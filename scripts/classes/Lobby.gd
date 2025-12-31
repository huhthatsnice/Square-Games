extends Node
class_name Lobby

var lobby_users: Dictionary[int,Dictionary] = {}

var is_host: bool = false
var host_id: int = 0

var local_hit_data:PackedByteArray=[]
var local_cursor_pos_data:PackedVector3Array=[]

var last_cursor_pos:Vector2

var clients_to_load: int = len(lobby_users)+1

var current_map: MapLoader.Map
var map_started_usec: int = 0

var is_spectating: bool = false
var spectated_user: int = 0

enum CLIENT_PACKET {
	PLAYER_ADDED,
	PLAYER_REMOVED,
	PLAYER_CHANGED,
	CHAT_MESSAGE,
	NOTE_HIT,
	CURSOR_UPDATE,
	PLAY_BEGIN, #related to sending over data
	PLAY_START, #related to actually starting the map
	DIED
}

enum HOST_PACKET {
	PLAYER_ADDED,
	CHAT_MESSAGE,
	NOTE_HIT,
	CURSOR_UPDATE,
	PLAY_READY,
	DIED
}

func _to_json_buffer(v: Variant) -> PackedByteArray:
	return JSON.stringify(v).to_ascii_buffer()

#region generic functions
func send_chat_message(msg: String) -> void:
	msg = Steam.getPersonaName()+": "+msg
	Terminal.print_console(msg+"\n")
	if is_host:
		print("send message")
		_send_to_clients(CLIENT_PACKET.CHAT_MESSAGE,msg.to_ascii_buffer())
	else:
		print("send to host")
		SteamHandler.send_message(SteamHandler.connection,HOST_PACKET.CHAT_MESSAGE,msg.to_ascii_buffer())

func _flush_replication_data() -> void:
	if !is_host:
		SteamHandler.send_message(SteamHandler.connection,CLIENT_PACKET.CURSOR_UPDATE,var_to_bytes(local_cursor_pos_data))
	else:
		_send_to_clients(CLIENT_PACKET.CURSOR_UPDATE,var_to_bytes(local_cursor_pos_data))
	local_cursor_pos_data.clear()

func start_lobby(map: MapLoader.Map) -> bool:
	if !is_host: return false

	SteamHandler.accepting_connections = false

	clients_to_load = len(lobby_users)+1
	_send_to_clients(CLIENT_PACKET.PLAY_BEGIN,var_to_bytes_with_objects({
		data=map.raw_data,
		audio=map.audio
	}))

	Terminal.is_accepting_input = false
	Terminal.print_console("Starting lobby...\n")

	var game_handler: GameHandler = GameHandler.new(map)
	SSCS.game_handler=game_handler

	game_handler.note_hit.connect(func(note_id: int) -> void:
		_send_to_clients(CLIENT_PACKET.NOTE_HIT,var_to_bytes({
			user_id=SteamHandler.steam_id,
			data=1,
			id=note_id,
		}))
	)

	game_handler.note_missed.connect(func(note_id: int) -> void:
		_send_to_clients(CLIENT_PACKET.NOTE_HIT,var_to_bytes({
			user_id=SteamHandler.steam_id,
			data=0,
			id=note_id,
		}))
	)

	game_handler.ended.connect(func() -> void:
		_send_to_clients(CLIENT_PACKET.DIED, var_to_bytes(SteamHandler.steam_id))
		Terminal.print_console(Steam.getPersonaName() +" has died.")
	)

	var game_scene:Node = $"/root/Game"
	game_scene.add_child(game_handler)

	clients_to_load -=1

	while clients_to_load > 0: await get_tree().physics_frame

	Terminal.visible = false

	_send_to_clients(CLIENT_PACKET.PLAY_START,[])
	game_handler.play(0)

	for user_id: int in lobby_users:
		var user: Dictionary = lobby_users[user_id]
		user.alive = true

	map_started_usec = Time.get_ticks_usec()
	current_map = map

	return true

func start_spectate(user_id: int) -> void: #should be called only when there isnt currently a GameHandler since it creates its own
	if is_spectating or current_map == null or !lobby_users.has(user_id) or !lobby_users[user_id].alive: return

	var game_handler: GameHandler = GameHandler.new(current_map, lobby_users[user_id].note_hit_data, lobby_users[user_id].cursor_pos_data)

	SSCS.game_handler = game_handler
	$"/root/Game".add_child(game_handler)

	Terminal.is_accepting_input = false
	Terminal.visible = false

	game_handler.ended.connect(func() -> void:
		is_spectating = false
		spectated_user = 0
		Terminal.is_accepting_input = true
		Terminal.visible = true
	)

	is_spectating = true
	spectated_user = user_id

	game_handler.play(((Time.get_ticks_usec()-map_started_usec)/1_000_000.0) - 0.5) #-0.5s cause im too lazy to properly account for ping and also to account for the fact that data is sent in 0.25s increments

#endregion
#region host functions
func _send_to_clients(packet_id: int, data: PackedByteArray, except: Array[int] = []) -> void:
	for client: int in lobby_users:
		if client in except: continue
		print("send to ", client)
		SteamHandler.send_message(SteamHandler.clients[client],packet_id,data)

func _client_connected_host(connection_handle: int, connection_data: Dictionary) -> void:
	print("client connected ",connection_data.identity)
	for client: int in lobby_users:
		if client == connection_data.identity: continue
		var client_data: Dictionary = lobby_users[client]
		SteamHandler.send_message(connection_handle, CLIENT_PACKET.PLAYER_ADDED, var_to_bytes({
			user_id=client_data.user_id,
			username=client_data.username,
			settings=client_data.settings
		}))
	SteamHandler.send_message(connection_handle, CLIENT_PACKET.PLAYER_ADDED, var_to_bytes({
		user_id=SteamHandler.steam_id,
		username=Steam.getPersonaName(),
		settings=SSCS.encode_class(SSCS.settings)
	}))


func _client_removed_host(_connection_handle: int, connection_data: Dictionary) -> void:
	print("client gone ",connection_data.identity)
	if !lobby_users.has(connection_data.identity): return
	Terminal.print_console("Player %s has left the lobby.\n" % lobby_users[connection_data.identity].username)
	lobby_users.erase(connection_data.identity)
	_send_to_clients(CLIENT_PACKET.PLAYER_REMOVED,var_to_bytes({
		user_id=connection_data.identity,
	}))

func _packet_received_host(packet: Dictionary) -> void:
	var type: int = packet.payload[0]
	packet.payload.remove_at(0)
	var raw_data: String = packet.payload.get_string_from_ascii()
	print("host received packet")
	match type:
		HOST_PACKET.PLAYER_ADDED:
			var data: Dictionary = bytes_to_var(packet.payload)
			Terminal.print_console("Player %s has joined the lobby.\n" % data.username)

			lobby_users[packet.identity]={
				user_id=packet.identity,
				username=data.username,
				settings=data.settings,

				note_hit_data=PackedByteArray(),
				cursor_pos_data=PackedVector3Array()
			}
			_send_to_clients(CLIENT_PACKET.PLAYER_ADDED,var_to_bytes({
				user_id=packet.identity,
				username=data.username,
				settings=data.settings
			}),[packet.identity])
		HOST_PACKET.CHAT_MESSAGE:
			Terminal.print_console(raw_data+"\n")
			_send_to_clients(CLIENT_PACKET.CHAT_MESSAGE,raw_data.to_ascii_buffer(),[packet.identity])
		HOST_PACKET.NOTE_HIT:
			var data: Dictionary = bytes_to_var(packet.payload)
			lobby_users[packet.identity].note_hit_data.resize(max(len(lobby_users[packet.identity].note_hit_data), data.id + 1))
			lobby_users[packet.identity].note_hit_data[data.id] = data.data
			_send_to_clients(CLIENT_PACKET.NOTE_HIT, var_to_bytes({
				user_id=packet.identity,
				data = data.data,
				id = data.id,
			}), [packet.identity])
		HOST_PACKET.CURSOR_UPDATE:
			var data: PackedVector3Array = bytes_to_var(packet.payload)
			lobby_users[packet.identity].cursor_pos_data.append_array(data)
			_send_to_clients(CLIENT_PACKET.CURSOR_UPDATE, var_to_bytes({
				user_id=packet.identity,
				data=packet.payload
			}), [packet.identity])
		HOST_PACKET.PLAY_READY:
			clients_to_load -= 1
		HOST_PACKET.DIED:
			Terminal.print_console(Steam.getFriendPersonaName(packet.identity) +" has died.")
			lobby_users[packet.identity].alive = false
			if is_spectating and spectated_user == packet.identity:
				SSCS.game_handler.stop()
			_send_to_clients(CLIENT_PACKET.DIED, var_to_bytes(packet.identity), [packet.identity])
#endregion
#region client functions
func _connection_removed_client(_connection_handle: int, _connection_data: Dictionary) -> void:
	print("host connection gone")
	self.queue_free()

func _packet_received_client(packet: Dictionary) -> void:
	var type: int = packet.payload[0]
	packet.payload.remove_at(0)
	var raw_data: String = packet.payload.get_string_from_ascii()
	print("client received packet %s" % type)
	match type:
		CLIENT_PACKET.PLAYER_ADDED:
			var data: Dictionary = bytes_to_var(packet.payload)
			print(data)
			Terminal.print_console("Player %s has joined the lobby.\n" % data.username)

			lobby_users[data.user_id]={
				user_id=data.user_id,
				username=data.username,
				settings=data.settings,

				alive=false,
				note_hit_data=PackedByteArray(),
				cursor_pos_data=PackedVector3Array()
			}
		CLIENT_PACKET.PLAYER_REMOVED:
			var data: Dictionary = bytes_to_var(packet.payload)
			Terminal.print_console("Player %s has left the lobby.\n" % lobby_users[data.user_id].username)
			lobby_users.erase(data.user_id)
		CLIENT_PACKET.PLAYER_CHANGED:
			var data: Dictionary = bytes_to_var(packet.payload)

			lobby_users[data.user_id].settings=data.settings
		CLIENT_PACKET.CHAT_MESSAGE:
			Terminal.print_console(raw_data+"\n")
		CLIENT_PACKET.NOTE_HIT:
			var data: Dictionary = bytes_to_var(packet.payload)
			lobby_users[data.user_id].note_hit_data.resize(max(len(lobby_users[data.user_id].note_hit_data), data.id + 1))
			lobby_users[data.user_id].note_hit_data[data.id] = data.data
		CLIENT_PACKET.CURSOR_UPDATE:
			var data: Dictionary = bytes_to_var(packet.payload)
			lobby_users[data.user_id].cursor_pos_data.append_array(data.data)
		CLIENT_PACKET.PLAY_BEGIN:
			var data: Dictionary = bytes_to_var_with_objects(packet.payload)

			var new_map: MapLoader.Map = MapLoader.Map.new()

			new_map.data = MapLoader._parse_data(data.data)
			new_map.audio = data.audio

			Terminal.is_accepting_input = false
			Terminal.print_console("Starting lobby...\n")

			var game_handler: GameHandler = GameHandler.new(new_map)
			SSCS.game_handler=game_handler

			game_handler.note_hit.connect(func(note_id: int) -> void:
				SteamHandler.send_message(SteamHandler.connection, HOST_PACKET.NOTE_HIT, var_to_bytes({
					data = 1,
					id = note_id,
				}))
			)

			game_handler.note_missed.connect(func(note_id: int) -> void:
				SteamHandler.send_message(SteamHandler.connection, HOST_PACKET.NOTE_HIT, var_to_bytes({
					data = 0,
					id = note_id,
				}))
			)

			game_handler.ended.connect(func() -> void:
				SteamHandler.send_message(SteamHandler.connection, HOST_PACKET.DIED, [])
				Terminal.print_console(Steam.getPersonaName() +" has died.")
			)

			var game_scene:Node = $"/root/Game"
			game_scene.add_child(game_handler)

			SteamHandler.send_message(SteamHandler.connection,HOST_PACKET.PLAY_READY,[])
		CLIENT_PACKET.PLAY_START:
			Terminal.visible = false
			SSCS.game_handler.play(0)

			map_started_usec = Time.get_ticks_usec()
			current_map = SSCS.game_handler.map

			for user_id: int in lobby_users:
				var user: Dictionary = lobby_users[user_id]
				user.alive = true
		CLIENT_PACKET.DIED:
			var user: int = bytes_to_var(packet.payload)
			Terminal.print_console(Steam.getFriendPersonaName(user) +" has died.")
			lobby_users[user].alive = false
			if is_spectating and spectated_user == packet.identity:
				SSCS.game_handler.stop()

#endregion

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		print("lobby closed")
		print(SteamHandler.leave_lobby())
		SteamHandler.accepting_connections = false

func _init(host_user_id: int = 0) -> void:
	print("lobby created with host id '%s'" % host_user_id)
	if host_user_id == 0:
		is_host = true
		host_id = SteamHandler.steam_id

		SteamHandler.connection_received.connect(_client_connected_host)
		SteamHandler.connection_ended.connect(_client_removed_host)
		SteamHandler.packet_received.connect(_packet_received_host)

		SteamHandler.accepting_connections = true
		SteamHandler.create_lobby()
		return
	host_id = host_user_id

	SteamHandler.connection_ended.connect(_connection_removed_client)
	SteamHandler.packet_received.connect(_packet_received_client)


	if !SteamHandler.connect_lobby(host_user_id):
		print("Failed to connect lobby, will cause major issues")
		return

	print(Steam.getPersonaName())
	SteamHandler.send_message(SteamHandler.connection, HOST_PACKET.PLAYER_ADDED, var_to_bytes({
		username=Steam.getPersonaName(),
		settings=SSCS.encode_class(SSCS.settings)
	}))

func _physics_process(_dt: float) -> void:
	if !(SSCS.game_handler and SSCS.game_handler.playing): return
	var cursor: Cursor = SSCS.game_handler.cursor
	var cursor_pos: Vector2 = cursor.pos
	var cursor_pos_time: Vector3 = Vector3(cursor_pos.x,cursor_pos.y,AudioManager.elapsed)
	var cursor_data_count:int = len(local_cursor_pos_data)
	if cursor_data_count==0:
		local_cursor_pos_data.append(cursor_pos_time)
		return
	elif cursor_data_count>=30:
		_flush_replication_data()

	if last_cursor_pos != cursor_pos:
		last_cursor_pos = cursor_pos
		local_cursor_pos_data.append(cursor_pos_time)
