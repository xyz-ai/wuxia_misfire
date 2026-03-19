extends RefCounted
class_name DataManager

const BATTLES_DIR := "res://data/battles"
const UNIT_TEMPLATES_PATH := "res://data/units/unit_templates.json"
const SKILLS_PATH := "res://data/skills/skills.json"
const ITEMS_PATH := "res://data/items/items.json"
const ENEMY_FORMATIONS_PATH := "res://data/formations/enemy_formations.json"
const PLAYER_FORMATIONS_PATH := "res://data/player_formations.json"
const RULES_PATH := "res://data/rules.json"

var _unit_templates: Dictionary = {}
var _skills: Dictionary = {}
var _items: Dictionary = {}
var _enemy_formations: Dictionary = {}
var _player_formations: Dictionary = {}
var _rules: Dictionary = {}
var _battle_cache: Dictionary = {}


func _init() -> void:
	reload_all()


func reload_all() -> void:
	_unit_templates = _read_json_file(UNIT_TEMPLATES_PATH)
	_skills = _read_json_file(SKILLS_PATH)
	_items = _read_json_file(ITEMS_PATH)
	_enemy_formations = _read_json_file(ENEMY_FORMATIONS_PATH)
	_player_formations = _read_json_file(PLAYER_FORMATIONS_PATH)
	_rules = _read_json_file(RULES_PATH)
	_battle_cache.clear()


func get_rules() -> Dictionary:
	return _rules.duplicate(true)


func get_battle(battle_id: String) -> Dictionary:
	if _battle_cache.has(battle_id):
		return _battle_cache[battle_id].duplicate(true)

	var path := "%s/%s.json" % [BATTLES_DIR, battle_id]
	var battle_data := _read_json_file(path)
	if battle_data.is_empty():
		return {}

	_battle_cache[battle_id] = battle_data
	return battle_data.duplicate(true)


func get_unit_template(template_id: String) -> Dictionary:
	return _unit_templates.get(template_id, {}).duplicate(true)


func get_skill(skill_id: String) -> Dictionary:
	return _skills.get(skill_id, {}).duplicate(true)


func get_skills(skill_ids: Array[String]) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	for skill_id in skill_ids:
		var skill_def := get_skill(skill_id)
		if not skill_def.is_empty():
			results.append(skill_def)
	return results


func get_item(item_id: String) -> Dictionary:
	return _items.get(item_id, {}).duplicate(true)


func get_items(item_ids: Array[String]) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	for item_id in item_ids:
		var item_def := get_item(item_id)
		if not item_def.is_empty():
			results.append(item_def)
	return results


func get_enemy_formation(formation_id: String) -> Dictionary:
	return _enemy_formations.get(formation_id, {}).duplicate(true)


func get_player_formation_slot(slot_index: int) -> Dictionary:
	var slots: Dictionary = _player_formations.get("slots", {})
	return slots.get(str(slot_index), {}).duplicate(true)


func save_player_formation_slot(slot_index: int, slot_data: Dictionary) -> bool:
	if not _player_formations.has("slots"):
		_player_formations["slots"] = {}
	_player_formations["slots"][str(slot_index)] = slot_data.duplicate(true)
	return _write_json_file(PLAYER_FORMATIONS_PATH, _player_formations)


func generate_npc(build_request: Dictionary) -> Dictionary:
	return {
		"implemented": false,
		"request": build_request.duplicate(true)
	}


func _read_json_file(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_error("Missing JSON data file: %s" % path)
		return {}

	var text := FileAccess.get_file_as_string(path)
	var parsed = JSON.parse_string(text)
	if parsed == null:
		push_error("Failed to parse JSON file: %s" % path)
		return {}
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("JSON root must be a Dictionary: %s" % path)
		return {}
	return parsed


func _write_json_file(path: String, payload: Dictionary) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("Failed to write JSON file: %s" % path)
		return false
	file.store_string(JSON.stringify(payload, "\t"))
	file.close()
	return true
