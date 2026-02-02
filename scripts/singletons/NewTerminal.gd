extends Control

#@onready var noise_texture: NoiseTexture2D = $"./Background".material.get_shader_parameter("noise_texture")
#@onready var noise: FastNoiseLite = noise_texture.noise
#
#func _ready() -> void:
	#var viewport_size: Vector2 = get_viewport_rect().size
	#noise_texture.width = viewport_size.x
	#noise_texture.height = viewport_size.y

#func _process(delta: float) -> void:
	#noise.offset += Vector3(0, 0, 1) * delta * 1
