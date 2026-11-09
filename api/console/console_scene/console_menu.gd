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
var drag_start_mouse: Vector2 = Vector2.ZERO
var has_dragged: bool = false

var resizing: bool = false
var resize_start_mouse: Vector2 = Vector2.ZERO
var resize_start_size: Vector2 = Vector2.ZERO

var hint_matches: Array[StringName] = []
var hint_index: int = -1
var hint_confirmed: bool = false
var hint_restore_text: String = ""


func _ready() -> void:
	register_commands()
	hide()
	set_process_input(false)

	line.text_changed.connect(_on_line_text_changed)
	line.text_submitted.connect(send)
	line.focus_exited.connect(_on_line_focus_exited)

	hint_list.item_clicked.connect(func(idx: int, _pos: Vector2, _btn: int) -> void:
		set_history_input(hint_list.get_item_text(idx))
	)
	close_btn.pressed.connect(func() -> void:
		if not has_dragged:
			Console.toggle_console()
	)
	visibility_changed.connect(_on_visibility_changed)

	window.position = Settings.console_position
	window.size = Settings.console_size

	Console.console_menu = self


func register_commands() -> void:
	Console.register_command(&"clear", clear, "Clears the console log")
	Console.register_command(&"log", savelog, "Saves console log")
	Console.register_command(&"echo", echo, "Echo text to console")
	Console.register_command(&"quit", func() -> void: get_tree().quit(), "Quit the game")
	Console.register_command(&"help", help, "Shows command descriptions")


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
	var filename: String = "console_%04d-%02d-%02d_%02d-%02d-%02d.log" % [
		now["year"], now["month"], now["day"],
		now["hour"], now["minute"], now["second"]
	]
	var file: FileAccess = FileAccess.open("user://" + filename, FileAccess.WRITE)
	if file == null:
		Console.log("Failed to save log: " + str(FileAccess.get_open_error()))
		return

	file.store_string("\n".join(Console.history) + "\n")
	file.close()
	Console.log("Log saved: %s/%s" % [OS.get_user_data_dir(), filename])


func add_visible(message: String, color: Color = Color.WHITE) -> void:
	output.push_color(color)
	output.add_text(message + "\n")
	output.pop()


# --- Input Handling ---

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		if resizing or dragging:
			_handle_mouse_motion()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_handle_mouse_button(event)
	elif event is InputEventKey and event.pressed:
		_handle_key_input(event)


func _handle_mouse_button(event: InputEventMouseButton) -> void:
	var mouse_pos: Vector2 = get_global_mouse_position()

	if event.pressed:
		has_dragged = false
		if handle_btn.get_global_rect().has_point(mouse_pos):
			resizing = true
			resize_start_mouse = mouse_pos
			resize_start_size = window.size
		elif title_grabber.get_global_rect().has_point(mouse_pos):
			dragging = true
			drag_start_mouse = mouse_pos
			drag_offset = window.global_position - mouse_pos
			if line.has_focus():
				line.release_focus()
	else:
		if dragging:
			dragging = false
			Settings.console_position = window.position
		if resizing:
			resizing = false
			Settings.console_size = window.size


func _handle_mouse_motion() -> void:
	if resizing:
		has_dragged = true
		var available_size: Vector2 = get_viewport_rect().size - window.global_position
		var mouse_delta: Vector2 = get_global_mouse_position() - resize_start_mouse
		window.size = (resize_start_size + mouse_delta).clamp(MIN_WINDOW_SIZE.min(available_size), available_size)
		hint_list.update_position()
	elif dragging:
		var current_pos: Vector2 = get_global_mouse_position()
		if current_pos.distance_to(drag_start_mouse) > 4.0:
			has_dragged = true
		window.global_position = current_pos + drag_offset
		hint_list.update_position()


func _handle_key_input(event: InputEventKey) -> void:
	if event.keycode == KEY_ESCAPE and not event.echo:
		hide()
		get_viewport().set_input_as_handled()
		return

	var has_line_focus: bool = line.has_focus()

	if event.keycode == KEY_C and event.ctrl_pressed and not event.echo:
		if not (has_line_focus and line.has_selection()):
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
			if not event.echo and hint_index >= 0 and not line.hint_blocked:
				accept_hint(str(hint_matches[hint_index]))
				get_viewport().set_input_as_handled()
		KEY_UP, KEY_DOWN:
			var direction: int = -1 if event.keycode == KEY_UP else 1
			if hint_list.size.y > 0 and hint_list.get_item_count() > 0:
				navigate_hint_list(direction)
			else:
				navigate_history(direction)
			get_viewport().set_input_as_handled()


# --- Focus & Visibility ---

func _on_line_focus_exited() -> void:
	if not is_inside_tree():
		return

	reset_hints.call_deferred()
	hint_list.resize()


func _on_visibility_changed() -> void:
	set_process_input(visible)

	if visible:
		line.grab_focus()
		line.restore_selection()
		if not hint_restore_text.is_empty():
			populate_hints(hint_restore_text, false)
			hint_restore_text = ""
	else:
		hint_restore_text = draft_input if not hint_matches.is_empty() else ""
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

	if history_index < input_history.size():
		line.set_text_silent(input_history[history_index])
	elif history_index == input_history.size():
		line.set_text_silent(draft_input)
	else:
		line.set_text_silent(hint_list.get_item_text(history_index - input_history.size() - 1))


func navigate_hint_list(direction: int) -> void:
	var count: int = hint_list.get_item_count()
	if count == 0:
		return

	hint_index = (count - 1 if direction < 0 else 0) if hint_index == -1 else posmod(hint_index + direction, count)
	hint_confirmed = true

	hint_list.select(hint_index)
	hint_list.ensure_current_is_visible()
	line.set_text_silent(hint_list.get_item_text(hint_index))


func _on_line_text_changed(text: String) -> void:
	if line.setting_hint:
		return

	text = line.normalize_case(text.length() < draft_input.length())
	line.clear_selection_state()
	reset_hints()

	history_index = input_history.size()
	draft_input = text

	if line.has_focus() and not text.is_empty() and not text.contains(" "):
		populate_hints(text)


func populate_hints(text: String, inline: bool = true) -> void:
	var prefix: String = text.to_lower()
	var substring_matches: Array[StringName] = []

	for name: StringName in Console.get_sorted_names():
		var lower_name: String = str(name).to_lower()
		if lower_name.begins_with(prefix):
			hint_matches.append(name)
			add_hint_item(name)
		elif lower_name.contains(prefix):
			substring_matches.append(name)

	for name: StringName in substring_matches:
		hint_matches.append(name)
		add_hint_item(name)

	hint_list.resize()

	if hint_matches.is_empty():
		return

	var first_match: String = str(hint_matches[0])
	if first_match.to_lower().begins_with(prefix):
		hint_index = 0
		hint_confirmed = false
		if inline and not line.hint_blocked:
			line.set_hint(first_match, text.length())
	else:
		hint_index = -1
		hint_confirmed = true


func confirm_or_cycle_hint() -> bool:
	if hint_matches.is_empty():
		return false

	if not hint_confirmed:
		hint_confirmed = true
	else:
		hint_index = (hint_index + 1) % hint_matches.size()

	line.clear_selection_state()
	history_index = input_history.size() + 1 + hint_index

	var match_name: StringName = hint_matches[hint_index]
	var completion: String = str(match_name) + (" " if Console.is_convar(match_name) else "")
	line.set_text_silent(completion)
	return true


func add_hint_item(name: StringName) -> void:
	if Console.is_convar(name):
		hint_list.add_item("%s %s" % [name, _format_value(Console.get_convar_value(name))])
	else:
		hint_list.add_item(str(name))


func accept_hint(completion: String) -> void:
	var key: StringName = StringName(completion)
	if Console.has_arguments(key) or Console.is_convar(key):
		completion += " "
	set_history_input(completion)


func reset_hints() -> void:
	if hint_matches.is_empty() and hint_list.get_item_count() == 0:
		return

	hint_matches.clear()
	hint_index = -1
	hint_confirmed = false
	hint_list.clear()
	hint_list.resize()


func set_history_input(text: String) -> void:
	reset_hints()
	line.set_text_silent(text)
	draft_input = text
	history_index = input_history.size()


func _format_value(value: Variant) -> String:
	if value is float:
		return str(int(value)) if is_equal_approx(value, int(value)) else String.num(value)
	return str(value)


# --- Command Execution & Parsing ---

func send(text: String) -> void:
	var input: String = text.strip_edges()
	Console.log("> " + input, Color.GRAY)
	line.clear()
	draft_input = ""
	history_index = input_history.size()
	reset_hints()

	if input.is_empty():
		return

	var parts: PackedStringArray = parse_arguments(input)
	if parts.is_empty():
		return

	input_history.erase(input)
	input_history.append(input)
	history_index = input_history.size()

	var name: StringName = StringName(parts[0])
	var lookup_name: StringName = StringName(parts[0].to_lower())

	if Console.is_command(lookup_name):
		Console.execute_command(lookup_name, Array(parts.slice(1)))
		return

	if not Console.is_convar(lookup_name):
		Console.log("Unknown command: %s" % name)
		return

	var current_value: Variant = Console.get_convar_value(lookup_name)
	if parts.size() == 1:
		Console.log("[Console]", "%s = %s" % [name, _format_value(current_value)])
		return

	var parsed_value: Variant = Console.parse_value(" ".join(parts.slice(1)), typeof(current_value))
	if parsed_value != null:
		Console.set_convar_value(lookup_name, parsed_value)


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
		elif character == "\\" and in_quotes:
			escaping = true
		elif character == "\"":
			in_quotes = not in_quotes
			token_started = true
		elif character == " " and not in_quotes:
			if token_started:
				args.append(current)
				current = ""
				token_started = false
		else:
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
