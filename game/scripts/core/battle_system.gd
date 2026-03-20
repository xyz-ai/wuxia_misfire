extends Node2D
class_name BattleSystem

const BattleTexts = preload("res://scripts/core/battle_texts.gd")
const BattleVisuals = preload("res://scripts/ui/battle_visuals.gd")
const DataManagerScript = preload("res://scripts/data/data_manager.gd")
const BattleLoaderScript = preload("res://scripts/data/battle_loader.gd")
const FormationSystemScript = preload("res://scripts/systems/formation_system.gd")
const StanceSystemScript = preload("res://scripts/core/stance_system.gd")
const ResourceSystemScript = preload("res://scripts/core/resource_system.gd")
const ActionSystemScript = preload("res://scripts/core/action_system.gd")
const StatusSystemScript = preload("res://scripts/core/status_system.gd")
const MovementSystemScript = preload("res://scripts/core/movement_system.gd")
const CombatSystemScript = preload("res://scripts/core/combat_system.gd")
const SkillSystemScript = preload("res://scripts/systems/skill_system.gd")
const ItemSystemScript = preload("res://scripts/systems/item_system.gd")
const TurnManagerScript = preload("res://scripts/core/turn_manager.gd")
const BattleConditionSystemScript = preload("res://scripts/core/battle_condition_system.gd")
const AIEvaluatorScript = preload("res://scripts/ai/ai_evaluator.gd")
const AIControllerScript = preload("res://scripts/ai/ai_controller.gd")
const PlayerUnitScript = preload("res://scripts/entities/player_unit.gd")
const EnemyUnitScript = preload("res://scripts/entities/enemy_unit.gd")
const BattleHUDPresenterScript = preload("res://scripts/ui/battle_hud_presenter.gd")

signal unit_killed(context: Dictionary)
signal non_lethal_hit(context: Dictionary)
signal control_applied(context: Dictionary)
signal battle_result(context: Dictionary)

const BOARD_TOP_MARGIN := 18.0
const BOARD_SIDE_MARGIN := 16.0
const BOARD_BOTTOM_RESERVED := 174.0

@export var initial_battle_id := "battle_001"
@export var debug_click_trace := true

@onready var camera_2d: Camera2D = $Camera2D
@onready var background_sprite = $BackgroundLayer/BackgroundSprite
@onready var grid_manager: GridManager = $BoardRoot
@onready var player_units_root: Node2D = $BoardRoot/UnitLayer/PlayerUnits
@onready var enemy_units_root: Node2D = $BoardRoot/UnitLayer/EnemyUnits
@onready var battle_meta_panel: PanelContainer = $CanvasLayer/UIRoot/SafeArea/MainVBox/TopRow/BattleMetaInfo
@onready var battle_title_label: Label = $CanvasLayer/UIRoot/SafeArea/MainVBox/TopRow/BattleMetaInfo/MetaMargin/MetaVBox/TitleLabel
@onready var battle_note_label: Label = $CanvasLayer/UIRoot/SafeArea/MainVBox/TopRow/BattleMetaInfo/MetaMargin/MetaVBox/NoteLabel
@onready var top_info_panel: PanelContainer = $CanvasLayer/UIRoot/SafeArea/MainVBox/TopRow/BattleTopInfo
@onready var round_label: Label = $CanvasLayer/UIRoot/SafeArea/MainVBox/TopRow/BattleTopInfo/Margin/VBox/RoundLabel
@onready var current_unit_label: Label = $CanvasLayer/UIRoot/SafeArea/MainVBox/TopRow/BattleTopInfo/Margin/VBox/CurrentUnitLabel
@onready var phase_label: Label = $CanvasLayer/UIRoot/SafeArea/MainVBox/TopRow/BattleTopInfo/Margin/VBox/PhaseLabel
@onready var prompt_label: Label = $CanvasLayer/UIRoot/SafeArea/MainVBox/TopRow/BattleTopInfo/Margin/VBox/PromptLabel
@onready var battle_hud: Control = $CanvasLayer/UIRoot/SafeArea/MainVBox/BottomDock/BottomHUD

var runtime_rules: Dictionary = {}
var data_manager
var battle_loader
var formation_system
var stance_system
var resource_system
var action_system
var status_system
var movement_system
var combat_system
var skill_system
var item_system
var turn_manager
var battle_condition_system
var ai_evaluator
var ai_controller
var battle_hud_presenter

var battle_config: Dictionary = {}
var player_units: Array = []
var enemy_units: Array = []
var all_units: Array = []

var selected_unit = null
var focused_unit = null
var active_unit = null
var hovered_unit = null
var interaction_feedback_text := ""
var current_move_preview_cells: Array[Vector2i] = []
var current_qinggong_preview := {"valid": [], "invalid": []}
var current_target_preview_cells: Array[Vector2i] = []

var battle_over := false
var input_locked := false
var pending_skill_id := ""
var pending_item_id := ""
var ai_difficulty := "simple"
var current_battle_id := ""
var battle_result_id := ""
var show_enemy_skills := true
var show_enemy_inventory := true

func _ready() -> void:
	_connect_ui()
	_apply_ui_theme()
	start_battle(initial_battle_id)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_SIZE_CHANGED and is_node_ready():
		call_deferred("_layout_battlefield")


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_update_hovered_unit(event.position)

func start_battle(battle_id: String) -> void:
	current_battle_id = battle_id
	battle_over = false
	input_locked = true
	pending_skill_id = ""
	pending_item_id = ""
	battle_result_id = ""
	show_enemy_skills = true
	show_enemy_inventory = true
	interaction_feedback_text = ""
	current_move_preview_cells.clear()
	current_qinggong_preview = {"valid": [], "invalid": []}
	current_target_preview_cells.clear()
	_clear_units()
	_build_runtime_services()
	battle_config = battle_loader.load_battle_config(battle_id)
	if battle_config.has("error"):
		battle_over = true
		update_ui()
		return
	battle_condition_system.configure(battle_config)
	ai_difficulty = String(battle_config.get("ai_difficulty", "simple"))
	_apply_enemy_info_flags()
	_apply_battle_meta()
	movement_system.configure_board(battle_config.get("board", {}), battle_config.get("terrain", []))
	var board: Dictionary = battle_config.get("board", {})
	grid_manager.configure_board(int(board.get("columns", 8)), int(board.get("rows", 8)), movement_system.get_terrain_map(), runtime_rules.get("terrain_types", {}))
	_layout_battlefield()
	var formation_result: Dictionary = formation_system.resolve_battle_formations(battle_config)
	if formation_result.has("error"):
		battle_over = true
		update_ui()
		return
	_spawn_units(formation_result)
	battle_condition_system.capture_initial_units(all_units)
	movement_system.register_units(all_units)
	active_unit = turn_manager.begin_battle(player_units, enemy_units)
	_after_turn_advanced()

func get_all_units() -> Array:
	var alive: Array = []
	for unit in all_units:
		if unit != null and unit.is_alive():
			alive.append(unit)
	return alive

func get_player_units() -> Array:
	var alive: Array = []
	for unit in player_units:
		if unit != null and unit.is_alive():
			alive.append(unit)
	return alive

func get_enemy_units() -> Array:
	var alive: Array = []
	for unit in enemy_units:
		if unit != null and unit.is_alive():
			alive.append(unit)
	return alive

func get_ai_difficulty() -> String:
	return ai_difficulty

func _connect_ui() -> void:
	battle_hud.system_action_requested.connect(_on_system_action_requested)
	battle_hud.skill_requested.connect(_on_skill_requested)
	battle_hud.item_requested.connect(_on_item_requested)
	battle_hud.facing_requested.connect(_on_facing_requested)

func _apply_ui_theme() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.06, 0.05, 0.74)
	style.border_color = Color(0.36, 0.31, 0.27, 0.46)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_left = 12
	style.corner_radius_bottom_right = 12
	battle_meta_panel.add_theme_stylebox_override("panel", style)
	top_info_panel.add_theme_stylebox_override("panel", style)
	_apply_label_theme(battle_title_label, 18, "primary", 2)
	_apply_label_theme(battle_note_label, 12, "body", 1)
	for label in [round_label, current_unit_label, phase_label]:
		_apply_label_theme(label, 13, "primary", 1)
	_apply_label_theme(prompt_label, 12, "highlight", 1)


func _apply_label_theme(label: Label, font_size: int, color_role: String, outline_size: int) -> void:
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", BattleVisuals.get_text_color(color_role))
	label.add_theme_color_override("font_outline_color", BattleVisuals.get_outline_color())
	label.add_theme_constant_override("outline_size", outline_size)

func _build_runtime_services() -> void:
	data_manager = DataManagerScript.new()
	battle_loader = BattleLoaderScript.new(data_manager)
	runtime_rules = data_manager.get_rules()
	formation_system = FormationSystemScript.new(data_manager)
	stance_system = StanceSystemScript.new(runtime_rules)
	resource_system = ResourceSystemScript.new(runtime_rules)
	action_system = ActionSystemScript.new(runtime_rules)
	status_system = StatusSystemScript.new(runtime_rules)
	movement_system = MovementSystemScript.new(runtime_rules)
	combat_system = CombatSystemScript.new(runtime_rules, stance_system, status_system, action_system)
	skill_system = SkillSystemScript.new(data_manager, movement_system, action_system, resource_system, stance_system, status_system, combat_system)
	item_system = ItemSystemScript.new(data_manager, action_system, resource_system, status_system)
	turn_manager = TurnManagerScript.new(action_system, resource_system, status_system)
	battle_condition_system = BattleConditionSystemScript.new()
	ai_evaluator = AIEvaluatorScript.new(skill_system, movement_system, stance_system, combat_system)
	ai_controller = AIControllerScript.new(skill_system, movement_system, action_system, ai_evaluator)
	battle_hud_presenter = BattleHUDPresenterScript.new(skill_system, item_system, action_system, movement_system)

func _apply_enemy_info_flags() -> void:
	var by_difficulty: Dictionary = runtime_rules.get("enemy_info_visibility_by_difficulty", {})
	var visibility: Dictionary = by_difficulty.get(ai_difficulty, by_difficulty.get("normal", {}))
	show_enemy_skills = bool(visibility.get("show_enemy_skills", true))
	show_enemy_inventory = bool(visibility.get("show_enemy_inventory", true))

func _spawn_units(formation_result: Dictionary) -> void:
	player_units.clear()
	enemy_units.clear()
	all_units.clear()
	for spawn_data in formation_result.get("player_spawns", []):
		var player_unit = _spawn_unit_from_entry(spawn_data, "player")
		if player_unit != null:
			player_units.append(player_unit)
			all_units.append(player_unit)
	for spawn_data in formation_result.get("enemy_spawns", []):
		var enemy_unit = _spawn_unit_from_entry(spawn_data, "enemy")
		if enemy_unit != null:
			enemy_units.append(enemy_unit)
			all_units.append(enemy_unit)

func _spawn_unit_from_entry(spawn_data: Dictionary, team_name: String):
	var template_id := String(spawn_data.get("template_id", ""))
	var template_data: Dictionary = data_manager.get_unit_template(template_id)
	if template_data.is_empty():
		return null
	var unit = PlayerUnitScript.new() if team_name == "player" else EnemyUnitScript.new()
	unit.setup_from_data(String(spawn_data.get("instance_id", template_id)), template_data, spawn_data, team_name, _get_team_facing(team_name))
	resource_system.initialize_unit(unit)
	var spawn_cell: Vector2i = _array_to_cell(spawn_data.get("cell", []))
	unit.set_board_visual_metrics(grid_manager.cell_size)
	unit.set_grid_cell(spawn_cell, grid_manager.grid_to_world(spawn_cell))
	if team_name == "player":
		player_units_root.add_child(unit)
	else:
		enemy_units_root.add_child(unit)
	return unit

func _get_team_facing(team_name: String) -> Vector2i:
	return _array_to_cell(runtime_rules.get("facing", {}).get(team_name, [1, 0]))

func execute_skill_for_unit(unit, skill_id: String, target) -> bool:
	if unit == null or not unit.is_alive():
		return false
	var start_cell: Vector2i = unit.grid_position
	var result: Dictionary = skill_system.execute_skill(unit, skill_id, target, all_units)
	if not bool(result.get("success", false)):
		refresh_highlights()
		update_ui()
		return false
	pending_skill_id = ""
	pending_item_id = ""
	var movement_result: Dictionary = result.get("movement", {})
	if not movement_result.is_empty():
		_face_unit_between(unit, start_cell, movement_result.get("target", unit.grid_position))
		_sync_unit_visual(unit)
	else:
		_face_unit_to_target(unit, target)
	_process_damage_events(result.get("damage_events", []))
	_process_status_events(result.get("status_events", []))
	_cleanup_dead_units()
	if _check_battle_end():
		refresh_highlights()
		update_ui()
		return true
	if unit == active_unit and unit.is_alive():
		_set_focused_unit(unit)
	refresh_highlights()
	update_ui()
	return true

func execute_item_for_unit(unit, item_id: String, target) -> bool:
	if unit == null or not unit.is_alive():
		return false
	var result: Dictionary = item_system.execute_item(unit, item_id, target, all_units)
	if not bool(result.get("success", false)):
		refresh_highlights()
		update_ui()
		return false
	pending_skill_id = ""
	pending_item_id = ""
	_process_status_events(result.get("status_events", []))
	_cleanup_dead_units()
	if _check_battle_end():
		refresh_highlights()
		update_ui()
		return true
	if unit == active_unit and unit.is_alive():
		_set_focused_unit(unit)
	refresh_highlights()
	update_ui()
	return true

func move_unit_for_ai(unit, target_cell: Vector2i) -> bool:
	return bool(_execute_normal_move(unit, target_cell).get("success", false))

func skip_move_phase_for_ai(unit) -> bool:
	if unit == null or not unit.is_alive() or action_system.is_move_phase_done(unit):
		return false
	action_system.advance_to_action_phase(unit)
	refresh_highlights()
	update_ui()
	return true

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton) or not event.pressed:
		return
	if event.button_index == MOUSE_BUTTON_RIGHT:
		if _has_pending_target_selection():
			pending_skill_id = ""
			pending_item_id = ""
			_clear_interaction_feedback()
			_debug_click_trace("CLICK_CANCEL", {
				"phase": _get_phase_id(),
				"actor": _debug_unit_name(active_unit),
				"reason": "cancelled"
			})
			refresh_highlights()
			update_ui()
		return
	if event.button_index != MOUSE_BUTTON_LEFT:
		return
	var click_context := _build_battle_left_click_context(event.position)
	var result := handle_battle_left_click(click_context)
	_trace_left_click_decision(click_context, result)


func handle_battle_left_click(click_context: Dictionary) -> Dictionary:
	var targeting_mode := String(click_context.get("targeting_mode", "none"))
	if targeting_mode != "none":
		return _handle_pending_selection_click(click_context)
	if click_context.get("clicked_unit", null) != null:
		return _handle_click_on_unit(click_context)
	if bool(click_context.get("has_valid_cell", false)):
		return _handle_click_on_board_cell(click_context)
	return {
		"handled": false,
		"decision": "IGNORE",
		"success": false,
		"reason": "out_of_bounds",
		"show_feedback": false
	}


func _build_battle_left_click_context(screen_position: Vector2) -> Dictionary:
	var world_position := _screen_to_world(screen_position)
	var clicked_cell: Vector2i = grid_manager.world_to_cell(world_position)
	var has_valid_cell := grid_manager.is_in_bounds(clicked_cell)
	var clicked_unit = _get_unit_under_world_position(world_position, true, clicked_cell)
	return {
		"screen_pos": screen_position,
		"world_pos": world_position,
		"clicked_unit": clicked_unit,
		"clicked_cell": clicked_cell,
		"has_valid_cell": has_valid_cell,
		"phase": _get_phase_id(),
		"targeting_mode": _get_targeting_mode(),
		"pending_skill_id": pending_skill_id,
		"pending_item_id": pending_item_id,
		"actor": active_unit,
		"focused_unit": focused_unit,
		"move_preview": current_move_preview_cells.duplicate(),
		"qinggong_preview": {
			"valid": current_qinggong_preview.get("valid", []).duplicate(),
			"invalid": current_qinggong_preview.get("invalid", []).duplicate()
		},
		"target_preview": current_target_preview_cells.duplicate()
	}


func _build_click_result(
	decision: String,
	success: bool,
	reason: String = "",
	handled: bool = true,
	show_feedback: bool = false
) -> Dictionary:
	return {
		"handled": handled,
		"decision": decision,
		"success": success,
		"reason": reason,
		"show_feedback": show_feedback
	}


func _handle_pending_selection_click(click_context: Dictionary) -> Dictionary:
	var actor = click_context.get("actor", null)
	var clicked_unit = click_context.get("clicked_unit", null)
	var clicked_cell: Vector2i = click_context.get("clicked_cell", Vector2i(-1, -1))
	var has_valid_cell := bool(click_context.get("has_valid_cell", false))
	var targeting_mode := String(click_context.get("targeting_mode", "none"))

	if battle_over:
		_set_interaction_feedback("battle_over")
		update_ui()
		return _build_click_result("REJECT", false, "battle_over", true, true)
	if not _can_player_act() or actor == null or not actor.is_alive():
		_set_interaction_feedback("wrong_phase")
		update_ui()
		return _build_click_result("REJECT", false, "wrong_phase", true, true)

	if targeting_mode == "qinggong":
		if not has_valid_cell:
			_set_interaction_feedback("out_of_bounds")
			update_ui()
			return _build_click_result("MOVE_QINGGONG", false, "out_of_bounds", true, true)
		var move_validation := _validate_qinggong_click(actor, clicked_cell, click_context)
		if not bool(move_validation.get("ok", false)):
			_set_interaction_feedback(String(move_validation.get("reason", "unknown")))
			update_ui()
			return _build_click_result("MOVE_QINGGONG", false, String(move_validation.get("reason", "unknown")), true, true)
		if execute_skill_for_unit(actor, pending_skill_id, clicked_cell):
			_clear_interaction_feedback()
			_after_player_action()
			return _build_click_result("MOVE_QINGGONG", true, "ok")
		_set_interaction_feedback("invalid_target")
		update_ui()
		return _build_click_result("MOVE_QINGGONG", false, "invalid_target", true, true)

	if not pending_skill_id.is_empty():
		var skill_def: Dictionary = skill_system.get_skill(pending_skill_id)
		if skill_def.is_empty():
			pending_skill_id = ""
			_set_interaction_feedback("invalid_target")
			update_ui()
			return _build_click_result("REJECT", false, "invalid_target", true, true)
		var target_type := String(skill_def.get("targeting", {}).get("type", "self"))
		var skill_target = null
		match target_type:
			"self":
				skill_target = actor
			"cell":
				if not has_valid_cell:
					_set_interaction_feedback("out_of_bounds")
					update_ui()
					return _build_click_result("CONFIRM_TARGET", false, "out_of_bounds", true, true)
				if not _cell_in_cells(current_target_preview_cells, clicked_cell):
					_set_interaction_feedback("not_in_target_range")
					update_ui()
					return _build_click_result("CONFIRM_TARGET", false, "not_in_target_range", true, true)
				skill_target = clicked_cell
			"unit":
				if clicked_unit == null:
					_set_interaction_feedback("invalid_target")
					update_ui()
					return _build_click_result("CONFIRM_TARGET", false, "invalid_target", true, true)
				if not _cell_in_cells(current_target_preview_cells, clicked_unit.grid_position):
					_set_interaction_feedback("not_in_target_range")
					update_ui()
					return _build_click_result("CONFIRM_TARGET", false, "not_in_target_range", true, true)
				skill_target = clicked_unit
			_:
				skill_target = null
		if skill_target == null:
			_set_interaction_feedback("invalid_target")
			update_ui()
			return _build_click_result("CONFIRM_TARGET", false, "invalid_target", true, true)
		if execute_skill_for_unit(actor, pending_skill_id, skill_target):
			_clear_interaction_feedback()
			_after_player_action()
			return _build_click_result("CONFIRM_TARGET", true, "ok")
		_set_interaction_feedback("invalid_target")
		update_ui()
		return _build_click_result("CONFIRM_TARGET", false, "invalid_target", true, true)

	if not pending_item_id.is_empty():
		var item_def: Dictionary = item_system.get_item(pending_item_id)
		if item_def.is_empty():
			pending_item_id = ""
			_set_interaction_feedback("invalid_target")
			update_ui()
			return _build_click_result("REJECT", false, "invalid_target", true, true)
		var target_type := String(item_def.get("targeting", {}).get("type", "self"))
		var item_target = actor if target_type == "self" else clicked_unit
		if item_target == null:
			_set_interaction_feedback("invalid_target")
			update_ui()
			return _build_click_result("CONFIRM_TARGET", false, "invalid_target", true, true)
		if target_type == "unit" and not _cell_in_cells(current_target_preview_cells, item_target.grid_position):
			_set_interaction_feedback("not_in_target_range")
			update_ui()
			return _build_click_result("CONFIRM_TARGET", false, "not_in_target_range", true, true)
		if execute_item_for_unit(actor, pending_item_id, item_target):
			_clear_interaction_feedback()
			_after_player_action()
			return _build_click_result("CONFIRM_TARGET", true, "ok")
		_set_interaction_feedback("invalid_target")
		update_ui()
		return _build_click_result("CONFIRM_TARGET", false, "invalid_target", true, true)

	_set_interaction_feedback("no_pending_target")
	update_ui()
	return _build_click_result("REJECT", false, "no_pending_target", true, true)


func _handle_click_on_unit(click_context: Dictionary) -> Dictionary:
	var clicked_unit = click_context.get("clicked_unit", null)
	if clicked_unit == null:
		return _build_click_result("IGNORE", false, "", false, false)

	var decision := "FOCUS_ENEMY"
	if clicked_unit == active_unit:
		decision = "FOCUS_ACTIVE"
	elif String(clicked_unit.team) == "player":
		decision = "FOCUS_ALLY"

	_set_focused_unit(clicked_unit)
	_clear_interaction_feedback()
	refresh_highlights()
	update_ui()
	return _build_click_result(decision, true, "ok")


func _handle_click_on_board_cell(click_context: Dictionary) -> Dictionary:
	var phase := String(click_context.get("phase", "loading"))
	var clicked_cell: Vector2i = click_context.get("clicked_cell", Vector2i(-1, -1))
	var actor = click_context.get("actor", null)

	match phase:
		"waiting_move":
			var validation := _validate_ground_move_click(actor, clicked_cell, click_context)
			if not bool(validation.get("ok", false)):
				_set_interaction_feedback(String(validation.get("reason", "unknown")))
				update_ui()
				return _build_click_result("MOVE_NORMAL", false, String(validation.get("reason", "unknown")), true, true)
			var move_result := _execute_normal_move(actor, clicked_cell)
			if bool(move_result.get("success", false)):
				_clear_interaction_feedback()
				return _build_click_result("MOVE_NORMAL", true, "ok")
			_set_interaction_feedback(String(move_result.get("reason", "unknown")))
			update_ui()
			return _build_click_result("MOVE_NORMAL", false, String(move_result.get("reason", "unknown")), true, true)
		"waiting_action", "waiting_end":
			if active_unit != null:
				_set_focused_unit(active_unit)
				_clear_interaction_feedback()
				refresh_highlights()
				update_ui()
				return _build_click_result("RETURN_TO_ACTIVE", true, "ok")
			return _build_click_result("IGNORE", false, "no_active_unit", true, false)
		_:
			_set_interaction_feedback("wrong_phase")
			update_ui()
			return _build_click_result("REJECT", false, "wrong_phase", true, true)


func _validate_ground_move_click(unit, target_cell: Vector2i, click_context: Dictionary = {}) -> Dictionary:
	if battle_over:
		return {"ok": false, "reason": "battle_over", "in_preview": false}
	if unit == null or not unit.is_alive():
		return {"ok": false, "reason": "no_active_unit", "in_preview": false}
	if String(click_context.get("phase", _get_phase_id())) != "waiting_move":
		return {"ok": false, "reason": "wrong_phase", "in_preview": false}
	if not _can_player_act():
		return {"ok": false, "reason": "wrong_phase", "in_preview": false}
	if not grid_manager.is_in_bounds(target_cell):
		return {"ok": false, "reason": "out_of_bounds", "in_preview": false}
	if target_cell == unit.grid_position:
		return {"ok": false, "reason": "same_cell", "in_preview": false}
	if not action_system.can_move_normally(unit):
		return {"ok": false, "reason": "no_move_budget", "in_preview": false}
	if movement_system.is_cell_occupied(target_cell, unit):
		return {"ok": false, "reason": "occupied", "in_preview": false}
	var in_preview := _cell_in_cells(current_move_preview_cells, target_cell)
	if not in_preview:
		return {"ok": false, "reason": "not_in_move_range", "in_preview": false}
	var validation: Dictionary = movement_system.validate_move_destination(unit, target_cell, action_system.get_remaining_move(unit), "ground")
	validation["in_preview"] = in_preview
	return validation


func _validate_qinggong_click(unit, target_cell: Vector2i, click_context: Dictionary = {}) -> Dictionary:
	if battle_over:
		return {"ok": false, "reason": "battle_over", "in_preview": false}
	if unit == null or not unit.is_alive():
		return {"ok": false, "reason": "no_active_unit", "in_preview": false}
	if String(click_context.get("targeting_mode", _get_targeting_mode())) != "qinggong":
		return {"ok": false, "reason": "no_pending_qinggong", "in_preview": false}
	if not _can_player_act():
		return {"ok": false, "reason": "wrong_phase", "in_preview": false}
	if not grid_manager.is_in_bounds(target_cell):
		return {"ok": false, "reason": "out_of_bounds", "in_preview": false}
	if movement_system.is_cell_occupied(target_cell, unit):
		return {"ok": false, "reason": "occupied", "in_preview": false}
	var preview_valid: Array = current_qinggong_preview.get("valid", [])
	var preview_invalid: Array = current_qinggong_preview.get("invalid", [])
	var in_preview := _cell_in_cells(preview_valid, target_cell)
	if not in_preview:
		return {
			"ok": false,
			"reason": "enemy_back_landing" if _cell_in_cells(preview_invalid, target_cell) else "not_in_qinggong_range",
			"in_preview": false
		}
	var skill_def: Dictionary = skill_system.get_skill(pending_skill_id)
	var range_limit: int = skill_system.get_skill_range(unit, skill_def)
	var validation: Dictionary = movement_system.validate_move_destination(unit, target_cell, range_limit, "qinggong")
	validation["in_preview"] = in_preview
	return validation


func _execute_normal_move(unit, target_cell: Vector2i) -> Dictionary:
	if unit == null or not unit.is_alive():
		return {"success": false, "reason": "no_active_unit"}
	if target_cell == unit.grid_position:
		return {"success": false, "reason": "same_cell"}
	if not action_system.can_move_normally(unit):
		return {"success": false, "reason": "no_move_budget"}
	var start_cell: Vector2i = unit.grid_position
	var move_result: Dictionary = movement_system.apply_move(unit, target_cell, "ground", action_system.get_remaining_move(unit))
	if not bool(move_result.get("success", false)):
		return {"success": false, "reason": String(move_result.get("reason", "unreachable"))}
	action_system.record_normal_move(unit, int(move_result.get("distance", 0)))
	pending_skill_id = ""
	pending_item_id = ""
	_face_unit_between(unit, start_cell, target_cell)
	_sync_unit_visual(unit)
	if unit == active_unit:
		_set_focused_unit(unit)
	if _check_battle_end():
		refresh_highlights()
		update_ui()
		return {"success": true, "reason": "ok"}
	refresh_highlights()
	update_ui()
	return {
		"success": true,
		"reason": "ok",
		"distance": int(move_result.get("distance", 0)),
		"target": target_cell
	}

func _after_player_action() -> void:
	if not battle_over and active_unit != null and active_unit.is_alive():
		_set_focused_unit(active_unit)
	_clear_interaction_feedback()
	refresh_highlights()
	update_ui()

func _end_active_unit_turn() -> void:
	if active_unit == null or battle_over:
		return
	pending_skill_id = ""
	pending_item_id = ""
	_clear_interaction_feedback()
	turn_manager.end_current_turn()
	active_unit = turn_manager.advance_to_next_unit()
	_after_turn_advanced()

func _after_turn_advanced() -> void:
	if _check_battle_end():
		refresh_highlights()
		update_ui()
		return
	if active_unit == null:
		_set_focused_unit(null)
		refresh_highlights()
		update_ui()
		return
	pending_skill_id = ""
	pending_item_id = ""
	_clear_interaction_feedback()
	_set_focused_unit(active_unit)
	if active_unit.team == "player":
		input_locked = false
	else:
		input_locked = true
	refresh_highlights()
	update_ui()
	if input_locked:
		call_deferred("_run_enemy_turns")

func _run_enemy_turns() -> void:
	while not battle_over and active_unit != null and active_unit.team == "enemy":
		_set_focused_unit(active_unit)
		refresh_highlights()
		update_ui()
		await get_tree().create_timer(0.30).timeout
		ai_controller.take_turn(active_unit, self)
		if battle_over:
			return
		turn_manager.end_current_turn()
		active_unit = turn_manager.advance_to_next_unit()
	_after_turn_advanced()

func _process_damage_events(damage_events: Array) -> void:
	for event_data in damage_events:
		if not (event_data is Dictionary):
			continue
		if bool(event_data.get("killed", false)):
			emit_signal("unit_killed", event_data)
		else:
			emit_signal("non_lethal_hit", event_data)

func _process_status_events(status_events: Array) -> void:
	for event_data in status_events:
		if event_data is Dictionary and bool(event_data.get("is_control", false)):
			emit_signal("control_applied", event_data)

func _cleanup_dead_units() -> void:
	for unit in all_units.duplicate():
		if unit == null or unit.is_alive():
			continue
		if selected_unit == unit:
			selected_unit = null
		if focused_unit == unit:
			focused_unit = null
		if active_unit == unit:
			active_unit = null
		if hovered_unit == unit:
			hovered_unit = null
		player_units.erase(unit)
		enemy_units.erase(unit)
		all_units.erase(unit)
		unit.queue_free()
	movement_system.register_units(all_units)
	if focused_unit == null and active_unit != null and active_unit.is_alive():
		_set_focused_unit(active_unit)

func _check_battle_end() -> bool:
	if battle_result_id != "":
		return true
	var result := String(battle_condition_system.resolve_battle_result(_build_battle_condition_state()))
	if not result.is_empty():
		battle_over = true
		input_locked = true
		battle_result_id = result
		grid_manager.clear_highlights()
		emit_signal("battle_result", {"result": result, "battle_id": current_battle_id})
		return true
	return false

func _has_action_options(unit) -> bool:
	if unit == null or not unit.is_alive() or not action_system.can_use_action(unit):
		return false
	for skill_id in unit.skills:
		var skill_def: Dictionary = skill_system.get_skill(skill_id)
		if not skill_def.is_empty() and String(skill_def.get("action_type", "")) != "move" and skill_system.has_valid_target(unit, skill_def, all_units):
			return true
	return false

func _has_item_options(unit) -> bool:
	if unit == null or not unit.is_alive() or not action_system.can_use_action(unit):
		return false
	for entry in unit.get_inventory_entries():
		var item_def: Dictionary = item_system.get_item(String(entry.get("item_id", "")))
		if not item_def.is_empty() and item_system.has_valid_target(unit, item_def, all_units):
			return true
	return false

func _has_normal_move_tiles(unit) -> bool:
	if unit == null or not unit.is_alive() or not action_system.can_move_normally(unit):
		return false
	return not movement_system.get_reachable_cells(unit, action_system.get_remaining_move(unit), "ground").is_empty()

func _get_attack_preview_cells(unit) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	if unit == null or not unit.is_alive() or not action_system.can_use_action(unit):
		return cells
	var lookup: Dictionary = {}
	for skill_id in unit.skills:
		var skill_def: Dictionary = skill_system.get_skill(skill_id)
		if skill_def.is_empty() or String(skill_def.get("action_type", "")) == "move":
			continue
		for target in skill_system.get_valid_targets(unit, skill_def, all_units):
			if target == null or not (target is Node):
				continue
			var cell: Vector2i = target.grid_position
			var key := "%d,%d" % [cell.x, cell.y]
			if not lookup.has(key):
				lookup[key] = true
				cells.append(cell)
	return cells

func _get_qinggong_preview(unit) -> Dictionary:
	var move_skill_id := _get_move_skill_id(unit)
	if unit == null or move_skill_id.is_empty():
		return {"valid": [], "invalid": []}
	var move_skill: Dictionary = skill_system.get_skill(move_skill_id)
	if move_skill.is_empty():
		return {"valid": [], "invalid": []}
	return movement_system.get_qinggong_target_map(unit, skill_system.get_skill_range(unit, move_skill))


func _update_hovered_unit(screen_position: Vector2) -> void:
	if grid_manager == null or movement_system == null:
		return
	var world_position := _screen_to_world(screen_position)
	var next_unit = _get_unit_under_world_position(world_position, false)
	_set_hovered_unit(next_unit)


func _set_hovered_unit(unit) -> void:
	if hovered_unit == unit:
		return
	if hovered_unit != null:
		hovered_unit.set_hovered(false)
	hovered_unit = unit
	if hovered_unit != null:
		hovered_unit.set_hovered(true)


func _set_focused_unit(unit = null) -> void:
	if selected_unit != null:
		selected_unit.set_selected(false)
	selected_unit = unit
	focused_unit = unit
	if selected_unit != null:
		selected_unit.set_selected(true)
		grid_manager.set_selected_cell(selected_unit.grid_position)
	else:
		grid_manager.set_selected_cell(Vector2i(-1, -1))


func _screen_to_world(screen_position: Vector2) -> Vector2:
	return get_viewport().get_canvas_transform().affine_inverse() * screen_position


func _get_unit_under_world_position(world_position: Vector2, use_click_hit: bool = false, resolved_cell: Vector2i = Vector2i(-1, -1)):
	var hit_unit = null
	var best_score := -INF
	for unit in all_units:
		if unit == null or not unit.is_alive():
			continue
		var did_hit := false
		if use_click_hit and unit.has_method("hit_test_click_world_point"):
			did_hit = unit.hit_test_click_world_point(world_position)
		elif not use_click_hit and unit.has_method("hit_test_hover_world_point"):
			did_hit = unit.hit_test_hover_world_point(world_position)
		elif unit.has_method("hit_test_world_point"):
			did_hit = unit.hit_test_world_point(world_position)
		if did_hit:
			var score: float = float(unit.z_index) * 10000.0 - unit.global_position.distance_squared_to(world_position)
			if score > best_score:
				best_score = score
				hit_unit = unit
	if hit_unit != null:
		return hit_unit
	var hovered_cell := resolved_cell if resolved_cell != Vector2i(-1, -1) else grid_manager.world_to_cell(world_position)
	if grid_manager.is_in_bounds(hovered_cell):
		return movement_system.get_unit_at(hovered_cell)
	return null


func _cell_in_highlight(kind: String, cell: Vector2i) -> bool:
	return _cell_in_cells(grid_manager.highlights.get(kind, []), cell)


func _cell_in_cells(cells: Array, cell: Vector2i) -> bool:
	for candidate in cells:
		if candidate == cell:
			return true
	return false


func _debug_click_trace(kind: String, payload: Dictionary) -> void:
	if not debug_click_trace:
		return
	var preferred_keys := [
		"phase", "targeting_mode", "actor", "focused", "mouse", "world", "cell", "actor_cell",
		"clicked_unit", "clicked_team", "hovered_unit", "focused_before", "focused_after",
		"in_move_range", "in_qinggong_range", "in_target_range", "can_move", "decision", "success", "reason"
	]
	var parts: Array[String] = ["[%s]" % kind]
	for key in preferred_keys:
		if payload.has(key):
			var value: Variant = payload[key]
			if key == "reason":
				value = BattleTexts.click_failure_reason(String(value))
			parts.append("%s=%s" % [key, String(value)])
	print(" ".join(parts))


func _debug_unit_name(unit) -> String:
	if unit == null:
		return "none"
	return String(unit.unit_id if not String(unit.unit_id).is_empty() else unit.display_name)


func _debug_cell(cell: Vector2i) -> String:
	return "(%d,%d)" % [cell.x, cell.y]


func _debug_vec2(value: Vector2) -> String:
	return "(%.1f,%.1f)" % [value.x, value.y]


func _trace_left_click_decision(click_context: Dictionary, result: Dictionary) -> void:
	if not bool(result.get("handled", false)) and not debug_click_trace:
		return
	_debug_click_trace("LEFT_CLICK", {
		"phase": String(click_context.get("phase", "loading")),
		"targeting_mode": String(click_context.get("targeting_mode", "none")),
		"actor": _debug_unit_name(click_context.get("actor", null)),
		"focused": _debug_unit_name(click_context.get("focused_unit", null)),
		"mouse": _debug_vec2(click_context.get("screen_pos", Vector2.ZERO)),
		"world": _debug_vec2(click_context.get("world_pos", Vector2.ZERO)),
		"cell": _debug_cell(click_context.get("clicked_cell", Vector2i(-1, -1))),
		"actor_cell": _debug_cell(click_context.get("actor", null).grid_position if click_context.get("actor", null) != null else Vector2i(-1, -1)),
		"clicked_unit": _debug_unit_name(click_context.get("clicked_unit", null)),
		"clicked_team": String(click_context.get("clicked_unit", null).team) if click_context.get("clicked_unit", null) != null else "",
		"decision": String(result.get("decision", "IGNORE")),
		"success": bool(result.get("success", false)),
		"reason": String(result.get("reason", ""))
	})


func _get_targeting_mode() -> String:
	if not pending_skill_id.is_empty():
		var skill_def: Dictionary = skill_system.get_skill(pending_skill_id)
		if String(skill_def.get("action_type", "")) == "move":
			return "qinggong"
		return "skill"
	if not pending_item_id.is_empty():
		return "item"
	return "none"


func _set_interaction_feedback(reason_id: String, custom_text: String = "") -> void:
	interaction_feedback_text = custom_text if not custom_text.is_empty() else BattleTexts.click_failure_reason(reason_id)


func _clear_interaction_feedback() -> void:
	interaction_feedback_text = ""

func refresh_highlights() -> void:
	current_move_preview_cells.clear()
	current_qinggong_preview = {"valid": [], "invalid": []}
	current_target_preview_cells.clear()
	if battle_over or active_unit == null or active_unit.team != "player":
		grid_manager.clear_highlights()
		return
	var next_highlights := {"move": [], "qinggong": [], "attack": [], "invalid": []}
	next_highlights["target"] = []
	if not pending_item_id.is_empty():
		for target in item_system.get_valid_targets(active_unit, item_system.get_item(pending_item_id), all_units):
			if target != null and target is Node:
				current_target_preview_cells.append(target.grid_position)
				next_highlights["attack"].append(target.grid_position)
			elif target is Vector2i:
				current_target_preview_cells.append(target)
				next_highlights["attack"].append(target)
		if focused_unit != null and focused_unit != active_unit and _cell_in_cells(current_target_preview_cells, focused_unit.grid_position):
			next_highlights["target"].append(focused_unit.grid_position)
		grid_manager.set_highlights(next_highlights)
		return
	if not pending_skill_id.is_empty():
		var pending_skill: Dictionary = skill_system.get_skill(pending_skill_id)
		if String(pending_skill.get("action_type", "")) == "move":
			current_qinggong_preview = _get_qinggong_preview(active_unit)
			next_highlights["qinggong"] = current_qinggong_preview.get("valid", []).duplicate()
			next_highlights["invalid"] = current_qinggong_preview.get("invalid", []).duplicate()
		else:
			for target in skill_system.get_valid_targets(active_unit, pending_skill, all_units):
				if target != null and target is Node:
					current_target_preview_cells.append(target.grid_position)
					next_highlights["attack"].append(target.grid_position)
				elif target is Vector2i:
					current_target_preview_cells.append(target)
					next_highlights["attack"].append(target)
			if focused_unit != null and focused_unit != active_unit and _cell_in_cells(current_target_preview_cells, focused_unit.grid_position):
				next_highlights["target"].append(focused_unit.grid_position)
	elif not action_system.is_move_phase_done(active_unit):
		current_move_preview_cells = movement_system.get_reachable_cells(active_unit, action_system.get_remaining_move(active_unit), "ground")
		next_highlights["move"] = current_move_preview_cells.duplicate()
	elif action_system.can_use_action(active_unit):
		current_target_preview_cells = _get_attack_preview_cells(active_unit)
		next_highlights["attack"] = current_target_preview_cells.duplicate()
	if focused_unit != null and focused_unit != active_unit and focused_unit.is_alive():
		next_highlights["target"].append(focused_unit.grid_position)
	grid_manager.set_highlights(next_highlights)

func update_ui() -> void:
	var phase_id := _get_phase_id()
	var focus_unit = focused_unit if focused_unit != null else active_unit
	round_label.text = BattleTexts.format_round(turn_manager.get_round_index()) if turn_manager != null else "回合：-"
	current_unit_label.text = BattleTexts.format_current_unit(active_unit.display_name) if active_unit != null else BattleTexts.format_current_unit("无")
	phase_label.text = BattleTexts.format_phase(phase_id)
	prompt_label.text = _get_prompt_text(phase_id)
	var view_model: Dictionary = battle_hud_presenter.build_view_model({
		"battle_config": battle_config,
		"phase_id": phase_id,
		"prompt_text": prompt_label.text,
		"active_unit": active_unit,
		"focused_unit": focus_unit,
		"selected_cell": grid_manager.selected_cell,
		"pending_skill_id": pending_skill_id,
		"pending_item_id": pending_item_id,
		"show_enemy_skills": show_enemy_skills,
		"show_enemy_inventory": show_enemy_inventory,
		"battle_over": battle_over,
		"battle_result_id": battle_result_id,
		"all_units": all_units,
		"can_player_act": _can_player_act(),
		"interaction_feedback_text": interaction_feedback_text
	})
	battle_hud.update_view(view_model)

func _apply_battle_meta() -> void:
	var title := String(battle_config.get("title", current_battle_id))
	var ui_note := String(battle_config.get("ui_note", ""))
	var background_path := String(battle_config.get("background_path", ""))
	battle_title_label.text = title
	battle_note_label.text = ui_note
	battle_note_label.visible = not ui_note.is_empty()
	background_sprite.set_background_texture_path(background_path, BattleVisuals.get_default_background_path())


func _build_battle_condition_state() -> Dictionary:
	return {
		"all_units": all_units,
		"player_units": player_units,
		"enemy_units": enemy_units,
		"active_unit": active_unit,
		"round_index": turn_manager.get_round_index() if turn_manager != null else 1
	}

func _get_phase_id() -> String:
	if battle_over:
		return "battle_over"
	if active_unit == null:
		return "loading"
	if input_locked or active_unit.team != "player":
		return "enemy_turn"
	if _has_pending_target_selection():
		return "waiting_target"
	if not action_system.is_move_phase_done(active_unit):
		return "waiting_move"
	if action_system.can_use_action(active_unit):
		return "waiting_action"
	return "waiting_end"

func _get_prompt_text(phase_id: String) -> String:
	if phase_id == "battle_over":
		return BattleTexts.prompt_for_battle_over(battle_result_id)
	if phase_id == "enemy_turn":
		return BattleTexts.prompt_for_enemy_turn()
	if not pending_item_id.is_empty():
		return BattleTexts.prompt_for_item_target(item_system.get_item(pending_item_id))
	if not pending_skill_id.is_empty():
		return BattleTexts.prompt_for_target(skill_system.get_skill(pending_skill_id))
	if focused_unit != null and focused_unit != active_unit:
		return BattleTexts.prompt_for_viewing_enemy() if focused_unit.team == "enemy" else BattleTexts.prompt_for_locked_ally()
	if phase_id == "waiting_move":
		return BattleTexts.prompt_for_move(_has_normal_move_tiles(active_unit) or not _get_qinggong_preview(active_unit).get("valid", []).is_empty())
	if phase_id == "waiting_action":
		return BattleTexts.prompt_for_action(_has_action_options(active_unit), _has_item_options(active_unit))
	if phase_id == "waiting_end":
		return BattleTexts.prompt_for_end()
	return "载入中"

func _on_system_action_requested(action_id: String) -> void:
	match action_id:
		"move":
			_on_move_pressed()
		"qinggong":
			_on_qinggong_pressed()
		"skip_move":
			_on_skip_move_pressed()
		"end_turn":
			_on_end_turn_pressed()

func _on_move_pressed() -> void:
	if not _can_player_act() or focused_unit != active_unit or active_unit == null or action_system.is_move_phase_done(active_unit):
		return
	pending_skill_id = ""
	pending_item_id = ""
	_clear_interaction_feedback()
	refresh_highlights()
	update_ui()

func _on_qinggong_pressed() -> void:
	if not _can_player_act() or focused_unit != active_unit or active_unit == null:
		return
	var move_skill_id := _get_move_skill_id(active_unit)
	var skill_def: Dictionary = skill_system.get_skill(move_skill_id)
	if move_skill_id.is_empty() or skill_def.is_empty() or not skill_system.has_valid_target(active_unit, skill_def, all_units):
		return
	pending_item_id = ""
	pending_skill_id = move_skill_id
	_clear_interaction_feedback()
	refresh_highlights()
	update_ui()

func _on_skip_move_pressed() -> void:
	if not _can_player_act() or focused_unit != active_unit or active_unit == null or action_system.is_move_phase_done(active_unit):
		return
	pending_skill_id = ""
	pending_item_id = ""
	_clear_interaction_feedback()
	action_system.advance_to_action_phase(active_unit)
	refresh_highlights()
	update_ui()

func _on_skill_requested(skill_id: String) -> void:
	if not _can_player_act() or focused_unit != active_unit or active_unit == null or not action_system.can_use_action(active_unit):
		return
	var skill_def: Dictionary = skill_system.get_skill(skill_id)
	if skill_def.is_empty():
		return
	var valid_targets: Array = skill_system.get_valid_targets(active_unit, skill_def, all_units)
	if valid_targets.is_empty():
		return
	if String(skill_def.get("targeting", {}).get("type", "self")) == "self":
		if execute_skill_for_unit(active_unit, skill_id, active_unit):
			_clear_interaction_feedback()
			_after_player_action()
		return
	pending_item_id = ""
	pending_skill_id = skill_id
	_clear_interaction_feedback()
	refresh_highlights()
	update_ui()

func _on_item_requested(item_id: String) -> void:
	if not _can_player_act() or focused_unit != active_unit or active_unit == null or not action_system.can_use_action(active_unit):
		return
	var item_def: Dictionary = item_system.get_item(item_id)
	if item_def.is_empty():
		return
	if String(item_def.get("targeting", {}).get("type", "self")) == "self":
		if execute_item_for_unit(active_unit, item_id, active_unit):
			_clear_interaction_feedback()
			_after_player_action()
		return
	pending_skill_id = ""
	pending_item_id = item_id
	_clear_interaction_feedback()
	refresh_highlights()
	update_ui()

func _on_facing_requested(facing_id: String) -> void:
	if not _can_player_act() or focused_unit != active_unit or active_unit == null:
		return
	var facing_vector := _facing_id_to_vector(facing_id)
	if facing_vector != Vector2i.ZERO:
		active_unit.set_facing(facing_vector)
		_clear_interaction_feedback()
		grid_manager.refresh_board_layers()
		update_ui()

func _on_end_turn_pressed() -> void:
	if _can_player_act() and focused_unit == active_unit:
		_end_active_unit_turn()

func _can_player_act() -> bool:
	return not battle_over and not input_locked and active_unit != null and active_unit.team == "player"

func _has_pending_target_selection() -> bool:
	return not pending_skill_id.is_empty() or not pending_item_id.is_empty()

func _get_focus_mode(unit) -> String:
	if unit == null:
		return "none"
	if unit.team == "enemy":
		return "readonly_enemy"
	if unit == active_unit and _can_player_act():
		return "controllable"
	return "locked_ally"

func _get_move_skill_id(unit) -> String:
	if unit == null:
		return ""
	for skill_id in unit.skills:
		var skill_def: Dictionary = skill_system.get_skill(skill_id)
		if not skill_def.is_empty() and String(skill_def.get("action_type", "")) == "move":
			return skill_id
	return ""

func _face_unit_between(unit, from_cell: Vector2i, to_cell: Vector2i) -> void:
	var delta := to_cell - from_cell
	var facing := Vector2i.ZERO
	if delta != Vector2i.ZERO:
		if absi(delta.x) >= absi(delta.y):
			facing = Vector2i(signi(delta.x), 0)
		else:
			facing = Vector2i(0, signi(delta.y))
	if facing != Vector2i.ZERO:
		unit.set_facing(facing)

func _face_unit_to_target(unit, target) -> void:
	if target is Vector2i:
		_face_unit_between(unit, unit.grid_position, target)
	elif target != null and target is Node:
		_face_unit_between(unit, unit.grid_position, target.grid_position)

func _facing_id_to_vector(facing_id: String) -> Vector2i:
	match facing_id:
		"up":
			return Vector2i.UP
		"down":
			return Vector2i.DOWN
		"left":
			return Vector2i.LEFT
		"right":
			return Vector2i.RIGHT
		_:
			return Vector2i.ZERO

func _clear_units() -> void:
	for root in [player_units_root, enemy_units_root]:
		for child in root.get_children():
			child.queue_free()
	player_units.clear()
	enemy_units.clear()
	all_units.clear()
	selected_unit = null
	focused_unit = null
	active_unit = null
	hovered_unit = null

func _sync_unit_visual(unit) -> void:
	unit.set_board_visual_metrics(grid_manager.cell_size)
	unit.set_grid_cell(unit.grid_position, grid_manager.grid_to_world(unit.grid_position))
	movement_system.register_units(all_units)
	if selected_unit == unit:
		grid_manager.set_selected_cell(unit.grid_position)


func _layout_battlefield() -> void:
	if grid_manager == null or camera_2d == null:
		return
	var viewport_size := get_viewport_rect().size
	camera_2d.position = viewport_size * 0.5
	camera_2d.zoom = Vector2.ONE
	var reserved_rect := Rect2(
		Vector2(BOARD_SIDE_MARGIN, BOARD_TOP_MARGIN),
		Vector2(
			maxf(1.0, viewport_size.x - BOARD_SIDE_MARGIN * 2.0),
			maxf(1.0, viewport_size.y - BOARD_TOP_MARGIN - BOARD_BOTTOM_RESERVED)
		)
	)
	grid_manager.relayout_board(viewport_size, reserved_rect)
	for unit in all_units:
		if unit != null:
			unit.set_board_visual_metrics(grid_manager.cell_size)
			unit.set_grid_cell(unit.grid_position, grid_manager.grid_to_world(unit.grid_position))
	grid_manager.refresh_board_layers()

func _array_to_cell(raw_value) -> Vector2i:
	if raw_value is Array and raw_value.size() >= 2:
		return Vector2i(int(raw_value[0]), int(raw_value[1]))
	return Vector2i.ZERO
