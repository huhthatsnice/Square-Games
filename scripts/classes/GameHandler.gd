extends MultiMeshInstance3D
class_name GameHandler

const cursor_base: PackedScene = preload("res://scenes/prefabs/cursor.tscn")
const note_mesh: ArrayMesh = preload("res://assets/meshes/Rounded.obj")
const note_material: ShaderMaterial = preload("res://assets/materials/note_shader_material.tres")
const hud_base: PackedScene = preload("res://scenes/prefabs/hud.tscn")


const nan_transform: Transform3D = Transform3D(Basis(),Vector3(-2^52,-2^52,-2^52))

var map: MapLoader.Map

var notes: Array[Note]
var allocated_notes: PackedByteArray = []
var cursor: Cursor
var hud: Hud

var max_loaded_notes: int = 0

var last_top_note_id: int = 0

var note_added: int = -1
var note_removed:int = -1

var misses: int = 0 
var hits: int = 0

var last_loaded_note_id: int=0

var ran: bool = false
var stopped: bool = false

var playing: bool = false

var hit_time: float = (SSCS.modifiers.hit_time/1000) * SSCS.modifiers.speed
var hitbox_size: float = SSCS.modifiers.hitbox_size

var approach_time: float = (SSCS.settings.spawn_distance/SSCS.settings.approach_rate) * SSCS.modifiers.speed

var no_fail: bool = SSCS.modifiers.no_fail or SSCS.modifiers.autoplay

var autoplay:bool = SSCS.modifiers.autoplay

var health: float = 5
var reset_timer: int = -1

var autoplay_handler: AutoplayHandler

signal ended

func _init(map_arg: MapLoader.Map) -> void:
	map = map_arg
	
	var max_t: int = ceil(((SSCS.settings.spawn_distance+0.1)/SSCS.settings.approach_rate)*1000) + SSCS.modifiers.hit_time
	var note_counter: PackedInt32Array = []
	
	for v: MapLoader.NoteDataMinimal in map.data:
		var ct: int = v.t
		var to_remove: int = 0
		
		for t in note_counter:
			if ct-t>max_t:
				to_remove += 1
			else:
				break
		
		note_counter = note_counter.slice(to_remove)
		note_counter.append(ct)
		if len(note_counter) > max_loaded_notes:
			max_loaded_notes=len(note_counter)
	max_loaded_notes+=1
	
	allocated_notes.resize(max_loaded_notes)
	allocated_notes.fill(0)
	

func _ready() -> void:
	print(SSCS.modifiers.speed)
	RenderingServer.global_shader_parameter_set("approach_time",approach_time)
	RenderingServer.global_shader_parameter_set("spawn_distance",SSCS.settings.spawn_distance)
	RenderingServer.global_shader_parameter_set("vanish_distance",-SSCS.settings.vanish_distance)
	
	RenderingServer.global_shader_parameter_set("note_begin_transparency",SSCS.settings.note_begin_transparency)
	RenderingServer.global_shader_parameter_set("note_transparency",SSCS.settings.note_transparency)
	RenderingServer.global_shader_parameter_set("note_end_transparency",SSCS.settings.note_end_transparency)
	
	RenderingServer.global_shader_parameter_set("note_fade_in_begin",SSCS.settings.note_fade_in_begin)
	RenderingServer.global_shader_parameter_set("note_fade_in_end",SSCS.settings.note_fade_in_end)
	
	RenderingServer.global_shader_parameter_set("note_fade_out_begin",SSCS.settings.note_fade_out_begin)
	RenderingServer.global_shader_parameter_set("note_fade_out_end",SSCS.settings.note_fade_out_end)
	
	cursor = cursor_base.instantiate()
	self.add_child(cursor)
	
	hud = hud_base.instantiate()
	self.add_child(hud)
	
	if autoplay:
		autoplay_handler = AutoplayHandler.new(map,cursor)
	
	self.multimesh = MultiMesh.new()
	
	update_note_mesh(note_mesh)
	self.multimesh.transform_format=MultiMesh.TRANSFORM_3D
	self.multimesh.use_custom_data=true
	
	self.multimesh.instance_count=max_loaded_notes
	self.multimesh.visible_instance_count=1


#region note creation and deletion

func spawn_note(note_id: int, pos: Vector2, t: float) -> Note:
	
	var new_index: int = allocated_notes.find(0,0)
	
	if new_index>note_added:
		note_added=new_index
	
	allocated_notes[new_index]=1
	var new_note:Note = Note.new(note_id, pos, t, multimesh, new_index)
	#self.add_child(new_note)
	
	return new_note

func remove_note(note: Note) -> void:
	var index:int = note.multimesh_index
	if index>note_removed:
		note_removed=index
	
	allocated_notes[index]=0
	multimesh.set_instance_transform(index,nan_transform)
	
	note.queue_free()


func update_note_mesh(mesh: Mesh) -> void:
	var new_note_mesh: Mesh = mesh.duplicate()
	
	new_note_mesh.surface_set_material(0,note_material)
	self.multimesh.mesh=new_note_mesh

#endregion
#region time control

func play(from: float) -> void:
	assert(not ran, "Tried to run game manager more than once")
	ran = true
	
	Input.mouse_mode=Input.MOUSE_MODE_CONFINED_HIDDEN
	cursor.pos=Vector2()
	cursor.update_position()
	playing = true
	AudioManager.set_stream(map.audio)
	AudioManager.set_playback_speed(SSCS.modifiers.speed)
	AudioManager.play(from - 1)
	
	var threshold: int = ceil( (AudioManager.elapsed + approach_time) * 1000)
	while last_loaded_note_id<len(map.data):
		var note_data: MapLoader.NoteDataMinimal = map.data[last_loaded_note_id]
		if note_data.t <= threshold:
			last_loaded_note_id += 1
		else:
			break

func stop() -> void:
	assert(not stopped, "Tried to stop game manager more than once")
	stopped = true
	
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	ended.emit()
	playing = false
	AudioManager.full_stop()

func pause() -> void:
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	playing = false
	AudioManager.stop()
	#Input.warp_mouse(get_viewport().get_camera_3d().unproject_position(cursor.position))

func unpause() -> void:
	Input.mouse_mode=Input.MOUSE_MODE_CONFINED_HIDDEN
	playing = true
	AudioManager.resume()

#endregion
#region note functionality

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
	if (health==0 and !no_fail) or (AudioManager.elapsed > map.data[-1].t/1000.0):
		stop()

var last_load:float = 0
func _load_notes() -> void:
	var threshold: int = ceil( (AudioManager.elapsed + approach_time) * 1000)
	while last_loaded_note_id<len(map.data):
		var note_data: MapLoader.NoteDataMinimal = map.data[last_loaded_note_id]
		if note_data.t <= threshold:
			var note:Note = spawn_note(last_loaded_note_id, Vector2(note_data.x,note_data.y), float(note_data.t)/1000)
			notes.append(note)
			
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
				var diff: Vector2 = (note.pos-cursor.pos).abs()

				if max(diff.x,diff.y)<hitbox_size:
					_register_hit()
					
					to_remove.append(i)
		else:
			break
	
	var shift: int = 0
	for v in to_remove:
		var note: Note = notes.pop_at(v-shift)
		remove_note(note)
		shift+=1

func _process(_dt: float) -> void:
	if not playing or stopped: return
	if autoplay:
		cursor.pos=autoplay_handler.get_cursor_position()
		cursor.update_position()
	_load_notes()
	_check_hitreg()
	_check_death()
	
	if note_added>last_top_note_id:
		last_top_note_id = note_added
		self.multimesh.visible_instance_count=note_added+1
	if note_removed==last_top_note_id:
		var top_note_id: int = allocated_notes.rfind(1)
		last_top_note_id=top_note_id
		self.multimesh.visible_instance_count=top_note_id+1
		hud.update_info_right(hits,misses)
	
	if Input.is_action_pressed(&"reset"):
		if reset_timer == -1:
			reset_timer=Time.get_ticks_msec()
		elif Time.get_ticks_msec()-reset_timer > 500:
			stop()
	elif reset_timer != -1:
		reset_timer = -1

#endregion

func _input(event: InputEvent) -> void:
	if event.is_action_pressed(&"pause"):
		if playing:
			pause()
		else:
			unpause()
