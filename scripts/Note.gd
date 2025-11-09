extends MeshInstance3D
class_name Note

var note_id:int = 0
var color:Color
var pos:Vector2
var t:float

func _ready() -> void:
	if color==null:
		color=SSCS.derived.ColorSet[note_id%len(SSCS.derived.ColorSet)]
	
	var material:StandardMaterial3D = self.get_surface_override_material(0).duplicate()
	
	material.albedo_color = color
	
	self.set_surface_override_material(0, material)
