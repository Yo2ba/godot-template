extends Node

const CONSOLE_SCENE: PackedScene = preload('uid://nugh2wokqnq3')

var current_color: Color = Color.WHITE

var console_menu: Control
var history: String

func _ready() -> void:
	console_menu = CONSOLE_SCENE.instantiate()
	get_tree().root.add_child.call_deferred(console_menu)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_QUOTELEFT and not event.is_echo():
			toggle_console()
			get_viewport().set_input_as_handled()

func toggle_console() -> void:
	console_menu.visible = !console_menu.visible

func color(value: Color = Color.WHITE) -> void:
	current_color = value


func log(... args: Array) -> void:
	if args.is_empty():
		return
	
	var message_color: Color = current_color
	
	if args.back() is Color:
		message_color = args.pop_back()
	
	var message: String = " ".join(
		args.map(func(arg: Variant) -> String: return str(arg))
	)
	
	history += message + "\n"
	
	if is_instance_valid(console_menu):
		console_menu.add_visible(message, message_color)
