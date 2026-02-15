extends Node

var game_id: int = 480 #SpaceWar for testing
var steam_enabled: bool = false

var local_steam_id: int

var current_lobby_id: int
var is_host: bool
var host_id: int

var lobby_users: Dictionary[int, Dictionary] = {}

var listen_socket: int
var accepting_connections: bool = false

signal player_joined(user_id: int)
signal player_left(user_id: int)
signal host_changed(user_id: int)
signal connection_status_changed(user_id: int, connected: bool)
signal user_data_updated(user_id: int)
signal packet_received(user_id: int, packet_type: int, packet_data: PackedByteArray, raw_packet: Dictionary)

func join_lobby(lobby_id: int) -> void:
	print("attempt to join lobby")
	print(lobby_id)
	if current_lobby_id == 0:
		Steam.joinLobby(lobby_id)

func create_lobby(type: Steam.LobbyType) -> void:
	print("attempt to create lobby")
	if current_lobby_id == 0:
		accepting_connections = true
		Steam.createLobby(type, 16)

func leave_lobby() -> void:
	print("attempt to leave lobby")
	if current_lobby_id != 0:
		Steam.leaveLobby(current_lobby_id)

func send_message(user_id: int, packet_type: int, data: PackedByteArray) -> void:
	print("send message")
	print(user_id)
	print(packet_type)
	data.append(packet_type)
	if lobby_users.has(user_id) and lobby_users[user_id].has("connection"):
		print("actually send")
		Steam.sendMessageToConnection(lobby_users[user_id].connection, data, Steam.NETWORKING_SEND_RELIABLE)
	data.remove_at(len(data)-1)

func send_message_to_users(user_ids: Array[int], packet_type: int, data:PackedByteArray, exclude: bool = true) -> void:
	print("send message to multiple")
	if exclude:
		for user_id in lobby_users:
			if !(user_id in user_ids):
				send_message(user_id, packet_type, data)
	else:
		for user_id in user_ids:
			send_message(user_id, packet_type, data)

func get_user_index(user_id: int) -> int:
	var sorted_user_ids: Array[int] = [local_steam_id]

	for user_id_2: int in lobby_users:
		sorted_user_ids.append(user_id_2)

	sorted_user_ids.sort()

	return sorted_user_ids.find(user_id)

func get_user_display_name(user_id: int) -> String:
	return "{0} ({1})".format([
		Steam.getPersonaName() if user_id == local_steam_id else lobby_users[user_id].name,
		"user" + str(get_user_index(user_id))
	])

func _ready() -> void:
	print("Attempt to initialize steam...")
	var init_success: Dictionary = Steam.steamInitEx(game_id)

	if init_success.status != 0:
		print("Steam failed to initialize. (%s)" % init_success.verbal)
	else:
		steam_enabled = true
		print("Steam initialized successfully")

	if !steam_enabled: return

	listen_socket = Steam.createListenSocketP2P(0,{})

	local_steam_id = Steam.getSteamID()

	Steam.network_connection_status_changed.connect(func(connection_handle: int, connection_data: Dictionary, _old_state: int) -> void:
		match connection_data.connection_state:
			Steam.CONNECTION_STATE_CONNECTING:
				print("receive connection attempt")
				if accepting_connections:
					Steam.acceptConnection(connection_handle)
				else:
					for i: int in range(0,10):
						await get_tree().create_timer(0.1).timeout
						if accepting_connections:
							Steam.acceptConnection(connection_handle)
							break
			Steam.CONNECTION_STATE_CONNECTED:
				lobby_users[connection_data.identity].connection = connection_handle
				connection_status_changed.emit(connection_data.identity, true)
			_:
				if connection_data.end_reason != 0:
					if lobby_users.has(connection_data.identity):
						lobby_users[connection_data.identity].erase("connection")
						connection_status_changed.emit(connection_data.identity, false)
	)

	Steam.lobby_created.connect(func(connection_status: int, lobby_id: int) -> void: #NOTE: no clue what connection_status is
		if connection_status == 1:
			print("opened lobby ", lobby_id)
			current_lobby_id = lobby_id
			is_host = true
			host_id = local_steam_id
			accepting_connections = true

			Steam.setLobbyMemberData(lobby_id, "settings", var_to_str(SSCS.encode_class(SSCS.settings)))
	)

	Steam.lobby_joined.connect(func(lobby_id: int, permissions: int, locked: bool, response: int) -> void:
		if response == Steam.CHAT_ROOM_ENTER_RESPONSE_SUCCESS:
			print("successfully entered lobby")
			if is_host: return

			current_lobby_id = lobby_id
			host_id = Steam.getLobbyOwner(lobby_id)

			var user_count: int = Steam.getNumLobbyMembers(current_lobby_id)

			Steam.setLobbyMemberData(lobby_id, "settings", var_to_str(SSCS.encode_class(SSCS.settings)))

			for i: int in range(0, user_count):
				var user_id: int = Steam.getLobbyMemberByIndex(current_lobby_id, i)

				if user_id == current_lobby_id: continue

				lobby_users[user_id] = {
					user_id = user_id,
					name = Steam.getFriendPersonaName(user_id),
					is_host = user_id == host_id,
				}
			lobby_users[host_id].connect = Steam.connectP2P(host_id, 0, {})

			print("connected to lobby")
			print(host_id)
			print()
		else:
			print("Failed to join lobby: ", response)
	)

	Steam.lobby_chat_update.connect(func(lobby_id: int, user_id: int, user_id_2: int, update: int) -> void:
		if update == Steam.ChatMemberStateChange.CHAT_MEMBER_STATE_CHANGE_LEFT or update == Steam.ChatMemberStateChange.CHAT_MEMBER_STATE_CHANGE_KICKED:
			if user_id == local_steam_id:
				current_lobby_id = 0
				lobby_users.clear()
			else:
				lobby_users.erase(user_id)
			player_left.emit(user_id)
			print("player left")
		elif user_id != local_steam_id:
			if update == Steam.ChatMemberStateChange.CHAT_MEMBER_STATE_CHANGE_ENTERED:
				print("player entered")
				lobby_users[user_id] = {
					user_id = user_id,
					name = Steam.getFriendPersonaName(user_id),
					is_host = false
				}
				player_joined.emit(user_id)
	)

	Steam.lobby_data_update.connect(func(success: int, lobby_id: int, user_id: int) -> void:
		if success == 1:
			if lobby_id != user_id and user_id != local_steam_id:
				user_data_updated.emit(user_id)
				print("user data updated")
			else: #no clue if this works since idk if host update is considered a lobby data or user data update
				var new_host_id: int = Steam.getLobbyOwner(lobby_id)
				if new_host_id == host_id: return

				print("host changed")
				for user_id_2: int in lobby_users:
					lobby_users[user_id_2].host = false
					if lobby_users[user_id_2].has("connection"):
						Steam.closeP2PSessionWithUser(user_id_2)
						lobby_users[user_id_2].erase("connection")
				accepting_connections = false
				is_host = false

				host_id = new_host_id

				if host_id == local_steam_id:
					is_host = true
					accepting_connections = true
				else:
					lobby_users[host_id].host = true
					lobby_users[host_id].connect = Steam.connectP2P(host_id, 0, {})
				host_changed.emit(host_id)
				print("new host")
				print(host_id)
	)

	SSCS.setting_updated.connect(func() -> void:
		if current_lobby_id:
			Steam.setLobbyMemberData(current_lobby_id, "settings", var_to_str(SSCS.encode_class(SSCS.settings)))
	)


var i: int = 0
func _process(_dt: float) -> void:
	Steam.run_callbacks()
	i += 1
	for user_id: int in lobby_users:
		if lobby_users[user_id].has("connection"):
			if i%500 == 0:
				print("user %s has connection" % str(user_id))
			var packets: Array = Steam.receiveMessagesOnConnection(lobby_users[user_id].connection, 64)
			for packet: Dictionary in packets:
				var packet_data: PackedByteArray = packet.payload
				var packet_type: int = packet_data[-1]
				packet_data.remove_at(len(packet_data)-1)

				print("received packet")
				print(user_id)
				print(packet_type)

				packet_received.emit(user_id, packet_type, packet_data, packet)
