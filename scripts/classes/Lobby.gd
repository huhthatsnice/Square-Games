extends Node
class_name Lobby

var lobby_users: Dictionary[int,Dictionary] = {}

var is_host: bool = false
var host_id: int = 0

enum CLIENT_PACKET {
	PLAYER_ADDED,
	PLAYER_REMOVED,
	PLAYER_CHANGED,
	CHAT_MESSAGE,
}

enum HOST_PACKET {
	PLAYER_ADDED,
	CHAT_MESSAGE,
}

func _to_json_buffer(v: Variant) -> PackedByteArray:
	return JSON.stringify(v).to_ascii_buffer()

#region generic functions
func send_chat_message(msg: String) -> void:
	msg = Steam.getPersonaName()+": "+msg
	Terminal.print_console(msg+"\n")
	if is_host:
		_send_to_clients(CLIENT_PACKET.CHAT_MESSAGE,msg.to_ascii_buffer())
	else:
		SteamHandler.send_message(SteamHandler.connection,HOST_PACKET.CHAT_MESSAGE,msg.to_ascii_buffer())

#endregion
#region host functions
func _send_to_clients(packet_id: int, data: PackedByteArray, except: Array[int] = []) -> void:
	for client: int in lobby_users:
		if client in except: continue
		SteamHandler.send_message(client,packet_id,data)
	
func _client_connected_host(connection_handle: int, connection_data: Dictionary) -> void:
	print("client connected ",connection_data.identity)
	for client: int in lobby_users:
		var client_data: Dictionary = lobby_users[client]
		SteamHandler.send_message(connection_handle, CLIENT_PACKET.PLAYER_ADDED, _to_json_buffer({
			user_id=client_data.user_id,
			settings=client_data.settings
		}))
	SteamHandler.send_message(connection_handle, CLIENT_PACKET.PLAYER_ADDED, _to_json_buffer({
		user_id=SteamHandler.steam_id,
		settings=SSCS.encode_class(SSCS.settings)
	}))
	

func _client_removed_host(_connection_handle: int, connection_data: Dictionary) -> void:
	print("client gone ",connection_data.identity)
	if !lobby_users.has(connection_data.identity): return
	lobby_users.erase(connection_data.identity)
	_send_to_clients(CLIENT_PACKET.PLAYER_REMOVED,_to_json_buffer({
		user_id=connection_data.identity,
	}))

func _packet_received_host(packet: Dictionary) -> void:
	var type: int = packet.payload.to_ascii_buffer()[0]
	var raw_data: String = packet.payload.substr(1)
	print("host received packet")
	match type:
		HOST_PACKET.PLAYER_ADDED:
			var data: Dictionary = JSON.parse_string(raw_data)
			lobby_users[packet.identity].settings=data
			_send_to_clients(CLIENT_PACKET.PLAYER_ADDED,_to_json_buffer({
				user_id=packet.identity,
				settings=data
			}))
		HOST_PACKET.CHAT_MESSAGE:
			Terminal.print_console(raw_data+"\n")
			_send_to_clients(CLIENT_PACKET.CHAT_MESSAGE,raw_data.to_ascii_buffer(),[packet.identity])

#endregion
#region client functions
func _connection_removed_client(_connection_handle: int, connection_data: Dictionary) -> void:
	print("host connection gone")
	Steam.CONNECTION_END_APP_EXCEPTION_GENERIC
	self.queue_free()

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
		CLIENT_PACKET.CHAT_MESSAGE:
			Terminal.print_console(raw_data+"\n")

#endregion

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		print("lobby closed")
		SteamHandler.leave_lobby()
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
	
	SteamHandler.send_message(SteamHandler.connection, HOST_PACKET.PLAYER_ADDED, JSON.stringify(SSCS.encode_class(SSCS.settings)).to_ascii_buffer())
