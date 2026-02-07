extends RefCounted
class_name Command2

var callback: Callable
var aliases: PackedStringArray
var argument_count: int
var echoes: bool
var metadata: Dictionary
var autocomplete: Callable

func _default_autocomplete() -> String:
	return ""

@warning_ignore("shadowed_variable")
func _init(callback: Callable, aliases: PackedStringArray, argument_count: int = -1, echoes: bool = true, metadata: Dictionary = {}, autocomplete: Callable = _default_autocomplete) -> void:
	self.callback = callback
	self.aliases = aliases
	self.argument_count = callback.get_argument_count() if argument_count == -1 else argument_count
	self.echoes = echoes
	self.metadata = metadata
	self.autocomplete = autocomplete

func invoke(inputs: PackedStringArray) -> void:
	if len(inputs) < argument_count:
		push_error("you fucking retard you put too few variables") #replace with terminal print later
		return
	print("> " + aliases[0]) #replace with terminal print later

	callback.callv(inputs)

func autocomplete_string(input: String, cycle: int = 0) -> String:
	return autocomplete.call(input, cycle)
