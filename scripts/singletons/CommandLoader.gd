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
		for i:String in SSCS.settings.keys():
			var v:Variant = SSCS.settings[i]
			Terminal.print_console("{0}:{1}\n".format([i,v]))
	,["lss","listsettings"]))
	
	register_command(Command.new(func(setting_name:String,setting_value:String) -> void:
		if SSCS.settings.has(setting_name):
			var type:int = typeof(SSCS.settings[setting_name])
			var valid:bool = true
			match type:
				TYPE_FLOAT:
					if setting_value.is_valid_float():
						SSCS.settings[setting_name]=setting_value.to_float()
					else:
						valid = false
				TYPE_INT:
					if setting_value.is_valid_int():
						SSCS.settings[setting_name]=setting_value.to_int()
					else:
						valid = false
				TYPE_BOOL:
					if setting_value=="false" or setting_value=="true":
						SSCS.settings[setting_name]=setting_value=="true"
					else:
						valid = false
			if valid:
				Terminal.print_console("Set {0} to {1} successfully.\n".format([setting_name,setting_value]))
			else:
				Terminal.print_console("Failed to set {0} to {1} (invalid setting value).\n".format([setting_name,setting_value]))
		else:
			Terminal.print_console("Failed to set {0} to {1} (invalid setting name).\n".format([setting_name,setting_value]))
	,["set","setsetting"]))
	
	register_command(Command.new(func(map_name: String) -> void:
		var map:MapLoader.Map = MapLoader.from_path_native("user://maps/{0}".format([map_name]))
		var game_handler:GameHandler = GameHandler.new(map)
		
		var game_scene:Node = $"/root/Game"

		game_scene.add_child(game_handler)
		
		game_handler.play()
		
		Terminal.visible = false
		
		await game_handler.ended
		
		game_handler.queue_free()
		Terminal.visible = true
		
	,["play","playmap"]))
