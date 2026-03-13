extends RefCounted
class_name EnemyAI


func choose_action(enemy: BattleUnit, player: BattleUnit, battle_manager) -> Dictionary:
	if player == null or not is_instance_valid(player) or player.is_dead():
		return {"type": "wait"}

	if battle_manager.are_adjacent(enemy.grid_position, player.grid_position):
		return {"type": "attack"}

	if enemy.has_active_stance() and battle_manager.does_stance_counter(player.current_stance, enemy.current_stance):
		return {"type": "guard"}

	var move_cell := choose_move_cell(enemy, player, battle_manager)
	if move_cell != enemy.grid_position:
		return {"type": "move", "cell": move_cell}

	return {"type": "wait"}


func choose_move_cell(enemy: BattleUnit, player: BattleUnit, battle_manager) -> Vector2i:
	var best_cell := enemy.grid_position
	var best_distance = battle_manager.grid_distance(enemy.grid_position, player.grid_position)
	var reachable = battle_manager.get_reachable_cells(enemy)

	for cell in reachable:
		var distance = battle_manager.grid_distance(cell, player.grid_position)
		if distance < best_distance:
			best_distance = distance
			best_cell = cell

	return best_cell
