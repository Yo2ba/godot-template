extends Control

var context_menu: ItemList
var pressed_item_index: int = -1


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.is_released():
		handle_menu(event.button_index)


func handle_menu(mouse_btn: MouseButton) -> void:
	if mouse_btn not in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
		return

	if not context_menu:
		if mouse_btn == MOUSE_BUTTON_RIGHT:
			add_menu(get_global_mouse_position())
		return

	# If LMB or RMB was initially held on an item, check release conditions
	if pressed_item_index != -1:
		var released_item_index: int = get_hovered_item_index()
		var clicked_index: int = pressed_item_index
		pressed_item_index = -1

		# Do nothing if RMB was used on an item, or if LMB was released elsewhere
		if mouse_btn == MOUSE_BUTTON_RIGHT or released_item_index != clicked_index:
			context_menu.deselect_all()
			return

		print(clicked_index)

	# Close on release for both LMB and RMB (valid LMB item click, empty space, or outside)
	context_menu.queue_free()
	context_menu = null


func get_hovered_item_index() -> int:
	if not context_menu:
		return -1
	if not context_menu.get_global_rect().has_point(get_global_mouse_position()):
		return -1
	return context_menu.get_item_at_position(context_menu.get_local_mouse_position(), true)


func item_clicked(index: int, _at_position: Vector2, mouse_button_index: int) -> void:
	if mouse_button_index == MOUSE_BUTTON_LEFT:
		pressed_item_index = index
	elif mouse_button_index == MOUSE_BUTTON_RIGHT:
		pressed_item_index = index
		context_menu.deselect_all()


func add_menu(at_position: Vector2) -> void:
	context_menu = ItemList.new()
	context_menu.allow_rmb_select = true
	context_menu.add_item("Copy All Text")
	context_menu.add_item("Select All")
	context_menu.add_item("Save To Log")
	
	context_menu.item_clicked.connect(item_clicked)
	add_child(context_menu)
	context_menu.size = Vector2(260, 120)
	context_menu.position = at_position
