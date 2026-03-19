extends RefCounted
class_name FormationSystem

var _data_manager
var _rng = RandomNumberGenerator.new()


func _init(data_manager) -> void:
	_data_manager = data_manager
	_rng.randomize()


func load_player_formation(slot_index: int) -> Dictionary:
	return _data_manager.get_player_formation_slot(slot_index)


func save_player_formation(slot_index: int, formation_data: Dictionary) -> bool:
	return _data_manager.save_player_formation_slot(slot_index, formation_data)


func resolve_battle_formations(battle_config: Dictionary) -> Dictionary:
	var board: Dictionary = battle_config.get("board", {})
	var player_formation: Dictionary = battle_config.get("player_formation", {})
	var player_units: Array = player_formation.get("units", [])
	if player_units.is_empty():
		return {"error": "Player formation is empty."}
	if not _all_units_in_bounds(player_units, board):
		return {"error": "Player formation contains out-of-bounds cells."}

	var enemy_formation = choose_enemy_formation(battle_config.get("enemy_formation_pool", []), battle_config.get("enemy_units", []).size(), board)
	if enemy_formation.is_empty():
		return {"error": "No valid enemy formation found for battle %s." % battle_config.get("battle_id", "")}

	return {
		"player_spawns": player_units.duplicate(true),
		"enemy_spawns": build_enemy_spawns(battle_config.get("enemy_units", []), enemy_formation),
		"enemy_formation": enemy_formation
	}


func choose_enemy_formation(formation_pool: Array, enemy_count: int, board: Dictionary) -> Dictionary:
	var valid_formations: Array[Dictionary] = []
	for formation_id in formation_pool:
		var formation = _data_manager.get_enemy_formation(String(formation_id))
		if formation.is_empty():
			continue
		var slots: Array = formation.get("slots", [])
		if slots.size() < enemy_count:
			continue
		if not _all_cells_in_bounds(slots, board):
			continue
		valid_formations.append(formation)
	if valid_formations.is_empty():
		return {}
	return valid_formations[_rng.randi_range(0, valid_formations.size() - 1)].duplicate(true)


func build_enemy_spawns(enemy_units: Array, formation: Dictionary) -> Array[Dictionary]:
	var spawns: Array[Dictionary] = []
	var slots: Array = formation.get("slots", [])
	for index in range(enemy_units.size()):
		var spawn_entry: Dictionary = enemy_units[index].duplicate(true)
		spawn_entry["cell"] = slots[index]
		spawns.append(spawn_entry)
	return spawns


func _all_units_in_bounds(units: Array, board: Dictionary) -> bool:
	var used_cells: Dictionary = {}
	for unit_data in units:
		if not (unit_data is Dictionary):
			return false
		var cell = unit_data.get("cell", [])
		if not _is_cell_in_bounds(cell, board):
			return false
		var cell_key = "%s,%s" % [cell[0], cell[1]]
		if used_cells.has(cell_key):
			return false
		used_cells[cell_key] = true
	return true


func _all_cells_in_bounds(cells: Array, board: Dictionary) -> bool:
	for cell in cells:
		if not _is_cell_in_bounds(cell, board):
			return false
	return true


func _is_cell_in_bounds(raw_cell, board: Dictionary) -> bool:
	if not (raw_cell is Array) or raw_cell.size() < 2:
		return false
	var cell = Vector2i(int(raw_cell[0]), int(raw_cell[1]))
	return cell.x >= 0 and cell.x < int(board.get("columns", 8)) and cell.y >= 0 and cell.y < int(board.get("rows", 8))
