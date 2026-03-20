extends RefCounted
class_name BoardHighlightRenderer

const BattleVisuals = preload("res://scripts/ui/battle_visuals.gd")


func draw_move(layer: Node2D, grid) -> void:
	_draw_cells_with_style(layer, grid, grid.highlights.get("move", []), "move", grid.HIGHLIGHT_COLORS["move"], false, -2.5, 0.82)


func draw_attack(layer: Node2D, grid) -> void:
	_draw_cells_with_style(layer, grid, grid.highlights.get("attack", []), "attack_range", grid.HIGHLIGHT_COLORS["attack"], false, -2.5, 0.86)


func draw_skill(layer: Node2D, grid) -> void:
	_draw_cells_with_style(layer, grid, grid.highlights.get("qinggong", []), "qinggong", grid.HIGHLIGHT_COLORS["qinggong"], false, -2.5, 0.84)
	_draw_cells_with_style(layer, grid, grid.highlights.get("invalid", []), "", grid.HIGHLIGHT_COLORS["invalid"], true, -2.5, 0.84)


func draw_cursor(layer: Node2D, grid) -> void:
	_draw_cells_with_style(layer, grid, grid.highlights.get("target", []), "target", grid.HIGHLIGHT_COLORS["target"], false, -2.5, 0.92)
	if not grid.is_in_bounds(grid.selected_cell):
		return
	var texture := BattleVisuals.get_highlight_texture("selected")
	var rect: Rect2 = grid._cell_rect(grid.selected_cell).grow(-1.5)
	if texture != null:
		layer.draw_texture_rect(texture, rect, false, Color(1.0, 1.0, 1.0, 0.94))
		return

	rect = grid._cell_rect(grid.selected_cell).grow(-4.0)
	layer.draw_rect(rect, Color(1.0, 0.98, 0.90, 0.04), true)
	layer.draw_rect(rect, grid.HIGHLIGHT_COLORS["cursor"]["line"], false, 1.5)
	var accent: Color = grid.HIGHLIGHT_COLORS["cursor"]["accent"]
	var corner := 6.0
	layer.draw_line(rect.position, rect.position + Vector2(corner, 0.0), accent, 2.0, true)
	layer.draw_line(rect.position, rect.position + Vector2(0.0, corner), accent, 2.0, true)
	layer.draw_line(rect.position + Vector2(rect.size.x, 0.0), rect.position + Vector2(rect.size.x - corner, 0.0), accent, 2.0, true)
	layer.draw_line(rect.position + Vector2(rect.size.x, 0.0), rect.position + Vector2(rect.size.x, corner), accent, 2.0, true)
	layer.draw_line(rect.position + Vector2(0.0, rect.size.y), rect.position + Vector2(corner, rect.size.y), accent, 2.0, true)
	layer.draw_line(rect.position + Vector2(0.0, rect.size.y), rect.position + Vector2(0.0, rect.size.y - corner), accent, 2.0, true)
	layer.draw_line(rect.position + rect.size, rect.position + Vector2(rect.size.x - corner, rect.size.y), accent, 2.0, true)
	layer.draw_line(rect.position + rect.size, rect.position + Vector2(rect.size.x, rect.size.y - corner), accent, 2.0, true)


func _draw_cells_with_style(
	layer: Node2D,
	grid,
	cells: Array,
	texture_id: String,
	style: Dictionary,
	draw_invalid_cross: bool = false,
	grow_amount: float = -2.5,
	texture_alpha: float = 0.86
) -> void:
	var texture := BattleVisuals.get_highlight_texture(texture_id)
	for cell in cells:
		if not (cell is Vector2i) or not grid.is_in_bounds(cell):
			continue
		var rect: Rect2 = grid._cell_rect(cell).grow(grow_amount)
		if texture != null:
			layer.draw_texture_rect(texture, rect, false, Color(1.0, 1.0, 1.0, texture_alpha))
			continue
		layer.draw_rect(rect, style["fill"], true)
		layer.draw_rect(rect, style["line"], false, 1.0)
		if draw_invalid_cross:
			layer.draw_line(rect.position + Vector2(7.0, 7.0), rect.position + rect.size - Vector2(7.0, 7.0), style["line"], 1.0, true)
			layer.draw_line(rect.position + Vector2(rect.size.x - 7.0, 7.0), rect.position + Vector2(7.0, rect.size.y - 7.0), style["line"], 1.0, true)
