extends Node3D


func _ready() -> void:
	#make sure directories exist
	DirAccess.make_dir_recursive_absolute("user://maps")
	
	#set up commands
	%Terminal.line_entered.connect(func(line:String)->void:
		var split:PackedStringArray = line.split(" ")
		
		var cmd:String = split[0]
		if cmd=="clr" or cmd=="clear":
			%terminal.consoleText=""
		elif cmd=="set" or cmd=="setsetting":
			print("got set command")
			if len(split)!=3:
				%terminal.print_console("Invalid argument count.\n")
				return
			
			if SSCS.settings.has(split[1]):
				var type:int = typeof(SSCS.settings[split[1]])
				var out:Variant
				var valid:bool = true
				match type:
					TYPE_FLOAT:
						if split[2].is_valid_float():
							SSCS.settings[split[1]]=split[2].to_float()
						else:
							valid = false
							%terminal.print_console("Failed to set {0} to {1} (invalid setting value).\n".format([split[1],split[2]]))
					TYPE_INT:
						if split[2].is_valid_int():
							SSCS.settings[split[1]]=split[2].to_int()
						else:
							valid = false
							%terminal.print_console("Failed to set {0} to {1} (invalid setting value).\n".format([split[1],split[2]]))
					TYPE_BOOL:
						if split[2]=="false" or split[2]=="true":
							SSCS.settings[split[1]]=split[2]=="true"
						else:
							valid = false
							%terminal.print_console("Failed to set {0} to {1} (invalid setting value).\n".format([split[1],split[2]]))
				if valid:
					%terminal.print_console("Set {0} to {1} successfully.\n".format([split[1],split[2]]))
			else: 
				%terminal.print_console("Failed to set {0} to {1} (invalid setting name).\n".format([split[1],split[2]]))
			
		elif cmd =="lsm" or cmd =="listsongs" or cmd=="listmaps":
			for v:String in DirAccess.get_directories_at("user://maps"):
				%terminal.print_console(v+"\n")
		elif cmd=="lss" or cmd=="listsettings":
			for i:String in SSCS.settings.keys():
				var v:Variant = SSCS.settings[i]
				%terminal.print_console("{0}:{1}\n".format([i,v]))
		else:
			%terminal.print_console("No valid command named {0}.\n".format([split[0]]))
	)
