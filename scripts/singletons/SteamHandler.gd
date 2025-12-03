extends Node

var steam_enabled: bool = false
var steam_id: int = 0

var clients: Dictionary[int,int] = {}
var listen_socket: int = 0
var connection: int = 0
var accepting_connections: bool = false

signal packet_received(packet: Dictionary)
signal connection_received(connection: int, connection_data: Dictionary)
signal connection_ended(connection: int, connection_data: Dictionary)

func connect_lobby(host_user_id: int) -> bool:
	if !steam_enabled or listen_socket != 0 or connection != 0:
		print("steam not enabled or already connected")
		return false
	connection = Steam.connectP2P(host_user_id,0,{})
	if connection == Steam.NETWORKING_CONNECTION_INVALID:
		print("connection is invalid")
		connection = 0
		return false
	print("successfully connected to lobby")
	return true

func create_lobby() -> bool:
	if !steam_enabled or listen_socket != 0 or connection != 0:
		print("steam not enabled or already connected")
		return false
	listen_socket = Steam.createListenSocketP2P(0,{})
	if listen_socket == Steam.LISTEN_SOCKET_INVALID:
		print("failed to create listen socket")
		listen_socket = 0
		return false
	print("successfully created lobby ",SteamHandler.steam_id)
	return true

func leave_lobby() -> bool:
	if !steam_enabled or (listen_socket == 0 and connection == 0):
		return false
	if listen_socket != 0:
		Steam.closeListenSocket(listen_socket)
		listen_socket=0
		clients.clear()
	else:
		Steam.closeConnection(connection,0,"Left the lobby", true)
		connection=0
	return true

func send_message(connection_handle: int, packet_id: int, data: PackedByteArray) -> Dictionary:
	data.insert(0,packet_id)
	return Steam.sendMessageToConnection(connection_handle,data,Steam.NETWORKING_SEND_RELIABLE)

func _ready() -> void:
	print("Attempt to initialize steam...")
	var init_success: Dictionary = Steam.steamInitEx(480)
	
	if init_success.status!=0:
		print("Steam failed to initialize. (%s)" % init_success.verbal)
	else:
		steam_enabled=true
		print("Steam initialized successfully")
	
	if !steam_enabled: return
	
	steam_id = Steam.getSteamID()
	
	Steam.initRelayNetworkAccess()
	
	Steam.network_connection_status_changed.connect(func(connection_handle: int, connection_data: Dictionary, _old_state: int) -> void:
		print("network connection status changed ",connection_data)
		match connection_data.connection_state:
			Steam.CONNECTION_STATE_CONNECTING:
				if accepting_connections:
					Steam.acceptConnection(connection_handle)
			Steam.CONNECTION_STATE_CONNECTED:
				connection_received.emit(connection_handle, connection_data)
				clients[connection_data.identity]=connection_handle
			_:
				if connection_data.end_reason != 0:
					print("connection ended")
					connection_ended.emit(connection_handle, connection_data)
					clients.erase(connection_data.identity)
	)

func _process(_dt: float) -> void:
	Steam.run_callbacks()
	
	for client_id: int in clients:
		var client_connection: int = clients[client_id]
		for packet: Dictionary in Steam.receiveMessagesOnConnection(client_connection,100):
			packet_received.emit(packet)
	if connection!=0:
		for packet: Dictionary in Steam.receiveMessagesOnConnection(connection,100):
			packet_received.emit(packet)
