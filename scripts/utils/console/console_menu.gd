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
var hint_restore_text: String = ""

var selection_start: int = -1
var selection_end: int = -1
var selection_text: String = ""
var selection_pending: bool = false


func _ready() -> void:
	register_commands()
	hide()
	set_process_input(false)

	output.focus_mode = Control.FOCUS_CLICK

	line.text_changed.connect(_on_line_text_changed)
	line.text_submitted.connect(send)
	line.focus_exited.connect(_on_line_focus_exited)
	line.gui_input.connect(_on_line_gui_input)
	line.deselect_on_focus_loss_enabled = false

	hint_list.item_clicked.connect(_on_hint_list_item_clicked)

	close_btn.pressed.connect(Console.toggle_console)
	visibility_changed.connect(_on_visibility_changed)

	window.position = Settings.console_position
	window.size = Settings.console_size

	Console.console_menu = self
	history_index = input_history.size()


func register_commands() -> void:
	Console.register_command(&"clear", clear, "Clears the console log")
	Console.register_command(&"log", savelog, "Saves console log")
	Console.register_command(&"echo", echo, "Echo text to console")
	Console.register_command(&"quit", func(): get_tree().quit(), "Quit the game")
	Console.register_command(&"help", help, "Shows command descriptions")


# --- Helpers for Line State ---

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
		if Console.exists(entry):
			Console.log("[Console]", "%s - %s" % [entry, Console.get_description(entry)])
		else:
			Console.log("[Console]", "help: no cvar or command named %s" % name)
		return

	for entry: StringName in Console.get_sorted_names():
		Console.log("[Console]", "%s - %s" % [entry, Console.get_description(entry)])


func clear() -> void:
	Console.history.clear()
	output.clear()


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

	file.store_string("\n".join(Console.history) + "\n")
	file.close()
	Console.log("Log saved: %s" % path)


func add_visible(message: String, color: Color = Color.WHITE) -> void:
	output.push_color(color)
	output.add_text(message + "\n")
	output.pop()


# --- Input Handling ---

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		if resizing or dragging:
			_handle_mouse_motion()
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_handle_mouse_button(event)
		return

	if event is InputEventKey and event.pressed:
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
		elif event.unicode > 0:
			hint_blocked = false

	if event.keycode == KEY_ESCAPE and not event.echo:
		hide()
		get_viewport().set_input_as_handled()
		return

	if event.keycode == KEY_C and event.ctrl_pressed and not event.echo:
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
			if not event.echo and hint_active and hint_index >= 0 and not hint_blocked:
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
	if event is InputEventKey and event.pressed:
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
	line.deselect()
	# Deferred so a click on the HintList still registers before it is emptied
	reset_hints.call_deferred()
	hint_list.resize()


func _on_visibility_changed() -> void:
	set_process_input(visible)

	if visible:
		line.grab_focus()
		restore_hint_selection()
		if not hint_restore_text.is_empty():
			populate_hints(hint_restore_text, false)
			hint_restore_text = ""
	else:
		hint_restore_text = hint_prefix if hint_list.get_item_count() > 0 else ""
		if line.has_focus():
			line.release_focus()
		else:
			hint_list.resize()


# --- History & Hint Navigation ---

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

func navigate_hint_list(direction: int) -> void:
	var count: int = hint_list.get_item_count()
	if count == 0:
		return

	if hint_list_index == -1:
		hint_list_index = count - 1 if direction < 0 else 0
	else:
		hint_list_index = posmod(hint_list_index + direction, count)

	hint_index = hint_list_index
	hint_confirmed = true

	hint_list.deselect_all()
	hint_list.select(hint_list_index)
	hint_list.ensure_current_is_visible()

	set_line_text_silent(hint_list.get_item_text(hint_list_index))

func _on_line_text_changed(text: String) -> void:
	if setting_hint:
		return

	var is_deletion: bool = text.length() < draft_input.length()

	# Only auto-lowercase if the entire input string is a valid prefix of a command or ConVar
	if not is_deletion:
		var lower_text: String = text.to_lower()
		var matches_full_prefix: bool = false

		for name: StringName in Console.get_sorted_names():
			if str(name).to_lower().begins_with(lower_text):
				matches_full_prefix = true
				break

		if matches_full_prefix and lower_text != text:
			setting_hint = true
			var caret: int = line.caret_column
			line.text = lower_text
			line.caret_column = caret
			setting_hint = false
			text = lower_text

	clear_selection_state()
	reset_hints()

	history_index = input_history.size()
	draft_input = text

	if not line.has_focus() or text.is_empty() or text.contains(" "):
		return

	populate_hints(text)


func populate_hints(text: String, inline: bool = true) -> void:
	hint_prefix = text.to_lower()
	var substring_matches: Array[StringName] = []

	for name: StringName in Console.get_sorted_names():
		var name_str: String = str(name)
		var lower_name: String = name_str.to_lower()
		
		if lower_name.begins_with(hint_prefix):
			hint_matches.append(name)
			add_hint_item(name, name_str)
		elif lower_name.contains(hint_prefix):
			substring_matches.append(name)

	for name: StringName in substring_matches:
		hint_matches.append(name)
		add_hint_item(name, str(name))

	hint_list.resize()

	hint_active = not hint_matches.is_empty()
	if hint_active:
		var first_match: String = str(hint_matches[0])
		if first_match.to_lower().begins_with(hint_prefix):
			hint_index = 0
			hint_confirmed = false
			if inline and not hint_blocked:
				set_hint(first_match, text.length())
		else:
			hint_index = -1
			hint_confirmed = true

func confirm_or_cycle_hint() -> bool:
	if not hint_active or hint_matches.is_empty():
		return false

	if not hint_confirmed:
		hint_confirmed = true
	else:
		hint_index = (hint_index + 1) % hint_matches.size()

	hint_list_index = hint_index
	clear_selection_state()
	history_index = input_history.size() + 1 + hint_index

	var match_name: StringName = hint_matches[hint_index]
	var completion: String = str(match_name)
	if Console.is_convar(match_name):
		completion += " "

	set_line_text_silent(completion)
	return true

func add_hint_item(name: StringName, name_str: String) -> void:
	if Console.is_convar(name):
		var value: Variant = Console.get_convar_value(name)
		if value is float:
			if is_equal_approx(value, int(value)):
				value = int(value)
			else:
				value = String.num(value)
		hint_list.add_item(name_str + " " + str(value))
	else:
		hint_list.add_item(name_str)


func _on_hint_list_item_clicked(index: int, _at_position: Vector2, _mouse_button_index: int) -> void:
	set_history_input(hint_list.get_item_text(index))


func set_hint(completion: String, caret_position: int) -> void:
	set_line_text_silent(completion, caret_position)

	selection_start = caret_position
	selection_end = completion.length()
	selection_text = completion
	selection_pending = true


func accept_hint(completion: String) -> void:
	var key: StringName = StringName(completion)
	if Console.has_arguments(key) or Console.is_convar(key):
		completion += " "

	set_history_input(completion)


func reset_hints() -> void:
	if hint_matches.is_empty() and hint_list.get_item_count() == 0 and not hint_active:
		return

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
	var lookup_name: StringName = StringName(parts[0].to_lower())

	Console.log("> " + input, Color.GRAY)

	if Console.is_command(lookup_name):
		Console.execute_command(lookup_name, Array(parts.slice(1)))
		return

	if not Console.is_convar(lookup_name):
		Console.log("Unknown command: %s" % name)
		return

	if parts.size() == 1:
		var display_value: Variant = Console.get_convar_value(lookup_name)
		if display_value is float and is_equal_approx(display_value, int(display_value)):
			display_value = int(display_value)

		Console.log("[Console]", "%s = %s" % [name, display_value])
		return

	var value_text: String = " ".join(parts.slice(1))
	var current_value: Variant = Console.get_convar_value(lookup_name)
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

	Console.set_convar_value(lookup_name, value)


func parse_arguments(input: String) -> PackedStringArray:
	var args: PackedStringArray = []
	var current: String = ""
	var in_quotes: bool = false
	var escaping: bool = false
	var token_started: bool = false

	for i: int in input.length():
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
