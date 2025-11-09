extends Node3D
class_name NoteHandler

var notes:Array=[]
const note_base:PackedScene = preload("res://scenes/prefabs/note.tscn")


static func create_note(p:Vector2,t:float):
	var newNote:Note = NoteBase.instantiate()
	
	newNote.pos=p
	newNote.t=t

static func check() -> void:
	for note:Note in Notes:
