extends Node2D
class_name BattleUnit

enum Stance {
	NONE = -1,
	YOUSHEN = 0,
	FAJIN = 1,
	SHOUSHI = 2,
}

const STANCE_NAMES := {
	Stance.NONE: "None",
	Stance.YOUSHEN: "YouShen",
	Stance.FAJIN: "FaJin",
	Stance.SHOUSHI: "ShouShi",
}

const COUNTERS := {
	Stance.YOUSHEN: Stance.SHOUSHI,
	Stance.SHOUSHI: Stance.FAJIN,
	Stance.FAJIN: Stance.YOUSHEN,
}

@export var display_name := "Unit"
@export var is_player := false
@export var max_hp := 100
@export var max_qi := 10
@export var start_qi := 10
@export var qi_per_turn := 2
@export var base_move := 2
@export var base_attack := 10
@export var uses_qi := true
@export var fill_color := Color(0.25, 0.65, 0.95, 1.0)
@export var outline_color := Color(0.07, 0.07, 0.07, 1.0)

var hp := 0
var qi := 0
var grid_position := Vector2i.ZERO
var current_stance: int = Stance.NONE
var temporary_guard := false
var temporary_move_bonus := 0
var has_moved := false
var has_acted := false
var selected := false


func _ready() -> void:
	initialize_for_battle()


func initialize_for_battle() -> void:
	hp = max_hp
	qi = start_qi
	current_stance = Stance.NONE
	temporary_guard = false
	temporary_move_bonus = 0
	has_moved = false
	has_acted = false
	selected = false
	queue_redraw()


func begin_turn() -> void:
	if temporary_guard:
		clear_stance()
	temporary_move_bonus = 0
	has_moved = false
	has_acted = false
	recover_qi(qi_per_turn)
	queue_redraw()


func set_selected(value: bool) -> void:
	selected = value
	queue_redraw()


func set_grid_position(cell: Vector2i, world_position: Vector2) -> void:
	grid_position = cell
	position = world_position
	queue_redraw()


func get_stance_name() -> String:
	return STANCE_NAMES.get(current_stance, "None")


func has_active_stance() -> bool:
	return current_stance != Stance.NONE


func clear_stance() -> void:
	current_stance = Stance.NONE
	temporary_guard = false
	queue_redraw()


func set_stance(stance: int, temporary := false) -> void:
	current_stance = stance
	temporary_guard = temporary and stance == Stance.SHOUSHI
	queue_redraw()


func get_move_capacity() -> int:
	var total_move := base_move + temporary_move_bonus
	if current_stance == Stance.YOUSHEN:
		total_move += 1
	return total_move


func can_afford(cost: int) -> bool:
	return not uses_qi or qi >= cost


func spend_qi(cost: int) -> bool:
	if not can_afford(cost):
		return false
	if uses_qi:
		qi = max(qi - cost, 0)
		queue_redraw()
	return true


func recover_qi(amount: int) -> void:
	if not uses_qi:
		return
	qi = min(qi + amount, max_qi)
	queue_redraw()


func apply_light_step() -> bool:
	if has_acted or not spend_qi(2):
		return false
	temporary_move_bonus += 2
	has_acted = true
	set_stance(Stance.YOUSHEN)
	queue_redraw()
	return true


func apply_iron_wall() -> bool:
	if has_acted or not spend_qi(2):
		return false
	has_acted = true
	set_stance(Stance.SHOUSHI, true)
	queue_redraw()
	return true


func calculate_damage_against(defender: BattleUnit, base_damage: int) -> int:
	var total_damage := float(base_damage)
	if current_stance == Stance.FAJIN:
		total_damage *= 1.5
	if defender.current_stance == Stance.SHOUSHI:
		total_damage *= 0.5
	if has_active_stance() and defender.has_active_stance():
		if COUNTERS.get(current_stance, Stance.NONE) == defender.current_stance:
			total_damage *= 2.0
		elif COUNTERS.get(defender.current_stance, Stance.NONE) == current_stance:
			total_damage *= 0.5
	return max(1, int(round(total_damage)))


func take_damage(amount: int) -> int:
	hp = max(hp - amount, 0)
	queue_redraw()
	return amount


func is_dead() -> bool:
	return hp <= 0


func _draw() -> void:
	var body_radius := 28.0
	var body_color := fill_color
	if is_dead():
		body_color = fill_color.darkened(0.5)
	draw_circle(Vector2.ZERO, body_radius, body_color)
	draw_arc(Vector2.ZERO, body_radius, 0.0, TAU, 32, outline_color, 3.0)
	if selected:
		draw_arc(Vector2.ZERO, body_radius + 8.0, 0.0, TAU, 32, Color(1.0, 0.95, 0.45, 1.0), 4.0)

	var font := ThemeDB.fallback_font
	if font == null:
		return

	var title_color := Color(1.0, 1.0, 1.0, 1.0)
	var hp_color := Color(0.95, 0.95, 0.95, 1.0)
	draw_string(font, Vector2(-54.0, -40.0), display_name, HORIZONTAL_ALIGNMENT_CENTER, 108.0, 16, title_color)
	draw_string(font, Vector2(-50.0, 52.0), "HP %d" % hp, HORIZONTAL_ALIGNMENT_CENTER, 100.0, 15, hp_color)
	draw_string(font, Vector2(-50.0, 70.0), get_stance_name(), HORIZONTAL_ALIGNMENT_CENTER, 100.0, 14, Color(0.88, 0.88, 0.72, 1.0))
