extends Node
class_name ClientLobby

var user_data: Dictionary[int, Dictionary]

enum CLIENT_PACKET {
	CHAT_MESSAGE
}

func send_chat_message(message: String) -> void:
	var user_index: int = NewSteamHandler.get_user_index(NewSteamHandler.local_steam_id)

	Terminal.print_console("{1} ({2}): {3}".format([
		Steam.getPersonaName(),
		"user" + str(user_index),
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
		user_data.erase(user_id)
	)

	NewSteamHandler.user_data_updated.connect(func(user_id: int) -> void:
		if user_data.has(user_id):
			user_data[user_id].settings = str_to_var(Steam.getLobbyMemberData(NewSteamHandler.current_lobby_id, user_id, "settings"))
	)

	NewSteamHandler.packet_received.connect(func(user_id: int, packet_type: int, packet_data: PackedByteArray, raw_packet: Dictionary) -> void:
		match packet_type:
			CLIENT_PACKET.CHAT_MESSAGE:
				var user_index: int = NewSteamHandler.get_user_index(user_id)

				Terminal.print_console("{0}{1} ({2}){3}: {4}".format([
					"[color=yellow]" if NewSteamHandler.lobby_users[user_id].is_host else "",
					NewSteamHandler.lobby_users[user_id].name,
					"user" + str(user_index),
					"[/color]" if NewSteamHandler.lobby_users[user_id].is_host else "",
					packet_data.get_string_from_utf8(),
				]))
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
