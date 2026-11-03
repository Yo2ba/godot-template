extends Node

var cheats: bool = false

func _ready() -> void:
	Console.register_convar(&"sv_cheats", &"cheats", "Flag: cheats allowed")
