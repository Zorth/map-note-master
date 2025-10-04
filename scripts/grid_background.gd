extends Node2D

@export var square_size := 1.0            # size of each square in world units
@export var color_a := Color.BLACK        # first color
@export var color_b := Color.WHITE        # second color
@export var grid_alpha := 0.5             # transparency of squares

@onready var _camera: Camera2D = %Camera2D
@onready var _viewport := get_viewport()

func _process(_delta):
	queue_redraw()  # redraw each frame

func _draw():
	if _camera == null:
		return

	# viewport size in pixels
	var vp_size = _viewport.get_visible_rect().size

	# compute visible world area (divide by zoom to convert pixels to world units)
	var world_half_size = vp_size * 0.5 / _camera.zoom
	var top_left = _camera.position - world_half_size
	var bottom_right = _camera.position + world_half_size

	# determine which squares to draw
	var x_start = floor(top_left.x / square_size)
	var x_end = ceil(bottom_right.x / square_size)
	var y_start = floor(top_left.y / square_size)
	var y_end = ceil(bottom_right.y / square_size)

	# draw alternating squares
	for x in range(x_start, x_end):
		for y in range(y_start, y_end):
			var c = color_a if (x + y) % 2 == 0 else color_b
			c.a = grid_alpha
			var rect_pos = Vector2(x, y) * square_size
			draw_rect(Rect2(rect_pos, Vector2(square_size, square_size)), c)
