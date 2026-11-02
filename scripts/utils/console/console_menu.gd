extends Control
@warning_ignore_start("shadowed_variable_base_class")

@export var window: PanelContainer
@export var output: RichTextLabel
@export var line: LineEdit
@export var close_btn: TextureButton
@export var title_grabber: PanelContainer
@export var handle_btn: TextureButton
@export var hint_list: ItemList

const MIN_WINDOW_SIZE: Vector2 = Vector2(300.0, 300.0)

var input_history: Array[String] = []
var history_index: int = 0
var draft_input: String = ""

var dragging: bool = false
var drag_offset: Vector2 = Vector2.ZERO

var resizing: bool = false
var resize_start_mouse: Vector2 = Vector2.ZERO
var resize_start_size: Vector2 = Vector2.ZERO

var hint_matches: Array[StringName] = []
var hint_prefix: String = ""
var hint_index: int = -1
var hint_list_index: int = -1
var hint_active: bool = false
var hint_confirmed: bool = false
var setting_hint: bool = false
var hint_blocked: bool = false

var selection_start: int = -1
var selection_end: int = -1
var selection_text: String = ""
var selection_pending: bool = false


func _ready() -> void:
	register_commands()
	hide()

	output.focus_mode = Control.FOCUS_CLICK

	line.text_changed.connect(_on_line_text_changed)
	line.text_submitted.connect(send)
	line.focus_exited.connect(_on_line_focus_exited)
	line.gui_input.connect(_on_line_gui_input)
	line.deselect_on_focus_loss_enabled = false

	hint_list.item_clicked.connect(_on_hint_list_item_clicked)

	close_btn.pressed.connect(func(): Console.toggle_console())
	visibility_changed.connect(_on_visibility_changed)

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


# --- Helpers for Shared State & Registered Names ---

func get_all_registered_names(case_insensitive_sort: bool = true) -> Array[StringName]:
	var names: Array[StringName] = Commands.get_all_names()

	for entry: StringName in ConVars.get_all_names():
		if not names.has(entry):
			names.append(entry)

	if case_insensitive_sort:
		names.sort_custom(func(a: StringName, b: StringName) -> bool:
			return str(a).to_lower() < str(b).to_lower()
		)
	else:
		names.sort()

	return names


func set_line_text_silent(new_text: String, select_from: int = -1) -> void:
	setting_hint = true
	line.text = new_text

	if select_from >= 0:
		line.caret_column = select_from
		line.select(select_from, new_text.length())
	else:
		line.deselect()
		line.caret_column = new_text.length()

	setting_hint = false


func clear_selection_state() -> void:
	selection_pending = false
	selection_start = -1
	selection_end = -1
	selection_text = ""


# --- Built-in Console Commands ---

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

	for entry: StringName in get_all_registered_names(true):
		var description: String = ""

		if Commands.exists(entry):
			description = Commands.get_description(entry)
		elif ConVars.exists(entry):
			description = ConVars.get_description(entry)

		Console.log("[Console]", "%s - %s" % [entry, description])


func clear() -> void:
	Console.history = ""
	output.text = ""


func echo(text: String = "") -> void:
	Console.log("[Console]", text)


func savelog() -> void:
	var now: Dictionary = Time.get_datetime_dict_from_system()
	var path: String = "user://console_%04d-%02d-%02d_%02d-%02d-%02d.log" % [
		now["year"], now["month"], now["day"],
		now["hour"], now["minute"], now["second"]
	]

	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		Console.log("Failed to save log: " + str(FileAccess.get_open_error()))
		return

	file.store_string(Console.history)
	file.close()
	Console.log("Log saved: %s" % path)


func escape(text: String) -> String:
	return text.replace("[", "[lb]")


func add_visible(message: String, color: Color = Color.WHITE) -> void:
	output.append_text("[color=#%s]%s[/color]\n" % [color.to_html(false), escape(message)])


# --- Input Handling ---

func _input(event: InputEvent) -> void:
	if not visible:
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_handle_mouse_button(event)
		return

	if event is InputEventMouseMotion:
		_handle_mouse_motion()
		return

	if event is InputEventKey and event.pressed and not event.echo:
		_handle_key_input(event)


func _handle_mouse_button(event: InputEventMouseButton) -> void:
	var mouse_pos: Vector2 = get_global_mouse_position()

	if event.pressed:
		if handle_btn.get_global_rect().has_point(mouse_pos):
			resizing = true
			resize_start_mouse = mouse_pos
			resize_start_size = window.size
		elif title_grabber.get_global_rect().has_point(mouse_pos):
			dragging = true
			drag_offset = window.global_position - mouse_pos
	else:
		if dragging:
			dragging = false
			Settings.console_position = window.position
		if resizing:
			resizing = false
			Settings.console_size = window.size


func _handle_mouse_motion() -> void:
	var screen_size: Vector2 = get_viewport_rect().size

	if resizing:
		var available_size: Vector2 = screen_size - window.global_position
		var mouse_delta: Vector2 = get_global_mouse_position() - resize_start_mouse
		var min_size: Vector2 = MIN_WINDOW_SIZE.min(available_size)

		window.size = (resize_start_size + mouse_delta).clamp(min_size, available_size)
		hint_list.update_position()

	elif dragging:
		var max_pos: Vector2 = screen_size - window.size
		var new_pos: Vector2 = get_global_mouse_position() + drag_offset

		window.global_position = new_pos.clamp(Vector2.ZERO, max_pos)
		hint_list.update_position()


func _handle_key_input(event: InputEventKey) -> void:
	var has_line_focus: bool = line.has_focus()

	if has_line_focus:
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

	if not has_line_focus:
		return

	match event.keycode:
		KEY_TAB:
			if confirm_or_cycle_hint():
				get_viewport().set_input_as_handled()
		KEY_RIGHT:
			if hint_active and hint_index >= 0:
				accept_hint(str(hint_matches[hint_index]))
				get_viewport().set_input_as_handled()
		KEY_UP, KEY_DOWN:
			var direction: int = -1 if event.keycode == KEY_UP else 1
			if hint_list.size.y > 0 and hint_list.get_item_count() > 0:
				navigate_hint_list(direction)
			else:
				navigate_history(direction)
			get_viewport().set_input_as_handled()


func _on_line_gui_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_BACKSPACE and selection_pending and selection_start == selection_end:
			clear_selection_state()
			get_viewport().set_input_as_handled()


# --- Focus & Selection Persistence ---

func remember_line_selection() -> void:
	if not line.has_selection():
		clear_selection_state()
		return

	selection_start = line.get_selection_from_column()
	selection_end = line.get_selection_to_column()
	selection_text = line.text
	selection_pending = true


func restore_hint_selection() -> void:
	if not selection_pending:
		return

	if line.text != selection_text or selection_start < 0 or selection_end > line.text.length():
		selection_pending = false
		return

	line.select(selection_start, selection_end)


func _on_line_focus_exited() -> void:
	if not is_inside_tree():
		return

	remember_line_selection()
	hint_list.resize()
	line.deselect()


func _on_visibility_changed() -> void:
	if visible:
		line.grab_focus()
		restore_hint_selection()
	else:
		if line.has_focus():
			line.release_focus()
		else:
			hint_list.resize()


# --- History & Hint Navigation ---

func navigate_hint_list(direction: int) -> void:
	var count: int = hint_list.get_item_count()
	if count == 0:
		return

	if hint_list_index == -1:
		hint_list_index = count - 1 if direction < 0 else 0
	else:
		hint_list_index = posmod(hint_list_index + direction, count)

	hint_list.deselect_all()
	hint_list.select(hint_list_index)
	hint_list.ensure_current_is_visible()

	set_line_text_silent(hint_list.get_item_text(hint_list_index))


func navigate_history(direction: int) -> void:
	var max_index: int = input_history.size() + hint_list.get_item_count()
	var new_index: int = clampi(history_index + direction, 0, max_index)

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

	set_line_text_silent(text)


func _on_line_text_changed(text: String) -> void:
	if setting_hint:
		return

	clear_selection_state()
	reset_hints()

	history_index = input_history.size()
	draft_input = text

	if not line.has_focus() or hint_blocked or text.is_empty() or text.contains(" "):
		return

	hint_prefix = text.to_lower()
	update_hint_list(hint_prefix)

	for name: StringName in get_all_registered_names(false):
		if str(name).begins_with(hint_prefix):
			hint_matches.append(name)

	hint_active = not hint_matches.is_empty()
	if hint_active:
		hint_index = 0
		set_hint(str(hint_matches[hint_index]), text.length())


func update_hint_list(query: String) -> void:
	hint_list.clear()
	hint_list_index = -1

	var names: Array[StringName] = get_all_registered_names(true)
	var substring_matches: Array[StringName] = []

	for name: StringName in names:
		var normalized: String = str(name).to_lower()
		if normalized.begins_with(query):
			add_hint_item(name)
		elif normalized.contains(query):
			substring_matches.append(name)

	for name: StringName in substring_matches:
		add_hint_item(name)

	hint_list.resize()
	hint_list.update_position()


func add_hint_item(name: StringName) -> void:
	var hint: String = str(name)
	if ConVars.exists(name):
		hint += " " + str(ConVars.get_value(name))
	hint_list.add_item(hint)


func _on_hint_list_item_clicked(index: int, _at_position: Vector2, _mouse_button_index: int) -> void:
	set_history_input(hint_list.get_item_text(index))


func set_hint(completion: String, caret_position: int) -> void:
	set_line_text_silent(completion, caret_position)

	selection_start = caret_position
	selection_end = completion.length()
	selection_text = completion
	selection_pending = true


func confirm_or_cycle_hint() -> bool:
	if not hint_active or hint_matches.is_empty():
		return false

	if not hint_confirmed:
		hint_confirmed = true
	else:
		hint_index = (hint_index + 1) % hint_matches.size()

	clear_selection_state()
	history_index = input_history.size() + 1 + hint_index

	var completion: String = str(hint_matches[hint_index])
	if ConVars.exists(StringName(completion)):
		completion += " "

	set_line_text_silent(completion)
	return true


func accept_hint(completion: String) -> void:
	var key: StringName = StringName(completion)
	if Commands.has_arguments(key) or ConVars.exists(key):
		completion += " "

	set_history_input(completion)


func reset_hints() -> void:
	hint_matches.clear()
	hint_prefix = ""
	hint_index = -1
	hint_list_index = -1
	hint_active = false
	hint_confirmed = false

	hint_list.clear()
	hint_list.resize()


func set_history_input(text: String) -> void:
	reset_hints()
	set_line_text_silent(text)
	draft_input = text
	history_index = input_history.size()


# --- Command Execution & Parsing ---

func send(text: String) -> void:
	var input: String = text.strip_edges()
	if input.is_empty():
		return

	var parts: PackedStringArray = parse_arguments(input)
	if parts.is_empty():
		return

	input_history.erase(input)
	input_history.append(input)
	history_index = input_history.size()
	draft_input = ""

	line.clear()
	reset_hints()

	var name: StringName = StringName(parts[0])
	var lookup_name: StringName = StringName(str(name).to_lower())

	Console.log("> " + input, Color.GRAY)

	if Commands.exists(lookup_name):
		var args: Array = Array(parts.slice(1))
		Commands.execute(lookup_name, args)
		return

	if not ConVars.exists(lookup_name):
		Console.log("Unknown command: %s" % name)
		return

	if parts.size() == 1:
		var display_value: Variant = ConVars.get_value(lookup_name)
		if display_value is float and is_equal_approx(display_value, int(display_value)):
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

		TYPE_INT, TYPE_FLOAT:
			if not value_text.is_valid_float():
				Console.log("Expected a numeric value.", Color.RED)
				return
			@warning_ignore("incompatible_ternary")
			value = int(value_text.to_float()) if typeof(current_value) == TYPE_INT else value_text.to_float()

		TYPE_STRING:
			value = value_text

		_:
			Console.log("Unsupported ConVar type.", Color.RED)
			return

	ConVars.set_value(lookup_name, value)


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
