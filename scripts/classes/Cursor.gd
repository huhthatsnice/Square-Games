extends Sprite3D
class_name Cursor

var pos:Vector2 = Vector2(0,0)

const gridMax = Vector2(3,3)/2

var grid_distance:float = SSCS.settings.grid_distance

func _ready() -> void:
	var texture_size:Vector2 = self.texture.get_size()
	self.scale=(Vector3(texture_size.x,texture_size.y,1)*self.pixel_size).inverse() * Vector3(0.28,0.28,1)
	print(self.scale)
	update_position()

func update_position() -> void:
	self.position=Vector3(pos.x,pos.y,grid_distance)


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		pos = (pos+(-event.relative)/SSCS.settings.pixels_per_grid_unit).clamp(-gridMax,gridMax)
		update_position()
