extends Node

var music_volume: float:
	set(volume):
		volume = clampf(volume, 0.0, 1.0)
		if is_equal_approx(music_volume, volume):
			return
		
		music_volume = volume
		var bus_index := AudioServer.get_bus_index("music")
		AudioServer.set_bus_mute(bus_index, volume == 0.0)
		AudioServer.set_bus_volume_linear(bus_index, volume)
		
		if not is_loading:
			save_setting("music_volume", music_volume)

var sfx_volume: float:
	set(volume):
		volume = clampf(volume, 0.0, 1.0)
		if is_equal_approx(sfx_volume, volume):
			return
		
		sfx_volume = volume
		var bus_index := AudioServer.get_bus_index("sfx")
		AudioServer.set_bus_mute(bus_index, volume == 0.0)
		AudioServer.set_bus_volume_linear(bus_index, volume)
		if not is_loading:
			save_setting("sfx_volume", sfx_volume)

var console_position: Vector2 = Vector2.ZERO:
	set(value):
		if console_position == value:
			return

		console_position = value

		if not is_loading:
			save_setting("console_position", console_position)

var console_size: Vector2 = Vector2(600.0, 400.0):
	set(value):
		if console_size == value:
			return

		console_size = value

		if not is_loading:
			save_setting("console_size", console_size)


var config: ConfigFile = ConfigFile.new()
#const CONFIG_PATH: String = "user://settings.cfg"
const CONFIG_PATH: String = "res://settings.cfg"
var is_loading: bool = false


func _ready() -> void:
	load_config()
	ConVars.register(self, &"music", &"music_volume", TYPE_FLOAT)
	ConVars.register(self, &"sfx", &"sfx_volume", TYPE_FLOAT)

func _exit_tree() -> void:
	save_config()

func load_config() -> void:
	var error: Error = config.load(CONFIG_PATH)
	
	if error == ERR_FILE_NOT_FOUND:
		print("Settings: Config file not found. Using defaults.")
	elif error != OK:
		push_error("Settings: Config file has not been loaded.")
		return
	
	is_loading = true
	console_position = config.get_value("settings", "console_position", Vector2.ZERO)
	console_size = config.get_value("settings", "console_size", Vector2(600.0, 400.0))
	music_volume = config.get_value("settings", "music_volume", 1.0)
	sfx_volume = config.get_value("settings", "sfx_volume", 1.0)
	is_loading = false

func save_config() -> void:
	config.set_value("settings", "console_position", console_position)
	config.set_value("settings", "console_size", console_size)
	config.set_value("settings", "music_volume", music_volume)
	config.set_value("settings", "sfx_volume", sfx_volume)
	
	var error: Error = config.save(CONFIG_PATH)
	
	if error != OK:
		push_error("Settings: Config file has not been saved.")
		return
	
	print("Config saved successfully.")

func save_setting(key: String, value: Variant) -> void:
	config.set_value("settings", key, value)
	
	var error: Error = config.save(CONFIG_PATH)
	
	if error != OK:
		push_error("Settings: Setting has not been saved.")
		return
	
	print("Setting saved: %s: %s." %[key, str(value)])
