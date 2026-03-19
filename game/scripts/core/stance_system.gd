extends RefCounted
class_name StanceSystem

var _counter_map: Dictionary = {}
var _multipliers: Dictionary = {}
var _default_stance := "none"


func _init(rules: Dictionary) -> void:
	var stance_rules: Dictionary = rules.get("stances", {})
	_counter_map = stance_rules.get("counter_map", {}).duplicate(true)
	_multipliers = stance_rules.get("multipliers", {}).duplicate(true)
	_default_stance = String(stance_rules.get("default", "none"))


func set_stance(unit, stance_id: String) -> void:
	unit.current_stance = stance_id if not stance_id.is_empty() else _default_stance
	unit.queue_redraw()


func does_counter(attacker_stance: String, defender_stance: String) -> bool:
	if attacker_stance == _default_stance or defender_stance == _default_stance:
		return false
	return String(_counter_map.get(attacker_stance, "")) == defender_stance


func get_damage_multiplier(attacker_stance: String, defender_stance: String) -> float:
	if attacker_stance == _default_stance:
		return float(_multipliers.get("none_attack", 1.0))
	if defender_stance == _default_stance:
		return float(_multipliers.get("against_none", 1.5))
	if does_counter(attacker_stance, defender_stance):
		return float(_multipliers.get("counter", 2.0))
	if does_counter(defender_stance, attacker_stance):
		return float(_multipliers.get("countered", 0.5))
	return float(_multipliers.get("neutral", 1.0))
