extends Node3D

class Settings:
	var approach_rate: float = 50.0
	var spawn_distance: float = 25.0
	var color_set: Array[Color] = [
		Color.from_string("#ffffff", Color.WHITE),
		Color.from_string("#66ffff", Color.WHITE),
	]
	var grid_distance:float = 5
	var vanish_distance:float = 0.2
	var pixels_per_grid_unit:int = 80

class Modifiers:
	var hit_time:float = 50
	var hitbox_size:float = 1.28/2
	var speed:float = 1

var settings: Settings = Settings.new()
var modifiers: Modifiers = Modifiers.new()
func _ready() -> void:
	#make sure directories exist
	DirAccess.make_dir_absolute("user://maps")
