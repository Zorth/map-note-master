extends Node

@export var project_folder := "/home/zorth/Documents/sythian"

var dungeon_files: Array[String] = []

func _ready():
	dungeon_files.clear()
	scan_folder(project_folder)

# Recursively scan folders for .md files with "#module/dungeon"
func scan_folder(folder_path: String) -> void:
	var dir = DirAccess.open(folder_path)
	if dir == null:
		push_error("Cannot open folder: %s" % folder_path)
		return

	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		# Skip hidden files/folders
		if file_name.begins_with("."):
			file_name = dir.get_next()
			continue

		var full_path = folder_path + "/" + file_name
		if dir.current_is_dir():
			scan_folder(full_path)
		elif file_name.to_lower().ends_with(".md"):
			if file_has_module_dungeon(full_path):
				dungeon_files.append(full_path)

		file_name = dir.get_next()
	dir.list_dir_end()

# Check if file contains "#module/dungeon" according to Obsidian rules
func file_has_module_dungeon(file_path: String) -> bool:
	var file_name = file_path.get_file().to_lower()
	# Exclude files starting with underscore
	if file_name.begins_with("_"):
		return false

	if not FileAccess.file_exists(file_path):
		return false

	var f = FileAccess.open(file_path, FileAccess.READ)
	if f == null:
		return false

	var in_frontmatter := false
	while not f.eof_reached():
		var line = f.get_line().strip_edges()

		# Track frontmatter
		if line == "---":
			in_frontmatter = not in_frontmatter
			continue

		# Skip lines starting with quotes or backticks
		if line.begins_with('"') or line.begins_with("'") or line.begins_with("`"):
			continue

		# Match the exact tag in markdown content
		if line.find("#module/dungeon") != -1:
			f.close()
			return true

		# Optional: check frontmatter keys (tags:)
		if in_frontmatter:
			var key_value = line.split(":")
			if key_value.size() >= 2:
				var key = key_value[0].strip_edges()
				var value = key_value[1].strip_edges()
				if key == "tags" and value.find("module/dungeon") != -1:
					f.close()
					return true

	f.close()
	return false

# Parse YAML frontmatter for startLevel and endLevel
func parse_frontmatter(file_path: String) -> Dictionary:
	var frontmatter := {}
	if not FileAccess.file_exists(file_path):
		return frontmatter

	var f = FileAccess.open(file_path, FileAccess.READ)
	if f == null:
		return frontmatter

	var in_frontmatter := false
	while not f.eof_reached():
		var line = f.get_line().strip_edges()
		if line == "---":
			in_frontmatter = not in_frontmatter
			continue

		if in_frontmatter:
			var parts = line.split(":")
			if parts.size() >= 2:
				var key = parts[0].strip_edges()
				var value = parts[1].strip_edges().to_int()
				frontmatter[key] = value

	f.close()
	return frontmatter
