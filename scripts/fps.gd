extends RichTextLabel

func _physics_process(_dt:float ) -> void:
	self.text = str(Engine.get_frames_per_second())
	
func benchmark() -> void:
	#debug function for testing some stuff
	pass
	
	const num_trials: int = 1000
	const trial_iterations: int = 10000
	
	var t1s: Array[int] = []
	t1s.resize(num_trials)
	
	var t2s: Array[int] = []
	t2s.resize(num_trials)
	
	for trial in range(num_trials):
	
		var t1: int = Time.get_ticks_usec()
		
		for i in range(trial_iterations):
			var _a: int = randi()%10000
			
			
		t1s[trial]=(Time.get_ticks_usec()-t1)
		
		var t2: int = Time.get_ticks_usec()
		
		for i in range(trial_iterations):
			var _a: int = randi()%10000
			
		t2s[trial]=(Time.get_ticks_usec()-t2)
	
	var t1a:float = 0
	var t2a:float = 0
	
	for t in t1s:
		t1a+=t
	t1a/=len(t1s)
	
	for t in t2s:
		t2a+=t
	t2a/=len(t2s)
	
	print("T1: {0}\nT2: {1}".format([t1a,t2a]))

func _ready() -> void:
	pass
	
	#benchmark()
	
