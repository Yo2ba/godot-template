extends PopupMenu


func _ready() -> void:
	# Listen to the root window so we catch RMB both while hidden and before
	# the open PopupMenu consumes outside clicks to close itself.
	get_tree().root.window_input.connect(_on_root_window_input)


func _on_root_window_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		var mouse_pos: Vector2i = _get_popup_mouse_pos()
		
		if visible:
			# Keep normal menu behavior if RMB is pressed inside the open menu.
			# Remove this check if you want RMB inside the menu to also move it.
			if Rect2i(position, size).has_point(mouse_pos):
				return
			
			# Defer reopening until Godot finishes its internal popup-close pass
			_open_at_mouse.call_deferred(mouse_pos)
		else:
			_open_at_mouse(mouse_pos)


func _open_at_mouse(mouse_pos: Vector2i) -> void:
	position = mouse_pos
	popup()


func _get_popup_mouse_pos() -> Vector2i:
	if is_embedded():
		return Vector2i(get_tree().root.get_mouse_position())
	return DisplayServer.mouse_get_position()
