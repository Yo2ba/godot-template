extends Node
@warning_ignore_start('shadowed_variable_base_class')

var registry: Dictionary[StringName, Dictionary] = {}

func register(
	name: StringName,
	callback: Callable,
	description: String = ""
) -> void:
	assert(name == StringName(str(name).to_lower()),
		"Commands: Command name must be lowercase: '%s'." % name)
	assert(not registry.has(name),
		"Commands: Duplicate command name '%s'." % name)
	assert(callback.is_valid(),
		"Commands: Invalid callable for '%s'." % name)
	
	registry[name] = {
		"callback": callback,
		"description": description
	}
	
func unregister(name: StringName) -> void:
	registry.erase(name)

func exists(name: StringName) -> bool:
	return registry.has(name)

func execute(name: StringName, args: Array = []) -> void:
	if not registry.has(name):
		Console.log("Unknown command: %s" % name)
		return
	
	var command: Dictionary = registry[name]
	var callback: Callable = command["callback"]
	
	if not callback.is_valid():
		Console.log("[Commands] Command callback is no longer valid: %s" % name, Color.RED)
		return
	
	callback.callv(args)

func get_names(prefix: String = "") -> Array[StringName]:
	var names: Array[StringName] = []
	var normalized_prefix: String = prefix.to_lower()

	for name: StringName in registry:
		if str(name).begins_with(normalized_prefix):
			names.append(name)

	names.sort()
	return names

func get_all_names() -> Array[StringName]:
	return get_names()

func get_description(name: StringName) -> String:
	if not registry.has(name):
		return ""

	return registry[name]["description"]
