extends MeshInstance3D
class_name Note

const note_material: ShaderMaterial = preload("res://assets/materials/note_shader_material.tres")

var note_id: int = 0
var color: Color
var color_assigned:bool = false
var pos: Vector2
var t: float

var color_set:Array[Color]=SSCS.settings.color_set

var approach_rate:float = SSCS.settings.approach_rate
var spawn_distance:float = SSCS.settings.spawn_distance
var approach_time:float = spawn_distance/approach_rate

var vanish_distance:float = -SSCS.settings.vanish_distance
var grid_distance:float = SSCS.settings.grid_distance

var has_vanished:bool = false

var note_mesh: Mesh

func _init(note_id_arg: int, pos_arg: Vector2, t_arg: float, note_mesh_arg: Mesh) -> void:
	note_id=note_id_arg
	pos=pos_arg
	t=t_arg
	note_mesh = note_mesh_arg
	
func _ready() -> void:
	if not color_assigned:
		color_assigned = true
		color = color_set[note_id % len(color_set)]
	
	self.set_instance_shader_parameter("note_time",t)
	self.set_instance_shader_parameter("note_color",Vector3(color.r,color.g,color.b))
	
	self.mesh=note_mesh
	self.set_surface_override_material(0,note_material.duplicate())
	
	self.position=Vector3(pos.x,pos.y,grid_distance)
	
	#var material: StandardMaterial3D = self.get_surface_override_material(0)
	#material.albedo_color = color
	
	#guaruntees note's absolute size will be the Vector3 on the right
	var aabb:AABB = self.get_aabb()
	
	self.scale = aabb.size.inverse() * Vector3(1,1,0.2)
	

#func _render(ct: float) -> void:
	#if has_vanished: return
	#
	#var time_til_hit: float = t-ct
	#
	#var note_lerp: float = (time_til_hit/approach_time)
#
	#var new_pos: float = spawn_distance*note_lerp
	#
	#if new_pos < vanish_distance:
		#has_vanished=true
		#self.transparency=1
		#return
	#
	#self.position=Vector3(pos.x,pos.y,grid_distance+new_pos)
