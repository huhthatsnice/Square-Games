extends Node

class Command:
	var function:Callable
	var names:Array[String]
	
	func _init(function_arg:Callable,names_arg:Array[String]) -> void:
		function=function_arg
		names=names_arg

var commands:Array[Command]=[]

func register_command(command:Command) -> void:
	commands.append(command)

func _ready() -> void:
	if not Terminal.is_node_ready():
		await Terminal.ready
	Terminal.line_entered.connect(func(line:String)->void:
		var split:PackedStringArray = line.split(" ")
		var cmd:String = split[0]
		var args:PackedStringArray = split.slice(1)
		var argc:int = len(args)
		
		var ran:bool = false
		
		for command:Command in commands:
			if command.names.has(cmd):
				if argc>=command.function.get_argument_count():
					ran=true
					command.function.callv(args)
				else:
					Terminal.print_console("Too few arguments (Expected at least {0} arguments, got {1}).\n".format([command.function.get_argument_count(),argc]))
				break
		
		if not ran:
			Terminal.print_console("Could not find command named \"{0}\".\n".format([cmd]))
		
	)
	#register commands
	
	register_command(Command.new(func() -> void:
		Terminal.console_text=""
	,["clr","clear"]))
	
	register_command(Command.new(func() -> void:
		for v:String in DirAccess.get_directories_at("user://maps"):
			Terminal.print_console(v+"\n")
	,["lsm","listsongs","listmaps"]))
	
	register_command(Command.new(func() -> void:
		for i:Dictionary in SSCS.settings.get_property_list():
			var v:Variant = SSCS.settings[i.name]
			Terminal.print_console("{0}:{1}\n".format([i,v]))
	,["lss","listsettings"]))
	
	register_command(Command.new(func(setting_name: String, setting_value: String) -> void:
		if SSCS.set_setting(setting_name, setting_value, true):
			Terminal.print_console("Successfully set setting.\n")
		else:
			Terminal.print_console("Failed to set setting.\n")
	,["set","sets","setsetting"]))
	
	register_command(Command.new(func(modifier_name: String, modifier_value: String) -> void:
		if SSCS.set_modifier(modifier_name, modifier_value, true):
			Terminal.print_console("Successfully set modifier.\n")
		else:
			Terminal.print_console("Failed to set modifier.\n")
	,["setm","setmodifier"]))
	
	register_command(Command.new(func(map_name: String) -> void:
		if not DirAccess.dir_exists_absolute("user://maps/%s" % map_name): return
		
		var map:MapLoader.Map
		if FileAccess.file_exists("user://maps/%s/sspm.sspm" % map_name):
			map = MapLoader.from_path_sspm("user://maps/%s/sspm.sspm" % map_name)
		else:
			map = MapLoader.from_path_native("user://maps/%s" % map_name)
		
		var game_handler: GameHandler = GameHandler.new(map)
		
		var game_scene:Node = $"/root/Game"

		game_scene.add_child(game_handler)
		
		game_handler.play()
		
		Terminal.is_accepting_input = false
		Terminal.visible = false
		
		await game_handler.ended
		
		print("map ended")
		
		game_handler.queue_free()
		Terminal.visible = true
		Terminal.is_accepting_input = true
		
	,["play","playmap"]))
