extends RefCounted
class_name SkillSystem

var _data_manager
var _movement_system
var _action_system
var _resource_system
var _stance_system
var _status_system
var _combat_system


func _init(data_manager, movement_system, action_system, resource_system, stance_system, status_system, combat_system) -> void:
	_data_manager = data_manager
	_movement_system = movement_system
	_action_system = action_system
	_resource_system = resource_system
	_stance_system = stance_system
	_status_system = status_system
	_combat_system = combat_system


func get_skill(skill_id: String) -> Dictionary:
	return _data_manager.get_skill(skill_id)


func get_unit_skills(unit) -> Array[Dictionary]:
	return _data_manager.get_skills(unit.skills)


func get_primary_attack_skill(unit) -> Dictionary:
	for skill_id in unit.skills:
		var skill_def = get_skill(skill_id)
		if skill_def.is_empty():
			continue
		if String(skill_def.get("action_type", "")) == "attack" and String(skill_def.get("targeting", {}).get("type", "")) == "unit":
			return skill_def
	return {}


func get_skill_range(unit, skill_def: Dictionary) -> int:
	var targeting: Dictionary = skill_def.get("targeting", {})
	if targeting.has("range_formula"):
		return maxi(0, int(round(evaluate_formula(targeting.get("range_formula"), {"unit": unit, "skill": skill_def}))))
	return int(targeting.get("range", 0))


func get_valid_targets(unit, skill_def: Dictionary, all_units: Array, ignore_phase: bool = false) -> Array:
	if not _phase_requirements_pass(unit, skill_def, ignore_phase):
		return []
	if not _requirements_pass(unit, skill_def, null):
		return []

	var targeting: Dictionary = skill_def.get("targeting", {})
	var target_type = String(targeting.get("type", "self"))
	var valid_targets: Array = []

	match target_type:
		"self":
			valid_targets.append(unit)
		"cell":
			var movement_mode = String(targeting.get("movement_mode", "ground"))
			var range_limit = get_skill_range(unit, skill_def)
			valid_targets = _movement_system.get_reachable_cells(unit, range_limit, movement_mode)
		"unit":
			var filters: Array = targeting.get("filters", [])
			for candidate in all_units:
				if candidate == null or not candidate.is_alive():
					continue
				if candidate == unit and filters.has("enemy"):
					continue
				if not _unit_matches_filters(unit, candidate, filters):
					continue
				if not _matches_target_pattern(unit, candidate, targeting):
					continue
				if _requirements_pass(unit, skill_def, candidate):
					valid_targets.append(candidate)
	return valid_targets


func has_valid_target(unit, skill_def: Dictionary, all_units: Array, ignore_phase: bool = false) -> bool:
	return not get_valid_targets(unit, skill_def, all_units, ignore_phase).is_empty()


func can_execute_skill(unit, skill_def: Dictionary, target, all_units: Array) -> bool:
	if skill_def.is_empty():
		return false
	var valid_targets = get_valid_targets(unit, skill_def, all_units)
	for candidate in valid_targets:
		if candidate == target:
			return true
		if candidate is Vector2i and target is Vector2i and candidate == target:
			return true
	return false


func preview_damage(unit, skill_def: Dictionary, target) -> int:
	var damage_formula = _find_damage_formula(skill_def)
	if damage_formula == null:
		return 0
	var base_damage = int(round(evaluate_formula(damage_formula, {"unit": unit, "target": target, "skill": skill_def})))
	return _combat_system.preview_damage(unit, target, base_damage, predict_stance_after_pre_effects(unit, skill_def))


func predict_stance_after_pre_effects(unit, skill_def: Dictionary) -> String:
	for effect in skill_def.get("pre_effects", []):
		if effect is Dictionary and String(effect.get("type", "")) == "set_stance":
			return String(effect.get("stance", unit.current_stance))
	return unit.current_stance


func execute_skill(unit, skill_id: String, target, all_units: Array) -> Dictionary:
	var skill_def = get_skill(skill_id)
	if skill_def.is_empty():
		return {"success": false, "error": "Unknown skill: %s" % skill_id}
	if not can_execute_skill(unit, skill_def, target, all_units):
		return {"success": false, "error": "Skill target is invalid."}
	if not _pay_costs(unit, skill_def.get("costs", []), skill_def):
		return {"success": false, "error": "Skill costs could not be paid."}

	var context = {
		"unit": unit,
		"target": target,
		"skill": skill_def,
		"all_units": all_units,
		"result": {
			"success": true,
			"skill_id": skill_id,
			"action_type": String(skill_def.get("action_type", "")),
			"movement": {},
			"damage_events": [],
			"status_events": [],
			"messages": []
		}
	}

	_run_effects(skill_def.get("pre_effects", []), context)
	_run_effects(skill_def.get("resolve_effects", []), context)
	_run_effects(skill_def.get("post_effects", []), context)

	var action_type := String(skill_def.get("action_type", ""))
	if context["result"].get("damage_events", []).size() > 0:
		_action_system.mark_attack_performed(unit)
		_status_system.on_attack_performed(unit)
	elif action_type != "move":
		_action_system.mark_action_performed(unit)

	return context["result"]


func evaluate_formula(formula, context: Dictionary) -> float:
	if formula is int or formula is float:
		return float(formula)
	if not (formula is Dictionary):
		return 0.0

	match String(formula.get("type", "constant")):
		"constant":
			return float(formula.get("value", 0.0))
		"stat":
			var source_unit = _resolve_unit_reference(context, String(formula.get("source", "unit")))
			return source_unit.get_stat(String(formula.get("stat", ""))) if source_unit != null else 0.0
		"skill_value":
			var skill_def: Dictionary = context.get("skill", {})
			var values: Dictionary = skill_def.get("values", {})
			return float(values.get(String(formula.get("key", "")), 0.0))
		"status_stacks":
			var status_unit = _resolve_unit_reference(context, String(formula.get("source", "unit")))
			return float(status_unit.get_status_stacks(String(formula.get("status_id", "")))) if status_unit != null else 0.0
		"remaining_move":
			var move_unit = _resolve_unit_reference(context, String(formula.get("source", "unit")))
			return float(_action_system.get_remaining_move(move_unit)) if move_unit != null else 0.0
		"add":
			var total = 0.0
			for child in formula.get("values", []):
				total += evaluate_formula(child, context)
			return total
		"mul":
			var value = 1.0
			for child in formula.get("values", []):
				value *= evaluate_formula(child, context)
			return value
		_:
			return 0.0


func _run_effects(effects: Array, context: Dictionary) -> void:
	for effect in effects:
		if not (effect is Dictionary):
			continue
		match String(effect.get("type", "")):
			"set_stance":
				_stance_system.set_stance(context["unit"], String(effect.get("stance", "none")))
			"move_unit":
				_execute_move_effect(effect, context)
			"damage":
				_execute_damage_effect(effect, context)
			"apply_status":
				_execute_apply_status(effect, context)
			"clear_status":
				var clear_target = _resolve_effect_target(effect, context)
				if clear_target != null:
					_status_system.clear_status(clear_target, String(effect.get("status_id", "")))
			"modify_resource":
				var resource_target = _resolve_effect_target(effect, context)
				if resource_target != null:
					var delta = int(round(evaluate_formula(effect.get("formula", effect.get("amount", 0)), context)))
					_resource_system.modify(resource_target, String(effect.get("resource", "qi")), delta)
			"consume_action":
				_action_system.consume_budget(context["unit"], String(effect.get("budget", "action")), int(effect.get("amount", 1)))
			"reserve_stance_reselect":
				_action_system.reserve_stance_reselect(context["unit"])
			"call_hook":
				_execute_hook(effect, context)


func _execute_move_effect(effect: Dictionary, context: Dictionary) -> void:
	var unit = context["unit"]
	if not (context["target"] is Vector2i):
		context["result"]["success"] = false
		context["result"]["error"] = "Move target must be a cell."
		return
	var skill_def: Dictionary = context["skill"]
	var targeting: Dictionary = skill_def.get("targeting", {})
	var movement_mode = String(targeting.get("movement_mode", "ground"))
	var range_limit = get_skill_range(unit, skill_def)
	var move_result: Dictionary = _movement_system.apply_move(unit, context["target"], movement_mode, range_limit)
	if not bool(move_result.get("success", false)):
		context["result"]["success"] = false
		context["result"]["error"] = move_result.get("error", "Movement failed.")
		return
	if movement_mode == "qinggong":
		_action_system.record_qinggong_move(unit, int(move_result.get("distance", 0)))
	context["result"]["movement"] = move_result


func _execute_damage_effect(effect: Dictionary, context: Dictionary) -> void:
	var target = context["target"]
	if target == null:
		context["result"]["success"] = false
		context["result"]["error"] = "Damage effect requires a unit target."
		return
	var base_damage = int(round(evaluate_formula(effect.get("formula", 0), context)))
	var attack_stance = predict_stance_after_pre_effects(context["unit"], context["skill"])
	var damage_result = _combat_system.apply_damage(context["unit"], target, base_damage, attack_stance)
	var damage_events: Array = context["result"].get("damage_events", [])
	damage_events.append(damage_result)
	context["result"]["damage_events"] = damage_events


func _execute_apply_status(effect: Dictionary, context: Dictionary) -> void:
	var target = _resolve_effect_target(effect, context)
	if target == null:
		return
	var stacks = int(round(evaluate_formula(effect.get("formula", effect.get("stacks", 1)), context)))
	var apply_result = _status_system.apply_status(target, String(effect.get("status_id", "")), stacks, String(effect.get("mode", "add")))
	var status_events: Array = context["result"].get("status_events", [])
	status_events.append({
		"target": target,
		"status_id": apply_result.get("status_id", ""),
		"stacks": apply_result.get("stacks", 0),
		"is_control": apply_result.get("is_control", false)
	})
	context["result"]["status_events"] = status_events


func _execute_hook(effect: Dictionary, context: Dictionary) -> void:
	var skill_def: Dictionary = context.get("skill", {})
	var script_path = String(skill_def.get("script_hook", ""))
	if script_path.is_empty():
		return
	var script_resource = load(script_path)
	if script_resource == null:
		return
	var method_name = String(effect.get("method", "execute"))
	if script_resource is GDScript:
		var hook_instance = script_resource.new()
		if hook_instance != null and hook_instance.has_method(method_name):
			hook_instance.call(method_name, context)
	elif script_resource.has_method(method_name):
		script_resource.call(method_name, context)


func _requirements_pass(unit, skill_def: Dictionary, target) -> bool:
	for requirement in skill_def.get("requirements", []):
		if not (requirement is Dictionary):
			continue
		match String(requirement.get("type", "")):
			"budget_available":
				if not _action_system.can_use_budget(unit, String(requirement.get("budget", "")), int(requirement.get("amount", 1))):
					return false
			"resource_at_least":
				if not _resource_system.can_pay(unit, String(requirement.get("resource", "")), int(requirement.get("amount", 0))):
					return false
			"flag_false":
				if bool(unit.turn_state.get(String(requirement.get("flag", "")), false)):
					return false
			"flag_true":
				if not bool(unit.turn_state.get(String(requirement.get("flag", "")), false)):
					return false
			"alive":
				if not unit.is_alive():
					return false
			"target_alive":
				if target == null or not target.is_alive():
					return false
	return true


func _phase_requirements_pass(unit, skill_def: Dictionary, ignore_phase: bool) -> bool:
	if ignore_phase:
		return true
	var action_type := String(skill_def.get("action_type", ""))
	if action_type == "move":
		var targeting: Dictionary = skill_def.get("targeting", {})
		if String(targeting.get("movement_mode", "ground")) == "qinggong":
			return _action_system.can_use_qinggong(unit)
		return not _action_system.is_move_phase_done(unit)
	return _action_system.can_use_action(unit)


func _pay_costs(unit, costs: Array, skill_def: Dictionary) -> bool:
	for cost in costs:
		if not (cost is Dictionary):
			continue
		var amount = int(round(evaluate_formula(cost.get("formula", cost.get("amount", 0)), {"unit": unit, "skill": skill_def})))
		match String(cost.get("type", "")):
			"resource":
				if not _resource_system.spend(unit, String(cost.get("resource", "")), amount):
					return false
			"budget":
				if not _action_system.consume_budget(unit, String(cost.get("budget", "")), amount):
					return false
	return true


func _unit_matches_filters(source, candidate, filters: Array) -> bool:
	for filter_value in filters:
		match String(filter_value):
			"enemy":
				if not candidate.is_enemy_of(source):
					return false
			"ally":
				if candidate.is_enemy_of(source):
					return false
			"self":
				if candidate != source:
					return false
	return true


func _matches_target_pattern(source, candidate, targeting: Dictionary) -> bool:
	var pattern = String(targeting.get("pattern", "range"))
	var distance = _movement_system.get_distance(source.grid_position, candidate.grid_position)
	match pattern:
		"adjacent":
			return distance == 1
		_:
			return distance <= get_skill_range(source, {"targeting": targeting})


func _resolve_unit_reference(context: Dictionary, key: String):
	var value = context.get(key, null)
	return value


func _resolve_effect_target(effect: Dictionary, context: Dictionary):
	match String(effect.get("target", "target")):
		"self":
			return context["unit"]
		"target":
			return context["target"]
		_:
			return context["target"]


func _find_damage_formula(skill_def: Dictionary):
	for effect in skill_def.get("resolve_effects", []):
		if effect is Dictionary and String(effect.get("type", "")) == "damage":
			return effect.get("formula", null)
	return null
