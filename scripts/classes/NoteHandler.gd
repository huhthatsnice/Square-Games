extends Node3D
class_name NoteHandler

var notes: Array[Note] = []
const note_base: PackedScene = preload("res://scenes/prefabs/note.tscn")


static func create_note(pos: Vector2, t: float) -> void:
	var new_note: Note = note_base.instantiate()

	new_note.pos = pos
	new_note.t = t

func check() -> void:
	for note: Note in notes:
		pass
