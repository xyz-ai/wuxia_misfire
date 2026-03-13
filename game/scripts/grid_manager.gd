extends Node2D
class_name GridManager

@export var columns := 7
@export var rows := 5
@export var cell_size := 84
@export var board_origin := Vector2(0, 0)

var move_highlights: Array[Vector2i] = []
var attack_highlights: Array[Vector2i] = []
var selected_cell := Vector2i(-1, -1)


func _draw() -> void:
	var board_rect := Rect2(board_origin, Vector2(columns * cell_size, rows * cell_size))
	draw_rect(board_rect.grow(6.0), Color(0.08, 0.08, 0.08, 0.95), true)

	for y in range(rows):
		for x in range(columns):
			var cell := Vector2i(x, y)
			var rect := cell_to_rect(cell)
			var tile_color := Color(0.83, 0.79, 0.68, 1.0) if (x + y) % 2 == 0 else Color(0.76, 0.71, 0.60, 1.0)
			draw_rect(rect, tile_color, true)
			draw_rect(rect, Color(0.2, 0.16, 0.10, 1.0), false, 2.0)

	for cell in move_highlights:
		draw_rect(cell_to_rect(cell).grow(-5.0), Color(0.23, 0.70, 0.38, 0.45), true)

	for cell in attack_highlights:
		draw_rect(cell_to_rect(cell).grow(-5.0), Color(0.85, 0.22, 0.22, 0.45), true)

	if is_in_bounds(selected_cell):
		draw_rect(cell_to_rect(selected_cell).grow(-3.0), Color(1.0, 0.93, 0.40, 0.95), false, 4.0)


func is_in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < columns and cell.y >= 0 and cell.y < rows


func cell_to_rect(cell: Vector2i) -> Rect2:
	return Rect2(board_origin + Vector2(cell.x * cell_size, cell.y * cell_size), Vector2(cell_size, cell_size))


func grid_to_world(cell: Vector2i) -> Vector2:
	var local_center := board_origin + Vector2(cell.x * cell_size + cell_size / 2.0, cell.y * cell_size + cell_size / 2.0)
	return global_position + local_center


func world_to_cell(world_position: Vector2) -> Vector2i:
	var local_position := world_position - global_position - board_origin
	return Vector2i(floori(local_position.x / cell_size), floori(local_position.y / cell_size))


func clear_highlights() -> void:
	move_highlights.clear()
	attack_highlights.clear()
	queue_redraw()


func set_highlights(moves: Array[Vector2i], attacks: Array[Vector2i]) -> void:
	move_highlights = moves.duplicate()
	attack_highlights = attacks.duplicate()
	queue_redraw()


func set_selected_cell(cell: Vector2i) -> void:
	selected_cell = cell
	queue_redraw()
