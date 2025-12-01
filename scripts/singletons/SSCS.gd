extends Node

## any setting which is related to track position is on a scale of 0-1 where 0 is hitting the grid and 1 is freshly spawned

class Settings:
	var approach_rate: float = 50.0
	var spawn_distance: float = 25.0
	var color_set: Array[Color] = [
		Color.from_string("#ffffff", Color.WHITE),
		Color.from_string("#66ffff", Color.WHITE),
	]
	var grid_distance: float = 4
	var vanish_distance: float = 0.2
	var pixels_per_grid_unit: float = 80.0
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

class Modifiers:
	var hit_time: float = 45.0
	var hitbox_size: float = 1.28/2
	var speed: float = 1
	var no_fail: bool = true
	var autoplay: bool = false

signal setting_updated(setting: String, old_value: Variant, new_value: Variant)
signal modifier_updated(modifier: String, old_value: Variant, new_value: Variant)

var settings: Settings = Settings.new()
var modifiers: Modifiers = Modifiers.new()
var lobby: Lobby

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

func _ready() -> void:
	#make sure directories exist
	DirAccess.make_dir_absolute("user://maps")
	
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
