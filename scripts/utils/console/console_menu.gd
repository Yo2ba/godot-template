
extends Control
@warning_ignore_start("shadowed_variable_base_class")

@export var window: PanelContainer
@export var output: RichTextLabel
@export var line: LineEdit
@export var close_btn: TextureButton
@export var title_grabber: PanelContainer
@export var handle_btn: TextureButton
@export var hint_list: ItemList

var input_history: Array[String] = []
var history_index: int = 0
var draft_input: String = ""

var dragging: bool = false
var drag_offset: Vector2 = Vector2.ZERO

const MIN_WINDOW_SIZE: Vector2 = Vector2(300.0, 300.0)

var resizing: bool = false
var resize_start_mouse: Vector2 = Vector2.ZERO
var resize_start_size: Vector2 = Vector2.ZERO

var hint_matches: Array[StringName] = []
var hint_prefix: String = ""
var hint_index: int = -1
var hint_active: bool = false
var hint_confirmed: bool = false
var setting_hint: bool = false
var hint_blocked: bool = false


func _ready() -> void:
	register_commands()
	hide()

	output.focus_mode = Control.FOCUS_CLICK

	line.text_changed.connect(_on_line_text_changed)
	line.text_submitted.connect(send)

	hint_list.item_clicked.connect(_on_hint_list_item_clicked)

	close_btn.pressed.connect(func(): Console.toggle_console())
	visibility_changed.connect(func(): if visible: line.grab_focus() else: line.release_focus())

	window.position = Settings.console_position
	window.size = Settings.console_size

	Console.console_menu = self

	history_index = input_history.size()


func register_commands() -> void:
	Commands.register(&"clear", clear, "Clears the console log")
	Commands.register(&"log", savelog, "Saves console log")
	Commands.register(&"echo", echo, "Echo text to console")
	Commands.register(&"quit", func(): get_tree().quit(), "Quit the game")
	Commands.register(&"help", help, "Shows command descriptions")


func help(name: String = "") -> void:
	if not name.is_empty():
		var entry: StringName = StringName(name.to_lower())

		if Commands.exists(entry):
			Console.log("[Console]", "%s - %s" % [entry, Commands.get_description(entry)])
		elif ConVars.exists(entry):
			Console.log("[Console]", "%s - %s" % [entry, ConVars.get_description(entry)])
		else:
			Console.log("[Console]", "help: no cvar or command named %s" % name)
		return

	var names: Array[StringName] = Commands.get_all_names()

	for entry: StringName in ConVars.get_all_names():
		if not names.has(entry):
			names.append(entry)

	names.sort_custom(func(a: StringName, b: StringName) -> bool:
		return str(a).to_lower() < str(b).to_lower()
	)

	for entry: StringName in names:
		var description: String = ""

		if Commands.exists(entry):
			description = Commands.get_description(entry)
		elif ConVars.exists(entry):
			description = ConVars.get_description(entry)

		Console.log("[Console]", "%s - %s" % [entry, description])

func _input(event: InputEvent) -> void:
	if not visible:
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var mouse_position: Vector2 = get_global_mouse_position()

		if event.pressed:
			if handle_btn.get_global_rect().has_point(mouse_position):
				resizing = true
				resize_start_mouse = mouse_position
				resize_start_size = window.size

			elif title_grabber.get_global_rect().has_point(mouse_position):
				dragging = true
				drag_offset = window.global_position - mouse_position

		else:
			if dragging:
				dragging = false
				Settings.console_position = window.position

			if resizing:
				resizing = false
				Settings.console_size = window.size

	elif event is InputEventMouseMotion:
		if resizing:
			var screen_size: Vector2 = get_viewport_rect().size
			var available_size: Vector2 = screen_size - window.global_position
			var mouse_delta: Vector2 = get_global_mouse_position() - resize_start_mouse
			var new_size: Vector2 = resize_start_size + mouse_delta

			var min_size: Vector2 = Vector2(
				minf(MIN_WINDOW_SIZE.x, available_size.x),
				minf(MIN_WINDOW_SIZE.y, available_size.y)
			)

			new_size.x = clampf(new_size.x, min_size.x, available_size.x)
			new_size.y = clampf(new_size.y, min_size.y, available_size.y)

			window.size = new_size
			hint_list.update_position()

		elif dragging:
			var screen_size: Vector2 = get_viewport_rect().size
			var window_size: Vector2 = window.size
			var max_position: Vector2 = screen_size - window_size
			var new_position: Vector2 = get_global_mouse_position() + drag_offset

			new_position.x = clampf(new_position.x, 0.0, max_position.x)
			new_position.y = clampf(new_position.y, 0.0, max_position.y)

			window.global_position = new_position
			hint_list.update_position()

	if event is InputEventKey and event.pressed and not event.echo:
		if line.has_focus():
			if event.keycode == KEY_BACKSPACE:
				hint_blocked = true
				reset_hints()
			elif event.unicode > 0:
				hint_blocked = false

		if event.keycode == KEY_ESCAPE:
			hide()
			get_viewport().set_input_as_handled()
			return

		if event.keycode == KEY_C and event.ctrl_pressed:
			var selected_text: String = output.get_selected_text()
			
			if not selected_text.is_empty():
				DisplayServer.clipboard_set(selected_text)
				get_viewport().set_input_as_handled()
				return

	if not line.has_focus():
		return

	if event is not InputEventKey or not event.pressed or event.echo:
		return

	if event.keycode == KEY_TAB:
		if confirm_or_cycle_hint():
			get_viewport().set_input_as_handled()
		return

	if event.keycode == KEY_RIGHT and hint_active and hint_index >= 0:
		accept_hint(str(hint_matches[hint_index]))
		get_viewport().set_input_as_handled()
		return

	match event.keycode:
		KEY_UP:
			navigate_history(-1)
			get_viewport().set_input_as_handled()

		KEY_DOWN:
			navigate_history(1)
			get_viewport().set_input_as_handled()


func navigate_history(direction: int) -> void:
	var max_index: int = input_history.size() + hint_matches.size()

	var new_index: int = clampi(
		history_index + direction,
		0,
		max_index
	)

	if new_index == history_index:
		return

	history_index = new_index

	var text: String

	if history_index < input_history.size():
		text = input_history[history_index]

	elif history_index == input_history.size():
		text = draft_input

	else:
		var index: int = history_index - input_history.size() - 1
		text = hint_list.get_item_text(index)

	setting_hint = true

	line.text = text
	line.deselect()
	line.caret_column = line.text.length()

	setting_hint = false


func send(text: String) -> void:
	var input: String = text.strip_edges()

	if input.is_empty():
		return

	var parts: PackedStringArray = parse_arguments(input)

	if parts.is_empty():
		return

	if input in input_history:
		input_history.erase(input)

	input_history.append(input)
	history_index = input_history.size()
	draft_input = ""

	line.clear()
	reset_hints()

	var name: StringName = StringName(parts[0])
	var lookup_name: StringName = StringName(str(name).to_lower())

	Console.log("> " + input, Color.GRAY)

	var args: Array = []

	for i in range(1, parts.size()):
		args.append(parts[i])

	if Commands.exists(lookup_name):
		Commands.execute(lookup_name, args)
		return

	if not ConVars.exists(lookup_name):
		Console.log("Unknown command: %s" % name)
		return

	if parts.size() == 1:
		var display_value: Variant = ConVars.get_value(lookup_name)

		if display_value is float and display_value == float(int(display_value)):
			display_value = int(display_value)

		Console.log("[Console]", "%s = %s" % [name, display_value])
		return

	var value_text: String = " ".join(parts.slice(1))
	var current_value: Variant = ConVars.get_value(lookup_name)
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
				Console.log("Expected a boolean or integer value.", Color.RED)
				return

		TYPE_INT:
			if not value_text.is_valid_float():
				Console.log("Expected a numeric value.", Color.RED)
				return

			value = int(value_text.to_float())

		TYPE_FLOAT:
			if not value_text.is_valid_float():
				Console.log("Expected a numeric value.", Color.RED)
				return

			value = value_text.to_float()

		TYPE_STRING:
			value = value_text

		_:
			Console.log("Unsupported ConVar type.", Color.RED)
			return

	ConVars.set_value(lookup_name, value)


func escape(text: String) -> String:
	return text.replace("[", "[lb]")


func clear() -> void:
	Console.history = ""
	output.text = ""


func echo(text: String = "") -> void:
	Console.log("[Console]", text)


func add_visible(message: String, color: Color = Color.WHITE) -> void:
	output.append_text(
		"[color=#%s]%s[/color]\n" % [
			color.to_html(false),
			escape(message)
		]
	)


func savelog() -> void:
	var now: Dictionary = Time.get_datetime_dict_from_system()

	var path: String = "user://console_%04d-%02d-%02d_%02d-%02d-%02d.log" % [
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

	Console.log("Log saved: %s" % path)


func parse_arguments(input: String) -> PackedStringArray:
	var args: PackedStringArray = []
	var current: String = ""
	var in_quotes: bool = false
	var escaping: bool = false
	var token_started: bool = false

	for i in range(input.length()):
		var character: String = input[i]

		if escaping:
			current += character
			escaping = false
			token_started = true
			continue

		if character == "\\" and in_quotes:
			escaping = true
			continue

		if character == "\"":
			in_quotes = not in_quotes
			token_started = true
			continue

		if character == " " and not in_quotes:
			if token_started:
				args.append(current)
				current = ""
				token_started = false
			continue

		current += character
		token_started = true

	if escaping:
		current += "\\"

	if in_quotes:
		Console.log("Unclosed quotation mark.", Color.RED)
		return PackedStringArray()

	if token_started:
		args.append(current)

	return args


func _on_line_text_changed(text: String) -> void:
	if setting_hint:
		return

	reset_hints()

	history_index = input_history.size()
	draft_input = text

	if hint_blocked or text.is_empty() or text.contains(" "):
		return

	hint_prefix = text.to_lower()

	var names: Array[StringName] = Commands.get_all_names()

	for name: StringName in ConVars.get_all_names():
		if not names.has(name):
			names.append(name)

	names.sort()

	for name: StringName in names:
		if str(name).begins_with(hint_prefix):
			hint_matches.append(name)

	hint_active = not hint_matches.is_empty()

	if hint_active:	
		hint_index = 0
		set_hint(str(hint_matches[hint_index]), text.length())

	update_hint_list()

func update_hint_list() -> void:
	hint_list.clear()

	for name: StringName in hint_matches:
		if ConVars.exists(name):
			var value: Variant = ConVars.get_value(name)
			var display_value: String = str(value)

			if value is float and is_equal_approx(value, roundf(value)):
				display_value = str(roundi(value))

			hint_list.add_item("%s %s" % [name, display_value])
		else:
			hint_list.add_item(str(name))

	hint_list.resize()
	hint_list.update_position()

	if hint_matches.is_empty():
		hint_list.hide()
	else:
		hint_list.show()

func _on_hint_list_item_clicked(index: int, _at_position: Vector2, _mouse_button_index: int) -> void:
	var completion: String = hint_list.get_item_text(index)

	reset_hints()

	setting_hint = true
	line.text = completion
	line.deselect()
	line.caret_column = completion.length()
	setting_hint = false

	draft_input = completion
	history_index = input_history.size()

func set_hint(completion: String, selection_start: int) -> void:
	setting_hint = true

	line.text = completion
	line.caret_column = selection_start
	line.select(selection_start, completion.length())

	setting_hint = false


func confirm_or_cycle_hint() -> bool:
	if not hint_active or hint_matches.is_empty():
		return false

	if not hint_confirmed:
		hint_confirmed = true
	else:
		hint_index = (hint_index + 1) % hint_matches.size()

	history_index = input_history.size() + 1 + hint_index

	var completion: String = str(hint_matches[hint_index])

	if ConVars.exists(StringName(completion)):
		completion += " "

	setting_hint = true
	line.text = completion
	line.deselect()
	line.caret_column = completion.length()
	setting_hint = false

	return true

func accept_hint(completion: String) -> void:
	if Commands.has_arguments(StringName(completion)):
		completion += " "
	elif ConVars.exists(StringName(completion)):
		completion += " "

	setting_hint = true

	line.text = completion
	line.deselect()
	line.caret_column = completion.length()

	setting_hint = false

	draft_input = completion
	history_index = input_history.size()

	reset_hints()


func reset_hints() -> void:
	hint_matches.clear()
	hint_prefix = ""
	hint_index = -1
	hint_active = false
	hint_confirmed = false

	hint_list.clear()
	hint_list.hide()


func set_history_input(text: String) -> void:
	reset_hints()

	setting_hint = true

	line.text = text
	line.deselect()
	line.caret_column = line.text.length()

	setting_hint = false

	draft_input = text
	history_index = input_history.size()
