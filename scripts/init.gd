extends Control


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
			SSCS.settings[setting]=value

	SSCS.setting_updated.connect(func(setting: String, _old: Variant, new: Variant) -> void:
		match setting:
			"fov":
				get_viewport().get_camera_3d().fov = new
	)

	get_tree().change_scene_to_file("res://scenes/game.tscn")
