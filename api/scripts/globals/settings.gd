extends Node

const CONFIG_PATH: String = "user://settings.cfg"
const DEBUG_SCENE = preload("uid://dxrsku6jfcilv")

var config: ConfigFile = ConfigFile.new()
var is_loading: bool = false
var debug_menu: Control

@onready var _bus_master: int = AudioServer.get_bus_index("Master")
@onready var _bus_music: int = AudioServer.get_bus_index("music")
@onready var _bus_sfx: int = AudioServer.get_bus_index("sfx")

var fps_max: int:
	set(value):
		if fps_max == value:
			return
			
		if value != 0:
			value = maxi(64, value)
		
		fps_max = value
		Engine.max_fps = fps_max
		if not is_loading:
			save_setting("fps_max", fps_max)

var showfps: bool:
	set(value):
		if showfps == value:
			return
		
		showfps = value
		if not is_loading:
			save_setting("showfps", showfps)

var showtick: bool:
	set(value):
		if showtick == value:
			return
		
		showtick = value
		if not is_loading:
			save_setting("showtick", showtick)

var master_volume: float:
	set(volume):
		volume = clampf(volume, 0.0, 1.0)
		if is_equal_approx(master_volume, volume):
			return

		master_volume = volume
		_apply_bus_volume(_bus_master, "master_volume", master_volume)

var music_volume: float:
	set(volume):
		volume = clampf(volume, 0.0, 1.0)
		if is_equal_approx(music_volume, volume):
			return

		music_volume = volume
		_apply_bus_volume(_bus_music, "music_volume", music_volume)

var sfx_volume: float:
	set(volume):
		volume = clampf(volume, 0.0, 1.0)
		if is_equal_approx(sfx_volume, volume):
			return

		sfx_volume = volume
		_apply_bus_volume(_bus_sfx, "sfx_volume", sfx_volume)

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


func _ready() -> void:
	load_config()
	Console.register_convar(&"fps_max", &"fps_max", "Set FPS limit")
	Console.register_convar(&"showfps", &"showfps", "Show frames rendering info")
	Console.register_convar(&"showtick", &"showtick", "Show physics tick info")
	Console.register_convar(&"volume", &"master_volume", "Master volume")
	Console.register_convar(&"music", &"music_volume", "Music volume")
	Console.register_convar(&"sfx", &"sfx_volume", "Sfx volume")
	
	debug_menu = DEBUG_SCENE.instantiate()
	get_tree().root.add_child.call_deferred(debug_menu)


func _exit_tree() -> void:
	save_config()


func _apply_bus_volume(bus_index: int, setting_key: String, volume: float) -> void:
	if bus_index >= 0:
		AudioServer.set_bus_mute(bus_index, is_zero_approx(volume))
		AudioServer.set_bus_volume_linear(bus_index, volume)
	if not is_loading:
		save_setting(setting_key, volume)


func load_config() -> void:
	var error: Error = config.load(CONFIG_PATH)

	if error == ERR_FILE_NOT_FOUND:
		print("Settings: Config file not found. Using defaults.")
	elif error != OK:
		push_error("Settings: Config file has not been loaded.")
		return

	var default_pos: Vector2 = Vector2(DisplayServer.screen_get_size()) * 0.5 - Vector2(400.0, 300.0)

	is_loading = true
	fps_max = config.get_value("settings", "fps_max", 0)
	showfps = config.get_value("settings", "showfps", false)
	showtick = config.get_value("settings", "showtick", false)
	console_position = config.get_value("settings", "console_position", default_pos)
	console_size = config.get_value("settings", "console_size", Vector2(800.0, 600.0))
	master_volume = config.get_value("settings", "master_volume", 1.0)
	music_volume = config.get_value("settings", "music_volume", 1.0)
	sfx_volume = config.get_value("settings", "sfx_volume", 1.0)
	is_loading = false


func save_config() -> void:
	config.set_value("settings", "fps_max", fps_max)
	config.set_value("settings", "showfps", showfps)
	config.set_value("settings", "showtick", showtick)
	config.set_value("settings", "console_position", console_position)
	config.set_value("settings", "console_size", console_size)
	config.set_value("settings", "master_volume", master_volume)
	config.set_value("settings", "music_volume", music_volume)
	config.set_value("settings", "sfx_volume", sfx_volume)

	if config.save(CONFIG_PATH) != OK:
		push_error("Settings: Config file has not been saved.")
		return

	print("Config saved successfully.")


func save_setting(key: String, value: Variant) -> void:
	config.set_value("settings", key, value)

	if config.save(CONFIG_PATH) != OK:
		push_error("Settings: Setting has not been saved.")
		return

	print("Setting saved: %s: %s." % [key, str(value)])
