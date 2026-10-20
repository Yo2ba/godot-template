extends Node

const PROMPT_SCENE: PackedScene = preload("res://scripts/utils/prompt/prompt.tscn")

var active_prompt: Prompt

func save_file(path: String, data: Variant) -> Error:
	return BinarySaver.save_file(path, data)


func load_file(path: String) -> Dictionary:
	return BinaryLoader.load_file(path)

func prompt(
	function: Callable,
	prompt_title: String,
	prompt_message:String,
	confirm_name: String = "Confirm",
	cancel_name: String = "Cancel",
	darken: bool = true,
	pause: bool = false
) -> Prompt:
	if is_instance_valid(active_prompt):
		return
	
	var instance: Prompt = PROMPT_SCENE.instantiate()
	
	instance.callable = function
	instance.darken = darken
	instance.is_paused = pause
	instance.process_mode = Node.PROCESS_MODE_ALWAYS
	
	active_prompt = instance
	instance.tree_exited.connect(_on_prompt_exited)
	
	
	get_tree().root.add_child(instance)
	
	instance.setup(
		prompt_title,
		prompt_message,
		confirm_name,
		cancel_name
	)
	
	return instance

func _on_prompt_exited() -> void:
	active_prompt = null
	
