extends LineEdit

var setting_hint: bool = false
var hint_blocked: bool = false

var selection_start: int = -1
var selection_end: int = -1
var selection_text: String = ""
var selection_pending: bool = false


func _ready() -> void:
	deselect_on_focus_loss_enabled = false
	focus_exited.connect(_on_focus_exited)


func _gui_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed):
		return

	if event.keycode == KEY_BACKSPACE or (event.keycode == KEY_X and event.ctrl_pressed):
		hint_blocked = true
	elif event.unicode > 0 and not event.ctrl_pressed:
		hint_blocked = false

	if event.is_action_pressed(&"ui_text_submit", true) and event.echo:
		text_submitted.emit(text)
		get_viewport().set_input_as_handled()
		return

	if event.keycode == KEY_BACKSPACE and selection_pending and selection_start == selection_end:
		clear_selection_state()
		get_viewport().set_input_as_handled()


func set_text_silent(new_text: String, select_from: int = -1) -> void:
	setting_hint = true
	text = new_text

	if select_from >= 0:
		caret_column = select_from
		select(select_from, new_text.length())
	else:
		deselect()
		caret_column = new_text.length()

	setting_hint = false


func set_hint(completion: String, caret_position: int) -> void:
	set_text_silent(completion, caret_position)

	selection_start = caret_position
	selection_end = completion.length()
	selection_text = completion
	selection_pending = true


func normalize_case(is_deletion: bool) -> String:
	if is_deletion:
		return text

	var lower_text: String = text.to_lower()
	if lower_text == text:
		return text

	for entry_name: StringName in Console.get_sorted_names():
		if str(entry_name).to_lower().begins_with(lower_text):
			setting_hint = true
			var caret: int = caret_column
			text = lower_text
			caret_column = caret
			setting_hint = false
			return lower_text

	return text


func clear_selection_state() -> void:
	selection_pending = false
	selection_start = -1
	selection_end = -1
	selection_text = ""


func remember_selection() -> void:
	if not has_selection():
		clear_selection_state()
		return

	selection_start = get_selection_from_column()
	selection_end = get_selection_to_column()
	selection_text = text
	selection_pending = true


func restore_selection() -> void:
	if not selection_pending:
		return

	if text != selection_text or selection_start < 0 or selection_end > text.length():
		selection_pending = false
		return

	select(selection_start, selection_end)


func _on_focus_exited() -> void:
	if not is_inside_tree():
		return

	remember_selection()
	deselect()
