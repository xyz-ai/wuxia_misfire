extends Node2D
class_name GridManager

const HIGHLIGHT_COLORS := {
	"move": {
		"fill": Color(0.30, 0.66, 0.46, 0.15),
		"line": Color(0.45, 0.80, 0.60, 0.46)
	},
	"attack": {
		"fill": Color(0.84, 0.36, 0.32, 0.16),
		"line": Color(0.92, 0.58, 0.50, 0.52)
	},
	"qinggong": {
		"fill": Color(0.28, 0.56, 0.86, 0.14),
		"line": Color(0.52, 0.76, 0.96, 0.44)
	},
	"invalid": {
		"fill": Color(0.28, 0.14, 0.16, 0.08),
		"line": Color(0.64, 0.34, 0.38, 0.40)
	},
	"cursor": {
		"line": Color(1.00, 0.92, 0.56, 0.72),
		"accent": Color(1.00, 0.96, 0.82, 0.54)
	}
}

@export var columns := 8
@export var rows := 8
@export var min_cell_size := 24.0
@export var max_cell_size := 84.0

var selected_cell := Vector2i(-1, -1)
var terrain_map: Dictionary = {}
var terrain_defs: Dictionary = {}
var texture_cache: Dictionary = {}
var highlights := {
	"move": [],
	"qinggong": [],
	"attack": [],
	"invalid": []
}

var cell_size := Vector2(48.0, 48.0)
var board_rect := Rect2(448.0, 56.0, 384.0, 384.0)
var _reserved_rect := Rect2(48.0, 56.0, 1184.0, 384.0)

@onready var grid_base_layer: BoardCanvasLayer = $GridBase
@onready var terrain_layer: BoardCanvasLayer = $TerrainLayer
@onready var move_range_layer: BoardCanvasLayer = $HighlightLayer/MoveRangeLayer
@onready var attack_range_layer: BoardCanvasLayer = $HighlightLayer/AttackRangeLayer
@onready var skill_range_layer: BoardCanvasLayer = $HighlightLayer/SkillRangeLayer
@onready var cursor_layer: BoardCanvasLayer = $HighlightLayer/CursorLayer
@onready var facing_marker_layer: Node2D = $OverlayLayer/FacingMarkerLayer


func is_in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < columns and cell.y >= 0 and cell.y < rows


func configure_board(board_columns: int, board_rows: int, next_terrain_map: Dictionary, next_terrain_defs: Dictionary = {}) -> void:
	columns = board_columns
	rows = board_rows
	terrain_map = next_terrain_map.duplicate(true)
	terrain_defs = next_terrain_defs.duplicate(true)
	selected_cell = Vector2i(-1, -1)
	clear_highlights()
	_queue_all_layers()


func relayout_board(viewport_size: Vector2, reserved_rect: Rect2) -> void:
	_reserved_rect = reserved_rect
	var available_width := maxf(1.0, reserved_rect.size.x)
	var available_height := maxf(1.0, reserved_rect.size.y)
	var raw_cell_size: float = floorf(minf(
		available_width / maxf(float(columns), 1.0),
		available_height / maxf(float(rows), 1.0)
	))
	var pixel_size := clampf(raw_cell_size, min_cell_size, max_cell_size)
	cell_size = Vector2(pixel_size, pixel_size)

	var board_size := Vector2(float(columns), float(rows)) * cell_size
	board_rect = Rect2(
		reserved_rect.position + (reserved_rect.size - board_size) * 0.5,
		board_size
	)
	_queue_all_layers()


func grid_to_world(cell: Vector2i) -> Vector2:
	return global_position + _cell_origin(cell) + cell_size * 0.5


func world_to_cell(world_position: Vector2) -> Vector2i:
	var local_position := world_position - global_position
	if not board_rect.has_point(local_position):
		return Vector2i(-1, -1)

	var x := floori((local_position.x - board_rect.position.x) / maxf(cell_size.x, 1.0))
	var y := floori((local_position.y - board_rect.position.y) / maxf(cell_size.y, 1.0))
	var cell := Vector2i(x, y)
	return cell if is_in_bounds(cell) else Vector2i(-1, -1)


func clear_highlights() -> void:
	highlights = {
		"move": [],
		"qinggong": [],
		"attack": [],
		"invalid": []
	}
	_queue_highlight_layers()


func set_highlights(next_highlights: Dictionary) -> void:
	highlights = {
		"move": _to_cell_array(next_highlights.get("move", [])),
		"qinggong": _to_cell_array(next_highlights.get("qinggong", [])),
		"attack": _to_cell_array(next_highlights.get("attack", [])),
		"invalid": _to_cell_array(next_highlights.get("invalid", []))
	}
	_queue_highlight_layers()


func set_selected_cell(cell: Vector2i) -> void:
	selected_cell = cell
	if cursor_layer != null:
		cursor_layer.redraw()


func refresh_board_layers() -> void:
	_queue_all_layers()


func _draw_grid_base_layer(layer: Node2D) -> void:
	var plain_texture := _get_plain_texture()
	var board_backdrop := board_rect.grow(6.0)
	layer.draw_rect(board_backdrop, Color(0.04, 0.05, 0.07, 0.08), true)
	layer.draw_rect(board_backdrop, Color(0.82, 0.84, 0.88, 0.04), false, 1.0)

	for y in range(rows):
		for x in range(columns):
			var cell := Vector2i(x, y)
			var rect := _cell_rect(cell).grow(-0.5)
			var base_color := Color(1.0, 1.0, 1.0, 0.14) if (x + y) % 2 == 0 else Color(0.94, 0.95, 0.96, 0.10)
			layer.draw_rect(rect, base_color, true)
			if plain_texture != null:
				layer.draw_texture_rect(plain_texture, rect, false, Color(1.0, 1.0, 1.0, 0.82))

	for x in range(columns + 1):
		var line_x := board_rect.position.x + float(x) * cell_size.x
		layer.draw_line(
			Vector2(line_x, board_rect.position.y),
			Vector2(line_x, board_rect.position.y + board_rect.size.y),
			Color(0.12, 0.14, 0.18, 0.18),
			1.0,
			true
		)

	for y in range(rows + 1):
		var line_y := board_rect.position.y + float(y) * cell_size.y
		layer.draw_line(
			Vector2(board_rect.position.x, line_y),
			Vector2(board_rect.position.x + board_rect.size.x, line_y),
			Color(0.12, 0.14, 0.18, 0.18),
			1.0,
			true
		)

	layer.draw_rect(board_rect, Color(0.10, 0.11, 0.14, 0.20), false, 1.0)


func _draw_terrain_layer(layer: Node2D) -> void:
	for y in range(rows):
		for x in range(columns):
			var cell := Vector2i(x, y)
			var terrain_type := _terrain_type_at(cell)
			if terrain_type == "plain":
				continue

			var terrain_rule: Dictionary = terrain_defs.get(terrain_type, {})
			var base_texture := _load_texture(String(terrain_rule.get("base_texture_path", "")))
			var overlay_texture := _load_texture(String(terrain_rule.get("overlay_texture_path", "")))
			var rect := _cell_rect(cell).grow(-1.5)
			if base_texture != null:
				layer.draw_texture_rect(base_texture, rect, false, Color(1.0, 1.0, 1.0, 0.42))
			if overlay_texture != null:
				layer.draw_texture_rect(overlay_texture, rect, false, Color(1.0, 1.0, 1.0, 0.94))
			else:
				layer.draw_rect(rect, _terrain_fallback_color(terrain_type), true)
			layer.draw_rect(rect, Color(0.12, 0.14, 0.18, 0.14), false, 1.0)


func _draw_move_range_layer(layer: Node2D) -> void:
	_draw_cells_with_style(layer, highlights.get("move", []), HIGHLIGHT_COLORS["move"])


func _draw_attack_range_layer(layer: Node2D) -> void:
	_draw_cells_with_style(layer, highlights.get("attack", []), HIGHLIGHT_COLORS["attack"])


func _draw_skill_range_layer(layer: Node2D) -> void:
	_draw_cells_with_style(layer, highlights.get("qinggong", []), HIGHLIGHT_COLORS["qinggong"])
	_draw_cells_with_style(layer, highlights.get("invalid", []), HIGHLIGHT_COLORS["invalid"], true)


func _draw_cursor_layer(layer: Node2D) -> void:
	if not is_in_bounds(selected_cell):
		return
	var rect := _cell_rect(selected_cell).grow(-4.0)
	layer.draw_rect(rect, Color(1.0, 0.98, 0.90, 0.04), true)
	layer.draw_rect(rect, HIGHLIGHT_COLORS["cursor"]["line"], false, 1.5)
	var accent := HIGHLIGHT_COLORS["cursor"]["accent"]
	var corner := 6.0
	layer.draw_line(rect.position, rect.position + Vector2(corner, 0.0), accent, 2.0, true)
	layer.draw_line(rect.position, rect.position + Vector2(0.0, corner), accent, 2.0, true)
	layer.draw_line(rect.position + Vector2(rect.size.x, 0.0), rect.position + Vector2(rect.size.x - corner, 0.0), accent, 2.0, true)
	layer.draw_line(rect.position + Vector2(rect.size.x, 0.0), rect.position + Vector2(rect.size.x, corner), accent, 2.0, true)
	layer.draw_line(rect.position + Vector2(0.0, rect.size.y), rect.position + Vector2(corner, rect.size.y), accent, 2.0, true)
	layer.draw_line(rect.position + Vector2(0.0, rect.size.y), rect.position + Vector2(0.0, rect.size.y - corner), accent, 2.0, true)
	layer.draw_line(rect.position + rect.size, rect.position + Vector2(rect.size.x - corner, rect.size.y), accent, 2.0, true)
	layer.draw_line(rect.position + rect.size, rect.position + Vector2(rect.size.x, rect.size.y - corner), accent, 2.0, true)


func _draw_cells_with_style(layer: Node2D, cells: Array, style: Dictionary, draw_invalid_cross: bool = false) -> void:
	for cell in cells:
		if not (cell is Vector2i) or not is_in_bounds(cell):
			continue
		var rect := _cell_rect(cell).grow(-4.0)
		layer.draw_rect(rect, style["fill"], true)
		layer.draw_rect(rect, style["line"], false, 1.0)
		if draw_invalid_cross:
			layer.draw_line(rect.position + Vector2(7.0, 7.0), rect.position + rect.size - Vector2(7.0, 7.0), style["line"], 1.0, true)
			layer.draw_line(rect.position + Vector2(rect.size.x - 7.0, 7.0), rect.position + Vector2(7.0, rect.size.y - 7.0), style["line"], 1.0, true)


func _cell_rect(cell: Vector2i) -> Rect2:
	return Rect2(_cell_origin(cell), cell_size)


func _cell_origin(cell: Vector2i) -> Vector2:
	return board_rect.position + Vector2(float(cell.x), float(cell.y)) * cell_size


func _terrain_type_at(cell: Vector2i) -> String:
	return String(terrain_map.get(_cell_key(cell), "plain"))


func _terrain_fallback_color(terrain_type: String) -> Color:
	match terrain_type:
		"stone":
			return Color(0.42, 0.45, 0.49, 0.82)
		"water":
			return Color(0.25, 0.43, 0.58, 0.78)
		"grass":
			return Color(0.43, 0.58, 0.36, 0.76)
		_:
			return Color(0.62, 0.62, 0.62, 0.40)


func _get_plain_texture() -> Texture2D:
	var plain_rule: Dictionary = terrain_defs.get("plain", {})
	return _load_texture(String(plain_rule.get("base_texture_path", "")))


func _load_texture(path: String) -> Texture2D:
	if path.is_empty():
		return null
	if texture_cache.has(path):
		return texture_cache[path]
	var texture = load(path)
	if texture is Texture2D:
		texture_cache[path] = texture
		return texture
	return null


func _queue_all_layers() -> void:
	if not is_node_ready():
		return
	for layer in [grid_base_layer, terrain_layer, move_range_layer, attack_range_layer, skill_range_layer, cursor_layer]:
		if layer != null:
			layer.redraw()
	if facing_marker_layer != null:
		facing_marker_layer.queue_redraw()


func _queue_highlight_layers() -> void:
	if not is_node_ready():
		return
	for layer in [move_range_layer, attack_range_layer, skill_range_layer, cursor_layer]:
		if layer != null:
			layer.redraw()


func _cell_key(cell: Vector2i) -> String:
	return "%d,%d" % [cell.x, cell.y]


func _to_cell_array(raw_value) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if raw_value is Array:
		for cell in raw_value:
			if cell is Vector2i:
				result.append(cell)
	return result
