extends Label

func _physics_process(_dt:float ) -> void:
	self.text = str(Engine.get_frames_per_second())
