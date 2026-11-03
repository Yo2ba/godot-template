extends Node

var cheats: bool = false

func _ready() -> void:
	Console.register_convar(&"sv_cheats", &"cheats", "Flag: cheats allowed")
	await get_tree().create_timer(0.1).timeout
	Utils.prompt(func(): Console.execute_command(&"quit"), "Quit", "Are you sure you want to quit?")
