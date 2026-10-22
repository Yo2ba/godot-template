extends Node
@warning_ignore_start('shadowed_variable_base_class')

var registry: Dictionary[StringName, Dictionary] = {}

func register(
	target: Object,
	name: StringName,
	property: StringName,
	type: int,
	description: String = ""
) -> void:
	assert(name == StringName(str(name).to_lower()),
	"ConVars: ConVar name must be lowercase: '%s'." % name)
	
	if not is_instance_valid(target):
		push_warning("ConVars: Invalid target for '%s'." % name)
		return
	
	if name == &"" or property == &"":
		push_warning("ConVars: name and property cannot be empty.")
		return
	
	assert(
		not registry.has(name),
		"ConVars: Duplicate registration of '%s'." % name
	)
	
	if not _has_property(target, property):
		push_warning(
			"ConVars: Property '%s' does not exist on '%s'."
			% [property, target]
		)
		return
	
	var actual_value: Variant = target.get(property)
	
	if typeof(actual_value) != type:
		push_warning(
			"ConVars: Property '%s' does not match declared type %s."
			% [property, type_string(type)]
		)
		return
	
	registry[name] = {
		"target": target,
		"property": property,
		"type": type,
		"description": description
	}

func unregister(name: StringName) -> void:
	if not registry.has(name):
		return

	registry.erase(name)

func get_description(name: StringName) -> String:
	if not registry.has(name):
		return ""

	return registry[name]["description"]

func _has_property(
	target: Object,
	property: StringName
) -> bool:
	for info: Dictionary in target.get_property_list():
		if info["name"] == property:
			return true

	return false


func exists(name: StringName) -> bool:
	return registry.has(name)

func get_value(name: StringName) -> Variant:
	if not registry.has(name):
		push_warning("ConVars: Unknown ConVar '%s'." % name)
		return null

	var entry: Dictionary = registry[name]
	var target: Object = entry["target"]

	if not is_instance_valid(target):
		push_warning("ConVars: Owner of '%s' is invalid." % name)
		return null

	return target.get(entry["property"])

func set_value(
	name: StringName,
	value: Variant
) -> void:
	if not registry.has(name):
		push_warning("ConVars: Unknown ConVar '%s'." % name)
		return

	var entry: Dictionary = registry[name]
	var target: Object = entry["target"]

	if not is_instance_valid(target):
		push_warning("ConVars: Owner of '%s' is invalid." % name)
		return

	if typeof(value) != entry["type"]:
		push_warning(
			"ConVars: Invalid type for '%s'. Expected %s, received %s."
			% [name, type_string(entry["type"]), type_string(typeof(value))]
		)
		return

	target.set(entry["property"], value)


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
