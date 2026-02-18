extends Node
class_name ClientLobby

var user_data: Dictionary[int, Dictionary]

var selected_map: MapLoader.Map

var local_note_hit_data: Dictionary
var local_cursor_pos_data: PackedByteArray

var replication_start: int
var last_replication_flush: int
var last_cursor_update: int

var cursor: Cursor

var lobby_modifiers: SSCS.Modifiers = SSCS.Modifiers.new()

enum CLIENT_PACKET {
	CHAT_MESSAGE,
	SELECTED_MAP_CHANGED,
	SELECTED_MODIFIERS_CHANGED,
	MAP_START,
	REPLICATION_DATA_UPDATE
}

func send_chat_message(message: String) -> void:
	Terminal.print_console("{0} ({1}): {2}\n".format([
		NewSteamHandler.get_user_display_name(NewSteamHandler.local_steam_id),
		message,
	]))

	NewSteamHandler.send_message(NewSteamHandler.host_id, HostLobby.HOST_PACKET.CHAT_MESSAGE, message.to_utf8_buffer())

func _init(lobby_id: int = 0) -> void:

	if NewSteamHandler.current_lobby_id == 0:
		print("do the join")
		NewSteamHandler.join_lobby(lobby_id)

	NewSteamHandler.player_joined.connect(func(user_id: int) -> void:
		user_data[user_id] = {
			alive = false,

			cursor_replication_data = [],
			note_hit_data = [],
		}
	)

	NewSteamHandler.player_left.connect(func(user_id: int) -> void:
		if user_id == NewSteamHandler.local_steam_id:
			self.queue_free()
			if SSCS.client_lobby:
				SSCS.client_lobby = null
		else:
			user_data.erase(user_id)
	)

	NewSteamHandler.user_data_updated.connect(func(user_id: int) -> void:
		if user_data.has(user_id):
			user_data[user_id].settings = str_to_var(Steam.getLobbyMemberData(NewSteamHandler.current_lobby_id, user_id, "settings"))
	)

	NewSteamHandler.packet_received.connect(func(user_id: int, packet_type: int, packet_data: PackedByteArray, raw_packet: Dictionary) -> void:
		match packet_type:
			CLIENT_PACKET.CHAT_MESSAGE:
				var data: Array = bytes_to_var(packet_data)
				user_id = data[0]

				Terminal.print_console("{0}{1}{2}: {3}\n".format([
					"[color=yellow]" if NewSteamHandler.lobby_users[user_id].is_host else "",
					NewSteamHandler.get_user_display_name(user_id),
					"[/color]" if NewSteamHandler.lobby_users[user_id].is_host else "",
					data[1],
				]))
			CLIENT_PACKET.SELECTED_MAP_CHANGED:
				print("selected map changed")
				selected_map = null
				var map: MapLoader.Map = await SSCS.get_map_from_url(packet_data.get_string_from_utf8())
				selected_map = map
				NewSteamHandler.send_message(NewSteamHandler.host_id, HostLobby.HOST_PACKET.PLAYER_READY, [])
			CLIENT_PACKET.SELECTED_MODIFIERS_CHANGED:
				var data: Dictionary = bytes_to_var(packet_data)

				for i: String in data:
					lobby_modifiers.set(i, data[i])
			CLIENT_PACKET.MAP_START:
				var from: float = packet_data.decode_double(0)

				SSCS.modifiers = lobby_modifiers
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

				SSCS.modifiers = SSCS.true_modifiers
				game_handler.queue_free()
				Terminal.visible = true
				Terminal.is_accepting_input = true
			_:
				print("unknown packet type ", packet_type)
	)

	NewSteamHandler.host_changed.connect(func(user_id: int) -> void:
		if user_id == NewSteamHandler.local_steam_id:
			var new_lobby: HostLobby = HostLobby.new(-1)

			SSCS.client_lobby = null
			SSCS.host_lobby = new_lobby
			self.queue_free()
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
