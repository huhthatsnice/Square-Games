extends Label

const allowedCharacters = "ABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890 "

var acceptingInput:bool = true
var consoleText:String = ""
var currentInput:String = ""

var cursor:int = 0
var selectionStart:int = cursor
var selectionEnd:int = cursor

signal line_entered

func print_console(txt:String) -> void:
	consoleText+=txt

func update_console() -> void:
	self.text=consoleText+">"+currentInput.insert(cursor,"❘")

func _ready() -> void:
	update_console()
	var root:Window = get_tree().get_root()
	
	root.size_changed.connect(func() -> void:
		print("resize ",root.size)
		self.size=root.size
	)

func _input(event:InputEvent) -> void:
	if not acceptingInput:
		return
	if event.is_pressed():
		if event is InputEventKey:
			var keylabel:int = event.key_label
			#print(keylabel)
			
			if OS.is_keycode_unicode(keylabel) and allowedCharacters.contains(char(keylabel)):
				var key:String = char(keylabel)
				if key=="V" and event.ctrl_pressed:
					key=DisplayServer.clipboard_get()
				elif not event.shift_pressed:
					key = key.to_lower()
				currentInput=currentInput.insert(cursor,key)
				cursor=clamp(cursor+1,0,len(currentInput))
				
			elif keylabel==KEY_BACKSPACE:
				currentInput = currentInput.erase(cursor-1,1)
				cursor=clamp(cursor-1,0,len(currentInput))
				
			elif keylabel==KEY_ENTER:
				consoleText+=">"+currentInput+"\n"
				line_entered.emit(currentInput)
				currentInput=""
				cursor=0
			
			elif keylabel==KEY_LEFT:
				cursor=clamp(cursor-1,0,len(currentInput))
			elif keylabel==KEY_RIGHT:
				cursor=clamp(cursor+1,0,len(currentInput))
				
			update_console()
