extends Label

const CHARACTER_WHITELIST: String = "ABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890 -."

var is_accepting_input: bool = true
var console_text:String = ""
var current_input: String = ""

var cursor: int = 0
var selection_start: int = cursor
var selection_end: int = cursor

var command_history: Array[String] = []
var command_history_cursor: int = -1

signal line_entered

func print_console(txt:String) -> void:
	console_text += txt
	update_console()

func update_console() -> void:
	self.text=console_text+">"+current_input.insert(cursor,"❘")

func _ready() -> void:
	update_console()
	print_console("Welcome to Square Games. Type \"help\" to see all commands.\n")

func _input(event:InputEvent) -> void:
	if not is_accepting_input:
		return
	if event.is_pressed():
		if event is InputEventKey:
			var keylabel: int = event.key_label
			#print(keylabel)

			if OS.is_keycode_unicode(keylabel) and CHARACTER_WHITELIST.contains(char(keylabel)):
				var key: String = char(keylabel)
				if key == "V" and event.ctrl_pressed:
					key = DisplayServer.clipboard_get()
				elif not event.shift_pressed:
					key = key.to_lower()
				elif key=="-":
					key="_"

				current_input = current_input.insert(cursor, key)
				cursor = clamp(cursor + len(key), 0, len(current_input))

			else:

				match keylabel:
					KEY_BACKSPACE:
						if cursor==0: return
						if event.is_command_or_control_pressed():
							var space: int = max(current_input.rfind(" ",cursor),0)
							current_input = current_input.erase(space, 0xffff)
							cursor = clamp(space, 0, len(current_input))
						else:
							current_input = current_input.erase(cursor - 1, 1)
							cursor = clamp(cursor - 1, 0, len(current_input))
					KEY_ENTER:
						console_text += ">" + current_input + "\n"
						command_history.insert(0,current_input)
						line_entered.emit(current_input)
						current_input = ""
						command_history_cursor=-1
						cursor = 0
					KEY_LEFT:
						cursor = clamp(cursor - 1, 0, len(current_input))
					KEY_RIGHT:
						cursor = clamp(cursor + 1, 0, len(current_input))
					KEY_UP:
						if len(command_history)==0: return
						command_history_cursor = clamp(command_history_cursor + 1, -1, len(command_history)-1)
						current_input = command_history[command_history_cursor]
						cursor = len(current_input)
					KEY_DOWN:
						if len(command_history)==0: return
						command_history_cursor = clamp(command_history_cursor - 1, -1, len(command_history)-1)
						if command_history_cursor==-1:
							current_input = ""
						else:
							current_input = command_history[command_history_cursor]
						cursor = len(current_input)

			update_console()
