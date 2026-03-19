extends RefCounted
class_name ResourceSystem

var _rules: Dictionary


func _init(rules: Dictionary) -> void:
	_rules = rules.duplicate(true)


func initialize_unit(unit) -> void:
	unit.hp = clampi(unit.hp, 0, unit.max_hp)
	if unit.uses_qi:
		unit.qi = clampi(unit.qi, 0, unit.max_qi)


func on_turn_start(unit) -> void:
	if unit.uses_qi and unit.qi_per_turn > 0:
		modify(unit, "qi", unit.qi_per_turn)


func can_pay(unit, resource_name: String, amount: int) -> bool:
	match resource_name:
		"qi":
			return not unit.uses_qi or unit.qi >= amount
		_:
			return true


func spend(unit, resource_name: String, amount: int) -> bool:
	if not can_pay(unit, resource_name, amount):
		return false
	modify(unit, resource_name, -amount)
	return true


func modify(unit, resource_name: String, delta: int) -> void:
	match resource_name:
		"qi":
			unit.modify_qi(delta)
		"hp":
			unit.modify_hp(delta)
