extends RefCounted
class_name BoardTerrainRenderer


func draw(layer: Node2D, grid) -> void:
	for y in range(grid.rows):
		for x in range(grid.columns):
			var cell := Vector2i(x, y)
			var terrain_type: String = grid._terrain_type_at(cell)
			if terrain_type == "plain":
				continue

			var terrain_rule: Dictionary = grid.terrain_defs.get(terrain_type, {})
			var base_texture: Texture2D = grid._load_texture(String(terrain_rule.get("base_texture_path", "")))
			var overlay_texture: Texture2D = grid._load_texture(String(terrain_rule.get("overlay_texture_path", "")))
			var rect: Rect2 = grid._cell_rect(cell).grow(-1.5)
			if base_texture != null:
				layer.draw_texture_rect(base_texture, rect, false, Color(1.0, 1.0, 1.0, 0.52))
			if overlay_texture != null:
				layer.draw_texture_rect(overlay_texture, rect, false, Color(1.0, 1.0, 1.0, 0.94))
			else:
				layer.draw_rect(rect, grid._terrain_fallback_color(terrain_type), true)
			layer.draw_rect(rect, Color(0.16, 0.14, 0.12, 0.22), false, 1.0)
