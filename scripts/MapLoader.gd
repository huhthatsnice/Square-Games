extends Node
class_name MapLoader

enum MapType {
	Native,
}

class Map:
	var mapType:MapType
	var path:String
	var rawData:String
	var data:Array
	var audio:AudioStream

static func _parse_data(data:String) -> Array:
	var outdata:Array = []
	
	for v:String in data.split(","):
		var split:PackedStringArray = v.split("|")
		outdata.append([split[0].to_int(),split[1].to_int(),split[2].to_int()])
	
	return outdata

static func from_path_native(path:String) -> Map:
	var newMap:Map = Map.new()
	
	var audio:AudioStream = load(path+"/audio.mp3")
	var rawdata:String = FileAccess.get_file_as_string(path+"/data.txt")
	var data:Array =  _parse_data(rawdata)
	
	newMap.mapType=MapType.Native
	newMap.path=path
	newMap.audio=audio
	newMap.rawData=rawdata
	newMap.data=data
	
	return newMap
	
