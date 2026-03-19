extends RefCounted
class_name MovementSystem

var _rules: Dictionary
var _columns = 8
var _rows = 8
var _terrain_map: Dictionary = {}
var _units_by_cell: Dictionary = {}


func _init(rules: Dictionary) -> void:
	_rules = rules.duplicate(true)


func configure_board(board: Dictionary, terrain: Array) -> void:
	_columns = int(board.get("columns", 8))
	_rows = int(board.get("rows", 8))
	_terrain_map.clear()
	for terrain_cell in terrain:
		if terrain_cell is Dictionary:
			var cell = _array_to_cell(terrain_cell.get("cell", []))
			_terrain_map[_cell_key(cell)] = String(terrain_cell.get("type", "plain"))


func register_units(units: Array) -> void:
	_units_by_cell.clear()
	for unit in units:
		if unit != null and unit.is_alive():
			_units_by_cell[_cell_key(unit.grid_position)] = unit


func is_in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < _columns and cell.y >= 0 and cell.y < _rows


func get_board_size() -> Vector2i:
	return Vector2i(_columns, _rows)


func get_terrain_at(cell: Vector2i) -> String:
	return String(_terrain_map.get(_cell_key(cell), "plain"))


func get_terrain_map() -> Dictionary:
	return _terrain_map.duplicate(true)


func get_unit_at(cell: Vector2i):
	return _units_by_cell.get(_cell_key(cell), null)


func is_cell_occupied(cell: Vector2i, ignore_unit = null) -> bool:
	var occupant = get_unit_at(cell)
	return occupant != null and occupant != ignore_unit


func get_distance(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)


func get_reachable_cells(unit, max_steps: int, movement_mode: String = "ground") -> Array[Vector2i]:
	return _get_reachable_cells_internal(unit, max_steps, movement_mode, false, false)


func get_qinggong_target_map(unit, max_steps: int) -> Dictionary:
	var valid_cells = _get_reachable_cells_internal(unit, max_steps, "qinggong", false, false)
	var preview_cells = _get_reachable_cells_internal(unit, max_steps, "qinggong", true, true)
	var valid_lookup: Dictionary = {}
	for cell in valid_cells:
		valid_lookup[_cell_key(cell)] = true

	var invalid_cells: Array[Vector2i] = []
	for cell in preview_cells:
		if valid_lookup.has(_cell_key(cell)):
			continue
		invalid_cells.append(cell)

	_sort_cells(valid_cells)
	_sort_cells(invalid_cells)
	return {
		"valid": valid_cells,
		"invalid": invalid_cells
	}


func find_path(unit, target_cell: Vector2i, max_steps: int, movement_mode: String = "ground") -> Array[Vector2i]:
	if target_cell == unit.grid_position or not is_in_bounds(target_cell):
		return []
	if max_steps <= 0:
		return []
	if movement_mode == "qinggong" and is_enemy_back_landing(unit, target_cell):
		return []

	var start = unit.grid_position
	var frontier: Array[Vector2i] = [start]
	var distance_map = {_cell_key(start): 0}
	var came_from = {_cell_key(start): start}

	while not frontier.is_empty():
		var current: Vector2i = frontier.pop_front()
		if current == target_cell:
			break
		var current_distance = int(distance_map[_cell_key(current)])
		for neighbor in _get_neighbors(current):
			if distance_map.has(_cell_key(neighbor)):
				continue
			if not _can_enter_cell(neighbor, movement_mode, unit, false):
				continue
			var next_distance = current_distance + 1
			if next_distance > max_steps:
				continue
			distance_map[_cell_key(neighbor)] = next_distance
			came_from[_cell_key(neighbor)] = current
			frontier.append(neighbor)

	if not came_from.has(_cell_key(target_cell)):
		return []

	var path: Array[Vector2i] = [target_cell]
	var step = target_cell
	while step != start:
		step = came_from[_cell_key(step)]
		path.push_front(step)
	return path


func apply_move(unit, target_cell: Vector2i, movement_mode: String, max_steps: int) -> Dictionary:
	var path = find_path(unit, target_cell, max_steps, movement_mode)
	if path.is_empty():
		return {"success": false, "error": "Target cell is unreachable."}

	_units_by_cell.erase(_cell_key(unit.grid_position))
	unit.set_grid_cell(target_cell)
	_units_by_cell[_cell_key(target_cell)] = unit
	return {
		"success": true,
		"target": target_cell,
		"path": path,
		"distance": maxi(path.size() - 1, 0),
		"movement_mode": movement_mode
	}


func is_enemy_back_landing(unit, cell: Vector2i) -> bool:
	var qinggong_rules: Dictionary = _rules.get("qinggong", {})
	if not bool(qinggong_rules.get("deny_enemy_back_landing", true)):
		return false
	for occupant in _units_by_cell.values():
		var other = occupant
		if other == null or not other.is_alive():
			continue
		if not other.is_enemy_of(unit):
			continue
		if other.get_back_cell() == cell:
			return true
	return false


func _get_reachable_cells_internal(unit, max_steps: int, movement_mode: String, ignore_unit_blockers: bool, ignore_enemy_back: bool) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if max_steps <= 0:
		return result

	var frontier: Array[Vector2i] = [unit.grid_position]
	var distances = {_cell_key(unit.grid_position): 0}

	while not frontier.is_empty():
		var current: Vector2i = frontier.pop_front()
		var current_distance = int(distances[_cell_key(current)])
		for neighbor in _get_neighbors(current):
			if distances.has(_cell_key(neighbor)):
				continue
			if not _can_enter_cell(neighbor, movement_mode, unit, ignore_unit_blockers):
				continue
			var next_distance = current_distance + 1
			if next_distance > max_steps:
				continue
			distances[_cell_key(neighbor)] = next_distance
			frontier.append(neighbor)
			if ignore_enemy_back or movement_mode != "qinggong" or not is_enemy_back_landing(unit, neighbor):
				result.append(neighbor)

	_sort_cells(result)
	return result


func _can_enter_cell(cell: Vector2i, movement_mode: String, ignore_unit, ignore_unit_blockers: bool) -> bool:
	if not is_in_bounds(cell):
		return false
	if not ignore_unit_blockers and is_cell_occupied(cell, ignore_unit):
		return false
	if movement_mode == "ground" and _terrain_blocks_ground(cell):
		return false
	return true


func _terrain_blocks_ground(cell: Vector2i) -> bool:
	var terrain_type = get_terrain_at(cell)
	var terrain_defs: Dictionary = _rules.get("terrain_types", {})
	return bool(terrain_defs.get(terrain_type, {}).get("blocks_ground", false))


func _get_neighbors(cell: Vector2i) -> Array[Vector2i]:
	var neighbors: Array[Vector2i] = []
	for direction in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		var next_cell = cell + direction
		if is_in_bounds(next_cell):
			neighbors.append(next_cell)
	return neighbors


func _sort_cells(cells: Array[Vector2i]) -> void:
	cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		if a.y == b.y:
			return a.x < b.x
		return a.y < b.y
	)


func _cell_key(cell: Vector2i) -> String:
	return "%d,%d" % [cell.x, cell.y]


func _array_to_cell(raw_value) -> Vector2i:
	if raw_value is Array and raw_value.size() >= 2:
		return Vector2i(int(raw_value[0]), int(raw_value[1]))
	return Vector2i.ZERO
