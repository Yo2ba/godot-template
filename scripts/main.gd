extends Node

@onready var button: Button = $CenterContainer/Button

func _ready() -> void:
	initial_messages()
	button.pressed.connect(func():
		Utils.prompt(
			func(): Commands.execute(&"quit"),
			"Quit",
			"Are you sure you want to quit?",
			"Quit",
			"Return",
			true
		)
		
	)

func initial_messages() -> void:
	Console.color(Color.AQUA)
	Console.log("###System###")
	Console.log("Datetime: " + Time.get_datetime_string_from_system())
	Console.log("OS version: " + OS.get_name() + " " + OS.get_version())
	Console.log("Rendering adapter: " + str(RenderingServer.get_video_adapter_name()))
	
	Console.log("")
	Console.color(Color.YELLOW)
	Console.log("###Display###")
	Console.log("Mode: " + str(DisplayServer.window_get_mode()))
	Console.log("Display: " + str(DisplayServer.screen_get_size().x) + "x" + str(DisplayServer.screen_get_size().y) + " @ " + str(roundi(DisplayServer.screen_get_refresh_rate())) + "Hz")
	Console.log("V-Sync: " + str(DisplayServer.window_get_vsync_mode()))
	
	Console.log("")
	Console.color(Color.CYAN)
	Console.log("###Engine###")
	Console.log("Max framerate: " + str(Engine.max_fps))
	Console.log("Time scale: " + str(Engine.time_scale))
	Console.log("Rendering method: " + str(RenderingServer.get_current_rendering_method()))
	
	Console.log("")
	Console.color(Color.MAGENTA)
	Console.log("###Runtime###")
	Console.log("Launch options: " + str(OS.get_cmdline_user_args()))
	Console.log("Debug: " + str(OS.has_feature("debug")))
	
	Console.color()
