extends Node

# Global registry of all dungeons and sublevels
var all_dungeons: Dictionary = {}   # key: dungeon name, value: DungeonNode
var all_sublevels: Dictionary = {}  # key: sublevel name, value: Panel node

# Register a dungeon node
func register_dungeon(dungeon_name: String, node: Node2D) -> void:
	all_dungeons[dungeon_name] = node

# Register a sublevel globally
func register_sublevel(sublevel_name: String, node: Panel) -> void:
	all_sublevels[sublevel_name] = node

# Get a sublevel node by name
func get_sublevel(sublevel_name: String) -> Panel:
	if all_sublevels.has(sublevel_name):
		return all_sublevels[sublevel_name]
	return null

# Arrange dungeons based on connections
func layout_dungeons(spacing: float = 50.0) -> void:
	var visited: Dictionary = {}
	var current_x: float = 0.0

	for dungeon_name in all_dungeons.keys():
		current_x = _layout_dungeon(dungeon_name, current_x, visited, spacing)

# Recursive layout helper
func _layout_dungeon(dungeon_name: String, current_x: float, visited: Dictionary, spacing: float) -> float:
	if visited.has(dungeon_name):
		return visited[dungeon_name]  # already positioned

	var dungeon_node = all_dungeons.get(dungeon_name, null)
	if dungeon_node == null:
		return current_x

	# Position this dungeon
	dungeon_node.position.x = current_x
	visited[dungeon_name] = current_x

	# Determine width of this dungeon
	var width = dungeon_node.panel.size.x + spacing
	var next_x = current_x + width

	# Collect all connected dungeons
	var connected_dungeons: Array = []
	for sublevel_name in dungeon_node.sublevel_nodes.keys():
		var connections = dungeon_node._get_sublevel_connections("%s.md" % sublevel_name)
		for target in connections:
			# Convert sublevel name to dungeon name
			var parts = target.split(" ")  # PackedStringArray
			if parts.size() < 2:
				continue
			var dungeon_parts := []
			for i in range(parts.size() - 1):
				dungeon_parts.append(parts[i])
			var target_dungeon_name = ""
			for j in range(dungeon_parts.size()):
				target_dungeon_name += dungeon_parts[j]
				if j < dungeon_parts.size() - 1:
					target_dungeon_name += " "
			if all_dungeons.has(target_dungeon_name) and target_dungeon_name not in connected_dungeons:
				connected_dungeons.append(target_dungeon_name)

	# Recursively position connected dungeons
	for conn_dungeon in connected_dungeons:
		next_x = _layout_dungeon(conn_dungeon, next_x, visited, spacing)

	return next_x
