extends RefCounted
class_name ActionSystem

var _rules: Dictionary


func _init(rules: Dictionary) -> void:
	_rules = rules.duplicate(true)


func begin_turn(unit) -> void:
	var default_budgets: Dictionary = _rules.get("action_budgets", {"move": 1, "action": 1})
	unit.turn_state = {
		"budgets": default_budgets.duplicate(true),
		"has_attacked": false,
		"used_qinggong": false,
		"moved_normally": false,
		"move_phase_done": false,
		"action_phase_done": false,
		"remaining_move": unit.base_move,
		"charge_mode": "ground",
		"movement_locked": false,
		"reserved_stance_reselect": false,
		"turn_ended": false
	}


func can_use_budget(unit, budget_name: String, amount: int = 1) -> bool:
	return get_budget(unit, budget_name) >= amount


func get_budget(unit, budget_name: String) -> int:
	var budgets: Dictionary = unit.turn_state.get("budgets", {})
	return int(budgets.get(budget_name, 0))


func consume_budget(unit, budget_name: String, amount: int = 1) -> bool:
	if not can_use_budget(unit, budget_name, amount):
		return false
	var budgets: Dictionary = unit.turn_state.get("budgets", {})
	budgets[budget_name] = int(budgets.get(budget_name, 0)) - amount
	unit.turn_state["budgets"] = budgets
	return true


func can_move_normally(unit) -> bool:
	return can_use_budget(unit, "move", 1) \
		and not bool(unit.turn_state.get("used_qinggong", false)) \
		and not bool(unit.turn_state.get("moved_normally", false)) \
		and not bool(unit.turn_state.get("move_phase_done", false)) \
		and not bool(unit.turn_state.get("movement_locked", false)) \
		and not bool(unit.turn_state.get("action_phase_done", false))


func can_use_qinggong(unit) -> bool:
	return can_use_budget(unit, "move", 1) \
		and not bool(unit.turn_state.get("moved_normally", false)) \
		and not bool(unit.turn_state.get("used_qinggong", false)) \
		and not bool(unit.turn_state.get("move_phase_done", false)) \
		and not bool(unit.turn_state.get("movement_locked", false)) \
		and not bool(unit.turn_state.get("action_phase_done", false))


func can_use_action(unit) -> bool:
	return can_use_budget(unit, "action", 1) \
		and bool(unit.turn_state.get("move_phase_done", false)) \
		and not bool(unit.turn_state.get("action_phase_done", false))


func is_move_phase_done(unit) -> bool:
	return bool(unit.turn_state.get("move_phase_done", false))


func is_action_phase_done(unit) -> bool:
	return bool(unit.turn_state.get("action_phase_done", false))


func advance_to_action_phase(unit) -> void:
	unit.turn_state["move_phase_done"] = true
	unit.turn_state["movement_locked"] = true


func record_normal_move(unit, distance: int) -> void:
	unit.turn_state["moved_normally"] = true
	unit.turn_state["remaining_move"] = maxi(0, unit.base_move - distance)
	unit.turn_state["charge_mode"] = "ground"
	consume_budget(unit, "move", 1)
	advance_to_action_phase(unit)


func record_qinggong_move(unit, distance: int) -> void:
	unit.turn_state["used_qinggong"] = true
	unit.turn_state["remaining_move"] = 0
	unit.turn_state["charge_mode"] = "qinggong"
	advance_to_action_phase(unit)


func mark_action_performed(unit) -> void:
	unit.turn_state["action_phase_done"] = true
	unit.turn_state["movement_locked"] = true


func mark_attack_performed(unit) -> void:
	unit.turn_state["has_attacked"] = true
	mark_action_performed(unit)


func get_remaining_move(unit) -> int:
	return int(unit.turn_state.get("remaining_move", unit.base_move))


func get_turn_flag(unit, flag_name: String):
	return unit.turn_state.get(flag_name, false)


func reserve_stance_reselect(unit) -> void:
	unit.turn_state["reserved_stance_reselect"] = true


func end_turn(unit) -> void:
	unit.turn_state["turn_ended"] = true
