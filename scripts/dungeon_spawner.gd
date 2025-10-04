extends Node2D   # MUST be Node or Node2D

@export var dungeon_scene: PackedScene      # assign DungeonNode.tscn in Inspector
@export var offset_x := 200.0               # horizontal distance between dungeon nodes

func _ready():
	# Get the FileScanner child node
	var scanner = get_node("FileScanner") as Node
	if scanner == null:
		push_error("FileScanner node not found as a child!")
		return

	# Populate dungeon_files
	scanner._ready()

	# Keep track of all spawned dungeon nodes
	var dungeon_nodes: Array = []

	# Spawn DungeonNodes for each file
	for file_path in scanner.dungeon_files:
		var dungeon_node = dungeon_scene.instantiate() as Node2D
		add_child(dungeon_node)

		var file_name = file_path.get_file().replace(".md", "")
		dungeon_node.set_label_text(file_name)

		var fm = scanner.parse_frontmatter(file_path)
		var start_level = fm.get("startLevel", 1)
		var end_level = fm.get("endLevel", 1)

		dungeon_node.create_sublevels(start_level, end_level)

		# Register dungeon in DungeonManager for layout
		DungeonManager.register_dungeon(file_name, dungeon_node)

		dungeon_nodes.append(dungeon_node)

	# Only call layout once after all dungeons are spawned
	DungeonManager.layout_dungeons_force_directed()  # optional param center_origin=false
