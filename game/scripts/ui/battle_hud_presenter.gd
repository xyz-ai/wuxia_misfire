class_name BattleHUDPresenter

const BattleTexts = preload("res://scripts/core/battle_texts.gd")
const BattleVisuals = preload("res://scripts/ui/battle_visuals.gd")

var _skill_system
var _item_system
var _action_system
var _movement_system


func _init(skill_system, item_system, action_system, movement_system) -> void:
	_skill_system = skill_system
	_item_system = item_system
	_action_system = action_system
	_movement_system = movement_system


func build_view_model(context: Dictionary) -> Dictionary:
	var focused_unit = context.get("focused_unit", null)
	var active_unit = context.get("active_unit", null)
	var pending_skill_id := String(context.get("pending_skill_id", ""))
	var pending_item_id := String(context.get("pending_item_id", ""))
	var phase_id := String(context.get("phase_id", "loading"))
	var interaction_feedback := String(context.get("interaction_feedback_text", ""))
	var focus_mode := _get_focus_mode(focused_unit, active_unit, bool(context.get("can_player_act", false)))

	return {
		"unit": focused_unit,
		"character": _build_character_section(focused_unit),
		"battle_info": _build_battle_info_section(
			context,
			focused_unit,
			active_unit,
			phase_id,
			pending_skill_id,
			pending_item_id,
			focus_mode,
			interaction_feedback
		),
		"command": {
			"system_actions": _build_system_action_entries(context, active_unit, pending_skill_id, pending_item_id, focus_mode),
			"skill_entries": _build_skill_entries(context, focused_unit, pending_skill_id, pending_item_id, focus_mode),
			"item_entries": _build_item_entries(context, focused_unit, pending_item_id, pending_skill_id, focus_mode),
			"skills_state_text": _get_skills_state_text(focused_unit, focus_mode, bool(context.get("show_enemy_skills", true)), pending_skill_id),
			"items_state_text": _get_items_state_text(focused_unit, focus_mode, bool(context.get("show_enemy_inventory", true)), pending_item_id)
		}
	}


func _build_character_section(unit) -> Dictionary:
	if unit == null:
		return {
			"title": BattleTexts.summary_unselected_character(),
			"portrait_texture": null,
			"tags": [],
			"hp_text": BattleTexts.format_hp(0, 0),
			"qi_text": BattleTexts.format_qi(false, 0, 0),
			"show_qi": false
		}

	return {
		"title": unit.display_name,
		"portrait_texture": BattleVisuals.get_portrait_texture_for_unit(unit),
		"tags": _build_status_tags(unit),
		"hp_text": BattleTexts.format_hp(unit.hp, unit.max_hp),
		"qi_text": BattleTexts.format_qi(unit.uses_qi, unit.qi, unit.max_qi),
		"show_qi": unit.uses_qi
	}


func _build_battle_info_section(
	context: Dictionary,
	focused_unit,
	active_unit,
	phase_id: String,
	pending_skill_id: String,
	pending_item_id: String,
	focus_mode: String,
	interaction_feedback: String
) -> Dictionary:
	var selected_cell: Vector2i = context.get("selected_cell", Vector2i(-1, -1))
	var display_unit = focused_unit if focused_unit != null else active_unit
	return {
		"selected_cell_text": _build_selected_cell_text(selected_cell),
		"target_text": _build_target_text(focused_unit, active_unit, pending_skill_id, pending_item_id, selected_cell),
		"action_text": _build_context_action_text(focused_unit, active_unit, phase_id, pending_skill_id, pending_item_id, interaction_feedback),
		"facing_hint_text": _build_facing_hint_text(display_unit, focus_mode),
		"facing_id": display_unit.get_facing_id() if display_unit != null else "none",
		"facing_enabled": focus_mode == "controllable"
	}


func _build_status_tags(unit) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	if unit == null:
		return entries
	var stance_id := String(unit.current_stance)
	entries.append({
		"id": "stance:%s" % stance_id,
		"text": BattleVisuals.get_stance_tag_text(stance_id),
		"kind": "stance",
		"description": BattleVisuals.get_stance_description(stance_id),
		"icon_texture": BattleVisuals.get_stance_icon(stance_id)
	})
	for status_id in unit.statuses.keys():
		var payload: Dictionary = unit.statuses[status_id]
		var stacks := int(payload.get("stacks", 0))
		var status_id_text := String(status_id)
		var kind := "buff" if status_id_text == "yinren" else "debuff"
		entries.append({
			"id": status_id_text,
			"text": BattleVisuals.get_status_tag_text(status_id_text, stacks),
			"kind": kind,
			"description": BattleVisuals.get_status_description(status_id_text, stacks),
			"icon_texture": BattleVisuals.get_tag_texture(kind)
		})
	return entries


func _build_system_action_entries(
	context: Dictionary,
	active_unit,
	pending_skill_id: String,
	pending_item_id: String,
	focus_mode: String
) -> Dictionary:
	var entries := {
		"move": {"text": BattleTexts.button_label("move"), "disabled": true, "selected": false, "button_role": "skill"},
		"qinggong": {"text": BattleTexts.button_label("qinggong"), "disabled": true, "selected": false, "button_role": "skill"},
		"skip_move": {"text": BattleTexts.button_label("skip_move"), "disabled": true, "selected": false, "button_role": "skill"},
		"end_turn": {"text": BattleTexts.button_label("end_turn"), "disabled": true, "selected": false, "button_role": "end_turn"}
	}
	if active_unit == null:
		return entries

	var all_units: Array = context.get("all_units", [])
	var controllable := focus_mode == "controllable"
	var has_pending_target := _has_pending_target_selection(pending_skill_id, pending_item_id)
	var move_skill_id := _get_move_skill_id(active_unit)
	var qinggong_skill: Dictionary = _skill_system.get_skill(move_skill_id)

	entries["move"]["selected"] = controllable and not _action_system.is_move_phase_done(active_unit) and not has_pending_target
	entries["move"]["disabled"] = not controllable or _action_system.is_move_phase_done(active_unit) or not _has_normal_move_tiles(active_unit)

	if not qinggong_skill.is_empty():
		entries["qinggong"]["text"] = BattleTexts.skill_name(qinggong_skill)
		entries["qinggong"]["icon_path"] = qinggong_skill.get("icon_path", "")
		entries["qinggong"]["selected"] = pending_skill_id == move_skill_id

	entries["qinggong"]["disabled"] = not controllable or move_skill_id.is_empty() or not _skill_system.has_valid_target(active_unit, qinggong_skill, all_units)
	entries["skip_move"]["disabled"] = not controllable or _action_system.is_move_phase_done(active_unit) or has_pending_target
	entries["end_turn"]["disabled"] = not controllable or has_pending_target or bool(context.get("battle_over", false))
	return entries


func _build_skill_entries(context: Dictionary, unit, pending_skill_id: String, pending_item_id: String, focus_mode: String) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	if unit == null:
		return entries
	if unit.team == "enemy" and not bool(context.get("show_enemy_skills", true)):
		return [{
			"id": "hidden_enemy_skills",
			"text": BattleTexts.hidden_skills_text(),
			"disabled": true,
			"kind": "hidden",
			"button_role": "skill"
		}]

	var all_units: Array = context.get("all_units", [])
	var controllable := focus_mode == "controllable"
	for skill_id in unit.skills:
		var skill_def: Dictionary = _skill_system.get_skill(skill_id)
		if skill_def.is_empty() or String(skill_def.get("action_type", "")) == "move":
			continue
		var skill_name_text := BattleTexts.skill_name(skill_def)
		entries.append({
			"id": skill_id,
			"text": skill_name_text,
			"tooltip": String(skill_def.get("description", skill_name_text)),
			"disabled": not controllable or _has_pending_target_selection(pending_skill_id, pending_item_id) or not _action_system.can_use_action(unit) or not _skill_system.has_valid_target(unit, skill_def, all_units),
			"kind": String(skill_def.get("ui_group", "guard")),
			"icon_path": String(skill_def.get("icon_path", "")),
			"selected": pending_skill_id == skill_id,
			"button_role": "skill"
		})
	if entries.is_empty():
		entries.append({
			"id": "no_skill",
			"text": "暂无技能",
			"disabled": true,
			"kind": "hidden",
			"button_role": "skill"
		})
	return entries


func _build_item_entries(context: Dictionary, unit, pending_item_id: String, pending_skill_id: String, focus_mode: String) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	if unit == null:
		return entries
	if unit.team == "enemy" and not bool(context.get("show_enemy_inventory", true)):
		return [{
			"id": "hidden_enemy_inventory",
			"text": BattleTexts.hidden_inventory_text(),
			"disabled": true,
			"kind": "hidden",
			"button_role": "skill"
		}]

	var all_units: Array = context.get("all_units", [])
	var controllable := focus_mode == "controllable"
	for entry in unit.get_inventory_entries():
		var item_id := String(entry.get("item_id", ""))
		var item_def: Dictionary = _item_system.get_item(item_id)
		if item_def.is_empty():
			continue
		var item_name_text := BattleTexts.item_name(item_def)
		entries.append({
			"id": item_id,
			"text": "%s x%d" % [item_name_text, int(entry.get("quantity", 0))],
			"tooltip": String(item_def.get("description", item_name_text)),
			"disabled": not controllable or _has_pending_target_selection(pending_skill_id, pending_item_id) or not _action_system.can_use_action(unit) or not _item_system.has_valid_target(unit, item_def, all_units),
			"kind": "item",
			"icon_path": String(item_def.get("icon_path", "")),
			"selected": pending_item_id == item_id,
			"button_role": "skill"
		})
	if entries.is_empty():
		entries.append({
			"id": "no_item",
			"text": BattleTexts.no_items_text(),
			"disabled": true,
			"kind": "hidden",
			"button_role": "skill"
		})
	return entries


func _build_selected_cell_text(selected_cell: Vector2i) -> String:
	return BattleTexts.summary_selected_cell(selected_cell)


func _build_target_text(focused_unit, active_unit, pending_skill_id: String, pending_item_id: String, selected_cell: Vector2i) -> String:
	if not _has_pending_target_selection(pending_skill_id, pending_item_id):
		return BattleTexts.summary_target_none()
	if focused_unit != null and focused_unit != active_unit:
		return BattleTexts.summary_target_unit(focused_unit.display_name)
	if selected_cell != Vector2i(-1, -1):
		return BattleTexts.summary_target_cell(selected_cell)
	return BattleTexts.summary_target_pending()


func _build_context_action_text(
	focused_unit,
	active_unit,
	phase_id: String,
	pending_skill_id: String,
	pending_item_id: String,
	interaction_feedback: String
) -> String:
	if not interaction_feedback.is_empty():
		return interaction_feedback
	if focused_unit != null and active_unit != null and focused_unit != active_unit:
		return BattleTexts.summary_viewing_unit(focused_unit.display_name, active_unit.display_name)
	if not pending_skill_id.is_empty():
		var skill_def: Dictionary = _skill_system.get_skill(pending_skill_id)
		return BattleTexts.summary_skill_selected(BattleTexts.skill_name(skill_def))
	if not pending_item_id.is_empty():
		var item_def: Dictionary = _item_system.get_item(pending_item_id)
		return BattleTexts.summary_item_selected(BattleTexts.item_name(item_def))
	match phase_id:
		"waiting_move":
			return BattleTexts.summary_waiting_move()
		"waiting_action":
			return BattleTexts.summary_waiting_action()
		"waiting_target":
			return BattleTexts.summary_waiting_target()
		"waiting_end":
			return BattleTexts.summary_waiting_end()
		"enemy_turn":
			return BattleTexts.summary_enemy_turn()
		_:
			return BattleTexts.summary_loading()


func _build_facing_hint_text(unit, focus_mode: String) -> String:
	if unit == null:
		return BattleTexts.summary_facing_hint("none", false)
	return BattleTexts.summary_facing_hint(unit.get_facing_id(), focus_mode == "controllable")


func _get_focus_mode(unit, active_unit, can_player_act: bool) -> String:
	if unit == null:
		return "none"
	if unit.team == "enemy":
		return "readonly_enemy"
	if unit == active_unit and can_player_act:
		return "controllable"
	return "locked_ally"


func _get_skills_state_text(unit, focus_mode: String, show_enemy_skills: bool, pending_skill_id: String) -> String:
	if unit == null:
		return ""
	if unit.team == "enemy":
		return BattleTexts.skills_state_enemy(show_enemy_skills)
	if focus_mode == "locked_ally":
		return BattleTexts.skills_state_locked()
	if not pending_skill_id.is_empty():
		return BattleTexts.skills_state_selecting(BattleTexts.skill_name(_skill_system.get_skill(pending_skill_id)))
	return BattleTexts.skills_state_ready()


func _get_items_state_text(unit, focus_mode: String, show_enemy_inventory: bool, pending_item_id: String) -> String:
	if unit == null:
		return ""
	if unit.team == "enemy":
		return BattleTexts.items_state_enemy(show_enemy_inventory)
	if focus_mode == "locked_ally":
		return BattleTexts.items_state_locked()
	if not pending_item_id.is_empty():
		return BattleTexts.items_state_selecting(BattleTexts.item_name(_item_system.get_item(pending_item_id)))
	return BattleTexts.items_state_ready()


func _has_normal_move_tiles(unit) -> bool:
	if unit == null or not unit.is_alive() or not _action_system.can_move_normally(unit):
		return false
	return not _movement_system.get_reachable_cells(unit, _action_system.get_remaining_move(unit), "ground").is_empty()


func _get_move_skill_id(unit) -> String:
	if unit == null:
		return ""
	for skill_id in unit.skills:
		var skill_def: Dictionary = _skill_system.get_skill(skill_id)
		if not skill_def.is_empty() and String(skill_def.get("action_type", "")) == "move":
			return skill_id
	return ""


func _has_pending_target_selection(pending_skill_id: String, pending_item_id: String) -> bool:
	return not pending_skill_id.is_empty() or not pending_item_id.is_empty()
