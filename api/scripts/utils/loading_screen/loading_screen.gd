extends CanvasLayer

@onready var progress_bar: ProgressBar = $Background/CenterContainer/VBoxContainer/ProgressBar

var blocks_input: bool = false

func set_progress(progress: float) -> void:
	var percentage: float = clampf(progress, 0.0, 1.0) * 100.0

	progress_bar.value = percentage

func _input(_event: InputEvent) -> void:
	if blocks_input:
		get_viewport().set_input_as_handled()

func reset() -> void:
	set_progress(0.0)
