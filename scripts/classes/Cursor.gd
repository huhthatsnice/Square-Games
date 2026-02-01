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

var true_spin: bool = SSCS.settings.true_spin

var hit_plane: Plane = Plane(Vector3(0, 0, 1), Vector3(0, 0, SSCS.settings.grid_distance))

var cursor_scale: float = SSCS.settings.cursor_scale

func update_position() -> void:
	pos_world.x=pos.x
	pos_world.y=pos.y
	self.position=pos_world
	camera.position=Vector3(pos.x*parallax,pos.y*parallax,0)

func _ready() -> void:
	var custom_cursor_resource: String = SSCS.get_arbitrary_exension("user://cursor", ["png","jpg"])
	if !custom_cursor_resource.is_empty():
		self.texture = ImageTexture.create_from_image(SSCS.load_image(custom_cursor_resource))
		print("yeah i found an image")
	var texture_size: Vector2 = self.texture.get_size()
	scale = (Vector3(texture_size.x,texture_size.y,1)*self.pixel_size).inverse() * Vector3(0.28,0.28,1.0) * cursor_scale
	#print(self.scale)

	camera = $"/root/Game/Camera"

	pos_world = Vector3(pos.x,pos.y,grid_distance)
	position = pos_world
	camera.position = Vector3(pos.x*parallax,pos.y*parallax,0)

	camera.look_at(Vector3(0, 0, 1))
	if semi_spin:
		camera.look_at(position)

func _input(event: InputEvent) -> void:
	if !accepts_input: return
	if event is InputEventMouseMotion:
		if true_spin:
			var mouse_rotation: Vector3 = Vector3(-event.relative.y, -event.relative.x, 0) * inverted_pixels_per_grid_unit
			camera.rotation += mouse_rotation
			var intersection: Vector3 = hit_plane.intersects_ray(camera.position, -camera.basis.z)

			if intersection != null:
				pos_world = intersection.clamp(Vector3(-GRID_MAX, -GRID_MAX, -INF), Vector3(GRID_MAX, GRID_MAX, INF))

				pos.x = pos_world.x
				pos.y = pos_world.y

				position = pos_world

				camera.look_at_from_position(Vector3(pos.x*parallax, pos.y*parallax, 0), pos_world)

		else:
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
