extends Node

@export var pan_sensitivity := 1.0
@export var zoom_step := 0.12
@export var min_zoom := 0.1
@export var max_zoom := 6.0

@onready var _camera: Camera2D = %Camera2D

var dragging := false
var drag_button := MOUSE_BUTTON_MIDDLE
var last_mouse_pos := Vector2.ZERO

func _unhandled_input(event):
	# Start drag: middle mouse OR (Space + left mouse)
	if event is InputEventMouseButton:
		if event.pressed:
			if event.button_index == drag_button or (Input.is_key_pressed(KEY_SPACE) and event.button_index == MOUSE_BUTTON_LEFT):
				dragging = true
				last_mouse_pos = get_viewport().get_mouse_position()
				get_viewport().set_input_as_handled()
		else:
			if event.button_index == drag_button or event.button_index == MOUSE_BUTTON_LEFT:
				dragging = false

	if event is InputEventMouseMotion and dragging:
		var now = get_viewport().get_mouse_position()
		var delta = now - last_mouse_pos
		last_mouse_pos = now
		_camera.position -= delta  * pan_sensitivity / _camera.zoom

	# Zoom with scroll wheel (wheel up = zoom in)
	if event is InputEventMouseButton and event.pressed:
		if event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			var zoom_in = event.button_index == MOUSE_BUTTON_WHEEL_UP
			var mouse_pos = get_viewport().get_mouse_position()
			_zoom_at_screen_point(zoom_in, mouse_pos)

func _zoom_at_screen_point(zoom_in: bool, screen_point: Vector2):
	var old_zoom = _camera.zoom.x
	var factor = 1.0 + (zoom_step if zoom_in else -zoom_step)
	var new_zoom_scalar = clamp(old_zoom * factor, min_zoom, max_zoom)
	if is_equal_approx(new_zoom_scalar, old_zoom):
		return
	var new_zoom = Vector2(new_zoom_scalar, new_zoom_scalar)

	# Pin the point under the cursor
	var world_before = get_viewport().get_canvas_transform().affine_inverse() * screen_point
	_camera.zoom = new_zoom
	var world_after = get_viewport().get_canvas_transform().affine_inverse() * screen_point
	_camera.position += world_before - world_after
