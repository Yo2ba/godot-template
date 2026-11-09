extends RichTextLabel


const FOLLOW_TOLERANCE: float = 2.0
const SNAP_DISTANCE: float = 0.5

# 12 ≈ 95% of the distance in 0.25 s, 6 ≈ 0.5 s, 24 ≈ 0.12 s.
var scroll_animation_speed: float = 12.0

var _following: bool = true
var _scroll_pos: float = 0.0
var _applying_scroll: bool = false


func _ready() -> void:
	focus_mode = Control.FOCUS_CLICK
	deselect_on_focus_loss_enabled = false

	# Built-in following snaps instantly; this script animates it instead.
	scroll_following = false
	var bar: VScrollBar = get_v_scroll_bar()
	bar.changed.connect(_on_scroll_range_changed)
	bar.value_changed.connect(_on_scroll_value_changed)
	set_process(false)


func _process(delta: float) -> void:
	var remaining: float = _get_scroll_bottom() - _scroll_pos
	if not _following or remaining <= 0.0:
		set_process(false)
		return

	if remaining <= SNAP_DISTANCE:
		_scroll_pos += remaining
		set_process(false)
	else:
		_scroll_pos += remaining * (1.0 - exp(-scroll_animation_speed * delta))
	_apply_scroll()


func _get_scroll_bottom() -> float:
	var bar: VScrollBar = get_v_scroll_bar()
	return maxf(0.0, bar.max_value - bar.page)


func _apply_scroll() -> void:
	_applying_scroll = true
	get_v_scroll_bar().value = _scroll_pos
	_applying_scroll = false


func _on_scroll_range_changed() -> void:
	# Content grew (or the view was resized): glide toward the new bottom.
	if _following:
		set_process(true)


func _on_scroll_value_changed(value: float) -> void:
	if _applying_scroll:
		return
	# Scroll change not made by the animation (wheel, drag, scroll_to_*, clamping).
	var scrolled_down: bool = value > _scroll_pos
	_scroll_pos = value
	_following = (
		value >= _get_scroll_bottom() - FOLLOW_TOLERANCE
		or (_following and scrolled_down)
	)


func _gui_input(event: InputEvent) -> void:
	var is_left_press: bool = (
		event is InputEventMouseButton
		and event.button_index == MOUSE_BUTTON_LEFT
		and event.pressed
	)
	var is_left_drag: bool = (
		event is InputEventMouseMotion
		and (event.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0
	)
	if not is_left_press and not is_left_drag:
		return

	var parsed: String = get_parsed_text()
	if parsed.is_empty():
		return

	var line_count: int = get_line_count()
	var text_bottom_doc_y: float = (
		get_line_offset(line_count - 1)
		if parsed.ends_with("\n") and line_count >= 2
		else float(get_content_height())
	)

	var stylebox: StyleBox = get_theme_stylebox("normal")
	var top_margin: float = stylebox.get_margin(SIDE_TOP) if stylebox else 0.0
	var text_bottom_y: float = top_margin + text_bottom_doc_y - get_v_scroll_bar().value

	if event.position.y >= text_bottom_y:
		event.position = Vector2(size.x, maxf(top_margin, text_bottom_y - 2.0))
