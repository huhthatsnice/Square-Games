extends Node
class_name AutoplayHandler

var map: MapLoader.Map

var processed_data: Array[MapLoader.NoteDataMinimal] = []

const max_shift_multi: float = 0.25

var cursor: Cursor

var max_range: float = SSCS.modifiers.hitbox_size*max_shift_multi

var last_loaded_note: int = 0

func _init(map_arg: MapLoader.Map, cursor_arg: Cursor) -> void:
	self.map = map_arg
	self.cursor = cursor_arg
	
	var i: int = 0
	
	var notes: Array[MapLoader.NoteDataMinimal] = map.data
	var notes_len: int = len(notes)
	
	var preprocessed_data: Array[MapLoader.NoteDataMinimal] = []
	
	print("begin initial preprocessing")
	#initial preprocessing
	while i < notes_len:
		var v: MapLoader.NoteDataMinimal = notes[i]
		i += 1
		
		var collected: Array[MapLoader.NoteDataMinimal] = [v]
		
		while i < notes_len:
			var v2: MapLoader.NoteDataMinimal = notes[i]
			if v2 and abs(v2.t-v.t) <= 3 and max(abs(v2.x-v.x),abs(v2.y-v.y)) < 1*1:
				collected.append(v2)
				i += 1
			else:
				break
		
		var avg_pos: Vector2 = Vector2()
		
		for note: MapLoader.NoteDataMinimal in collected:
			avg_pos += Vector2(note.x,note.y)
		avg_pos /= len(collected)
		
		preprocessed_data.append(MapLoader.NoteDataMinimal.new(avg_pos.x,avg_pos.y,v.t))
	
	#shift preprocessing
	i = 0
	var preprocessed_data_len: int = len(preprocessed_data)
	
	print("begin shift preprocessing")

	while i+1<preprocessed_data_len:
		
		var note_0: MapLoader.NoteDataMinimal = preprocessed_data[max(i-2,0)]
		var note_1: MapLoader.NoteDataMinimal = preprocessed_data[max(i-1,0)]
		var note_2: MapLoader.NoteDataMinimal = preprocessed_data[i]
		var note_3: MapLoader.NoteDataMinimal = preprocessed_data[i+1]
		var note_4: MapLoader.NoteDataMinimal = preprocessed_data[min(i+2,preprocessed_data_len-1)]
		
		var pos: Vector2 = SplineManager._get_position(note_0,note_1,note_3,note_4,note_2.t)
		
		var shift_vec: Vector2 = pos - Vector2(note_2.x,note_2.y)
		
		if shift_vec.x==0 or shift_vec.y==0:
			shift_vec = shift_vec.clampf(-max_range,max_range)
		else:
			shift_vec = shift_vec * clamp(shift_vec.x, -max_range, max_range)/shift_vec.x
			shift_vec = shift_vec * clamp(shift_vec.y, -max_range, max_range)/shift_vec.y
		
		
		var new_note: MapLoader.NoteDataMinimal = MapLoader.NoteDataMinimal.new(note_2.x+shift_vec.x, note_2.y+shift_vec.y, note_2.t)
		
		processed_data.append(new_note)
		i += 1

func get_cursor_position() -> Vector2:
	var elapsed: int = AudioManager.elapsed*1000.0
	while last_loaded_note+1<len(processed_data):
		var note: MapLoader.NoteDataMinimal = processed_data[last_loaded_note+1]
		if note.t>elapsed:
			break
		else:
			last_loaded_note+=1
	
	var note_0: MapLoader.NoteDataMinimal = processed_data[max(last_loaded_note-1,0)]
	var note_1: MapLoader.NoteDataMinimal = processed_data[last_loaded_note]
	var note_2: MapLoader.NoteDataMinimal = processed_data[min(last_loaded_note+1,len(processed_data)-1)]
	var note_3: MapLoader.NoteDataMinimal = processed_data[min(last_loaded_note+2,len(processed_data)-1)]
	
	var return_pos: Vector2 = SplineManager._get_position(note_0, note_1, note_2, note_3, elapsed).clampf(-cursor.GRID_MAX,cursor.GRID_MAX)
	
	return return_pos
	
