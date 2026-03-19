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
const AIEvaluatorScript = preload("res://scripts/ai/ai_evaluator.gd")
const AIControllerScript = preload("res://scripts/ai/ai_controller.gd")
const PlayerUnitScript = preload("res://scripts/entities/player_unit.gd")
const EnemyUnitScript = preload("res://scripts/entities/enemy_unit.gd")

signal unit_killed(context: Dictionary)
signal non_lethal_hit(context: Dictionary)
signal control_applied(context: Dictionary)
signal battle_result(context: Dictionary)

const BOARD_TOP_MARGIN := 36.0
const BOARD_SIDE_MARGIN := 28.0
const BOARD_BOTTOM_RESERVED := 204.0

@export var initial_battle_id := "battle_001"

@onready var camera_2d: Camera2D = $Camera2D
@onready var grid_manager: GridManager = $BoardRoot
@onready var player_units_root: Node2D = $BoardRoot/UnitLayer/PlayerUnits
@onready var enemy_units_root: Node2D = $BoardRoot/UnitLayer/EnemyUnits
@onready var top_info_panel: PanelContainer = $CanvasLayer/BattleTopInfo
@onready var round_label: Label = $CanvasLayer/BattleTopInfo/Margin/VBox/RoundLabel
@onready var current_unit_label: Label = $CanvasLayer/BattleTopInfo/Margin/VBox/CurrentUnitLabel
@onready var phase_label: Label = $CanvasLayer/BattleTopInfo/Margin/VBox/PhaseLabel
@onready var prompt_label: Label = $CanvasLayer/BattleTopInfo/Margin/VBox/PromptLabel
@onready var battle_hud: Control = $CanvasLayer/BottomHUD

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
var ai_evaluator
var ai_controller

var battle_config: Dictionary = {}
var player_units: Array = []
var enemy_units: Array = []
var all_units: Array = []

var selected_unit = null
var focused_unit = null
var active_unit = null
var hovered_unit = null

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
	_clear_units()
	_build_runtime_services()
	battle_config = battle_loader.load_battle_config(battle_id)
	if battle_config.has("error"):
		battle_over = true
		update_ui()
		return
	ai_difficulty = String(battle_config.get("ai_difficulty", "simple"))
	_apply_enemy_info_flags()
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
	style.bg_color = Color(0.08, 0.10, 0.14, 0.56)
	style.border_color = Color(0.86, 0.88, 0.92, 0.10)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	top_info_panel.add_theme_stylebox_override("panel", style)
	for label in [round_label, current_unit_label, phase_label, prompt_label]:
		label.add_theme_color_override("font_color", Color(0.95, 0.95, 0.94, 1.0))
		label.add_theme_font_size_override("font_size", 11)
	prompt_label.add_theme_font_size_override("font_size", 10)

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
	ai_evaluator = AIEvaluatorScript.new(skill_system, movement_system, stance_system, combat_system)
	ai_controller = AIControllerScript.new(skill_system, movement_system, action_system, ai_evaluator)

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
	return _execute_normal_move(unit, target_cell)

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
			refresh_highlights()
			update_ui()
		return
	if event.button_index != MOUSE_BUTTON_LEFT:
		return
	var clicked_cell: Vector2i = grid_manager.world_to_cell(event.position)
	if not grid_manager.is_in_bounds(clicked_cell):
		return
	var clicked_unit = movement_system.get_unit_at(clicked_cell)
	if _has_pending_target_selection() and _can_player_act() and _handle_pending_selection(clicked_cell, clicked_unit):
		return
	if clicked_unit != null:
		_set_focused_unit(clicked_unit)
		refresh_highlights()
		update_ui()
		return
	if battle_over or not _can_player_act() or active_unit == null or focused_unit != active_unit:
		return
	if not action_system.is_move_phase_done(active_unit) and _execute_normal_move(active_unit, clicked_cell):
		_after_player_action()

func _handle_pending_selection(clicked_cell: Vector2i, clicked_unit) -> bool:
	if not pending_skill_id.is_empty():
		var skill_def: Dictionary = skill_system.get_skill(pending_skill_id)
		if skill_def.is_empty():
			pending_skill_id = ""
			return false
		var skill_target = clicked_cell if String(skill_def.get("targeting", {}).get("type", "self")) == "cell" else clicked_unit
		if skill_target != null and execute_skill_for_unit(active_unit, pending_skill_id, skill_target):
			_after_player_action()
			return true
	if not pending_item_id.is_empty():
		var item_def: Dictionary = item_system.get_item(pending_item_id)
		if item_def.is_empty():
			pending_item_id = ""
			return false
		var item_target = active_unit if String(item_def.get("targeting", {}).get("type", "self")) == "self" else clicked_unit
		if item_target != null and execute_item_for_unit(active_unit, pending_item_id, item_target):
			_after_player_action()
			return true
	return false

func _execute_normal_move(unit, target_cell: Vector2i) -> bool:
	if unit == null or not unit.is_alive() or target_cell == unit.grid_position:
		return false
	if not action_system.can_move_normally(unit) or movement_system.is_cell_occupied(target_cell, unit):
		return false
	var start_cell: Vector2i = unit.grid_position
	var move_result: Dictionary = movement_system.apply_move(unit, target_cell, "ground", action_system.get_remaining_move(unit))
	if not bool(move_result.get("success", false)):
		return false
	action_system.record_normal_move(unit, int(move_result.get("distance", 0)))
	pending_skill_id = ""
	pending_item_id = ""
	_face_unit_between(unit, start_cell, target_cell)
	_sync_unit_visual(unit)
	if unit == active_unit:
		_set_focused_unit(unit)
	refresh_highlights()
	update_ui()
	return true

func _after_player_action() -> void:
	if not battle_over and active_unit != null and active_unit.is_alive():
		_set_focused_unit(active_unit)
	refresh_highlights()
	update_ui()

func _end_active_unit_turn() -> void:
	if active_unit == null or battle_over:
		return
	pending_skill_id = ""
	pending_item_id = ""
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
	if get_player_units().is_empty():
		battle_over = true
		input_locked = true
		battle_result_id = "defeat"
		grid_manager.clear_highlights()
		emit_signal("battle_result", {"result": "defeat", "battle_id": current_battle_id})
		return true
	if get_enemy_units().is_empty():
		battle_over = true
		input_locked = true
		battle_result_id = "victory"
		grid_manager.clear_highlights()
		emit_signal("battle_result", {"result": "victory", "battle_id": current_battle_id})
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
	var hovered_cell := grid_manager.world_to_cell(screen_position)
	var next_unit = null
	if grid_manager.is_in_bounds(hovered_cell):
		next_unit = movement_system.get_unit_at(hovered_cell)
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

func refresh_highlights() -> void:
	if battle_over or active_unit == null or active_unit.team != "player":
		grid_manager.clear_highlights()
		return
	var next_highlights := {"move": [], "qinggong": [], "attack": [], "invalid": []}
	if focused_unit != active_unit:
		grid_manager.set_highlights(next_highlights)
		return
	if not pending_item_id.is_empty():
		for target in item_system.get_valid_targets(active_unit, item_system.get_item(pending_item_id), all_units):
			if target != null and target is Node:
				next_highlights["attack"].append(target.grid_position)
		grid_manager.set_highlights(next_highlights)
		return
	if not pending_skill_id.is_empty():
		var pending_skill: Dictionary = skill_system.get_skill(pending_skill_id)
		if String(pending_skill.get("action_type", "")) == "move":
			var preview := _get_qinggong_preview(active_unit)
			next_highlights["qinggong"] = preview.get("valid", [])
			next_highlights["invalid"] = preview.get("invalid", [])
		else:
			for target in skill_system.get_valid_targets(active_unit, pending_skill, all_units):
				if target != null and target is Node:
					next_highlights["attack"].append(target.grid_position)
	elif not action_system.is_move_phase_done(active_unit):
		next_highlights["move"] = movement_system.get_reachable_cells(active_unit, action_system.get_remaining_move(active_unit), "ground")
	elif action_system.can_use_action(active_unit):
		next_highlights["attack"] = _get_attack_preview_cells(active_unit)
	grid_manager.set_highlights(next_highlights)

func update_ui() -> void:
	var phase_id := _get_phase_id()
	var focus_unit = focused_unit if focused_unit != null else active_unit
	round_label.text = BattleTexts.format_round(turn_manager.get_round_index()) if turn_manager != null else "回合：-"
	current_unit_label.text = BattleTexts.format_current_unit(active_unit.display_name) if active_unit != null else BattleTexts.format_current_unit("无")
	phase_label.text = BattleTexts.format_phase(phase_id)
	prompt_label.text = _get_prompt_text(phase_id)
	battle_hud.update_view(_build_hud_view_model(focus_unit, phase_id))

func _build_hud_view_model(unit, phase_id: String) -> Dictionary:
	var focus_mode := _get_focus_mode(unit)
	var view := {
		"unit": unit,
		"focused_title": "未选择角色",
		"phase_text": BattleTexts.format_phase(phase_id),
		"active_unit_text": "当前行动：%s" % (active_unit.display_name if active_unit != null else "无"),
		"view_mode_text": "查看模式：%s" % BattleTexts.focus_state_label("none"),
		"status_hint_text": "请选择战场中的单位查看信息",
		"hp_text": "生命：-",
		"qi_text": "真气：无",
		"show_qi": false,
		"portrait_texture": null,
		"facing_text": BattleTexts.format_facing("none"),
		"facing_id": "none",
		"facing_enabled": false,
		"status_tags": [],
		"system_actions": _build_system_action_entries(),
		"skill_entries": [],
		"item_entries": [],
		"skills_state_text": "",
		"items_state_text": ""
	}
	if unit == null:
		return view
	view["focused_title"] = unit.display_name
	view["hp_text"] = BattleTexts.format_hp(unit.hp, unit.max_hp)
	view["qi_text"] = BattleTexts.format_qi(unit.uses_qi, unit.qi, unit.max_qi)
	view["show_qi"] = unit.uses_qi
	view["facing_text"] = BattleTexts.format_facing(unit.get_facing_id())
	view["portrait_texture"] = unit.get_portrait_texture()
	view["facing_id"] = unit.get_facing_id()
	view["facing_enabled"] = focus_mode == "controllable"
	view["status_tags"] = _build_status_tags(unit)
	view["view_mode_text"] = _build_view_mode_text(unit, focus_mode)
	view["status_hint_text"] = _build_status_hint_text(unit, phase_id, focus_mode)
	view["skill_entries"] = _build_skill_entries(unit, focus_mode)
	view["item_entries"] = _build_item_entries(unit, focus_mode)
	view["skills_state_text"] = _get_skills_state_text(unit, focus_mode)
	view["items_state_text"] = _get_items_state_text(unit, focus_mode)
	return view

func _build_status_tags(unit) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
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
		entries.append({
			"id": String(status_id),
			"text": BattleVisuals.get_status_tag_text(String(status_id), stacks),
			"kind": "buff" if String(status_id) == "yinren" else "debuff",
			"description": BattleVisuals.get_status_description(String(status_id), stacks)
		})
	return entries


func _build_view_mode_text(unit, focus_mode: String) -> String:
	match focus_mode:
		"controllable":
			return "查看模式：当前行动单位"
		"locked_ally":
			return "查看模式：同伴信息"
		"readonly_enemy":
			return "查看模式：敌方情报"
		_:
			return "查看模式：%s" % BattleTexts.focus_state_label(focus_mode)


func _build_status_hint_text(unit, phase_id: String, focus_mode: String) -> String:
	if unit != null and active_unit != null and unit != active_unit:
		return "正在查看：%s / 当前行动：%s" % [unit.display_name, active_unit.display_name]
	match focus_mode:
		"controllable":
			if _has_pending_target_selection():
				return "左键确认目标，右键取消选择"
			match phase_id:
				"waiting_move":
					return "先移动，再选择本回合行动"
				"waiting_action":
					return "攻击、技能、道具共享一次行动"
				"waiting_end":
					return "当前角色已行动，可结束回合"
			return "当前角色可以操作"
		"locked_ally":
			return "当前不可操作，仅查看信息"
		"readonly_enemy":
			return "敌方单位不可控制，只能查看情报"
		_:
			return "请选择需要查看的单位"

func _build_system_action_entries() -> Dictionary:
	var entries := {"move": {"text": BattleTexts.button_label("move"), "disabled": true}, "qinggong": {"text": "轻功", "disabled": true}, "skip_move": {"text": BattleTexts.button_label("skip_move"), "disabled": true}, "end_turn": {"text": BattleTexts.button_label("end_turn"), "disabled": true}}
	if active_unit == null:
		return entries
	var controllable: bool = _can_player_act() and focused_unit == active_unit
	var move_skill_id := _get_move_skill_id(active_unit)
	var qinggong_skill: Dictionary = skill_system.get_skill(move_skill_id)
	if controllable and not action_system.is_move_phase_done(active_unit) and pending_skill_id.is_empty() and pending_item_id.is_empty():
		entries["move"]["text"] += BattleTexts.button_label("selected_suffix")
	entries["move"]["disabled"] = not controllable or action_system.is_move_phase_done(active_unit) or not _has_normal_move_tiles(active_unit)
	if not qinggong_skill.is_empty():
		entries["qinggong"]["text"] = BattleTexts.skill_name(qinggong_skill)
		entries["qinggong"]["icon_path"] = qinggong_skill.get("icon_path", "")
		if pending_skill_id == move_skill_id:
			entries["qinggong"]["text"] += BattleTexts.button_label("selected_suffix")
	entries["qinggong"]["disabled"] = not controllable or move_skill_id.is_empty() or not skill_system.has_valid_target(active_unit, qinggong_skill, all_units)
	entries["skip_move"]["disabled"] = not controllable or action_system.is_move_phase_done(active_unit) or _has_pending_target_selection()
	entries["end_turn"]["disabled"] = not controllable or _has_pending_target_selection() or battle_over
	return entries

func _build_skill_entries(unit, focus_mode: String) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	if unit.team == "enemy" and not show_enemy_skills:
		return [{"id": "hidden_enemy_skills", "text": BattleTexts.hidden_skills_text(), "disabled": true, "kind": "hidden"}]
	var controllable: bool = focus_mode == "controllable"
	for skill_id in unit.skills:
		var skill_def: Dictionary = skill_system.get_skill(skill_id)
		if skill_def.is_empty() or String(skill_def.get("action_type", "")) == "move":
			continue
		var text := BattleTexts.skill_name(skill_def)
		if pending_skill_id == skill_id:
			text += BattleTexts.button_label("selected_suffix")
		entries.append({"id": skill_id, "text": text, "tooltip": BattleTexts.skill_name(skill_def), "disabled": not controllable or _has_pending_target_selection() or not action_system.can_use_action(unit) or not skill_system.has_valid_target(unit, skill_def, all_units), "kind": String(skill_def.get("ui_group", "guard")), "icon_path": String(skill_def.get("icon_path", ""))})
	if entries.is_empty():
		entries.append({"id": "no_skill", "text": "暂无技能", "disabled": true, "kind": "hidden"})
	return entries

func _build_item_entries(unit, focus_mode: String) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	if unit.team == "enemy" and not show_enemy_inventory:
		return [{"id": "hidden_enemy_inventory", "text": BattleTexts.hidden_inventory_text(), "disabled": true, "kind": "hidden"}]
	var controllable: bool = focus_mode == "controllable"
	for entry in unit.get_inventory_entries():
		var item_id := String(entry.get("item_id", ""))
		var item_def: Dictionary = item_system.get_item(item_id)
		if item_def.is_empty():
			continue
		var text := "%s x%d" % [BattleTexts.item_name(item_def), int(entry.get("quantity", 0))]
		if pending_item_id == item_id:
			text += BattleTexts.button_label("selected_suffix")
		entries.append({"id": item_id, "text": text, "tooltip": String(item_def.get("description", "")), "disabled": not controllable or _has_pending_target_selection() or not action_system.can_use_action(unit) or not item_system.has_valid_target(unit, item_def, all_units), "kind": "item", "icon_path": String(item_def.get("icon_path", ""))})
	if entries.is_empty():
		entries.append({"id": "no_item", "text": BattleTexts.no_items_text(), "disabled": true, "kind": "hidden"})
	return entries

func _get_skills_state_text(unit, focus_mode: String) -> String:
	if unit.team == "enemy":
		return BattleTexts.hidden_skills_text() if not show_enemy_skills else "敌方技能只可查看"
	if focus_mode == "locked_ally":
		return "当前不可操作"
	return "武学列表" if pending_skill_id.is_empty() else "正在选择技能目标"

func _get_items_state_text(unit, focus_mode: String) -> String:
	if unit.team == "enemy":
		return BattleTexts.hidden_inventory_text() if not show_enemy_inventory else "敌方背包只可查看"
	if focus_mode == "locked_ally":
		return "当前不可操作"
	return "背包物品" if pending_item_id.is_empty() else "正在选择道具目标"

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
	refresh_highlights()
	update_ui()

func _on_skip_move_pressed() -> void:
	if not _can_player_act() or focused_unit != active_unit or active_unit == null or action_system.is_move_phase_done(active_unit):
		return
	pending_skill_id = ""
	pending_item_id = ""
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
			_after_player_action()
		return
	pending_item_id = ""
	pending_skill_id = skill_id
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
			_after_player_action()
		return
	pending_skill_id = ""
	pending_item_id = item_id
	refresh_highlights()
	update_ui()

func _on_facing_requested(facing_id: String) -> void:
	if not _can_player_act() or focused_unit != active_unit or active_unit == null:
		return
	var facing_vector := _facing_id_to_vector(facing_id)
	if facing_vector != Vector2i.ZERO:
		active_unit.set_facing(facing_vector)
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
