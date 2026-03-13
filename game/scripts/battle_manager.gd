extends Node2D

const PLAYER_SCENE := preload("res://units/player.tscn")
const ENEMY_SCENE := preload("res://units/enemy.tscn")

enum TurnSide {
	PLAYER,
	ENEMY,
}

enum PlayerMode {
	IDLE,
	SELECTED,
	MOVE,
	ATTACK_TARGET,
	SKILL_TARGET,
}

enum PendingAction {
	NONE,
	NORMAL_ATTACK,
	SPLIT_PALM,
	QINGGONG_STEP,
}

@onready var grid_manager: GridManager = $GridManager
@onready var units_root: Node2D = $Units

@onready var turn_label: Label = $CanvasLayer/UI/Panel/VBox/TurnLabel
@onready var mode_label: Label = $CanvasLayer/UI/Panel/VBox/ModeLabel
@onready var player_hp_label: Label = $CanvasLayer/UI/Panel/VBox/PlayerHpLabel
@onready var player_qi_label: Label = $CanvasLayer/UI/Panel/VBox/PlayerQiLabel
@onready var player_stance_label: Label = $CanvasLayer/UI/Panel/VBox/PlayerStanceLabel
@onready var selected_label: Label = $CanvasLayer/UI/Panel/VBox/SelectedLabel
@onready var message_label: Label = $CanvasLayer/UI/Panel/VBox/MessageLabel
@onready var light_step_button: Button = $CanvasLayer/UI/Panel/VBox/Buttons/LightStepButton
@onready var split_palm_button: Button = $CanvasLayer/UI/Panel/VBox/Buttons/SplitPalmButton
@onready var iron_wall_button: Button = $CanvasLayer/UI/Panel/VBox/Buttons/IronWallButton
@onready var attack_button: Button = $CanvasLayer/UI/Panel/VBox/Buttons/AttackButton
@onready var end_turn_button: Button = $CanvasLayer/UI/Panel/VBox/Buttons/EndTurnButton
@onready var hint_label: Label = $CanvasLayer/UI/HintLabel

var current_turn: int = TurnSide.PLAYER
var player_mode: int = PlayerMode.IDLE
var pending_action: int = PendingAction.NONE
var battle_over := false
var status_message := ""

var player_unit: BattleUnit
var enemy_units: Array[BattleUnit] = []
var selected_unit: BattleUnit

var enemy_ai := EnemyAI.new()


func _ready() -> void:
	connect_ui()
	spawn_units()
	start_player_turn(true)


func connect_ui() -> void:
	light_step_button.pressed.connect(_on_light_step_pressed)
	split_palm_button.pressed.connect(_on_split_palm_pressed)
	iron_wall_button.pressed.connect(_on_iron_wall_pressed)
	attack_button.pressed.connect(_on_attack_pressed)
	end_turn_button.pressed.connect(_on_end_turn_pressed)


func spawn_units() -> void:
	player_unit = PLAYER_SCENE.instantiate() as BattleUnit
	units_root.add_child(player_unit)
	player_unit.set_grid_position(Vector2i(1, 2), grid_manager.grid_to_world(Vector2i(1, 2)))

	var enemy_positions := [Vector2i(5, 1), Vector2i(5, 3)]
	for index in range(enemy_positions.size()):
		var enemy := ENEMY_SCENE.instantiate() as BattleUnit
		enemy.display_name = "Bandit %d" % (index + 1)
		units_root.add_child(enemy)
		enemy.set_grid_position(enemy_positions[index], grid_manager.grid_to_world(enemy_positions[index]))
		enemy_units.append(enemy)


func _unhandled_input(event: InputEvent) -> void:
	if battle_over or current_turn != TurnSide.PLAYER:
		return

	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			handle_right_click_cancel()
			return

		if event.button_index != MOUSE_BUTTON_LEFT:
			return

		var clicked_cell := grid_manager.world_to_cell(event.position)
		var hero_cell := Vector2i(-1, -1)
		if is_instance_valid(player_unit):
			hero_cell = player_unit.grid_position
		var called_select_hero := false
		print("[Input] mouse=", event.position, " cell=", clicked_cell, " hero_cell=", hero_cell)
		if not grid_manager.is_in_bounds(clicked_cell):
			print("[Input] click ignored: outside board")
			return

		if is_instance_valid(player_unit) and clicked_cell == player_unit.grid_position:
			called_select_hero = true
			select_hero("Hero selected. Choose a tile to move or a skill to use.")
		else:
			var clicked_unit := get_unit_at(clicked_cell)
			if clicked_unit != null:
				handle_enemy_click(clicked_unit)
			else:
				handle_empty_cell_click(clicked_cell)

		print("[Input] select_hero_called=", called_select_hero)

		refresh_highlights()
		update_ui()


func handle_right_click_cancel() -> void:
	if pending_action == PendingAction.NONE:
		if is_hero_selected():
			status_message = "Hero selected. Choose a tile to move or a skill to use."
		else:
			status_message = "Click Hero to select."
	else:
		pending_action = PendingAction.NONE
		update_neutral_mode()
		status_message = "Targeting canceled. Hero selected. Choose a tile to move or a skill to use."

	refresh_highlights()
	update_ui()


func handle_enemy_click(enemy: BattleUnit) -> void:
	if not is_hero_selected():
		status_message = "Click Hero to select."
		return

	match pending_action:
		PendingAction.NORMAL_ATTACK:
			player_attack(enemy, false)
		PendingAction.SPLIT_PALM:
			player_attack(enemy, true)
		_:
			status_message = "Choose Normal Attack or Split Palm, then click an adjacent enemy."


func handle_empty_cell_click(cell: Vector2i) -> void:
	if not is_hero_selected():
		status_message = "Click Hero to select."
		return

	if pending_action == PendingAction.QINGGONG_STEP:
		use_qinggong_step(cell)
		return

	if pending_action == PendingAction.NORMAL_ATTACK or pending_action == PendingAction.SPLIT_PALM:
		status_message = "Attack selected. Click an adjacent enemy. Right click to cancel current targeting mode."
		return

	if attempt_move(player_unit, cell):
		update_neutral_mode()
		status_message = "Hero moved to %s. Choose a skill to use or end turn." % format_cell(cell)


func start_player_turn(initial := false) -> void:
	if battle_over:
		return

	current_turn = TurnSide.PLAYER
	pending_action = PendingAction.NONE
	player_mode = PlayerMode.IDLE

	if is_instance_valid(player_unit):
		if initial:
			player_unit.has_moved = false
			player_unit.has_acted = false
			player_unit.temporary_move_bonus = 0
		else:
			player_unit.begin_turn()
		set_selected_unit(null)
		status_message = "Player turn. Click Hero to select."
	else:
		battle_over = true
		status_message = "The hero has fallen."

	refresh_highlights()
	update_ui()


func _on_light_step_pressed() -> void:
	if not ensure_player_action_ready(2):
		return

	pending_action = PendingAction.QINGGONG_STEP
	player_mode = PlayerMode.SKILL_TARGET
	status_message = "Qinggong Step selected. Click a reachable tile. Right click to cancel current targeting mode."
	refresh_highlights()
	update_ui()


func _on_split_palm_pressed() -> void:
	if not ensure_player_action_ready(3):
		return

	pending_action = PendingAction.SPLIT_PALM
	player_mode = PlayerMode.ATTACK_TARGET
	status_message = "Split Palm selected. Click an adjacent enemy. Right click to cancel current targeting mode."
	refresh_highlights()
	update_ui()


func _on_iron_wall_pressed() -> void:
	if not ensure_player_action_ready(2):
		return

	if player_unit.apply_iron_wall():
		pending_action = PendingAction.NONE
		update_neutral_mode()
		status_message = "Iron Wall used. Hero entered ShouShi immediately."

	refresh_highlights()
	update_ui()


func _on_attack_pressed() -> void:
	if not ensure_player_action_ready(0):
		return

	pending_action = PendingAction.NORMAL_ATTACK
	player_mode = PlayerMode.ATTACK_TARGET
	status_message = "Normal Attack selected. Click an adjacent enemy. Right click to cancel current targeting mode."
	refresh_highlights()
	update_ui()


func _on_end_turn_pressed() -> void:
	if battle_over or current_turn != TurnSide.PLAYER:
		return
	start_enemy_turn()


func ensure_player_action_ready(qi_cost: int) -> bool:
	if battle_over or current_turn != TurnSide.PLAYER:
		return false
	if not is_instance_valid(player_unit):
		return false
	if not is_hero_selected():
		status_message = "Click Hero to select before using skills."
		update_ui()
		return false
	if player_unit.has_acted:
		status_message = "This turn's action has already been used."
		update_ui()
		return false
	if qi_cost > 0 and not player_unit.can_afford(qi_cost):
		status_message = "Not enough Qi."
		update_ui()
		return false
	return true


func attempt_move(unit: BattleUnit, target_cell: Vector2i) -> bool:
	if unit.has_moved:
		status_message = "Movement has already been used this turn."
		return false
	if target_cell == unit.grid_position:
		return false
	if is_cell_occupied(target_cell):
		status_message = "That tile is occupied."
		return false
	if not get_reachable_cells(unit).has(target_cell):
		status_message = "That tile is outside your move range."
		return false

	move_unit(unit, target_cell)
	return true


func move_unit(unit: BattleUnit, target_cell: Vector2i) -> void:
	unit.has_moved = true
	unit.set_grid_position(target_cell, grid_manager.grid_to_world(target_cell))
	if unit == selected_unit:
		grid_manager.set_selected_cell(target_cell)


func use_qinggong_step(target_cell: Vector2i) -> void:
	if not ensure_player_action_ready(2):
		return
	if target_cell == player_unit.grid_position:
		status_message = "Qinggong Step selected. Click a different reachable tile."
		return
	if is_cell_occupied(target_cell):
		status_message = "That tile is occupied."
		return
	if not get_qinggong_reachable_cells(player_unit).has(target_cell):
		status_message = "That tile is outside Qinggong Step range."
		return

	if not player_unit.apply_light_step():
		status_message = "Qinggong Step could not be used."
		return

	if attempt_move(player_unit, target_cell):
		pending_action = PendingAction.NONE
		update_neutral_mode()
		status_message = "Qinggong Step used. Hero moved to %s." % format_cell(target_cell)

	refresh_highlights()
	update_ui()


func player_attack(target: BattleUnit, use_split_palm: bool) -> void:
	if not is_instance_valid(player_unit) or player_unit.has_acted:
		return
	if not are_adjacent(player_unit.grid_position, target.grid_position):
		status_message = "Only adjacent enemies can be attacked."
		return

	var skill_name := "Normal Attack"
	var base_damage := player_unit.base_attack
	var qi_refund := 1
	if use_split_palm:
		if not player_unit.spend_qi(3):
			status_message = "Not enough Qi for Split Palm."
			return
		player_unit.set_stance(BattleUnit.Stance.FAJIN)
		skill_name = "Split Palm"
		base_damage = 20
		qi_refund = 0

	perform_attack(player_unit, target, base_damage, skill_name, qi_refund)
	pending_action = PendingAction.NONE
	update_neutral_mode()


func perform_attack(attacker: BattleUnit, defender: BattleUnit, base_damage: int, attack_name: String, qi_refund: int) -> void:
	var damage := attacker.calculate_damage_against(defender, base_damage)
	defender.take_damage(damage)
	attacker.has_acted = true
	if qi_refund > 0:
		attacker.recover_qi(qi_refund)

	status_message = "%s used %s and dealt %d damage to %s." % [attacker.display_name, attack_name, damage, defender.display_name]
	if defender.is_dead():
		status_message += " %s was defeated." % defender.display_name

	cleanup_dead_units()
	check_battle_end()
	refresh_highlights()
	update_ui()


func start_enemy_turn() -> void:
	current_turn = TurnSide.ENEMY
	player_mode = PlayerMode.IDLE
	pending_action = PendingAction.NONE
	set_selected_unit(null)
	grid_manager.clear_highlights()
	status_message = "Enemy turn."
	update_ui()

	await get_tree().create_timer(0.35).timeout

	for enemy in enemy_units.duplicate():
		if battle_over or not is_instance_valid(enemy) or enemy.is_dead():
			continue

		enemy.begin_turn()
		var action := enemy_ai.choose_action(enemy, player_unit, self)
		var action_type = action.get("type", "wait")

		if action_type == "attack":
			enemy_attack(enemy)
		elif action_type == "guard":
			enemy.apply_iron_wall()
			status_message = "%s used Iron Wall and entered ShouShi." % enemy.display_name
		elif action_type == "move":
			var target_cell: Vector2i = action.get("cell", enemy.grid_position)
			move_unit(enemy, target_cell)
			status_message = "%s moved to %s." % [enemy.display_name, format_cell(target_cell)]
		else:
			status_message = "%s waited." % enemy.display_name

		update_ui()
		await get_tree().create_timer(0.35).timeout

		if battle_over:
			return

		if is_instance_valid(enemy) and not enemy.is_dead() and not enemy.has_acted and is_instance_valid(player_unit) and are_adjacent(enemy.grid_position, player_unit.grid_position):
			enemy_attack(enemy)
			await get_tree().create_timer(0.35).timeout
			if battle_over:
				return

	start_player_turn()


func enemy_attack(enemy: BattleUnit) -> void:
	if not is_instance_valid(player_unit) or not are_adjacent(enemy.grid_position, player_unit.grid_position):
		return
	perform_attack(enemy, player_unit, enemy.base_attack, "Close Strike", 0)


func get_unit_at(cell: Vector2i) -> BattleUnit:
	if is_instance_valid(player_unit) and player_unit.grid_position == cell and not player_unit.is_dead():
		return player_unit
	for enemy in enemy_units:
		if is_instance_valid(enemy) and enemy.grid_position == cell and not enemy.is_dead():
			return enemy
	return null


func is_cell_occupied(cell: Vector2i) -> bool:
	return get_unit_at(cell) != null


func are_adjacent(a: Vector2i, b: Vector2i) -> bool:
	return grid_distance(a, b) == 1


func grid_distance(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)


func does_stance_counter(attacker_stance: int, defender_stance: int) -> bool:
	if attacker_stance == BattleUnit.Stance.NONE or defender_stance == BattleUnit.Stance.NONE:
		return false
	return BattleUnit.COUNTERS.get(attacker_stance, BattleUnit.Stance.NONE) == defender_stance


func get_reachable_cells(unit: BattleUnit) -> Array[Vector2i]:
	var reachable: Array[Vector2i] = []
	if unit.has_moved:
		return reachable

	for y in range(grid_manager.rows):
		for x in range(grid_manager.columns):
			var cell := Vector2i(x, y)
			if cell == unit.grid_position:
				continue
			if is_cell_occupied(cell):
				continue
			if grid_distance(cell, unit.grid_position) <= unit.get_move_capacity():
				reachable.append(cell)

	return reachable


func get_qinggong_reachable_cells(unit: BattleUnit) -> Array[Vector2i]:
	var reachable: Array[Vector2i] = []
	if unit.has_moved:
		return reachable

	var qinggong_range := unit.base_move + 3
	for y in range(grid_manager.rows):
		for x in range(grid_manager.columns):
			var cell := Vector2i(x, y)
			if cell == unit.grid_position:
				continue
			if is_cell_occupied(cell):
				continue
			if grid_distance(cell, unit.grid_position) <= qinggong_range:
				reachable.append(cell)

	return reachable


func get_attackable_enemy_cells(unit: BattleUnit) -> Array[Vector2i]:
	var attackable: Array[Vector2i] = []
	for neighbor in get_neighbor_cells(unit.grid_position):
		var occupant := get_unit_at(neighbor)
		if occupant != null and occupant.is_player != unit.is_player:
			attackable.append(neighbor)
	return attackable


func get_neighbor_cells(cell: Vector2i) -> Array[Vector2i]:
	var neighbors: Array[Vector2i] = []
	var directions := [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]
	for direction in directions:
		var next = cell + direction
		if grid_manager.is_in_bounds(next):
			neighbors.append(next)
	return neighbors


func set_selected_unit(unit: BattleUnit = null) -> void:
	if is_instance_valid(selected_unit):
		selected_unit.set_selected(false)
	selected_unit = unit
	if is_instance_valid(selected_unit):
		selected_unit.set_selected(true)
		grid_manager.set_selected_cell(selected_unit.grid_position)
	else:
		grid_manager.set_selected_cell(Vector2i(-1, -1))


func select_hero(message: String) -> void:
	if not is_instance_valid(player_unit):
		return

	set_selected_unit(player_unit)
	pending_action = PendingAction.NONE
	update_neutral_mode()
	status_message = message


func update_neutral_mode() -> void:
	if not is_hero_selected():
		player_mode = PlayerMode.IDLE
		return

	if player_unit.has_moved:
		player_mode = PlayerMode.SELECTED
	else:
		player_mode = PlayerMode.MOVE


func is_hero_selected() -> bool:
	return is_instance_valid(player_unit) and selected_unit == player_unit


func refresh_highlights() -> void:
	if battle_over or current_turn != TurnSide.PLAYER or not is_hero_selected():
		grid_manager.clear_highlights()
		return

	var move_cells: Array[Vector2i] = []
	var attack_cells: Array[Vector2i] = []

	match pending_action:
		PendingAction.QINGGONG_STEP:
			move_cells = get_qinggong_reachable_cells(player_unit)
		PendingAction.NORMAL_ATTACK, PendingAction.SPLIT_PALM:
			attack_cells = get_attackable_enemy_cells(player_unit)
		_:
			move_cells = get_reachable_cells(player_unit)

	grid_manager.set_highlights(move_cells, attack_cells)


func cleanup_dead_units() -> void:
	if is_instance_valid(player_unit) and player_unit.is_dead():
		player_unit.queue_free()
		player_unit = null
		set_selected_unit(null)

	for enemy in enemy_units.duplicate():
		if is_instance_valid(enemy) and enemy.is_dead():
			if selected_unit == enemy:
				set_selected_unit(null)
			enemy_units.erase(enemy)
			enemy.queue_free()


func check_battle_end() -> void:
	if player_unit == null:
		battle_over = true
		current_turn = TurnSide.ENEMY
		player_mode = PlayerMode.IDLE
		pending_action = PendingAction.NONE
		grid_manager.clear_highlights()
		status_message = "Battle over: defeat."
	elif enemy_units.is_empty():
		battle_over = true
		player_mode = PlayerMode.IDLE
		pending_action = PendingAction.NONE
		grid_manager.clear_highlights()
		status_message = "Battle over: victory."


func format_cell(cell: Vector2i) -> String:
	return "(%d, %d)" % [cell.x + 1, cell.y + 1]


func get_mode_text() -> String:
	match player_mode:
		PlayerMode.SELECTED:
			return "Selected"
		PlayerMode.MOVE:
			return "Move"
		PlayerMode.ATTACK_TARGET:
			return "Attack Target"
		PlayerMode.SKILL_TARGET:
			return "Skill Target"
		_:
			return "Idle"


func get_hint_text() -> String:
	if battle_over:
		return "Battle finished."
	if current_turn != TurnSide.PLAYER:
		return "Enemy AI is acting."
	if not is_hero_selected():
		return "Left click Hero to select."
	if pending_action != PendingAction.NONE:
		return "Right click to cancel current targeting mode."
	return "Left click a green tile to move, or press a skill button."


func update_ui() -> void:
	turn_label.text = "Turn: %s" % ("Player" if current_turn == TurnSide.PLAYER and not battle_over else "Enemy")
	if battle_over:
		turn_label.text = "Turn: Battle Over"

	mode_label.text = "Mode: %s" % get_mode_text()

	if is_instance_valid(player_unit):
		player_hp_label.text = "Player HP: %d / %d" % [player_unit.hp, player_unit.max_hp]
		player_qi_label.text = "Player Qi: %d / %d" % [player_unit.qi, player_unit.max_qi]
		player_stance_label.text = "Player Stance: %s" % player_unit.get_stance_name()
	else:
		player_hp_label.text = "Player HP: 0 / 100"
		player_qi_label.text = "Player Qi: 0 / 10"
		player_stance_label.text = "Player Stance: Down"

	if is_instance_valid(selected_unit):
		var selected_qi_text := ""
		if selected_unit.uses_qi:
			selected_qi_text = " / Qi %d" % selected_unit.qi
		selected_label.text = "Selected: %s / HP %d / Stance %s%s" % [selected_unit.display_name, selected_unit.hp, selected_unit.get_stance_name(), selected_qi_text]
	else:
		selected_label.text = "Selected: None"

	message_label.text = "Status: %s" % status_message
	hint_label.text = get_hint_text()

	var can_player_operate := not battle_over and current_turn == TurnSide.PLAYER and is_hero_selected()
	var has_adjacent_enemy := can_player_operate and not get_attackable_enemy_cells(player_unit).is_empty()

	var action_spent := true
	var can_pay_light := false
	var can_pay_split := false
	if can_player_operate:
		action_spent = player_unit.has_acted
		can_pay_light = player_unit.can_afford(2)
		can_pay_split = player_unit.can_afford(3)

	light_step_button.disabled = not can_player_operate or action_spent or not can_pay_light or player_unit.has_moved
	split_palm_button.disabled = not can_player_operate or action_spent or not can_pay_split or not has_adjacent_enemy
	iron_wall_button.disabled = not can_player_operate or action_spent or not can_pay_light
	attack_button.disabled = not can_player_operate or action_spent or not has_adjacent_enemy
	end_turn_button.disabled = battle_over or current_turn != TurnSide.PLAYER

	light_step_button.text = "Qinggong Step" if pending_action != PendingAction.QINGGONG_STEP else "Qinggong Step [Armed]"
	attack_button.text = "Normal Attack" if pending_action != PendingAction.NORMAL_ATTACK else "Normal Attack [Armed]"
	split_palm_button.text = "Split Palm" if pending_action != PendingAction.SPLIT_PALM else "Split Palm [Armed]"
