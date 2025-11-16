extends RichTextLabel

func _physics_process(_dt:float ) -> void:
	self.text = str(Engine.get_frames_per_second())

func _ready() -> void:
	#debug function for testing some stuff
	pass
	
