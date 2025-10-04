extends Node

# Global registries
var all_dungeons: Dictionary = {}   # key: dungeon name (String) -> value: DungeonNode (Node2D)
var all_sublevels: Dictionary = {}  # key: sublevel name -> value: Panel node

# Register a dungeon node (call after spawning and calling create_sublevels())
func register_dungeon(dungeon_name: String, node: Node2D) -> void:
	all_dungeons[dungeon_name] = node

# Register a sublevel globally
func register_sublevel(sublevel_name: String, node: Panel) -> void:
	all_sublevels[sublevel_name] = node

# Get a sublevel node by name
func get_sublevel(sublevel_name: String) -> Panel:
	return all_sublevels.get(sublevel_name, null)


# ----------------------------
# Force-directed layout params
# ----------------------------
@export var iterations: int = 120             # simulation steps
@export var area_factor: float = 2000.0       # influences initial spacing
@export var repulsion_strength: float = 2000.0
@export var attraction_strength: float = 0.1
@export var ideal_edge_length: float = 400.0
@export var damping: float = 0.85
@export var max_displacement: float = 40.0

# Non-overlap params
@export var min_separation_x: float = 24.0    # extra horizontal padding between dungeon boxes
@export var min_separation_y: float = 24.0    # extra vertical padding (we still clamp Y to 0)

# Run the layout algorithm and apply positions to dungeon nodes
# center_origin: if true, center horizontally around x=0 (Y will be 0 for all nodes)
func layout_dungeons_force_directed(center_origin: bool = true) -> void:
	if all_dungeons.size() == 0:
		return

	# Build node list
	var node_names: Array = []
	for dungeon_key in all_dungeons.keys():
		node_names.append(dungeon_key)

	# Build undirected edges from sublevel connections
	var edges: Array = []
	var edge_map: Dictionary = {}
	for dungeon_key in node_names:
		var dnode = all_dungeons.get(dungeon_key, null)
		if dnode == null:
			continue
		if not dnode.has_method("_get_sublevel_connections"):
			continue
		for sublevel_key in dnode.sublevel_nodes.keys():
			var conn_list = dnode._get_sublevel_connections("%s.md" % sublevel_key)
			for target in conn_list:
				var target_dungeon = _dungeon_name_from_sublevel(target)
				if target_dungeon == "" or not all_dungeons.has(target_dungeon):
					continue
				if target_dungeon == dungeon_key:
					continue  # skip same-dungeon inter-sublevel edges here
				var a_name = dungeon_key
				var b_name = target_dungeon
				var key = ("%s|%s" % [a_name, b_name]) if a_name < b_name else ("%s|%s" % [b_name, a_name])
				if not edge_map.has(key):
					edge_map[key] = true
					edges.append([a_name, b_name])

	# Initialize positions and velocities
	var positions: Dictionary = {}
	var velocities: Dictionary = {}
	var n_count: int = node_names.size()
	var grid_size = int(ceil(sqrt(max(1, n_count))))
	var idx: int = 0
	for dn in node_names:
		var node_inst = all_dungeons.get(dn, null)
		var p: Vector2 = Vector2.ZERO
		if node_inst != null:
			p = node_inst.position
			# scatter only if at exact zero
			if p == Vector2.ZERO:
				var col = idx % grid_size
				var row = int(idx / max(1, grid_size))
				p = Vector2(col * (ideal_edge_length * 0.6), row * (ideal_edge_length * 0.6))
		positions[dn] = p
		velocities[dn] = Vector2.ZERO
		idx += 1

	# Force-directed simulation
	var k_repulsion = repulsion_strength
	var k_attraction = attraction_strength
	var L0 = ideal_edge_length

	for step in range(iterations):
		# Initialize forces
		var forces: Dictionary = {}
		for nm in node_names:
			forces[nm] = Vector2.ZERO

		# Repulsive forces (n^2)
		for i in range(n_count):
			var name_a = node_names[i]
			for j in range(i + 1, n_count):
				var name_b = node_names[j]
				var delta = positions[name_a] - positions[name_b]
				var dist = max(delta.length(), 0.01)
				var dir = delta / dist
				var repulse = k_repulsion / (dist * dist)
				var f = dir * repulse
				forces[name_a] += f
				forces[name_b] -= f

		# Attractive forces along edges (spring)
		for edge in edges:
			var a = edge[0]
			var b = edge[1]
			var delta = positions[b] - positions[a]
			var dist = max(delta.length(), 0.01)
			var dir = delta / dist
			var spring = k_attraction * (dist - L0)
			var f = dir * spring
			forces[a] += f
			forces[b] -= f

		# Integrate to velocities and positions
		for nm in node_names:
			var v = velocities[nm]
			var fvec = forces[nm]
			v = (v + fvec) * damping
			if v.length() > max_displacement:
				v = v.normalized() * max_displacement
			velocities[nm] = v
			positions[nm] += v

	# Strong overlap resolver (ensures no overlaps remain)
	_resolve_overlaps_strict(positions)

	# Compute horizontal bounding box and centering offset
	var min_x = 1e20
	var max_x = -1e20
	for nm in node_names:
		var p = positions[nm]
		if p.x < min_x:
			min_x = p.x
		if p.x > max_x:
			max_x = p.x

	var center_offset_x = 0.0
	if center_origin:
		var center_x = (min_x + max_x) * 0.5
		center_offset_x = -center_x

	# Apply positions to nodes — set Y = 0 for all nodes
	for nm in node_names:
		var node_inst = all_dungeons.get(nm, null)
		if node_inst == null:
			continue
		var final_x = positions[nm].x + center_offset_x
		node_inst.position = Vector2(final_x, 0.0)


# Helper: extract dungeon name from sublevel string like "Mourning Grotto 2"
func _dungeon_name_from_sublevel(sublevel: String) -> String:
	var parts = sublevel.split(" ")
	if parts.size() < 2:
		return ""
	var dungeon_parts: Array = []
	var last_idx: int = parts.size() - 1
	for i in range(0, last_idx):
		dungeon_parts.append(parts[i])
	var result: String = ""
	for i in range(dungeon_parts.size()):
		result += dungeon_parts[i]
		if i < dungeon_parts.size() - 1:
			result += " "
	return result


# Strict overlap resolver that ensures minimum separation (iterative, stable)
func _resolve_overlaps_strict(positions: Dictionary) -> void:
	# We'll iteratively push overlapping boxes apart until no overlap or we hit a pass limit.
	var names: Array = positions.keys()
	var max_passes: int = 64
	var pass_index: int = 0
	var moved_any: bool = true

	while moved_any and pass_index < max_passes:
		pass_index += 1
		moved_any = false

		# For each pair, check overlap and push apart if overlapping
		for i in range(names.size()):
			for j in range(i + 1, names.size()):
				var a_name: String = names[i]
				var b_name: String = names[j]
				if not all_dungeons.has(a_name) or not all_dungeons.has(b_name):
					continue
				var a_pos: Vector2 = positions[a_name]
				var b_pos: Vector2 = positions[b_name]

				# get bounding box for a
				var a_w: float = 300.0
				var a_h: float = 400.0
				var a_node = all_dungeons.get(a_name, null)
				if a_node != null and "panel" in a_node and a_node.panel != null:
					a_w = a_node.panel.size.x
					a_h = a_node.panel.size.y
				a_w += min_separation_x
				a_h += min_separation_y
				var a_half_w = a_w * 0.5
				var a_half_h = a_h * 0.5
				var a_x1 = a_pos.x - a_half_w
				var a_y1 = a_pos.y - a_half_h
				var a_x2 = a_pos.x + a_half_w
				var a_y2 = a_pos.y + a_half_h

				# get bounding box for b
				var b_w: float = 300.0
				var b_h: float = 400.0
				var b_node = all_dungeons.get(b_name, null)
				if b_node != null and "panel" in b_node and b_node.panel != null:
					b_w = b_node.panel.size.x
					b_h = b_node.panel.size.y
				b_w += min_separation_x
				b_h += min_separation_y
				var b_half_w = b_w * 0.5
				var b_half_h = b_h * 0.5
				var b_x1 = b_pos.x - b_half_w
				var b_y1 = b_pos.y - b_half_h
				var b_x2 = b_pos.x + b_half_w
				var b_y2 = b_pos.y + b_half_h

				# overlap amounts
				var overlap_x = min(a_x2, b_x2) - max(a_x1, b_x1)
				var overlap_y = min(a_y2, b_y2) - max(a_y1, b_y1)

				if overlap_x > 0.0 and overlap_y > 0.0:
					# compute push vector along smallest overlap axis
					var push_vec: Vector2 = Vector2.ZERO
					if overlap_x < overlap_y:
						var dir_x = 1.0 if a_pos.x < b_pos.x else -1.0
						push_vec.x = overlap_x * 0.51 * dir_x
					else:
						var dir_y = 1.0 if a_pos.y < b_pos.y else -1.0
						push_vec.y = overlap_y * 0.51 * dir_y

					# apply half to each (cap movement)
					var move_a: Vector2 = -push_vec * 0.5
					var move_b: Vector2 = push_vec * 0.5

					if move_a.length() > max_displacement:
						move_a = move_a.normalized() * max_displacement
					if move_b.length() > max_displacement:
						move_b = move_b.normalized() * max_displacement

					positions[a_name] = positions[a_name] + move_a
					positions[b_name] = positions[b_name] + move_b
					moved_any = true

	# After separation passes, clamp all Y to baseline 0.0
	for nm in names:
		var pos_vec: Vector2 = positions[nm]
		pos_vec.y = 0.0
		positions[nm] = pos_vec


# Convenience: clear registries
func clear() -> void:
	all_dungeons.clear()
	all_sublevels.clear()
