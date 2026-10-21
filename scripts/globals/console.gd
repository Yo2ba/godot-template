extends Node

const CONSOLE_SCENE: PackedScene = preload('uid://nugh2wokqnq3')


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

func log(message: String) -> void:
	var unix_time: float = Time.get_unix_time_from_system()
	var datetime: Dictionary = Time.get_datetime_dict_from_unix_time(int(unix_time))
	var milliseconds: int = int(fmod(unix_time, 1.0) * 1000.0)

	var timestamp: String = "%04d-%02d-%02dT%02d:%02d:%02d.%03dZ" % [
		datetime["year"],
		datetime["month"],
		datetime["day"],
		datetime["hour"],
		datetime["minute"],
		datetime["second"],
		milliseconds
	]

	var entry: String = "[`%s`] %s" % [timestamp, message]
	history += entry + "\n"

	if is_instance_valid(console_menu):
		console_menu.add_visible(message)
