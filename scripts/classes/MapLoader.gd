extends Node
class_name MapLoader

enum MapType {
	Native,
	SSPM
}

class Map:
	var map_type: MapType
	var path: String
	var raw_data: String
	var data: Array
	var audio: AudioStream
	var loaded_successfully: bool
	var map_name: String

class NoteDataMinimal:
	var x: float
	var y: float
	var t: int

	func _init(x_arg: float, y_arg: float, t_arg: int) -> void:
		x = x_arg
		y = y_arg
		t = t_arg

static func _parse_data(data: String) -> Array[NoteDataMinimal]:
	var output_data: Array[NoteDataMinimal] = []

	for v: String in data.split(","):
		var split: PackedStringArray = v.split("|")
		if len(split)==3:
			output_data.append(NoteDataMinimal.new(1-split[0].to_float(), split[1].to_float()-1, split[2].to_int()))

	return output_data

static func from_path_native(path: String) -> Map: #path to a folder with a data.txt file and audio.mp3 file
	var new_map: Map = Map.new()

	var audio: AudioStreamMP3 = AudioStreamMP3.new()
	audio.data = FileAccess.get_file_as_bytes("%s/audio.mp3" % path)

	var raw_data: String = FileAccess.get_file_as_string("%s/data.txt" % path)
	var data: Array =  _parse_data(raw_data)

	new_map.map_type = MapType.Native
	new_map.path = path
	new_map.audio = audio
	new_map.raw_data = raw_data
	new_map.data = data
	new_map.loaded_successfully = len(data) > 0

	return new_map

static func from_path_sspm(path: String) -> Map: #path to a .sspm file
	var new_map: Map = Map.new()

	var sspm_parsed: SSPMUtil.SSPM = SSPMUtil.load_from_path(path)
	var data: Array =  sspm_parsed.data_parsed

	new_map.map_type = MapType.SSPM
	new_map.path = path
	new_map.audio = sspm_parsed.audio
	new_map.raw_data = sspm_parsed.data_csv
	new_map.data = data
	new_map.loaded_successfully = len(data) > 0

	print(sspm_parsed.data_csv)

	return new_map
