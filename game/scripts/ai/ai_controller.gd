extends RefCounted
class_name AIController

var _skill_system
var _movement_system
var _action_system
var _ai_evaluator


func _init(skill_system, movement_system, action_system, ai_evaluator) -> void:
	_skill_system = skill_system
	_movement_system = movement_system
	_action_system = action_system
	_ai_evaluator = ai_evaluator


func take_turn(unit, battle_system) -> void:
	var guard = 0
	while guard < 4 and unit != null and unit.is_alive():
		var candidates = _build_candidates(unit, battle_system)
		if candidates.is_empty():
			return
		for candidate in candidates:
			candidate["score"] = _ai_evaluator.score_candidate(unit, candidate, battle_system)
		candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return float(a.get("score", -99999.0)) > float(b.get("score", -99999.0))
		)

		var best: Dictionary = candidates[0]
		var kind := String(best.get("kind", "wait"))
		if kind == "wait":
			return
		var success = _execute_candidate(unit, best, battle_system)
		if not success:
			return
		if kind == "move" or kind == "skip_move":
			guard += 1
			continue
		if kind == "skill" and String(best.get("skill_def", {}).get("action_type", "")) == "move":
			guard += 1
			continue
		return


func _build_candidates(unit, battle_system) -> Array[Dictionary]:
	var candidates: Array[Dictionary] = []
	var all_units = battle_system.get_all_units()

	if not _action_system.is_move_phase_done(unit):
		for skill_id in unit.skills:
			var skill_def = _skill_system.get_skill(skill_id)
			if skill_def.is_empty() or String(skill_def.get("action_type", "")) != "move":
				continue
			var valid_targets = _skill_system.get_valid_targets(unit, skill_def, all_units)
			for target in valid_targets:
				var candidate = {
					"kind": "skill",
					"skill_id": skill_id,
					"skill_def": skill_def,
					"target": target
				}
				if target is Vector2i:
					candidate["cell"] = target
				candidates.append(candidate)

		if _action_system.can_move_normally(unit):
			var reachable = _movement_system.get_reachable_cells(unit, _action_system.get_remaining_move(unit), "ground")
			for cell in reachable:
				candidates.append({
					"kind": "move",
					"cell": cell
				})

		candidates.append({"kind": "skip_move"})
	else:
		for skill_id in unit.skills:
			var skill_def = _skill_system.get_skill(skill_id)
			if skill_def.is_empty() or String(skill_def.get("action_type", "")) == "move":
				continue
			var valid_targets = _skill_system.get_valid_targets(unit, skill_def, all_units)
			for target in valid_targets:
				var candidate = {
					"kind": "skill",
					"skill_id": skill_id,
					"skill_def": skill_def,
					"target": target
				}
				if target is Vector2i:
					candidate["cell"] = target
				candidates.append(candidate)

	candidates.append({"kind": "wait"})
	return candidates


func _execute_candidate(unit, candidate: Dictionary, battle_system) -> bool:
	match String(candidate.get("kind", "wait")):
		"move":
			return battle_system.move_unit_for_ai(unit, candidate.get("cell", unit.grid_position))
		"skip_move":
			return battle_system.skip_move_phase_for_ai(unit)
		"skill":
			return battle_system.execute_skill_for_unit(unit, String(candidate.get("skill_id", "")), candidate.get("target", null))
		_:
			return false
