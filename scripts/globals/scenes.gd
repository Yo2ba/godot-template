extends Node
#__________ scenes ___________









#__________ methods __________
signal scene_load_progress(progress: float)
signal scene_load_finished(success: bool)

const LOADING_SCREEN_PATH: String = "res://scripts/utils/loading_screen/loading_screen.tscn"

var loading_screen: CanvasLayer
var loaded_scene: PackedScene
var is_loading: bool = false

func _ready() -> void:
	var loading_screen_scene: PackedScene = load(LOADING_SCREEN_PATH)
	loading_screen = loading_screen_scene.instantiate() as CanvasLayer
	get_tree().root.add_child.call_deferred(loading_screen)
	loading_screen.hide()

func load_scene(scene_path: String) -> void:
	if is_loading:
		return
	
	is_loading = true
	loaded_scene = null
	
	loading_screen.blocks_input = true
	loading_screen.reset()
	loading_screen.show()
	
	ThreadedLoader.load_async(
		scene_path,
		_on_scene_loaded,
		_on_scene_progress
	)

func _on_scene_progress(progress: float) -> void:
	loading_screen.set_progress(progress)
	scene_load_progress.emit(progress)

func _on_scene_loaded(resource: Resource) -> void:
	if resource is PackedScene:
		loaded_scene = resource as PackedScene
		scene_load_progress.emit(1.0)
		scene_load_finished.emit(true)
	else:
		loaded_scene = null
		loading_screen.blocks_input = false
		loading_screen.hide()
		scene_load_finished.emit(false)
	
	is_loading = false

func open_loaded_scene() -> void:
	if loaded_scene == null:
		push_error("Scenes: No scene has been loaded.")
		return
	
	get_tree().scene_changed.connect(_on_scene_changed, CONNECT_ONE_SHOT)
	
	var error: Error = get_tree().change_scene_to_packed(loaded_scene)
	
	if error != OK:
		get_tree().scene_changed.disconnect(_on_scene_changed)
		push_error("Scenes: Failed to open loaded scene. Error: " + str(error))
		return
	
	loaded_scene = null

func _on_scene_changed() -> void:
	await get_tree().create_timer(0.2).timeout
	loading_screen.blocks_input = false
	loading_screen.hide()
