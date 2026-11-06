extends ItemList

@export var marker_top: Control
@export var marker_bottom: Control

const LINE_HEIGHT: int = 23
const MAX_HEIGHT: int = 178


func _ready() -> void:
	resize()


func resize() -> void:
	var count: int = get_item_count()
	mouse_filter = Control.MOUSE_FILTER_IGNORE if count == 0 else Control.MOUSE_FILTER_STOP
	size.y = 0 if count == 0 else clampi(LINE_HEIGHT * count + count, LINE_HEIGHT, MAX_HEIGHT)

	update_position()


func update_position() -> void:
	if not is_inside_tree():
		return

	var window_height: float = get_viewport_rect().size.y
	if marker_bottom.global_position.y + size.y >= window_height:
		position.y = marker_top.position.y - size.y
	else:
		position.y = marker_bottom.position.y

	global_position.y = clampf(global_position.y, 0.0, maxf(0.0, window_height - size.y))
