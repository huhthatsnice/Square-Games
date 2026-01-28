extends Sprite3D
class_name Cursor

var pos: Vector2 = Vector2(0,0)
var pos_world: Vector3 = Vector3(0,0,0)
var camera: Camera3D

const GRID_MAX = (3-0.28)/2 #(grid size - cursor size) / 2

var screen_center: Vector2 = DisplayServer.window_get_size()/2

var grid_distance: float = SSCS.settings.grid_distance
var pixels_per_grid_unit: float = SSCS.settings.pixels_per_grid_unit
var inverted_pixels_per_grid_unit: float = 1/pixels_per_grid_unit
var parallax: float = SSCS.settings.parallax
var absolute: bool = SSCS.settings.absolute_input

var semi_spin: bool = SSCS.settings.semi_spin

var accepts_input: bool = true

func update_position() -> void:
	pos_world.x=pos.x
	pos_world.y=pos.y
	self.position=pos_world
	camera.position=Vector3(pos.x*parallax,pos.y*parallax,0)

func _ready() -> void:
	var texture_size: Vector2 = self.texture.get_size()
	scale = (Vector3(texture_size.x,texture_size.y,1)*self.pixel_size).inverse() * Vector3(0.28,0.28,1.0)
	#print(self.scale)

	camera = $"/root/Game/Camera"

	pos_world = Vector3(pos.x,pos.y,grid_distance)
	position = pos_world
	camera.position = Vector3(pos.x*parallax,pos.y*parallax,0)

	if semi_spin:
		camera.look_at(position)

func _input(event: InputEvent) -> void:
	if !accepts_input: return
	if event is InputEventMouseMotion:
		if absolute:
			pos = ((screen_center - event.position) * inverted_pixels_per_grid_unit).clampf(-GRID_MAX, GRID_MAX)
		else:
			pos -= event.relative * inverted_pixels_per_grid_unit
			pos = pos.clampf(-GRID_MAX, GRID_MAX)

		pos_world.x = pos.x
		pos_world.y = pos.y
		position = pos_world
		camera.position = Vector3(pos.x*parallax, pos.y*parallax, 0)

		if semi_spin:
			camera.look_at(position)
