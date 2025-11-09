extends MeshInstance3D
class_name Note

var color:Color = Color.WHITE
var x:float
var y:float
var t:float

func _ready() -> void:
	var material:StandardMaterial3D = self.get_surface_override_material(0).duplicate()
	
	material.albedo_color = color
	
	self.set_surface_override_material(0, material)
	
