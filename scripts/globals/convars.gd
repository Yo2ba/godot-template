extends Node

var registry: Dictionary = {}

func register(
	target: Object,
	label: StringName,
	property: StringName,
	type: int
) -> void:
	if not is_instance_valid(target):
		push_warning("ConVars: Invalid target for '%s'." % label)
		return
	
	if label == &"" or property == &"":
		push_warning("ConVars: label and property cannot be empty.")
		return
	
	assert(
		not registry.has(label),
		"ConVars: Duplicate registration of '%s'." % label
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
	
	registry[label] = {
		"target": target,
		"property": property,
		"type": type
	}

func unregister(label: StringName) -> void:
	if not registry.has(label):
		return

	registry.erase(label)
	

func _has_property(
	target: Object,
	property: StringName
) -> bool:
	for info: Dictionary in target.get_property_list():
		if info["name"] == property:
			return true

	return false


func exists(label: StringName) -> bool:
	return registry.has(label)

func get_value(label: StringName) -> Variant:
	if not registry.has(label):
		push_warning("ConVars: Unknown ConVar '%s'." % label)
		return null

	var entry: Dictionary = registry[label]
	var target: Object = entry["target"]

	if not is_instance_valid(target):
		push_warning("ConVars: Owner of '%s' is invalid." % label)
		return null

	return target.get(entry["property"])

func set_value(
	label: StringName,
	value: Variant
) -> void:
	if not registry.has(label):
		push_warning("ConVars: Unknown ConVar '%s'." % label)
		return

	var entry: Dictionary = registry[label]
	var target: Object = entry["target"]

	if not is_instance_valid(target):
		push_warning("ConVars: Owner of '%s' is invalid." % label)
		return

	if typeof(value) != entry["type"]:
		push_warning(
			"ConVars: Invalid type for '%s'. Expected %s, received %s."
			% [label, type_string(entry["type"]), type_string(typeof(value))]
		)
		return

	target.set(entry["property"], value)


func get_names(prefix: String = "") -> Array[StringName]:
	var names: Array[StringName] = []

	for key: StringName in registry:
		if String(key).begins_with(prefix):
			names.append(key)

	names.sort()
	return names


func get_all_names() -> Array[StringName]:
	return get_names()
