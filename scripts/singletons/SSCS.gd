extends Node

## any setting which is related to track position is on a scale of 0-1 where 0 is hitting the grid and 1 is freshly spawned

class Settings:
	var approach_rate: float = 50.0
	var spawn_distance: float = 25.0
	var color_set: Array[Color] = [
		Color.from_string("#ffffff", Color.WHITE),
		Color.from_string("#66ffff", Color.WHITE),
	]
	var grid_distance: float = 3.5
	var vanish_distance: float = 0.2
	var pixels_per_grid_unit: float = 100.0
	var parallax: float = 0.1

	var note_transparency: float = 0.3
	var note_begin_transparency: float = 1
	var note_end_transparency: float = 0.9

	var note_fade_in_begin: float = 1
	var note_fade_in_end: float = 0.8

	var note_fade_out_begin: float = 0.4
	var note_fade_out_end: float = 0

	var fov: float = 75

	var absolute_input: bool = false

	var auto_spectate: bool = true
	
	var glow_enabled: bool = false
	var glow_strength: float = 2
	var glow_bloom: float = 0.2

class Modifiers:
	var hit_time: float = 45.0
	var hitbox_size: float = 1.28/2
	var speed: float = 1
	var no_fail: bool = false
	var autoplay: bool = true

signal setting_updated(setting: String, old_value: Variant, new_value: Variant)
signal modifier_updated(modifier: String, old_value: Variant, new_value: Variant)

var settings: Settings = Settings.new()
var modifiers: Modifiers = Modifiers.new()
var lobby: Lobby
var game_handler: GameHandler
var map_cache: Dictionary[String, MapLoader.Map] = {}
var url_cache: Dictionary[String, Dictionary] = {}

var setting_parse_overrides: Dictionary[String,Callable] = {
	color_set = func(value: String) -> Array:
		var new_value: Array[Color] = []
		for color: String in value.split(","):
			new_value.append(Color.from_string(color,Color.WHITE))
		return [new_value,true]
}

var modifier_parse_overrides: Dictionary[String,Callable] = {
	color_set = func(value: String) -> Array[Color]:
		var colorset: Array[Color] = []
		for color: String in value.split(","):
			colorset.append(Color.from_string(color, Color.WHITE))
		return colorset
}

func set_setting(setting: String, value: Variant, generic: bool = false) -> bool:
	var cur_value: Variant = settings.get(setting)
	if cur_value==null: return false

	if generic and value is String:
		var new_value: Variant
		var valid: bool = true
		if setting_parse_overrides.has(setting):
			var data:Array = setting_parse_overrides.get(setting).call(value)
			new_value = data[0]
			valid = data[1]
		else:
			match typeof(cur_value):
				TYPE_STRING:
					new_value = value
				TYPE_FLOAT:
					if !value.is_valid_float(): valid = false
					new_value = value.to_float()
				TYPE_INT:
					if !value.is_valid_int(): valid = false
					new_value = value.to_int()
				TYPE_BOOL:
					var value_lower: String = value.to_lower()
					if value_lower=="true" or value_lower=="false":
						new_value = value_lower=="true"
					else:
						valid = false

		if !valid:
			return false

		settings.set(setting,new_value)
	else:
		if typeof(cur_value)!=typeof(value):
			return false
		settings.set(setting,value)

	setting_updated.emit(setting,cur_value,value)
	return true

func set_modifier(modifier: String, value: Variant, generic: bool = false) -> bool:
	var cur_value: Variant = modifiers.get(modifier)
	if cur_value==null: return false

	if generic and value is String:
		var new_value: Variant
		var valid: bool = true
		if modifier_parse_overrides.has(modifier):
			var data:Array = modifier_parse_overrides.get(modifier).call(value)
			new_value = data[0]
			valid = data[1]
		else:
			match typeof(cur_value):
				TYPE_STRING:
					new_value = value
				TYPE_FLOAT:
					if !value.is_valid_float(): valid = false
					new_value = value.to_float()
				TYPE_INT:
					if !value.is_valid_int(): valid = false
					new_value = value.to_int()
				TYPE_BOOL:
					var value_lower: String = value.to_lower()
					if value_lower=="true" or value_lower=="false":
						new_value = value_lower=="true"
					else:
						valid = false

		if !valid:
			return false

		modifiers.set(modifier,new_value)
	else:
		if typeof(cur_value)!=typeof(value):
			return false
		modifiers.set(modifier,value)

	modifier_updated.emit(modifier,cur_value,value)
	return true

const blacklisted_properties: Array[String] = ["RefCounted","script","Built-in script"]
func encode_class(obj: Variant) -> Dictionary:
	var encoded: Dictionary = {}

	for p: Dictionary in obj.get_property_list():
		if p.name not in blacklisted_properties:
			encoded[p.name]=obj.get(p.name)

	return encoded

func get_map_file_path_from_name(map_name: String) -> String:
	var map: String
	var is_sspm: bool = FileAccess.file_exists("user://rhythiamaps/%s.sspm" % map_name)
	if is_sspm:
		map = "user://rhythiamaps/%s.sspm" % map_name
	else:
		map = "user://maps/%s" % map_name

	return map

signal temporary_map_link_received
func get_temporary_map_download_link(map: MapLoader.Map) -> String:
	if url_cache.has(map.map_name):
		if Time.get_unix_time_from_system() - url_cache[map.map_name].time < (60*60) - 30:
			return url_cache[map.map_name].url
		else:
			url_cache.erase(map.map_name)

	var request: HTTPRequest = HTTPRequest.new()
	self.add_child(request)

	var data: PackedStringArray = []

	var boundary: String = "--GODOT" + Crypto.new().generate_random_bytes(16).hex_encode()

	var upload_data: PackedByteArray = var_to_bytes_with_objects({
		data=map.raw_data,
		audio=map.audio
	})

	print(len(upload_data))

	data.append("--%s" % boundary)
	data.append('Content-Disposition: form-data; name="time"')
	data.append("")
	data.append("1h")

	data.append("--%s" % boundary)
	data.append('Content-Disposition: form-data; name="fileNameLength"')
	data.append("")
	data.append("16")

	data.append("--%s" % boundary)
	data.append('Content-Disposition: form-data; name="reqtype"')
	data.append("")
	data.append("fileupload")

	data.append("--%s" % boundary)
	data.append('Content-Disposition: form-data; name="fileToUpload"; filename="map.txt"')
	data.append('Content-Type: text/plain')
	data.append("")
	data.append(Marshalls.raw_to_base64(upload_data))
	data.append("--%s--" % boundary)


	request.request("https://litterbox.catbox.moe/resources/internals/api.php", ["Content-Type: multipart/form-data;boundary=%s" % boundary], HTTPClient.METHOD_POST, "\r\n".join(data))

	request.request_completed.connect(func(_result: int, _response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
		var local_url: String = body.get_string_from_utf8()
		print("got map link")
		print("_result")
		print("_response_code")
		temporary_map_link_received.emit(local_url)
	)

	var url: String = await temporary_map_link_received
	request.queue_free()

	print("get url")
	print(url)

	if url.begins_with("http"):
		url_cache[map.map_name] = {
			time = Time.get_unix_time_from_system(),
			url = url
		}
		return url
	else:
		return ""

signal temporary_map_data_received
func get_map_from_url(url: String) -> MapLoader.Map:
	var request: HTTPRequest = HTTPRequest.new()
	self.add_child(request)

	print("requesting url: %s" % url)
	request.request(url)

	request.request_completed.connect(func(_result: int, _response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
		var local_data: PackedByteArray = Marshalls.base64_to_raw(body.get_string_from_ascii())
		print("got map data")
		print(_result)
		print(_response_code)
		print(len(local_data))
		temporary_map_data_received.emit(local_data)
	)

	var raw_data: PackedByteArray = await temporary_map_data_received

	print(len(raw_data))

	var data: Dictionary = bytes_to_var_with_objects(raw_data)


	var map: MapLoader.Map = MapLoader.Map.new()

	map.audio = data.audio
	map.raw_data = data.data
	map.data = MapLoader._parse_data(data.data)

	print("map url debug")
	print(len(data.data))
	print(len(map.data))
	print(map.audio.get_length())

	request.queue_free()

	return map


func get_map_hash(map_name: String) -> PackedByteArray:
	var map_path: String = get_map_file_path_from_name(map_name)

	if len(map_path) == 0 or not FileAccess.file_exists(map_path):
		return []
	var hashing_context: HashingContext = HashingContext.new()
	hashing_context.start(HashingContext.HashType.HASH_SHA256)

	var file: FileAccess = FileAccess.open(map_path,FileAccess.READ)

	while file.get_position() < file.get_length():
		var chunk_size: int = file.get_length() - file.get_position()
		hashing_context.update(file.get_buffer(min(chunk_size, 1024)))

	var hash_data: PackedByteArray = hashing_context.finish()

	return hash_data

func load_map_from_name(map_name: String, ignore_cache: bool = false) -> MapLoader.Map:
	if !ignore_cache and map_cache.has(map_name):
		return map_cache[map_name]

	var map: MapLoader.Map
	var is_sspm: bool = FileAccess.file_exists("user://rhythiamaps/%s.sspm" % map_name)
	if is_sspm:
		map = MapLoader.from_path_sspm("user://rhythiamaps/%s.sspm" % map_name)
	else:
		map = MapLoader.from_path_native("user://maps/%s" % map_name)
	map.map_name = map_name

	map_cache[map_name] = map

	return map

func _ready() -> void:
	#make sure directories exist
	DirAccess.make_dir_absolute("user://maps")
	DirAccess.make_dir_absolute("user://rhythiamaps")

	var raw_settings_data: PackedByteArray = FileAccess.get_file_as_bytes("user://settings.txt")

	if len(raw_settings_data)>=4:
		print("decode")
		var settings_data: Dictionary = bytes_to_var(raw_settings_data)
		for setting: String in settings_data:
			var value: Variant = settings_data[setting]
			settings[setting]=value

	setting_updated.connect(func(setting: String, _old: Variant, new: Variant) -> void:
		match setting:
			"fov":
				get_viewport().get_camera_3d().fov = new
	)

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		print("close")
		var settings_file: FileAccess = FileAccess.open("user://settings.txt",FileAccess.ModeFlags.WRITE_READ)
		print(settings_file.store_buffer(var_to_bytes(encode_class(settings))))
		settings_file.flush()
		settings_file.close()
		await get_tree().process_frame
		get_tree().quit()
