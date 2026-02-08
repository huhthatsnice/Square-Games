extends RefCounted
class_name Commands

var registered_commands: Array[Command2]

func register_command(command: Command2) -> void:
	registered_commands.append(command)

func parse_raw_input(input: String) -> void:
	var split_input: PackedStringArray = input.split(" ")

	var command_name: String = split_input[0]
	var args: PackedStringArray = split_input.slice(1)

	for command: Command2 in registered_commands:
		if command_name in command.aliases:
			command.invoke(args)
			break

func autocomplete_string(input: String, cycle: int = 0) -> String:
	var command_name: String = input.get_slice(" ", 0)

	if command_name == input:
		for command: Command2 in registered_commands:
			for alias: String in command.aliases:
				if alias.begins_with(command_name):
					return alias

	for command: Command2 in registered_commands:
		if command_name in command.aliases:
			return command.autocomplete_string(input, cycle)

	return ""

func _init() -> void:
	pass
