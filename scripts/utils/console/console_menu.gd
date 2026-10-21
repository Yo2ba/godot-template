extends Control

@export var window: PanelContainer
@export var output: RichTextLabel
@export var line: LineEdit
@export var close_btn: TextureButton
@export var title_grabber: PanelContainer

var input_history: Array[String] = []
var history_index: int = 0
var draft_input: String = ""

var dragging: bool = false
var drag_offset: Vector2 = Vector2.ZERO

func _ready() -> void:
	hide()
	
	window.position = Settings.console_position
	
	Console.console_menu = self
	line.text_submitted.connect(send)
	close_btn.pressed.connect(func(): Console.toggle_console())
	visibility_changed.connect(func(): if visible: line.grab_focus() else: line.release_focus())

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				if title_grabber.get_global_rect().has_point(get_global_mouse_position()):
					dragging = true
					drag_offset = window.get_global_position() - get_global_mouse_position()
			elif dragging:
				dragging = false
				Settings.console_position = window.position
	
	elif event is InputEventMouseMotion and dragging:
		window.global_position = get_global_mouse_position() + drag_offset

	if not visible or not line.has_focus():
		return
	
	if event is not InputEventKey or not event.pressed:
		return
	
	match event.keycode:
		KEY_UP:
			if input_history.is_empty():
				return
			
			if history_index == input_history.size():
				draft_input = line.text
			
			history_index = posmod(history_index - 1, input_history.size())
			line.text = input_history[history_index]
			line.caret_column = line.text.length()
			get_viewport().set_input_as_handled()
		
		KEY_DOWN:
			if input_history.is_empty():
				return

			history_index = (history_index + 1) % input_history.size()
			line.text = input_history[history_index]
			line.caret_column = line.text.length()
			get_viewport().set_input_as_handled()

func send(text: String) -> void:
	var input: String = text.strip_edges()
	
	if input.is_empty():
		return
	
	if input in input_history:
		input_history.erase(input)
	
	input_history.append(input)
	history_index = input_history.size()
	draft_input = ""
	
	line.clear()
	
	var parts: PackedStringArray = input.split(" ", false)
	var label: StringName = StringName(parts[0])
	
	output.append_text("[color=gray]> %s[/color]\n" %[escape(text)])
	
	match label:
		&"clear":
			clear()
			return

		&"log":
			savelog()
			return
	
	if not ConVars.exists(label):
		Console.log("Unknown command: %s" %label)
		return
	
	if parts.size() == 1:
		Console.log("[Console] %s = %s" %[label, ConVars.get_value(label)] )
		return
	
	var value_text: String = " ".join(parts.slice(1))
	var current_value: Variant = ConVars.get_value(label)
	var value: Variant
	
	match typeof(current_value):
		TYPE_BOOL:
			var normalized: String = value_text.to_lower()

			if normalized == "true":
				value = true
			elif normalized == "false":
				value = false
			elif value_text.is_valid_int():
				value = value_text.to_int() != 0
			else:
				Console.log("Expected a boolean or integer value.")
				return

		TYPE_INT:
			if not value_text.is_valid_float():
				Console.log("Expected a numeric value.")
				return

			value = int(value_text.to_float())

		TYPE_FLOAT:
			if not value_text.is_valid_float():
				Console.log("Expected a numeric value.")
				return

			value = value_text.to_float()

		TYPE_STRING:
			value = value_text

		_:
			Console.log("Unsupported ConVar type.")
			return

	ConVars.set_value(label, value)

func escape(text: String) -> String:
	return text.replace("[", "[lb]")

func clear() -> void:
	output.text = ""

func add_visible(message: String) -> void:
	output.append_text("%s\n" % escape(message))

func savelog() -> void:
	var now: Dictionary = Time.get_datetime_dict_from_system()
	
	var path: String = "user://console_%04d-%02d-%02d_%02d-%02d-%02d.txt" % [
		now["year"],
		now["month"],
		now["day"],
		now["hour"],
		now["minute"],
		now["second"]
	]
	
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	
	if file == null:
		Console.log("Failed to save log: " + str(FileAccess.get_open_error()))
		return
	
	file.store_string(Console.history)
	file.close()
	
	Console.log("Log saved: %s" %path)
	
