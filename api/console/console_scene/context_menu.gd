extends Control

const CONTEXT_MENU_THEME = preload("uid://b57q4puu0y02w")

var context_menu_width: int = 240
var context_menu_offset_x: int = 20

@export var line: LineEdit
@export var output: RichTextLabel

var mouse_on: Control
var context_menu: ItemList
var pressed_item_index: int = -1


func _ready() -> void:
	for node in [line, output]:
		node.mouse_entered.connect(func(): mouse_on = node)
		node.mouse_exited.connect(func(): mouse_on = null)


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.is_released():
		handle_menu(event.button_index)


func handle_menu(mouse_btn: MouseButton) -> void:
	if mouse_btn not in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
		return
	
	if not context_menu:
		if mouse_btn == MOUSE_BUTTON_RIGHT and mouse_on:
			add_menu(get_global_mouse_position())
		return
	
	if pressed_item_index != -1:
		var released_item_index: int = get_hovered_item_index()
		var clicked_index: int = pressed_item_index
		pressed_item_index = -1
	
		if mouse_btn == MOUSE_BUTTON_RIGHT or released_item_index != clicked_index:
			context_menu.deselect_all()
			if released_item_index != clicked_index:
				context_menu.notification(NOTIFICATION_MOUSE_EXIT)
			return
		
		execute_action(context_menu.get_item_text(clicked_index))
	
	context_menu.queue_free()
	context_menu = null

func execute_action(item_text: String) -> void:
	match item_text:
		"Cut":
			line.menu_option(LineEdit.MENU_CUT)
		"Copy":
			line.menu_option(LineEdit.MENU_COPY)
		"Paste":
			line.menu_option(LineEdit.MENU_PASTE)
		"Copy selected text":
			output.menu_option(RichTextLabel.MENU_COPY)
		"Copy All Text":
			DisplayServer.clipboard_set(output.get_parsed_text())
		"Select All":
			output.grab_focus()
			output.select_all()
		"Save to Log":
			Console.execute_command(&"log")

func get_hovered_item_index() -> int:
	if not context_menu:
		return -1
	if not context_menu.get_global_rect().has_point(get_global_mouse_position()):
		return -1
	return context_menu.get_item_at_position(context_menu.get_local_mouse_position(), true)


func menu_gui_input(event: InputEvent) -> void:
	if pressed_item_index != -1 and event is InputEventMouseMotion:
		if get_hovered_item_index() != pressed_item_index:
			context_menu.accept_event()


func item_clicked(index: int, _at_position: Vector2, mouse_button_index: int) -> void:
	if mouse_button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
		pressed_item_index = index


func add_menu(at_position: Vector2) -> void:
	context_menu = ItemList.new()
	context_menu.theme = CONTEXT_MENU_THEME
	context_menu.auto_height = true
	context_menu.allow_rmb_select = true
	context_menu.allow_search = false
	match mouse_on:
		line:
			if line.has_selection():
				var selection_from: int = line.get_selection_from_column()
				var selection_to: int = line.get_selection_to_column()
				line.release_focus()
				line.select(selection_from, selection_to)
				context_menu.add_item("Cut")
				context_menu.add_item("Copy")
			else:
				line.release_focus()
			context_menu.add_item("Paste")
		output:
			output.grab_focus()
			if output.get_selection_from() != output.get_selection_to():
				context_menu.add_item("Copy selected text")
			context_menu.add_item("Copy All Text")
			context_menu.add_item("Select All")
			context_menu.add_item("Save to Log")
	
	for i in range(context_menu.get_item_count()):
		context_menu.set_item_tooltip_enabled(i, false)
	
	context_menu.item_clicked.connect(item_clicked)
	context_menu.gui_input.connect(menu_gui_input)
	add_child(context_menu)
	
	context_menu.size.x = 240
	context_menu.force_update_list_size()
	
	var context_menu_height: float = context_menu.get_minimum_size().y / 2.0
	var window_width: float = get_viewport_rect().size.x
	
	if at_position.x + context_menu_width + context_menu_offset_x >= window_width:
		context_menu.global_position = at_position + Vector2(
			-context_menu_offset_x - context_menu_width,
			-context_menu_height
		)
	else:
		context_menu.global_position = at_position + Vector2(20, -context_menu_height)
