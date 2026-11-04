@abstract
class_name Scenes

@warning_ignore_start("shadowed_global_identifier")

class _SignalBus extends RefCounted:
	signal scene_load_progress(progress: float)
	signal scene_load_finished(success: bool)

const LOADING_SCREEN_PATH: String = "uid://ca8hnat43cwda"

static var _bus := _SignalBus.new()

static var scene_load_progress: Signal:
	get:
		return _bus.scene_load_progress

static var scene_load_finished: Signal:
	get:
		return _bus.scene_load_finished

static var loading_screen: CanvasLayer
static var loaded_scene: PackedScene
static var is_loading: bool = false


static func _static_init() -> void:
	if Engine.is_editor_hint():
		return
	_initialize.call_deferred()


static func _initialize() -> void:
	if is_instance_valid(loading_screen):
		return

	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null:
		return

	var loading_screen_scene: PackedScene = load(LOADING_SCREEN_PATH)
	loading_screen = loading_screen_scene.instantiate() as CanvasLayer
	loading_screen.layer = 9
	tree.root.add_child.call_deferred(loading_screen)
	loading_screen.hide()


static func load_scene(scene_path: String) -> void:
	if is_loading:
		return

	_initialize()

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


static func _on_scene_progress(progress: float) -> void:
	loading_screen.set_progress(progress)
	scene_load_progress.emit(progress)


static func _on_scene_loaded(resource: Resource) -> void:
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


static func open_loaded_scene() -> void:
	if loaded_scene == null:
		push_error("Scenes: No scene has been loaded.")
		return

	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null:
		return

	tree.scene_changed.connect(_on_scene_changed, CONNECT_ONE_SHOT)

	var error: Error = tree.change_scene_to_packed(loaded_scene)

	if error != OK:
		tree.scene_changed.disconnect(_on_scene_changed)
		push_error("Scenes: Failed to open loaded scene. Error: " + str(error))
		return

	loaded_scene = null


static func _on_scene_changed() -> void:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree != null:
		await tree.create_timer(0.2).timeout
	loading_screen.blocks_input = false
	loading_screen.hide()
