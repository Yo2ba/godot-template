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

	registry[name] = entry
	_sorted_names.append(name)
	_names_dirty = true


func register_convar(
	target: Object,
	name: StringName,
	property: StringName,
	type: int,
	description: String = ""
) -> void:
	assert(
		name == StringName(str(name).to_lower()),
		"Console: ConVar name must be lowercase: '%s'." % name
	)

	if not is_instance_valid(target):
		push_warning("Console: Invalid target for '%s'." % name)
		return

	if name == &"" or property == &"":
		push_warning("Console: name and property cannot be empty.")
		return

	assert(
		not registry.has(name),
		"Console: Duplicate registration of '%s'." % name
	)

	if not (property in target):
		push_warning(
			"Console: Property '%s' does not exist on '%s'."
			% [property, target]
		)
		return

	var actual_value: Variant = target.get(property)
	if typeof(actual_value) != type:
		push_warning(
			"Console: Property '%s' does not match declared type %s."
			% [property, type_string(type)]
		)
		return

	var entry := RegistryEntry.new()
	entry.entry_type = EntryType.CONVAR
	entry.target = target
	entry.property = property
	entry.type = type
	entry.description = description

	registry[name] = entry
	_sorted_names.append(name)
	_names_dirty = true


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


# --- Command & ConVar Operations ---

func has_arguments(name: StringName) -> bool:
	var entry: RegistryEntry = registry.get(name)
	if entry == null or entry.entry_type != EntryType.COMMAND:
		return false
	return entry.callback.get_argument_count() > 0


func execute_command(name: StringName, args: Array = []) -> void:
	var entry: RegistryEntry = registry.get(name)
	if entry == null or entry.entry_type != EntryType.COMMAND:
		self.log("Unknown command: %s" % name)
		return

	if not entry.callback.is_valid():
		self.log("[Console] Command callback is no longer valid: %s" % name, Color.RED)
		return

	entry.callback.callv(args)


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
