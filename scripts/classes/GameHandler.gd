extends Node3D
class_name GameHandler

const note_base: PackedScene = preload("res://scenes/prefabs/note.tscn")
const note_mesh: ArrayMesh = preload("res://assets/meshes/Rounded.obj")

var map: MapLoader.Map

var notes: Array[Note]
var cursor: Cursor

var misses: int = 0 
var hits: int = 0

var last_loaded_note_id: int=0

var ran: bool = false
var stopped: bool = false

var playing: bool = false

var hit_time: float = SSCS.modifiers.hit_time/1000
var hitbox_size: float = SSCS.modifiers.hitbox_size

var approach_time: float = SSCS.settings.spawn_distance/SSCS.settings.approach_rate

var health: float = 5

signal ended

func _init(map_arg: MapLoader.Map) -> void:
	map = map_arg

func _ready() -> void:
	cursor = $"../Cursor"

func play() -> void:
	assert(not ran, "Tried to run game manager more than once")
	ran = true
	
	Input.mouse_mode=Input.MOUSE_MODE_CONFINED_HIDDEN
	cursor.pos=Vector2()
	cursor.update_position()
	playing = true
	AudioManager.set_stream(map.audio)
	AudioManager.set_playback_speed(SSCS.modifiers.speed)
	AudioManager.play(0)

func stop() -> void:
	assert(not stopped, "Tried to stop game manager more than once")
	stopped = true
	
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	ended.emit()
	playing = false
	AudioManager.stop()

func pause() -> void:
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	playing = false
	AudioManager.stop()
	#Input.warp_mouse(get_viewport().get_camera_3d().unproject_position(cursor.position))

func unpause() -> void:
	Input.mouse_mode=Input.MOUSE_MODE_CONFINED_HIDDEN
	playing = true
	AudioManager.resume()

func _register_hit() -> void:
	#print('hit')
	hits+=1
	health=clamp(health+0.5,0,5)
	#print(health)

func _register_miss() -> void:
	#print('miss')
	misses+=1
	health=clamp(health-1,0,5)
	#print(health)

func _check_death() -> void:
	if health==0:
		stop()

var last_load:float = 0
func _load_notes() -> void:
	while last_loaded_note_id<len(map.data):
		var note_data: MapLoader.NoteDataMinimal = map.data[last_loaded_note_id]
		if float(note_data.t)/1000 <= AudioManager.elapsed+approach_time:
			var note:Note = Note.new(last_loaded_note_id, Vector2(note_data.x, note_data.y), float(note_data.t)/1000, note_mesh)
			notes.append(note)
			self.add_child(note)
			last_loaded_note_id += 1
		else:
			break
	
	#debug loader, just loads a string of notes at 10 notes per second
	#if AudioManager.elapsed-0.1>last_load:
		#last_load = AudioManager.elapsed
		#var note:Note = Note.new(last_loaded_note_id, Vector2(0, 0), AudioManager.elapsed+approach_time, note_mesh)
		#notes.append(note)
		#self.add_child(note)
		#last_loaded_note_id += 1


func _check_hitreg() -> void:
	var elapsed: float = AudioManager.elapsed

	var to_remove: PackedInt32Array = []
	var i: int = -1
	for note: Note in notes:
		i+=1
		if note.t<elapsed:
			if note.t<elapsed-hit_time:
				_register_miss()
				
				to_remove.append(i)
			else:
				var diff:Vector2 = (note.pos-cursor.pos).abs()

				if max(diff.x,diff.y)<hitbox_size:
					_register_hit()
					
					to_remove.append(i)
		else:
			break
	
	var shift: int = 0
	for v in to_remove:
		var note:Note = notes.pop_at(v-shift)
		note.queue_free()
		shift+=1

#func _update_render() -> void:
	#for note: Note in notes:
		#note._render(AudioManager.elapsed)

func _process(_dt:float) -> void:
	if not playing or stopped: return
	_load_notes()
	_check_hitreg()
	#_check_death()
	#_update_render()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed(&"pause"):
		if playing:
			pause()
		else:
			unpause()
