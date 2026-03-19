extends RefCounted
class_name CombatSystem

var _rules: Dictionary
var _stance_system
var _status_system
var _action_system


func _init(rules: Dictionary, stance_system, status_system, action_system) -> void:
	_rules = rules.duplicate(true)
	_stance_system = stance_system
	_status_system = status_system
	_action_system = action_system


func preview_damage(attacker, defender, base_damage: int, attack_stance: String = "") -> int:
	var resolved_stance = attack_stance if not attack_stance.is_empty() else attacker.current_stance
	var total = float(base_damage)
	total *= _stance_system.get_damage_multiplier(resolved_stance, defender.current_stance)
	total *= _status_system.get_outgoing_damage_multiplier(attacker)
	total *= get_charge_multiplier(attacker)
	return maxi(1, int(round(total)))


func apply_damage(attacker, defender, base_damage: int, attack_stance: String = "") -> Dictionary:
	var damage = preview_damage(attacker, defender, base_damage, attack_stance)
	defender.modify_hp(-damage)
	return {
		"attacker": attacker,
		"target": defender,
		"damage": damage,
		"killed": not defender.is_alive()
	}


func get_charge_multiplier(attacker) -> float:
	var charge_rules: Dictionary = _rules.get("charge", {})
	var applies_to_modes: Array = charge_rules.get("applies_to_modes", [])
	var current_mode = String(attacker.turn_state.get("charge_mode", "ground"))
	if not applies_to_modes.has(current_mode):
		return 1.0
	var remaining_move = _action_system.get_remaining_move(attacker)
	return 1.0 + float(charge_rules.get("damage_bonus_per_move_point", 0.0)) * remaining_move
