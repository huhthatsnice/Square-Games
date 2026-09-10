extends Node
class_name Note

#const note_material: ShaderMaterial = preload("res://assets/materials/note_shader_material.tres")

var note_id: int = 0
var color: Color
var pos: Vector2
var t: float
var multimesh: MultiMesh
var multimesh_index: int
var note_transform: Transform3D
var dead: bool

var color_set: Array = SSCS.settings.color_set
var color_set_len: int = len(color_set)
var grid_distance:float = SSCS.settings.grid_distance

var note_scale: float = SSCS.settings.note_scale

@warning_ignore("shadowed_variable")
func _init(multimesh: MultiMesh) -> void:
	self.multimesh = multimesh

	#guaruntees note's absolute size will be the Vector3 on the right
	var aabb:AABB = multimesh.mesh.get_aabb()

	var basis: Basis = Basis.from_scale(aabb.size.inverse() * Vector3(1,1,0.2) * note_scale)

	note_transform=Transform3D(basis, Vector3())


func initialize(note_id_arg: int, pos_arg: Vector2, t_arg: float, multimesh_index_arg: int) -> void:
	note_id=note_id_arg
	pos=pos_arg
	t=t_arg
	multimesh_index=multimesh_index_arg
	
	dead = false

	color = color_set[note_id % color_set_len]

	note_transform.origin = Vector3(pos.x,pos.y,grid_distance)
	
	multimesh.set_instance_transform(multimesh_index, note_transform)
	multimesh.set_instance_custom_data(multimesh_index, Color(color,t))

func reinitialize() -> void:
	dead = false

	note_transform.origin = Vector3(pos.x,pos.y,grid_distance)
	
	multimesh.set_instance_transform(multimesh_index, note_transform)
	multimesh.set_instance_custom_data(multimesh_index, Color(color,t))

const invisible_transform: Transform3D = Transform3D(Basis(Vector3(), Vector3(), Vector3()), Vector3(-2^52, -2^52, -2^52))

func deinitialize() -> void:
	multimesh.set_instance_transform(multimesh_index, invisible_transform)
	dead = true
