extends Node


func _enter_tree() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _ready() -> void:
	initialize_framework()


func initialize_framework() -> void:
	Console.initialize(self)
	Settings.initialize(self)
	Scenes.initialize(self)
	HTTP.initialize(self)


func _exit_tree() -> void:
	Settings.save_config()
