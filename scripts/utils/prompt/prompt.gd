class_name Prompt
extends CanvasLayer

@onready var color_rect: ColorRect = $ColorRect
@onready var title: Label = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/Title
@onready var message: RichTextLabel = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/Message
@onready var confirm_btn: Button = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/HBoxContainer/ConfirmBtn
@onready var cancel_btn: Button = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/HBoxContainer/CancelBtn
@onready var close_btn: Button = $CenterContainer/PanelContainer/MarginContainer/NE/CloseBtn

var callable: Callable
var is_paused: bool
var darken: bool

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	if is_paused:
		get_tree().paused = true
		
	if not darken:
		color_rect.hide()
	
	confirm_btn.pressed.connect(confirm)
	cancel_btn.pressed.connect(cancel)
	close_btn.pressed.connect(cancel)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE and not event.is_echo():
			get_viewport().set_input_as_handled()
			cancel()
		elif event.keycode == KEY_ENTER and not event.is_echo():
			get_viewport().set_input_as_handled()
			confirm()

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
