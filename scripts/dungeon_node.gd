extends Node2D

@export var width := 300.0
@export var color := Color(0.2, 0.6, 1.0, 0.8)
@export var text_color := Color.BLACK
@export var top_offset := 50.0
@export var sublevel_height := 30.0
@export var sublevel_spacing := 10.0
@export var bottom_padding := 50.0
@export var corner_radius := 16.0
@export var project_folder := "/home/zorth/Documents/sythian"

var panel: Panel
var label: Label
var sublevel_nodes: Dictionary = {}  # local sublevels for this dungeon

func _enter_tree():
	# Main dungeon panel
	panel = Panel.new()
	add_child(panel)

	var style = StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = corner_radius
	style.corner_radius_top_right = corner_radius
	style.corner_radius_bottom_left = corner_radius
	style.corner_radius_bottom_right = corner_radius
	panel.add_theme_stylebox_override("panel", style)

	panel.size = Vector2(width, 0)

	# Title label
	label = Label.new()
	label.modulate = text_color
	label.horizontal_alignment = HorizontalAlignment.HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VerticalAlignment.VERTICAL_ALIGNMENT_TOP
	label.size = Vector2(width, sublevel_height)
	label.position = Vector2(0, top_offset)
	panel.add_child(label)

func set_label_text(new_text: String) -> void:
	if label != null:
		label.text = new_text

# Recursive function to find a file in all subfolders
func _find_file_recursive(base_path: String, file_name: String) -> String:
	var dir = DirAccess.open(base_path)
	if dir == null:
		return ""
	dir.list_dir_begin()
	var file = dir.get_next()
	while file != "":
		if file == "." or file == "..":
			file = dir.get_next()
			continue
		var full_path = base_path + "/" + file
		if FileAccess.file_exists(full_path) and file == file_name:
			return full_path
		var sub_dir = DirAccess.open(full_path)
		if sub_dir != null:
			var result = _find_file_recursive(full_path, file_name)
			if result != "":
				return result
		file = dir.get_next()
	return ""

# Check if sublevel is done
func _is_sublevel_done(sub_file_name: String) -> bool:
	var file_path = _find_file_recursive(project_folder, sub_file_name)
	if file_path == "":
		return false
	var done := false
	var f = FileAccess.open(file_path, FileAccess.READ)
	var in_frontmatter = false
	while not f.eof_reached():
		var line = f.get_line().strip_edges()
		if line.begins_with("---"):
			in_frontmatter = not in_frontmatter
			continue
		if in_frontmatter and line.to_lower().find("module/done") != -1:
			done = true
			break
		if not in_frontmatter and line.to_lower().find("#module/done") != -1:
			done = true
			break
	f.close()
	return done

# Get connections from frontmatter
func _get_sublevel_connections(sub_file_name: String) -> Array:
	var file_path = _find_file_recursive(project_folder, sub_file_name)
	var connections: Array = []
	if file_path == "":
		return connections
	var f = FileAccess.open(file_path, FileAccess.READ)
	var in_frontmatter = false
	while not f.eof_reached():
		var line = f.get_line().strip_edges()
		if line.begins_with("---"):
			in_frontmatter = not in_frontmatter
			continue
		if in_frontmatter and line.find("connections:") != -1:
			while not f.eof_reached():
				var conn_line = f.get_line().strip_edges()
				if conn_line.begins_with("---") or conn_line == "":
					break
				var conn_name = conn_line.replace("- [[", "").replace("]]", "").strip_edges()
				if conn_name != "":
					connections.append(conn_name)
					print("Found connection for %s: %s" % [sub_file_name, conn_name])
			break
	f.close()
	return connections

# Create sublevels and register them globally
func create_sublevels(start_level: int, end_level: int) -> void:
	sublevel_nodes.clear()
	var index = 1
	var max_y := top_offset + sublevel_height
	for level in range(start_level, end_level + 1):
		var sub_panel = Panel.new()
		var sub_style = StyleBoxFlat.new()
		var sub_file_name = "%s %d.md" % [label.text, index]
		var is_done = _is_sublevel_done(sub_file_name)
		sub_style.bg_color = Color(0.3, 0.8, 0.3, 0.8) if is_done else Color(0.7, 0.7, 0.7, 0.8)
		sub_panel.add_theme_stylebox_override("panel", sub_style)
		sub_panel.size = Vector2(width, sublevel_height)
		panel.add_child(sub_panel)
		var y_pos = top_offset + sublevel_height + (level - 1) * (sublevel_height + sublevel_spacing)
		sub_panel.position = Vector2(0, y_pos)
		var sub_bottom = y_pos + sublevel_height
		if sub_bottom > max_y:
			max_y = sub_bottom
		# Sublevel label
		var sub_label_name = "%s %d" % [label.text, index]
		var sub_label = Label.new()
		sub_label.text = sub_label_name
		sub_label.horizontal_alignment = HorizontalAlignment.HORIZONTAL_ALIGNMENT_CENTER
		sub_label.vertical_alignment = VerticalAlignment.VERTICAL_ALIGNMENT_CENTER
		sub_label.size = sub_panel.size
		sub_panel.add_child(sub_label)
		# Store panel locally
		sublevel_nodes[sub_label_name] = sub_panel
		# Register globally
		DungeonManager.register_sublevel(sub_label_name, sub_panel)
		index += 1
	panel.size.y = max_y + bottom_padding
	queue_redraw()

# Draw connecting lines across all sublevels
func _draw():
	for sublevel_name in sublevel_nodes.keys():
		var panel_node = sublevel_nodes[sublevel_name]
		var connections = _get_sublevel_connections("%s.md" % sublevel_name)
		for target_name in connections:
			var target_panel = DungeonManager.get_sublevel(target_name)
			if target_panel != null:
				var start_pos = panel_node.global_position + Vector2(panel_node.size.x / 2, panel_node.size.y)
				var end_pos = target_panel.global_position + Vector2(target_panel.size.x / 2, 0)
				draw_line(to_local(start_pos), to_local(end_pos), Color(1,1,1), 2)
				print("Drawing line from %s to %s" % [sublevel_name, target_name])
