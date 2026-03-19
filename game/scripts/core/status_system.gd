extends RefCounted
class_name StatusSystem

var _status_rules: Dictionary = {}
var _control_statuses: Array[String] = []


func _init(rules: Dictionary) -> void:
	_status_rules = rules.get("statuses", {}).duplicate(true)
	_control_statuses = []
	for status_id in rules.get("control_statuses", []):
		_control_statuses.append(String(status_id))


func on_turn_end(unit) -> void:
	if not unit.is_alive():
		return
	var yinren_rules: Dictionary = _status_rules.get("yinren", {})
	if yinren_rules.is_empty():
		return
	if not bool(unit.turn_state.get("has_attacked", false)):
		var next_stacks = mini(unit.get_status_stacks("yinren") + int(yinren_rules.get("gain_if_no_attack", 1)), int(yinren_rules.get("max_stacks", 99)))
		apply_status(unit, "yinren", next_stacks, "set")


func on_attack_performed(unit) -> void:
	var yinren_rules: Dictionary = _status_rules.get("yinren", {})
	if bool(yinren_rules.get("clear_on_attack", true)):
		clear_status(unit, "yinren")


func apply_status(unit, status_id: String, stacks: int, mode: String = "add") -> Dictionary:
	var current_stacks = unit.get_status_stacks(status_id)
	var next_stacks = stacks
	if mode == "add":
		next_stacks = current_stacks + stacks
	var status_rule: Dictionary = _status_rules.get(status_id, {})
	if status_rule.has("max_stacks"):
		next_stacks = mini(next_stacks, int(status_rule.get("max_stacks", next_stacks)))
	unit.set_status_stacks(status_id, next_stacks)
	return {
		"status_id": status_id,
		"stacks": next_stacks,
		"is_control": is_control_status(status_id)
	}


func clear_status(unit, status_id: String) -> void:
	unit.clear_status(status_id)


func get_outgoing_damage_multiplier(unit) -> float:
	var yinren_rules: Dictionary = _status_rules.get("yinren", {})
	var stacks = unit.get_status_stacks("yinren")
	return 1.0 + float(yinren_rules.get("damage_bonus_per_stack", 0.0)) * stacks


func is_control_status(status_id: String) -> bool:
	return _control_statuses.has(status_id)
