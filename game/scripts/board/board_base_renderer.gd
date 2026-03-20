extends RefCounted
class_name BoardBaseRenderer


func draw(layer: Node2D, grid) -> void:
	var plain_texture: Texture2D = grid._get_plain_texture()
	var board_backdrop: Rect2 = grid.board_rect.grow(6.0)
	layer.draw_rect(board_backdrop, Color(0.04, 0.04, 0.04, 0.12), true)
	layer.draw_rect(board_backdrop, Color(0.78, 0.72, 0.64, 0.10), false, 1.0)

	for y in range(grid.rows):
		for x in range(grid.columns):
			var cell := Vector2i(x, y)
			var rect: Rect2 = grid._cell_rect(cell).grow(-0.5)
			var base_color := Color(1.0, 1.0, 1.0, 0.18) if (x + y) % 2 == 0 else Color(0.94, 0.95, 0.96, 0.12)
			layer.draw_rect(rect, base_color, true)
			if plain_texture != null:
				layer.draw_texture_rect(plain_texture, rect, false, Color(1.0, 1.0, 1.0, 0.90))

	for x in range(grid.columns + 1):
		var line_x: float = grid.board_rect.position.x + float(x) * grid.cell_size.x
		layer.draw_line(
			Vector2(line_x, grid.board_rect.position.y),
			Vector2(line_x, grid.board_rect.position.y + grid.board_rect.size.y),
			Color(0.12, 0.11, 0.10, 0.24),
			1.0,
			true
		)

	for y in range(grid.rows + 1):
		var line_y: float = grid.board_rect.position.y + float(y) * grid.cell_size.y
		layer.draw_line(
			Vector2(grid.board_rect.position.x, line_y),
			Vector2(grid.board_rect.position.x + grid.board_rect.size.x, line_y),
			Color(0.12, 0.11, 0.10, 0.24),
			1.0,
			true
		)

	layer.draw_rect(grid.board_rect, Color(0.18, 0.16, 0.14, 0.28), false, 1.0)
