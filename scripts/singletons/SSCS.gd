extends Node3D

class Settings:
	var approach_rate: float = 100.0
	var spawn_distance: float = 50.0
	var color_set: Array[Color] = [
		Color.from_string("#ffffff", Color.WHITE),
		Color.from_string("#80ff80", Color.WHITE),
	]

var settings: Settings = Settings.new()

func _ready() -> void:
	pass
