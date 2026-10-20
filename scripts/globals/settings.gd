extends Node

var music_volume: int:
	set(volume):
		volume = clampi(volume, 0, 100)
		if music_volume == volume:
			return
		
		music_volume = volume
		if not is_loading:
			save_setting("music_volume", music_volume)

var sfx_volume: int:
	set(volume):
		volume = clampi(volume, 0, 100)
		if sfx_volume == volume:
			return
		
		sfx_volume = volume
		if not is_loading:
			save_setting("sfx_volume", sfx_volume)



var config: ConfigFile = ConfigFile.new()
#const CONFIG_PATH: String = "user://settings.cfg"
const CONFIG_PATH: String = "res://settings.cfg"
var is_loading: bool = false


func _ready() -> void:
	load_config()

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
	music_volume = config.get_value("settings", "music_volume", 100)
	sfx_volume = config.get_value("settings", "sfx_volume", 100)
	is_loading = false

func save_config() -> void:
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
	
	print("Setting saved: %s: %d." %[key, value])
