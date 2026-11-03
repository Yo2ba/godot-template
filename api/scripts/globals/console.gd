extends Node
@warning_ignore_start("shadowed_variable_base_class")

enum EntryType {
	COMMAND,
	CONVAR,
}

class RegistryEntry:
	var entry_type: EntryType
	var description: String
	var callback: Callable
	var arg_types: PackedInt32Array
	var min_args: int = 0
	var is_vararg: bool = false
	var target: Object
	var property: StringName
	var type: int

const CONSOLE_SCENE: PackedScene = preload("uid://nugh2wokqnq3")

var current_color: Color = Color.WHITE
var console_menu: Control
var history: PackedStringArray = []

var registry: Dictionary[StringName, RegistryEntry] = {}
var _sorted_names: Array[StringName] = []
var _names_dirty: bool = false


func _ready() -> void:
	console_menu = CONSOLE_SCENE.instantiate()
	get_tree().root.add_child.call_deferred(console_menu)


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_QUOTELEFT:
			toggle_console()
			get_viewport().set_input_as_handled()


func toggle_console() -> void:
	console_menu.visible = not console_menu.visible


func color(value: Color = Color.WHITE) -> void:
	current_color = value


func log(...args: Array) -> void:
	if args.is_empty():
		return

	var message_color: Color = current_color
	if args.back() is Color:
		message_color = args.pop_back()

	var count: int = args.size()
	var message: String
	if count == 1:
		message = str(args[0])
	elif count == 2:
		message = str(args[0]) + " " + str(args[1])
	else:
		var parts: PackedStringArray = []
		parts.resize(count)
		for i: int in count:
			parts[i] = str(args[i])
		message = " ".join(parts)

	history.append(message)

	if is_instance_valid(console_menu):
		console_menu.add_visible(message, message_color)


# --- Unified Registry Management ---

func register_command(
	name: StringName,
	callback: Callable,
	description: String = ""
) -> void:
	assert(
		name == StringName(str(name).to_lower()),
		"Console: Command name must be lowercase: '%s'." % name
	)
	assert(
		not registry.has(name),
		"Console: Duplicate command/convar name '%s'." % name
	)
	assert(
		callback.is_valid(),
		"Console: Invalid callable for '%s'." % name
	)

	var entry := RegistryEntry.new()
	entry.entry_type = EntryType.COMMAND
	entry.callback = callback
	entry.description = description
	_extract_callable_signature(entry, callback)

	registry[name] = entry
	_sorted_names.append(name)
	_names_dirty = true


func _extract_callable_signature(entry: RegistryEntry, callback: Callable) -> void:
	var obj: Object = callback.get_object()
	var method_name: StringName = callback.get_method()
	var bound_count: int = callback.get_bound_arguments_count()

	if is_instance_valid(obj) and not callback.is_custom():
		var method_info: Dictionary = {}
		var script: Script = obj.get_script()
		if script != null:
			method_info = _find_method_info(script.get_script_method_list(), method_name)
		if method_info.is_empty():
			method_info = _find_method_info(obj.get_method_list(), method_name)

		if not method_info.is_empty():
			var raw_args: Array = method_info["args"]
			var default_args: Array = method_info["default_args"]
			var total_args: int = maxi(0, raw_args.size() - bound_count)
			var default_count: int = maxi(0, default_args.size() - bound_count)
			var first_default_idx: int = total_args - default_count

			entry.is_vararg = (int(method_info["flags"]) & METHOD_FLAG_VARARG) != 0
			entry.min_args = maxi(0, first_default_idx)
			entry.arg_types.resize(total_args)

			for i: int in total_args:
				var arg_type: int = raw_args[i]["type"]
				# Infer type from default value if parameter has no explicit type annotation
				if arg_type == TYPE_NIL and i >= first_default_idx:
					arg_type = typeof(default_args[i - first_default_idx])
				entry.arg_types[i] = arg_type
			return

	# Fallback for anonymous lambdas / custom callables
	var arg_count: int = callback.get_argument_count()
	entry.min_args = 0
	entry.arg_types.resize(arg_count)
	entry.arg_types.fill(TYPE_NIL)


func _find_method_info(method_list: Array[Dictionary], method_name: StringName) -> Dictionary:
	for info: Dictionary in method_list:
		if info["name"] == method_name:
			return info
	return {}


func register_convar(
	name: StringName,
	property: StringName = &"",
	description: String = "",
	target: Object = null
) -> void:
	assert(
		name == StringName(str(name).to_lower()),
		"Console: ConVar name must be lowercase: '%s'." % name
	)

	if name == &"":
		push_warning("Console: ConVar name cannot be empty.")
		return

	if property == &"":
		property = name

	assert(
		not registry.has(name),
		"Console: Duplicate registration of '%s'." % name
	)

	var resolved_target: Object = target if is_instance_valid(target) else _resolve_convar_owner(property)
	if not is_instance_valid(resolved_target):
		push_warning(
			"Console: Could not resolve owner with property '%s' for ConVar '%s'."
			% [property, name]
		)
		return

	if not (property in resolved_target):
		push_warning(
			"Console: Property '%s' does not exist on '%s'."
			% [property, resolved_target]
		)
		return

	var actual_value: Variant = resolved_target.get(property)
	var inferred_type: int = typeof(actual_value)

	if inferred_type == TYPE_NIL:
		for info: Dictionary in resolved_target.get_property_list():
			if info["name"] == property:
				inferred_type = info["type"]
				break

	var entry := RegistryEntry.new()
	entry.entry_type = EntryType.CONVAR
	entry.target = resolved_target
	entry.property = property
	entry.type = inferred_type
	entry.description = description

	registry[name] = entry
	_sorted_names.append(name)
	_names_dirty = true


func _resolve_convar_owner(property: StringName) -> Object:
	var root: Window = get_tree().root
	var stack: Array = get_stack()

	# 1. Editor/Debug: match the exact calling script path from the call stack
	if stack.size() > 1:
		var caller_source: String = stack[1].get("source", "")
		if not caller_source.is_empty():
			var matched: Object = _find_node_by_script(root, caller_source, property)
			if matched != null:
				return matched

	# 2. Release fallback: check Autoloads and top-level nodes first, then tree
	for child: Node in root.get_children():
		if property in child:
			return child

	return _find_node_by_property(root, property)


func _find_node_by_script(node: Node, script_path: String, property: StringName) -> Object:
	for child: Node in node.get_children():
		var script: Script = child.get_script()
		if script != null and script.resource_path == script_path and property in child:
			return child

	for child: Node in node.get_children():
		var found: Object = _find_node_by_script(child, script_path, property)
		if found != null:
			return found

	return null


func _find_node_by_property(node: Node, property: StringName) -> Object:
	for child: Node in node.get_children():
		if property in child:
			return child
		var found: Object = _find_node_by_property(child, property)
		if found != null:
			return found

	return null

func unregister(name: StringName) -> void:
	if registry.erase(name):
		_sorted_names.erase(name)


func exists(name: StringName) -> bool:
	return registry.has(name)


func is_command(name: StringName) -> bool:
	var entry: RegistryEntry = registry.get(name)
	return entry != null and entry.entry_type == EntryType.COMMAND


func is_convar(name: StringName) -> bool:
	var entry: RegistryEntry = registry.get(name)
	return entry != null and entry.entry_type == EntryType.CONVAR


func get_description(name: StringName) -> String:
	var entry: RegistryEntry = registry.get(name)
	return entry.description if entry != null else ""


func get_sorted_names() -> Array[StringName]:
	if _names_dirty:
		_sorted_names.sort_custom(func(a: StringName, b: StringName) -> bool:
			return str(a) < str(b)
		)
		_names_dirty = false
	return _sorted_names


# --- Argument & Value Parsing ---

func parse_value(raw: String, expected_type: int) -> Variant:
	match expected_type:
		TYPE_BOOL:
			var normalized: String = raw.to_lower()
			if normalized == "true":
				return true
			if normalized == "false":
				return false
			if raw.is_valid_int():
				return raw.to_int() != 0
			self.log("Error: Expected a boolean or integer value.", Color.YELLOW)
			return null

		TYPE_INT:
			if not raw.is_valid_float():
				self.log("Error: Expected a numeric value.", Color.YELLOW)
				return null
			return int(raw.to_float())

		TYPE_FLOAT:
			if not raw.is_valid_float():
				self.log("Error: Expected a numeric value.", Color.YELLOW)
				return null
			return raw.to_float()

		TYPE_STRING:
			return raw

		TYPE_STRING_NAME:
			return StringName(raw)

		TYPE_NIL:
			# Untyped Variant or lambda argument: infer primitive types automatically
			var normalized: String = raw.to_lower()
			if normalized == "true":
				return true
			if normalized == "false":
				return false
			if raw.is_valid_int():
				return raw.to_int()
			if raw.is_valid_float():
				return raw.to_float()
			return raw

		_:
			var parsed: Variant = str_to_var(raw)
			if typeof(parsed) == expected_type:
				return parsed
			self.log("Expected %s value." % type_string(expected_type), Color.RED)
			return null


# --- Command & ConVar Operations ---

func has_arguments(name: StringName) -> bool:
	var entry: RegistryEntry = registry.get(name)
	if entry == null or entry.entry_type != EntryType.COMMAND:
		return false
	return not entry.arg_types.is_empty() or entry.is_vararg


func execute_command(name: StringName, raw_args: Array = []) -> void:
	var entry: RegistryEntry = registry.get(name)
	if entry == null or entry.entry_type != EntryType.COMMAND:
		self.log("Unknown command: %s" % name)
		return

	if not entry.callback.is_valid():
		self.log("[Console] Command callback is no longer valid: %s" % name, Color.RED)
		return

	var max_args: int = entry.arg_types.size()
	var provided: int = raw_args.size()

	if provided < entry.min_args or (not entry.is_vararg and provided > max_args):
		if entry.min_args == max_args:
			self.log("Expected %d argument(s), received %d." % [entry.min_args, provided], Color.RED)
		else:
			self.log("Expected %d to %d arguments, received %d." % [entry.min_args, max_args, provided], Color.RED)
		return

	var converted_args: Array = []
	converted_args.resize(provided)

	for i: int in provided:
		var target_type: int = entry.arg_types[i] if i < max_args else TYPE_NIL
		var parsed: Variant = parse_value(str(raw_args[i]), target_type)
		if parsed == null:
			return
		converted_args[i] = parsed

	entry.callback.callv(converted_args)


func get_convar_value(name: StringName) -> Variant:
	var entry: RegistryEntry = registry.get(name)
	if entry == null or entry.entry_type != EntryType.CONVAR:
		push_warning("Console: Unknown ConVar '%s'." % name)
		return null

	if not is_instance_valid(entry.target):
		push_warning("Console: Owner of '%s' is invalid." % name)
		return null

	return entry.target.get(entry.property)


func set_convar_value(name: StringName, value: Variant) -> void:
	var entry: RegistryEntry = registry.get(name)
	if entry == null or entry.entry_type != EntryType.CONVAR:
		push_warning("Console: Unknown ConVar '%s'." % name)
		return

	if not is_instance_valid(entry.target):
		push_warning("Console: Owner of '%s' is invalid." % name)
		return

	if typeof(value) != entry.type:
		push_warning(
			"Console: Invalid type for '%s'. Expected %s, received %s."
			% [name, type_string(entry.type), type_string(typeof(value))]
		)
		return

	entry.target.set(entry.property, value)
