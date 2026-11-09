class_name Prompt
extends CanvasLayer

@export var color_rect: ColorRect
@export var title: Label
@export var message: RichTextLabel
@export var confirm_btn: Button
@export var cancel_btn: Button
@export var close_btn: TextureButton

var callable: Callable
var is_paused: bool
var darken: bool


func _ready() -> void:
	assert(get_tree().current_scene != self, "This scene cannot be used as an entry point.")
	
	layer = RenderingServer.CANVAS_LAYER_MAX - 1
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	if is_paused:
		get_tree().paused = true
		
	color_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	if not darken:
		color_rect.color.a = 0.0
	
	confirm_btn.pressed.connect(confirm)
	cancel_btn.pressed.connect(cancel)
	close_btn.pressed.connect(cancel)


func _input(event: InputEvent) -> void:
	if event is InputEventKey:
		if event.keycode == KEY_QUOTELEFT:
			return

		var console_open: bool = is_instance_valid(Console.console_menu) and Console.console_menu.visible
		if console_open:
			Console.console_menu._input(event)

		if event.pressed and not event.is_echo():
			match event.keycode:
				KEY_ESCAPE:
					cancel()
					get_viewport().set_input_as_handled()
					return

		if console_open and Console.console_menu.line.has_focus():
			return

		get_viewport().set_input_as_handled()


func _unhandled_input(_event: InputEvent) -> void:
	get_viewport().set_input_as_handled()


func setup(
	prompt_title: String,
	prompt_message: String,
	confirm_name: String,
	cancel_name: String
) -> void:
	title.text = prompt_title
	message.text = prompt_message
	confirm_btn.text = confirm_name
	cancel_btn.text = cancel_name


func confirm() -> void:
	if callable.is_valid():
		callable.call()
	close()


func cancel() -> void:
	close()


func close() -> void:
	if is_paused:
		get_tree().paused = false

	queue_free()
