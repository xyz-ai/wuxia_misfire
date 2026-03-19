extends RefCounted
class_name AIEvaluator

var _skill_system
var _movement_system
var _stance_system
var _combat_system


func _init(skill_system, movement_system, stance_system, combat_system) -> void:
	_skill_system = skill_system
	_movement_system = movement_system
	_stance_system = stance_system
	_combat_system = combat_system


func score_candidate(unit, candidate: Dictionary, battle_system) -> float:
	var difficulty = battle_system.get_ai_difficulty()
	var current_distance = _nearest_opponent_distance(unit.grid_position, battle_system.get_player_units())
	var projected_cell = unit.grid_position
	if candidate.has("cell") and candidate["cell"] is Vector2i:
		projected_cell = candidate["cell"]
	var projected_distance = _nearest_opponent_distance(projected_cell, battle_system.get_player_units())
	var kind := String(candidate.get("kind", "wait"))

	match kind:
		"wait":
			return -5.0
		"move":
			return _score_move_candidate(current_distance, projected_distance, difficulty)
		"skip_move":
			return _score_skip_move_candidate(unit, battle_system, projected_distance)
		"skill":
			return _score_skill_candidate(unit, candidate, battle_system, current_distance, projected_distance, difficulty)
		_:
			return -10.0


func _score_move_candidate(current_distance: int, projected_distance: int, difficulty: String) -> float:
	var score = float(current_distance - projected_distance) * 4.0
	if difficulty == "normal":
		return score + float(current_distance - projected_distance)
	if difficulty == "extreme":
		return score + maxf(0.0, 6.0 - float(projected_distance))
	return score


func _score_skip_move_candidate(unit, battle_system, projected_distance: int) -> float:
	var best_score = 0.0
	var all_units = battle_system.get_all_units()
	for skill_id in unit.skills:
		var skill_def = _skill_system.get_skill(skill_id)
		if skill_def.is_empty() or String(skill_def.get("action_type", "")) == "move":
			continue
		var valid_targets = _skill_system.get_valid_targets(unit, skill_def, all_units, true)
		for target in valid_targets:
			var candidate = {
				"kind": "skill",
				"skill_def": skill_def,
				"target": target
			}
			best_score = maxf(best_score, _score_skill_candidate(unit, candidate, battle_system, projected_distance, projected_distance, battle_system.get_ai_difficulty()))
	return best_score + 2.0


func _score_skill_candidate(unit, candidate: Dictionary, battle_system, current_distance: int, projected_distance: int, difficulty: String) -> float:
	var skill_def: Dictionary = candidate.get("skill_def", {})
	var skill_action = String(skill_def.get("action_type", ""))
	var score = 0.0

	if skill_action == "move":
		score += float(current_distance - projected_distance) * 5.0
	else:
		var target = candidate.get("target", null)
		if target != null:
			var predicted_damage = _skill_system.preview_damage(unit, skill_def, target)
			score += predicted_damage
			if difficulty != "simple" and predicted_damage >= target.hp:
				score += 25.0
			if difficulty != "simple":
				var predicted_stance = _skill_system.predict_stance_after_pre_effects(unit, skill_def)
				if _stance_system.does_counter(predicted_stance, target.current_stance):
					score += 8.0
				elif _stance_system.does_counter(target.current_stance, predicted_stance):
					score -= 4.0
				if target.current_stance == "none":
					score += 5.0
			if difficulty == "hard" or difficulty == "extreme":
				score += maxf(0.0, 8.0 - float(projected_distance) * 1.25)
				score += _survival_score(unit, skill_def, projected_distance)
			if difficulty == "extreme":
				score += _skill_tag_bonus(skill_def)

	if difficulty == "simple":
		return score
	if difficulty == "normal":
		return score + float(current_distance - projected_distance)
	if difficulty == "hard":
		return score
	return score + maxf(0.0, 6.0 - float(projected_distance))


func _nearest_opponent_distance(cell: Vector2i, opponents: Array) -> int:
	var best_distance = 999
	for opponent in opponents:
		if opponent != null and opponent.is_alive():
			best_distance = mini(best_distance, _movement_system.get_distance(cell, opponent.grid_position))
	return best_distance if best_distance != 999 else 0


func _survival_score(unit, skill_def: Dictionary, projected_distance: int) -> float:
	var hp_ratio = float(unit.hp) / maxf(1.0, float(unit.max_hp))
	var score = 0.0
	if hp_ratio <= 0.4:
		score += float(projected_distance) * 1.8
	if _skill_system.predict_stance_after_pre_effects(unit, skill_def) == "shoushi" and hp_ratio <= 0.7:
		score += 8.0
	return score


func _skill_tag_bonus(skill_def: Dictionary) -> float:
	var bonus = 0.0
	for tag_value in skill_def.get("ai_tags", {}).values():
		bonus += float(tag_value) * 1.5
	return bonus
