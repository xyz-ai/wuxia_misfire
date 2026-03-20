extends RefCounted
class_name BattleLoader

const BattleVisuals = preload("res://scripts/ui/battle_visuals.gd")

const CONDITION_ALIASES := {
	"defeat_all_enemies": "all_enemies_defeated",
	"all_players_down": "all_allies_defeated"
}

var _data_manager


func _init(data_manager) -> void:
	_data_manager = data_manager


func load_battle_config(battle_id: String) -> Dictionary:
	var battle_data = _data_manager.get_battle(battle_id)
	if battle_data.is_empty():
		return {"error": "Unknown battle_id: %s" % battle_id}

	var rules = _data_manager.get_rules()
	var board_defaults: Dictionary = rules.get("board_defaults", {})
	var board_data: Dictionary = battle_data.get("board", {})
	var board := {
		"columns": int(board_data.get("columns", board_defaults.get("columns", 8))),
		"rows": int(board_data.get("rows", board_defaults.get("rows", 8)))
	}

	var player_data: Dictionary = battle_data.get("player", {})
	var formation_slot := int(player_data.get("formation_slot", 1))
	var player_formation: Dictionary = _data_manager.get_player_formation_slot(formation_slot)
	if player_formation.is_empty():
		return {"error": "Player formation slot %d is missing." % formation_slot}
	if player_formation.get("units", []).is_empty():
		return {"error": "Player formation slot %d has no units." % formation_slot}

	var enemy_data: Dictionary = battle_data.get("enemies", {})
	var enemy_units: Array = enemy_data.get("units", [])
	var enemy_formation_pool: Array = enemy_data.get("formation_pool", [])
	if enemy_units.is_empty():
		return {"error": "Battle %s has no enemy units." % battle_id}
	if enemy_formation_pool.is_empty():
		return {"error": "Battle %s has no enemy formation pool." % battle_id}

	return {
		"battle_id": battle_id,
		"name": String(battle_data.get("name", battle_id)),
		"title": String(battle_data.get("title", battle_data.get("name", battle_id))),
		"background_path": String(battle_data.get("background_path", BattleVisuals.get_default_background_path())),
		"ui_note": String(battle_data.get("ui_note", "")),
		"board": board,
		"terrain": battle_data.get("terrain", []).duplicate(true),
		"player_formation_slot": formation_slot,
		"player_formation": player_formation,
		"enemy_units": enemy_units.duplicate(true),
		"enemy_formation_pool": enemy_formation_pool.duplicate(true),
		"ai_difficulty": String(battle_data.get("ai_difficulty", "simple")),
		"victory_conditions": _normalize_conditions(
			battle_data.get("victory_conditions", []),
			[{"type": "all_enemies_defeated"}]
		),
		"defeat_conditions": _normalize_conditions(
			battle_data.get("defeat_conditions", []),
			[{"type": "all_allies_defeated"}]
		),
		"hooks": {
			"on_unit_killed": null,
			"on_non_lethal_hit": null,
			"on_control_applied": null,
			"on_battle_result": null
		}
	}


func _normalize_conditions(raw_conditions, fallback_conditions: Array) -> Array:
	var normalized: Array = []
	if raw_conditions is Array:
		for entry in raw_conditions:
			if not (entry is Dictionary):
				continue
			normalized.append(_normalize_condition_entry(entry))
	if normalized.is_empty():
		for entry in fallback_conditions:
			normalized.append(_normalize_condition_entry(entry))
	return normalized


func _normalize_condition_entry(entry: Dictionary) -> Dictionary:
	var normalized := entry.duplicate(true)
	var raw_type := String(normalized.get("type", ""))
	normalized["type"] = String(CONDITION_ALIASES.get(raw_type, raw_type))
	if normalized["type"] == "reach_tile" and normalized.get("unit_scope", null) == null:
		normalized["unit_scope"] = "any"
	return normalized
