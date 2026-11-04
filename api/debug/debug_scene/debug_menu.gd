extends Control

@export var label: RichTextLabel

var lines: PackedStringArray = []

var fps_timer: float = 0.0
var frame_count: int = 0
var fps: int = 0
var max_frame_time: float = 0.0

var physics_frame_count: int = 0
var physics_tps: int = 0

func _process(delta: float) -> void:
	frame_count += 1
	fps_timer += delta
	max_frame_time = maxf(max_frame_time, delta * 1000.0)

	var whole: int = int(max_frame_time)
	var decimal: int = roundi((max_frame_time - whole) * 10.0)

	if fps_timer >= 0.5:
		fps = roundi(frame_count / fps_timer)
		physics_tps = roundi(physics_frame_count / fps_timer)

		var color: String = ""
		var fps_max: int = Settings.fps_max

		if fps_max > 0:
			if fps < fps_max * 0.2:
				color = "[color=#F07878]"
			elif fps < fps_max * 0.5:
				color = "[color=#F0B478]"
			else:
				color = "[color=#78F078]"
		
		var frame_line: String = "%sMax[code] %d[/code].[code]%d[/code]ms | Avg[code] %d[/code]FPS%s" % [
			color, whole, decimal, fps, "[/color]" if color else ""
		]
		
		var ticks_line: String = "Physics ticks[code] %d[/code].[code]0[/code]t/s" % physics_tps
		
		lines.clear()
		
		if Settings.showfps:
			lines.append(frame_line)

		if Settings.showtick:
			lines.append(ticks_line)
		
		label.text = "\n".join(lines)
		
		frame_count = 0
		physics_frame_count = 0
		fps_timer = 0.0
		max_frame_time = 0.0

func _physics_process(_delta: float) -> void:
	physics_frame_count += 1
