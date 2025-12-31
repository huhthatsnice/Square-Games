extends Node
class_name SSPMUtil

class SSPM:
	var data_csv: String
	var audio: AudioStream
	var audiobuffer: PackedByteArray
	var cover: Image
	var name: String
	var mapper: String
	var difficulty: String
	var data_parsed: Array[MapLoader.NoteDataMinimal]

static func load_from_path(path: String) -> SSPM:

	var newdata:SSPM = SSPM.new()

	var file:FileAccess = FileAccess.open(path,FileAccess.READ)

	if file==null:
		return newdata

	file.get_32() #skip header
	var version:int = file.get_16()
	file.get_32() #skip Literally Nothing

	if version!=2:
		return newdata

	file.get_buffer(20) #skip hash
	var _lastMarkerMs:int = file.get_32()
	var noteCount:int = file.get_32()
	var _markerCount:int = file.get_32()
	var mapDifficulty:int = file.get_8()
	var _mapRating:int = file.get_16() #what the fuck is this
	var hasAudio:bool = file.get_8()
	var hasCover:bool = file.get_8()
	var _requiresModifier:bool = file.get_8() #what does this even mean

	match mapDifficulty:
		0: newdata.difficulty="None"
		1: newdata.difficulty="Easy"
		2: newdata.difficulty="Medium"
		3: newdata.difficulty="Hard"
		4: newdata.difficulty="Logic"
		5: newdata.difficulty="Tasukete"


	var _customDataOffset:int = file.get_64()
	var _customDataLength:int = file.get_64()

	var audioOffset:int = file.get_64()
	var audioLength:int = file.get_64()

	var coverOffset:int = file.get_64()
	var coverLength:int = file.get_64()

	var _markerDefinitionsOffset:int = file.get_64()
	var _markerDefinitionsLength:int = file.get_64()

	file.seek(0x70) #just to make sure
	var markersOffset:int = file.get_64()
	var _markersLength:int = file.get_64()


	var _mapId:String = file.get_buffer(file.get_16()).get_string_from_utf8()
	var mapname:String = file.get_buffer(file.get_16()).get_string_from_utf8()
	var _songname:String = file.get_buffer(file.get_16()).get_string_from_utf8()

	var mapperCount:int = file.get_16()

	var mappers:Array = []

	for i in range(mapperCount):
		mappers.append(file.get_buffer(file.get_16()).get_string_from_utf8())

	newdata.mapper=" & ".join(mappers)
	#if songname.replace("_"," ")!="Artist Name - Song Name":
		#newdata.name=songname
	#else:
	newdata.name=mapname


	if hasAudio:
		file.seek(audioOffset)
		var audioData:PackedByteArray = file.get_buffer(audioLength)
		if !audioData.is_empty():
			var audioStream:AudioStream
			if audioData[0]==0x4F && audioData[1]==0x67 && audioData[2]==0x67 && audioData[3]==0x53:
				audioStream = AudioStreamOggVorbis.load_from_buffer(audioData)
			else:
				audioStream = AudioStreamMP3.load_from_buffer(audioData)
			newdata.audio=audioStream
			newdata.audiobuffer=audioData

	if hasCover:
		file.seek(coverOffset)
		var coverData:PackedByteArray = file.get_buffer(coverLength)

		var cover:Image = Image.new()

		var imgtype:String = ""
		var i:int=0
		for v:int in [0x89,0x50,0x4E,0x47,0x0D,0x0A,0x1A,0x0A]:
			if coverData[i]!=v:
				break
			i+=1
		if i==8:
			imgtype="png"

		if imgtype=="png":
			cover.load_png_from_buffer(coverData)
		elif imgtype=="jpg":
			cover.load_jpg_from_buffer(coverData)
		else:
			for v:int in coverData.slice(1,10):
				print(char(v))

		newdata.cover=cover

	#only reason we go to marker definitions is for ssp_note

	file.seek(markersOffset)

	var note_data: Array[MapLoader.NoteDataMinimal]

	for i:int in range(noteCount):
		var ms:int = file.get_32()

		var mtype:int = file.get_8() #skip marker type, only marker type thats ever used is ssp_note

		if mtype!=0: continue

		var isQuantum:bool = file.get_8()

		if !isQuantum:
			var x:int = -file.get_8()+2
			var y:int = -file.get_8()+2
			note_data.append(MapLoader.NoteDataMinimal.new(1-x,y-1,ms))
		else:
			var x:float = -file.get_float()+2
			var y:float = -file.get_float()+2
			note_data.append(MapLoader.NoteDataMinimal.new(1-x,y-1,ms))

	note_data.sort_custom(
		func(a:MapLoader.NoteDataMinimal,b:MapLoader.NoteDataMinimal) -> bool:
			return a.t<b.t
	)

	newdata.data_csv=""
	newdata.data_parsed=note_data

	return newdata
