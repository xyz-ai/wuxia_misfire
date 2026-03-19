extends RefCounted
class_name TurnManager

var _action_system
var _resource_system
var _status_system

var _player_units: Array = []
var _enemy_units: Array = []
var _current_team := "player"
var _current_index := -1
var _current_unit
var _round_index := 1


func _init(action_system, resource_system, status_system) -> void:
	_action_system = action_system
	_resource_system = resource_system
	_status_system = status_system


func begin_battle(player_units: Array, enemy_units: Array):
	_player_units = player_units
	_enemy_units = enemy_units
	_current_team = "player"
	_current_index = -1
	_current_unit = null
	_round_index = 1
	return advance_to_next_unit()


func end_current_turn() -> void:
	if _current_unit == null:
		return
	_status_system.on_turn_end(_current_unit)
	_action_system.end_turn(_current_unit)
	_current_unit.set_active_turn(false)


func advance_to_next_unit():
	var guard := 0
	while guard < 4:
		var unit_list := _get_team_list(_current_team)
		_current_index += 1
		while _current_index < unit_list.size():
			var candidate = unit_list[_current_index]
			if candidate != null and candidate.is_alive():
				_current_unit = candidate
				_action_system.begin_turn(candidate)
				_resource_system.on_turn_start(candidate)
				candidate.set_active_turn(true)
				return candidate
			_current_index += 1

		if _current_team == "player":
			_current_team = "enemy"
		else:
			_current_team = "player"
			_round_index += 1
		_current_index = -1
		guard += 1

		if _living_units(_player_units).is_empty() or _living_units(_enemy_units).is_empty():
			break

	_current_unit = null
	return null


func is_player_phase() -> bool:
	return _current_team == "player"


func get_current_unit():
	return _current_unit


func get_round_index() -> int:
	return _round_index


func _get_team_list(team_name: String) -> Array:
	return _player_units if team_name == "player" else _enemy_units


func _living_units(units: Array) -> Array:
	var result: Array = []
	for unit in units:
		if unit != null and unit.is_alive():
			result.append(unit)
	return result
