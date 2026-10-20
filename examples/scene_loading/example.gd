extends Node2D

@onready var button_2: Button = $Button2

const TARGET_SCENE_PATH: String = "res://examples/scene_loading/load_this.tscn"


func _ready() -> void:
	Scenes.scene_load_progress.connect(_on_progress_updated)
	Scenes.scene_load_finished.connect(_on_load_finished)
	
	button_2.pressed.connect(func():
		Utils.prompt(loader, "Confirm", "Change scene?", "Confirm", "Cancel", false, false)
	)

func loader() -> void:
	Scenes.load_scene(TARGET_SCENE_PATH)

func _on_progress_updated(progress: float) -> void:
	print("Loading: ", progress * 100.0, "%")

func _on_load_finished(success: bool) -> void:
	if not success:
		return
	Scenes.open_loaded_scene()
