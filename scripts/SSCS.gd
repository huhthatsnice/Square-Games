extends Node3D

var settings:Dictionary = {
	ApproachRate=100,
	ApproachDistance=50,
	ColorSet="0xffffff,0x80ff80"
};
var derived:Dictionary = {
	ColorSet=[]
}

func updateDerivedSettings() -> void:
	derived.ColorSet.clear()
	var i:int = 0
	for v:String in settings.ColorSet.split(","):
		derived.ColorSet[i]=Color.from_string(v,Color.WHITE)
		i+=1
