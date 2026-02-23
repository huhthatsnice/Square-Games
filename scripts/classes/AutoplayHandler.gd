extends Node
class_name AutoplayHandler

var map: MapLoader.Map

var processed_data: Array[Array] = []

const max_shift_multi: float = 0.25

var cursor: Cursor

var max_range: float = SSCS.modifiers.hitbox_size*max_shift_multi

var last_loaded_note: int = 0

static func _check_hit(note_pos: Variant, cursor_pos: Variant, size: float) -> bool:
	if typeof(note_pos) != TYPE_VECTOR2:
		note_pos = Vector2(note_pos[0], note_pos[1])
	if typeof(cursor_pos) != TYPE_VECTOR2:
		cursor_pos = Vector2(cursor_pos[0], cursor_pos[1])

	var diff: Vector2 = (note_pos - cursor_pos).abs()

	return max(diff.x, diff.y) < size

func _init(map_arg: MapLoader.Map, cursor_arg: Cursor) -> void:
	self.map = map_arg
	self.cursor = cursor_arg

	var i: int = 0

	var notes: Array[Array] = map.data.duplicate(true)
	var notes_len: int = len(notes)

	for note: Array in notes:
		note[2] /= SSCS.modifiers.speed

	var preprocessed_data: Array[Array] = []

	print("begin initial preprocessing")
	#initial preprocessing
	while i < notes_len:
		var v: Array = notes[i]
		i += 1

		var collected: Array[Array] = [v]

		while i < notes_len:
			var v2: Array = notes[i]
			if v2 and abs(v2[2] - v[2]) <= 5 and _check_hit(v, v2, SSCS.modifiers.hitbox_size * 0.9):
				collected.append(v2)
				i += 1
			else:
				break

		var avg_pos: Vector2 = Vector2()

		for note: Array in collected:
			avg_pos += Vector2(note[0], note[1])
		avg_pos /= len(collected)

		if i > 1:
			var prev_data: Array = preprocessed_data[-1]
			var prev_data_pos: Vector2 = Vector2(prev_data[0], prev_data[1])

			var time_elapsed: float = abs(prev_data[2] - v[2]) / 1000.0

			var speed: float = (prev_data_pos - avg_pos).length() / (time_elapsed * 100)
			avg_pos *= 0.8 + (sigmoid(speed * 5) - 0.5) * 2 * 0.2

			if i > 2 and len(preprocessed_data) >= 2:
				var prev_prev_data: Array = preprocessed_data[-2]
				var prev_prev_data_pos: Vector2 = Vector2(prev_prev_data[0], prev_prev_data[1])

				var dir_1: Vector2 = (prev_data_pos - prev_prev_data_pos).normalized()
				var dir_2: Vector2 = (avg_pos - prev_data_pos).normalized()

				avg_pos *= 1 + (max(-dir_1.dot(dir_2) - 0.5, 0) * (1 / (time_elapsed * 20 + 1)))

		var new_note_data: Array = [
			avg_pos.x,
			avg_pos.y,
			v[2]
		]

		var v_prev: Array = notes[i - 2]
		if v_prev != null and len(collected) == 1 and v[0] == v_prev[0] and v[1] == v_prev[1] and len(preprocessed_data) > 0:
			print("stack old avg")
			new_note_data[0] = preprocessed_data[-1][0]
			new_note_data[1] = preprocessed_data[-1][1]

		preprocessed_data.append(new_note_data)

	print("begin aggressive stack compressing")
	i = 2

	var preprocessed_data_len: int = len(preprocessed_data)

	var secondary_preprocessed_data: Array[Array] = []

	if preprocessed_data_len > 5 and true:

		secondary_preprocessed_data.append(preprocessed_data[0])
		secondary_preprocessed_data.append(preprocessed_data[1])

		var merged: bool = false
		while i + 3 < preprocessed_data_len:

			var stack_length: int = 1

			var top_note: Array = preprocessed_data[i]
			var top_note_i: int = i
			i += 1
			#secondary_preprocessed_data.append(top_note)

			while i + 2 < preprocessed_data_len:
				var next_note: Array = preprocessed_data[i]
				i += 1
				if _check_hit(next_note, top_note, 0.1):
					stack_length += 1
				else:
					break
			i -= 1

			if stack_length > 1:
				print("stack found ", top_note[2])
				print(stack_length)

				var end_note: Array = preprocessed_data[i-1]

				var valid: bool = false

				if !valid:
					print("stackify")
					secondary_preprocessed_data.append(top_note)
					var top_note_shifted: Array = top_note.duplicate()
					top_note_shifted[2] += 10
					secondary_preprocessed_data.append(top_note_shifted)

					var end_note_shifted: Array = end_note.duplicate()
					end_note_shifted[2] -= 10
					secondary_preprocessed_data.append(end_note_shifted)
					secondary_preprocessed_data.append(end_note)

			else:
				secondary_preprocessed_data.append(top_note)

		secondary_preprocessed_data.append(preprocessed_data[-3])
		secondary_preprocessed_data.append(preprocessed_data[-2])
		secondary_preprocessed_data.append(preprocessed_data[-1])
	else:
		secondary_preprocessed_data = preprocessed_data

	#shift preprocessing
	i = 0
	var secondary_preprocessed_data_len: int = len(secondary_preprocessed_data)
	print(secondary_preprocessed_data_len)

	print("begin shift preprocessing")



	while i+1<secondary_preprocessed_data_len:

		var note_0: Array = secondary_preprocessed_data[max(i-2,0)]
		var note_1: Array = secondary_preprocessed_data[max(i-1,0)]
		var note_2: Array = secondary_preprocessed_data[i]
		var note_3: Array = secondary_preprocessed_data[i+1]
		var note_4: Array = secondary_preprocessed_data[min(i+2,secondary_preprocessed_data_len-1)]

		if (note_2[0] == note_3[0] and note_2[1] == note_3[1]) or (note_2[0] == note_1[0] and note_2[1] == note_1[1]):
			print("ignore")
			var desired: Vector2 = Vector2(
				((processed_data[-1] if len(processed_data) > 0 else note_1)[0] + note_2[0] + note_3[0]) / 3.0,
				((processed_data[-1] if len(processed_data) > 0 else note_1)[1] + note_2[1] + note_3[1]) / 3.0,
			)

			var shift_vec: Vector2 = desired - Vector2(note_2[0], note_2[1])

			if shift_vec.x==0 or shift_vec.y==0:
				shift_vec = shift_vec.clampf(-SSCS.modifiers.hitbox_size * 0.5, SSCS.modifiers.hitbox_size * 0.5)
			else:
				shift_vec = shift_vec * clamp(shift_vec.x, -SSCS.modifiers.hitbox_size * 0.5, SSCS.modifiers.hitbox_size * 0.5)/shift_vec.x
				shift_vec = shift_vec * clamp(shift_vec.y, -SSCS.modifiers.hitbox_size * 0.5, SSCS.modifiers.hitbox_size * 0.5)/shift_vec.y

			print(shift_vec)

			var new_note: Array = [
				note_2[0] + shift_vec.x,
				note_2[1] + shift_vec.y,
				note_2[2]
			]

			processed_data.append(new_note)
			i += 1
			continue

		var pos: Vector2 = SplineManager._get_position(note_0, note_1, note_3, note_4, note_2[2])

		var shift_vec: Vector2 = pos - Vector2(note_2[0], note_2[1])

		if shift_vec.x==0 or shift_vec.y==0:
			shift_vec = shift_vec.clampf(-max_range,max_range)
		else:
			shift_vec = shift_vec * clamp(shift_vec.x, -max_range, max_range)/shift_vec.x
			shift_vec = shift_vec * clamp(shift_vec.y, -max_range, max_range)/shift_vec.y

		var new_note: Array = [
			note_2[0] + shift_vec.x,
			note_2[1] + shift_vec.y,
			note_2[2]
		]

		if _check_hit(SplineManager._get_position(note_1, new_note, note_3, note_4, new_note[2]), note_2, SSCS.modifiers.hitbox_size):
			processed_data.append(new_note)
		else:
			processed_data.append(note_2)
		i += 1

	processed_data.append(preprocessed_data[-1])

	#processed_data = secondary_preprocessed_data


func get_cursor_position() -> Vector2:
	var elapsed: int = int(AudioManager.elapsed * 1000.0 / SSCS.modifiers.speed)
	while last_loaded_note+1<len(processed_data):
		var note: Array = processed_data[last_loaded_note+1]
		if note[2] > elapsed:
			break
		else:
			last_loaded_note+=1

	var note_0: Array = processed_data[max(last_loaded_note - 1,0)]
	var note_1: Array = processed_data[last_loaded_note]
	var note_2: Array = processed_data[min(last_loaded_note + 1, len(processed_data) - 1)]
	var note_3: Array = processed_data[min(last_loaded_note + 2, len(processed_data) - 1)]

	var offset_forward: int = 1
	while _check_hit(note_2, note_3, SSCS.modifiers.hitbox_size * 0.5 + 0.01) and last_loaded_note + 2 + offset_forward < len(processed_data):
		#print('forward ', offset_forward)
		note_3 = processed_data[min(last_loaded_note + 2 + offset_forward, len(processed_data) - 1)]
		offset_forward += 1

	#var offset_backward: int = 1
	#while _check_hit(note_1, note_0, 0.5) and last_loaded_note - 1 - offset_backward >= 0:
		##print('backward')
		#note_0 = processed_data[max(last_loaded_note - 1 - offset_backward,0)]
		#offset_backward += 1

	var return_pos: Vector2 = SplineManager._get_position(note_0, note_1, note_2, note_3, elapsed).clampf(-cursor.GRID_MAX,cursor.GRID_MAX)

	return return_pos
