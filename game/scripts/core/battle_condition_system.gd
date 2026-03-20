extends RefCounted
class_name BattleConditionSystem

const CONDITION_ALIASES := {
	"defeat_all_enemies": "all_enemies_defeated",
	"all_players_down": "all_allies_defeated"
}

var _battle_config: Dictionary = {}
var _initial_units: Array[Dictionary] = []


func _init(battle_config: Dictionary = {}) -> void:
	configure(battle_config)


func configure(battle_config: Dictionary) -> void:
	_battle_config = battle_config.duplicate(true)
	_initial_units.clear()


func capture_initial_units(units: Array) -> void:
	_initial_units.clear()
	for unit in units:
		if unit == null:
			continue
		_initial_units.append({
			"instance_id": String(unit.unit_id),
			"template_id": String(unit.template_id),
			"team": String(unit.team)
		})


func resolve_battle_result(state: Dictionary) -> String:
	if _conditions_met(_battle_config.get("defeat_conditions", []), state):
		return "defeat"
	if _conditions_met(_battle_config.get("victory_conditions", []), state):
		return "victory"
	return ""


func _conditions_met(raw_conditions, state: Dictionary) -> bool:
	if not (raw_conditions is Array):
		return false
	for entry in raw_conditions:
		if entry is Dictionary and _condition_met(_normalize_condition_entry(entry), state):
			return true
	return false


func _condition_met(condition: Dictionary, state: Dictionary) -> bool:
	match String(condition.get("type", "")):
		"all_enemies_defeated":
			return _living_units_for_team(state.get("enemy_units", []), "enemy").is_empty()
		"all_allies_defeated":
			return _living_units_for_team(state.get("player_units", []), "player").is_empty()
		"leader_dead":
			return _is_leader_dead(condition, state)
		"turn_limit_survive":
			return _is_turn_limit_survive_met(condition, state)
		"reach_tile":
			return _is_reach_tile_met(condition, state)
		_:
			return false


func _is_leader_dead(condition: Dictionary, state: Dictionary) -> bool:
	var leader_id := String(condition.get("leader_id", ""))
	var team := String(condition.get("team", ""))
	if leader_id.is_empty():
		return false
	if not _leader_existed_initially(leader_id, team):
		return false
	for unit in state.get("all_units", []):
		if unit == null or not unit.is_alive():
			continue
		if not team.is_empty() and String(unit.team) != team:
			continue
		if String(unit.unit_id) == leader_id or String(unit.template_id) == leader_id:
			return false
	return true


func _leader_existed_initially(leader_id: String, team: String) -> bool:
	for entry in _initial_units:
		if not team.is_empty() and String(entry.get("team", "")) != team:
			continue
		if String(entry.get("instance_id", "")) == leader_id or String(entry.get("template_id", "")) == leader_id:
			return true
	return false


func _is_turn_limit_survive_met(condition: Dictionary, state: Dictionary) -> bool:
	var team := String(condition.get("team", "player"))
	var active_unit = state.get("active_unit", null)
	if active_unit == null or String(active_unit.team) != team:
		return false
	var turn_limit := int(condition.get("turn_limit", 0))
	return int(state.get("round_index", 1)) > turn_limit


func _is_reach_tile_met(condition: Dictionary, state: Dictionary) -> bool:
	var cell := _array_to_cell(condition.get("cell", []))
	if cell == Vector2i(-1, -1):
		return false
	var team := String(condition.get("team", "player"))
	var unit_id := String(condition.get("unit_id", ""))
	for unit in state.get("all_units", []):
		if unit == null or not unit.is_alive():
			continue
		if String(unit.team) != team:
			continue
		if not unit_id.is_empty() and String(unit.unit_id) != unit_id and String(unit.template_id) != unit_id:
			continue
		if unit.grid_position == cell:
			return true
	return false


func _living_units_for_team(units: Array, team: String) -> Array:
	var result: Array = []
	for unit in units:
		if unit != null and unit.is_alive() and String(unit.team) == team:
			result.append(unit)
	return result


func _normalize_condition_entry(entry: Dictionary) -> Dictionary:
	var normalized := entry.duplicate(true)
	var raw_type := String(normalized.get("type", ""))
	normalized["type"] = String(CONDITION_ALIASES.get(raw_type, raw_type))
	return normalized


func _array_to_cell(raw_value) -> Vector2i:
	if raw_value is Array and raw_value.size() >= 2:
		return Vector2i(int(raw_value[0]), int(raw_value[1]))
	return Vector2i(-1, -1)
