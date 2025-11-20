extends Node

# script for handling spline calculations
# massive credit to Laith Hijazi (https://github.com/Gapva) who provided basically everything here

const tension: float = 0.75

func _catmull_rom(pos_0: float, pos_1: float, pos_2: float, pos_3: float, u: float, time_0: float, time_1: float, time_2: float, time_3: float) -> float:
	
	var dt0: float = max(time_1 - time_0,1)
	var dt1: float = max(time_2 - time_1,1)
	var dt2: float = max(time_3 - time_2,1)
	
	var dt1_tension:float = dt1**tension
	
	var m0: float = ((pos_1 - pos_0) / (dt0**tension) * (dt1_tension)) if dt0>0.0 else 0.0
	var m1: float = ((pos_3 - pos_2) / (dt2**tension) * (dt1_tension)) if dt2>0.0 else 0.0
	
	var u2: float = u * u
	var u3: float = u2 * u
	
	return (2*u3 - 3*u2 + 1)*pos_1 + (u3 - 2*u2 + u)*m0 + (-2*u3 + 3*u2)*pos_2 + (u3 - u2)*m1

func _get_position(note_0: MapLoader.NoteDataMinimal, note_1: MapLoader.NoteDataMinimal, note_2: MapLoader.NoteDataMinimal, note_3: MapLoader.NoteDataMinimal, time: float) -> Vector2:
	var segment_duration: float = note_2.t - note_1.t
	if segment_duration <= 0: return Vector2(note_1.x,note_1.y)
	
	var u: float = (time - note_1.t) / segment_duration
	
	return Vector2(
		_catmull_rom(note_0.x, note_1.x, note_2.x, note_3.x, u, note_0.t,note_1.t,note_2.t,note_3.t),
		_catmull_rom(note_0.y, note_1.y, note_2.y, note_3.y, u, note_0.t,note_1.t,note_2.t,note_3.t)
	)
