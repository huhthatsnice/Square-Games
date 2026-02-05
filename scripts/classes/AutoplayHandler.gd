extends Node
class_name AutoplayHandler

var map: MapLoader.Map

var processed_data: Array[MapLoader.NoteDataMinimal] = []

const max_shift_multi: float = 0.25

var cursor: Cursor

var max_range: float = SSCS.modifiers.hitbox_size*max_shift_multi

var last_loaded_note: int = 0

static func _check_hit(note_pos: Variant, cursor_pos: Variant, size: float) -> bool:
	if typeof(note_pos) != TYPE_VECTOR2:
		note_pos = Vector2(note_pos.x, note_pos.y)
	if typeof(cursor_pos) != TYPE_VECTOR2:
		cursor_pos = Vector2(cursor_pos.x, cursor_pos.y)

	var diff: Vector2 = (note_pos - cursor_pos).abs()

	return max(diff.x, diff.y) < size

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

		if i > 1:
			var prev_data: MapLoader.NoteDataMinimal = preprocessed_data[-1]
			var prev_data_pos: Vector2 = Vector2(prev_data.x, prev_data.y)

			var time_elapsed: float = abs(prev_data.t - v.t) / 1000.0

			var speed: float = (prev_data_pos - avg_pos).length() / (time_elapsed * 100)
			avg_pos *= 0.8 + (sigmoid(speed * 5) - 0.5) * 2 * 0.2

			if i > 2:
				var prev_prev_data: MapLoader.NoteDataMinimal = preprocessed_data[-2]
				var prev_prev_data_pos: Vector2 = Vector2(prev_prev_data.x, prev_prev_data.y)

				var dir_1: Vector2 = (prev_data_pos - prev_prev_data_pos).normalized()
				var dir_2: Vector2 = (avg_pos - prev_data_pos).normalized()

				avg_pos *= 1 + (max(-dir_1.dot(dir_2) - 0.5, 0) * (1 / (time_elapsed * 20 + 1)))

		var new_note_data: MapLoader.NoteDataMinimal = MapLoader.NoteDataMinimal.new()
		new_note_data.x = avg_pos.x
		new_note_data.y = avg_pos.y
		new_note_data.t = v.t

		preprocessed_data.append(new_note_data)

	print("begin aggressive stack compressing")
	i = 2

	var preprocessed_data_len: int = len(preprocessed_data)

	var secondary_preprocessed_data: Array[MapLoader.NoteDataMinimal] = []

	if preprocessed_data_len > 5:

		secondary_preprocessed_data.append(preprocessed_data[0])
		secondary_preprocessed_data.append(preprocessed_data[1])

		while i + 3 < preprocessed_data_len:

			var stack_length: int = 1

			var top_note: MapLoader.NoteDataMinimal = preprocessed_data[i]
			var top_note_i: int = i
			i += 1
			#secondary_preprocessed_data.append(top_note)

			while i + 2 < preprocessed_data_len:
				var next_note: MapLoader.NoteDataMinimal = preprocessed_data[i]
				i += 1
				if _check_hit(next_note, top_note, 0.1):
					stack_length += 1
				else:
					break
			i -= 1

			if stack_length > 1:
				print("stack found ", top_note.t)
				print(stack_length)

				var prev_note_2: MapLoader.NoteDataMinimal = preprocessed_data[top_note_i - 2]
				var prev_note_1: MapLoader.NoteDataMinimal = preprocessed_data[top_note_i - 1]

				var end_note: MapLoader.NoteDataMinimal = preprocessed_data[i-1]

				var past_note_1: MapLoader.NoteDataMinimal = preprocessed_data[i]
				var past_note_2: MapLoader.NoteDataMinimal = preprocessed_data[i + 1]

				var tests: Array[MapLoader.NoteDataMinimal] = []

				var new_note_1: MapLoader.NoteDataMinimal = MapLoader.NoteDataMinimal.new()
				new_note_1.x = top_note.x
				new_note_1.y = top_note.y
				new_note_1.t = floor((top_note.t + end_note.t) / 2.0)
				tests.append(new_note_1)

				var new_note_2: MapLoader.NoteDataMinimal = MapLoader.NoteDataMinimal.new()
				new_note_2.x = top_note.x
				new_note_2.y = top_note.y
				new_note_2.t = top_note.t
				tests.append(new_note_2)

				var new_note_3: MapLoader.NoteDataMinimal = MapLoader.NoteDataMinimal.new()
				new_note_3.x = top_note.x
				new_note_3.y = top_note.y
				new_note_3.t = end_note.t
				tests.append(new_note_3)

				var valid: bool = false

				#for new_note: MapLoader.NoteDataMinimal in tests:
					#if _check_hit(top_note, SplineManager._get_position(prev_note_2, prev_note_1, new_note, past_note_1, top_note.t), SSCS.modifiers.hitbox_size) and _check_hit(end_note, SplineManager._get_position(prev_note_1, new_note, past_note_1, past_note_2, end_note.t), SSCS.modifiers.hitbox_size):
						#secondary_preprocessed_data.append(new_note)
						#print("merge")
						#valid = true
						#break

				if !valid:
					print("stackify")
					secondary_preprocessed_data.append(top_note)
					secondary_preprocessed_data.append(top_note)

					secondary_preprocessed_data.append(end_note)
					secondary_preprocessed_data.append(end_note)

					#for i2: int in range(top_note_i, i):
						#print("add")
						#secondary_preprocessed_data.append(preprocessed_data[i2])
						#secondary_preprocessed_data.append(preprocessed_data[i2])
			else:
				secondary_preprocessed_data.append(top_note)

		secondary_preprocessed_data.append(preprocessed_data[-1])
		secondary_preprocessed_data.append(preprocessed_data[-2])
	else:
		secondary_preprocessed_data = preprocessed_data

	#shift preprocessing
	i = 0
	var secondary_preprocessed_data_len: int = len(secondary_preprocessed_data)
	print(secondary_preprocessed_data_len)

	print("begin shift preprocessing")



	while i+1<secondary_preprocessed_data_len:

		var note_0: MapLoader.NoteDataMinimal = secondary_preprocessed_data[max(i-2,0)]
		var note_1: MapLoader.NoteDataMinimal = secondary_preprocessed_data[max(i-1,0)]
		var note_2: MapLoader.NoteDataMinimal = secondary_preprocessed_data[i]
		var note_3: MapLoader.NoteDataMinimal = secondary_preprocessed_data[i+1]
		var note_4: MapLoader.NoteDataMinimal = secondary_preprocessed_data[min(i+2,secondary_preprocessed_data_len-1)]

		var pos: Vector2 = SplineManager._get_position(note_0,note_1,note_3,note_4,note_2.t)

		var shift_vec: Vector2 = pos - Vector2(note_2.x,note_2.y)

		if shift_vec.x==0 or shift_vec.y==0:
			shift_vec = shift_vec.clampf(-max_range,max_range)
		else:
			shift_vec = shift_vec * clamp(shift_vec.x, -max_range, max_range)/shift_vec.x
			shift_vec = shift_vec * clamp(shift_vec.y, -max_range, max_range)/shift_vec.y

		var new_note: MapLoader.NoteDataMinimal = MapLoader.NoteDataMinimal.new()

		new_note.x = note_2.x+shift_vec.x
		new_note.y = note_2.y+shift_vec.y
		new_note.t = note_2.t

		if _check_hit(SplineManager._get_position(note_1, new_note, note_3, note_4, new_note.t), note_2, SSCS.modifiers.hitbox_size):
			processed_data.append(new_note)
		else:
			processed_data.append(note_2)
		i += 1

	processed_data.append(preprocessed_data[-1])

	#processed_data = secondary_preprocessed_data


func get_cursor_position() -> Vector2:
	var elapsed: int = int(AudioManager.elapsed*1000.0)
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
