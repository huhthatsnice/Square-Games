extends Node
class_name HostLobby

var discoverability: Steam.LobbyType

var user_data: Dictionary[int, Dictionary]

var selected_map: MapLoader.Map
var map_url: String

var local_note_hit_data: Dictionary
var local_cursor_pos_data: PackedByteArray

var replication_start: int
var last_replication_flush: int
var last_cursor_update: int

var cursor: Cursor

enum HOST_PACKET {
	CHAT_MESSAGE,
	CHANGE_SELECTED_MAP,
	REPLICATION_DATA_UPDATE,
	PLAYER_READY
}

func send_chat_message(message: String) -> void:
	Terminal.print_console("{0}{1}{3}: {4}\n".format([
		"[color=yellow]",
		NewSteamHandler.get_user_display_name(NewSteamHandler.local_steam_id),
		"[/color]",
		message,
	]))

	NewSteamHandler.send_message_to_users([], ClientLobby.CLIENT_PACKET.CHAT_MESSAGE, var_to_bytes([NewSteamHandler.local_steam_id, message]))

func change_map(new_map: MapLoader.Map, url: String = "") -> void:
	if selected_map == new_map: return

	selected_map = new_map

	for user_id: int in user_data:
		user_data[user_id].ready = false

	if url == "":
		url = await SSCS.get_temporary_map_download_link(new_map)

	map_url = url

	NewSteamHandler.send_message_to_users([], ClientLobby.CLIENT_PACKET.SELECTED_MAP_CHANGED, url.to_utf8_buffer())

func start_lobby(from: float = 0) -> void:
	var all_ready: bool = true
	for user_id: int in user_data:
		if !user_data[user_id].ready:
			all_ready = false
			break
	while !all_ready:
		await SSCS.wait(0.1)
		all_ready = true
		for user_id: int in user_data:
			if !user_data[user_id].ready:
				all_ready = false
				break

	NewSteamHandler.send_message_to_users([], ClientLobby.CLIENT_PACKET.MAP_START, [])

	var game_handler: GameHandler = GameHandler.new(selected_map)

	game_handler.note_hit.connect(func(note_id: int) -> void:
		local_note_hit_data[note_id] = true
	)

	game_handler.note_hit.connect(func(note_id: int) -> void:
		local_note_hit_data[note_id] = false
	)

	last_replication_flush = Time.get_ticks_msec()
	replication_start = last_replication_flush

	SSCS.game_handler = game_handler

	SSCS.get_node("/root/Game").add_child(game_handler)

	cursor = game_handler.cursor

	Terminal.is_accepting_input = false
	Terminal.visible = false

	game_handler.play(from)

	await game_handler.ended

	game_handler.queue_free()
	Terminal.visible = true
	Terminal.is_accepting_input = true

func _init(lobby_discoverability: Steam.LobbyType) -> void:
	lobby_discoverability = discoverability

	if NewSteamHandler.current_lobby_id == 0:
		NewSteamHandler.create_lobby(lobby_discoverability)
	elif lobby_discoverability != -1:
		Steam.setLobbyType(NewSteamHandler.current_lobby_id, lobby_discoverability)

	NewSteamHandler.player_joined.connect(func(user_id: int) -> void:
		user_data[user_id] = {
			alive = false,

			cursor_replication_data = [],
			note_hit_data = [],

			ready = false
		}

		NewSteamHandler.send_message(user_id, ClientLobby.CLIENT_PACKET.SELECTED_MAP_CHANGED, map_url.to_utf8_buffer())
		NewSteamHandler.send_message(user_id, ClientLobby.CLIENT_PACKET.SELECTED_MODIFIERS_CHANGED, var_to_bytes(SSCS.modifiers))
	)

	NewSteamHandler.player_left.connect(func(user_id: int) -> void:
		if user_id == NewSteamHandler.local_steam_id:
			self.queue_free()
			if SSCS.host_lobby:
				SSCS.host_lobby = null
		else:
			user_data.erase(user_id)
	)

	NewSteamHandler.user_data_updated.connect(func(user_id: int) -> void:
		if user_data.has(user_id):
			user_data[user_id].settings = str_to_var(Steam.getLobbyMemberData(NewSteamHandler.current_lobby_id, user_id, "settings"))
	)

	NewSteamHandler.packet_received.connect(func(user_id: int, packet_type: int, packet_data: PackedByteArray, raw_packet: Dictionary) -> void:
		match packet_type:
			HOST_PACKET.CHAT_MESSAGE:
				Terminal.print_console("{0}: {1}\n".format([
					NewSteamHandler.get_user_display_name(user_id),
					packet_data.get_string_from_utf8()
				]))

				NewSteamHandler.send_message_to_users([user_id], ClientLobby.CLIENT_PACKET.CHAT_MESSAGE, var_to_bytes([user_id, packet_data.get_string_from_utf8()]))
			HOST_PACKET.CHANGE_SELECTED_MAP:
				var data: Array = bytes_to_var(packet_data)

				Terminal.print_console("{0} would like to change the map to {1}. Type \"y\" to accept or type anything else to ignore.".format([NewSteamHandler.get_user_display_name(user_id), data[0]]))

				var answer: String = await Terminal.line_entered

				if answer.to_lower() == "y":
					Terminal.print_console("Downloading map...")

					var temp_selected_map: MapLoader.Map = selected_map
					selected_map = null
					var new_map: MapLoader.Map = await SSCS.get_map_from_url(data[1])
					new_map.map_name = data[0]

					if !new_map.loaded_successfully:
						selected_map = temp_selected_map
						return

					selected_map = new_map
			HOST_PACKET.PLAYER_READY:
				user_data[packet_data.decode_s64(0)].ready = true
			_:
				print("unknown packet type ", packet_type)
	)

	NewSteamHandler.host_changed.connect(func(user_id: int) -> void:
		if user_id != NewSteamHandler.local_steam_id:
			var new_lobby: ClientLobby = ClientLobby.new(NewSteamHandler.current_lobby_id)

			SSCS.host_lobby = null
			SSCS.client_lobby = new_lobby
			self.queue_free()
	)

	SSCS.modifier_updated.connect(func() -> void:
		NewSteamHandler.send_message_to_users([], ClientLobby.CLIENT_PACKET.SELECTED_MODIFIERS_CHANGED, var_to_bytes(SSCS.modifiers))
	)

func _process(_delta: float) -> void:
	if SSCS.game_handler != null:
		var current_tick: int = Time.get_ticks_msec()

		var cursor_data: PackedByteArray
		cursor_data.resize(2 + 2 + 1)

		cursor_data.encode_u16(0, roundi(remap(cursor.pos.x, -Cursor.GRID_MAX, Cursor.GRID_MAX, 0, 0xffff)))
		cursor_data.encode_u16(2, roundi(remap(cursor.pos.y, -Cursor.GRID_MAX, Cursor.GRID_MAX, 0, 0xffff)))
		cursor_data.encode_u16(4, last_cursor_update - current_tick)

		last_cursor_update = current_tick

		local_cursor_pos_data.append_array(cursor_data)

		if current_tick - last_replication_flush > 500:
			last_replication_flush = current_tick

			NewSteamHandler.send_message_to_users([], ClientLobby.CLIENT_PACKET.REPLICATION_DATA_UPDATE, var_to_bytes([local_cursor_pos_data, local_note_hit_data]))

			local_cursor_pos_data.clear()
			local_note_hit_data.clear()
