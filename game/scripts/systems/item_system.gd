extends RefCounted
class_name ItemSystem

var _data_manager
var _action_system
var _resource_system
var _status_system


func _init(data_manager, action_system, resource_system, status_system) -> void:
	_data_manager = data_manager
	_action_system = action_system
	_resource_system = resource_system
	_status_system = status_system


func get_item(item_id: String) -> Dictionary:
	return _data_manager.get_item(item_id)


func get_valid_targets(unit, item_def: Dictionary, all_units: Array) -> Array:
	if unit == null or item_def.is_empty():
		return []
	if not _phase_requirements_pass(unit, item_def):
		return []
	if not _requirements_pass(unit, item_def, null):
		return []

	var targeting: Dictionary = item_def.get("targeting", {})
	var target_type := String(targeting.get("type", "self"))
	var valid_targets: Array = []

	match target_type:
		"self":
			valid_targets.append(unit)
		"unit":
			var filters: Array = targeting.get("filters", ["ally"])
			for candidate in all_units:
				if candidate == null or not candidate.is_alive():
					continue
				if not _unit_matches_filters(unit, candidate, filters):
					continue
				if _requirements_pass(unit, item_def, candidate):
					valid_targets.append(candidate)

	return valid_targets


func has_valid_target(unit, item_def: Dictionary, all_units: Array) -> bool:
	return not get_valid_targets(unit, item_def, all_units).is_empty()


func can_execute_item(unit, item_def: Dictionary, target, all_units: Array) -> bool:
	if item_def.is_empty():
		return false
	for candidate in get_valid_targets(unit, item_def, all_units):
		if candidate == target:
			return true
	return false


func execute_item(unit, item_id: String, target, all_units: Array) -> Dictionary:
	var item_def: Dictionary = get_item(item_id)
	if item_def.is_empty():
		return {"success": false, "error": "Unknown item: %s" % item_id}
	if not can_execute_item(unit, item_def, target, all_units):
		return {"success": false, "error": "Item target is invalid."}
	if not _pay_costs(unit, item_def.get("costs", [])):
		return {"success": false, "error": "Item costs could not be paid."}
	if not unit.consume_item(item_id, 1):
		return {"success": false, "error": "Item is out of stock."}

	var result := {
		"success": true,
		"item_id": item_id,
		"target": target,
		"status_events": [],
		"messages": []
	}

	for effect in item_def.get("effects", []):
		if not (effect is Dictionary):
			continue
		match String(effect.get("type", "")):
			"modify_resource":
				_resource_system.modify(target, String(effect.get("resource", "hp")), int(effect.get("amount", 0)))
			"apply_status":
				var apply_result = _status_system.apply_status(
					target,
					String(effect.get("status_id", "")),
					int(effect.get("stacks", 1)),
					String(effect.get("mode", "add"))
				)
				result["status_events"].append({
					"target": target,
					"status_id": apply_result.get("status_id", ""),
					"stacks": apply_result.get("stacks", 0),
					"is_control": apply_result.get("is_control", false)
				})
			"clear_status":
				_status_system.clear_status(target, String(effect.get("status_id", "")))

	_action_system.mark_action_performed(unit)
	return result


func _phase_requirements_pass(unit, item_def: Dictionary) -> bool:
	return _action_system.can_use_action(unit) and _requirements_pass(unit, item_def, null)


func _requirements_pass(unit, item_def: Dictionary, target) -> bool:
	for requirement in item_def.get("requirements", []):
		if not (requirement is Dictionary):
			continue
		match String(requirement.get("type", "")):
			"budget_available":
				if not _action_system.can_use_budget(unit, String(requirement.get("budget", "")), int(requirement.get("amount", 1))):
					return false
			"resource_at_least":
				if not _resource_system.can_pay(unit, String(requirement.get("resource", "")), int(requirement.get("amount", 0))):
					return false
			"target_alive":
				if target == null or not target.is_alive():
					return false
	return true


func _pay_costs(unit, costs: Array) -> bool:
	for cost in costs:
		if not (cost is Dictionary):
			continue
		match String(cost.get("type", "")):
			"resource":
				if not _resource_system.spend(unit, String(cost.get("resource", "")), int(cost.get("amount", 0))):
					return false
			"budget":
				if not _action_system.consume_budget(unit, String(cost.get("budget", "")), int(cost.get("amount", 1))):
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
