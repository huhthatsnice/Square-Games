extends Node
class_name Lobby

var lobby_users: Dictionary[int,Dictionary] = {}

var is_host: bool = false
var host_id: int = 0

enum CLIENT_PACKET {
	PLAYER_ADDED,
	PLAYER_REMOVED,
	PLAYER_CHANGED
}

enum HOST_PACKET {
	PLAYER_ADDED,
}

func _client_connected(connection_handle: int) -> void:
	print("client connected")
	for i: int in lobby_users:
		var user: Dictionary = lobby_users[i]
		if user.user_id == connection_handle: continue
		Steam.sendMessageToConnection(connection_handle,(char(2)+JSON.stringify({
			user_id=user.user_id,
			settings=user.settings
		})).to_ascii_buffer(),Steam.NETWORKING_SEND_RELIABLE)
		

func _client_removed(connection_handle: int) -> void:
	print("client removed")
	lobby_users.erase(connection_handle)
	for i: int in lobby_users:
		var user: Dictionary = lobby_users[i]
		SteamHandler.send_message(SteamHandler.connection, 0, JSON.stringify({
			user_id=user.user_id,
			settings=user.settings,
			method=1
		}).to_ascii_buffer())
	
func _packet_received_host(packet: Dictionary) -> void:
	var type: int = packet.payload.to_ascii_buffer()[0]
	var raw_data: String = packet.payload.substr(1)
	print("host received packet")
	match type:
		HOST_PACKET.PLAYER_ADDED:
			var data: Dictionary = JSON.parse_string(raw_data)
			lobby_users[packet.identity].settings=data
			for connection: int in SteamHandler.clients:
				if connection == packet.identity: continue
				Steam.sendMessageToConnection(connection,(char(2)+JSON.stringify({
					user_id=packet.identity,
					settings=data
				})).to_ascii_buffer(),Steam.NETWORKING_SEND_RELIABLE)

func _packet_received_client(packet: Dictionary) -> void:
	var type: int = packet.payload.to_ascii_buffer()[0]
	var raw_data: String = packet.payload.substr(1)
	print("client received packet")
	match type:
		CLIENT_PACKET.PLAYER_ADDED:
			var data: Dictionary = JSON.parse_string(raw_data.substr(1))
			
			lobby_users[data.user_id]={
				user_id=data.user_id,
				name=data.name,
				settings=data.settings
			}
		CLIENT_PACKET.PLAYER_REMOVED:
			var data: Dictionary = JSON.parse_string(raw_data.substr(1))
			
			lobby_users.erase(data.user_id)
		CLIENT_PACKET.PLAYER_CHANGED:
			var data: Dictionary = JSON.parse_string(raw_data.substr(1))
			
			lobby_users[data.user_id].settings=data.settings

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		SteamHandler.leave_lobby()
		SteamHandler.accepting_connections = false

func _init(host_user_id: int = 0) -> void:
	print("lobby created with host id '%s'" % host_user_id)
	if host_user_id == 0:
		is_host = true
		host_id = SteamHandler.steam_id
		SteamHandler.accepting_connections = true
		SteamHandler.create_lobby()
		return
	host_id = host_user_id
	
	SteamHandler.packet_received.connect(_packet_received_host if is_host else _packet_received_client)
	SteamHandler.connection_received.connect(_client_connected)
	SteamHandler.connection_received.connect(_client_removed)
	
	if !SteamHandler.connect_lobby(host_user_id):
		print("Failed to connect lobby, will cause major issues")
		return
	
	SteamHandler.send_message(SteamHandler.connection, HOST_PACKET.PLAYER_ADDED, JSON.stringify(SSCS.encode_class(SSCS.settings)).to_ascii_buffer())
