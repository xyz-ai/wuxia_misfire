extends Node2D

const BattleTexts = preload("res://scripts/core/battle_texts.gd")
const BattleVisuals = preload("res://scripts/ui/battle_visuals.gd")

var unit_id := ""
var template_id := ""
var display_name := "Unit"
var team := "neutral"
var faction := ""
var personality := ""
var tags: Array[String] = []
var skills: Array[String] = []
var inventory: Array[Dictionary] = []
var visuals: Dictionary = {}
var is_player := false

var max_hp := 100
var hp := 100
var max_qi := 0
var qi := 0
var start_qi := 0
var qi_per_turn := 0
var base_move := 3
var base_attack := 10
var uses_qi := false

var current_stance := "none"
var statuses: Dictionary = {}
var runtime_tags: Dictionary = {}
var turn_state: Dictionary = {}

var grid_position := Vector2i.ZERO
var facing := Vector2i.RIGHT
var selected := false
var active_turn := false
var hovered := false

var fill_color := Color(0.25, 0.65, 0.95, 1.0)
var outline_color := Color(0.07, 0.07, 0.07, 1.0)
var battlefield_texture: Texture2D
var portrait_texture: Texture2D
var icon_texture: Texture2D
var battlefield_scale := 1.0
var foot_anchor_offset := Vector2.ZERO
var board_cell_size := Vector2(48.0, 48.0)

var visual_root: Node2D
var sprite_node: Sprite2D


func _ready() -> void:
	_ensure_visual_nodes()
	_apply_visual_resources()
	queue_redraw()


func setup_from_data(instance_id: String, template_data: Dictionary, override_data: Dictionary, team_name: String, facing_vector: Vector2i) -> void:
	unit_id = instance_id
	template_id = String(template_data.get("id", override_data.get("template_id", "")))
	display_name = String(override_data.get("display_name", template_data.get("display_name", instance_id)))
	team = team_name
	is_player = bool(template_data.get("is_player", team_name == "player"))
	faction = String(override_data.get("faction", template_data.get("faction", "")))
	personality = String(override_data.get("personality", template_data.get("personality", "")))
	tags = _to_string_array(override_data.get("tags", template_data.get("tags", [])))
	skills = _to_string_array(override_data.get("skills", template_data.get("skills", [])))
	inventory = _to_inventory_array(override_data.get("inventory", template_data.get("inventory", [])))

	max_hp = int(template_data.get("max_hp", 100))
	hp = int(override_data.get("hp", max_hp))
	max_qi = int(template_data.get("max_qi", 0))
	start_qi = int(template_data.get("start_qi", max_qi))
	qi = int(override_data.get("qi", start_qi))
	qi_per_turn = int(template_data.get("qi_per_turn", 0))
	base_move = int(template_data.get("base_move", 3))
	base_attack = int(template_data.get("base_attack", 10))
	uses_qi = bool(template_data.get("uses_qi", false))
	current_stance = String(override_data.get("stance", "none"))
	fill_color = _color_from_data(template_data.get("fill_color", [0.25, 0.65, 0.95, 1.0]), fill_color)
	outline_color = _color_from_data(template_data.get("outline_color", [0.07, 0.07, 0.07, 1.0]), outline_color)

	visuals = _merged_visuals(template_data.get("visuals", {}), override_data.get("visuals", {}))
	battlefield_texture = _load_texture(String(visuals.get("battlefield_texture_path", "")))
	portrait_texture = _load_texture(String(visuals.get("portrait_texture_path", "")))
	icon_texture = _load_texture(String(visuals.get("icon_texture_path", "")))
	battlefield_scale = float(visuals.get("battlefield_scale", 1.0))
	foot_anchor_offset = _vector2_from_array(visuals.get("foot_anchor_offset", [0.0, 0.0]))

	statuses.clear()
	runtime_tags.clear()
	turn_state.clear()
	selected = false
	active_turn = false
	hovered = false
	if override_data.get("facing", null) is Array:
		set_facing(_array_to_cell(override_data.get("facing", [])))
	else:
		set_facing(facing_vector)
	_apply_visual_resources()
	queue_redraw()


func set_grid_cell(cell: Vector2i, world_position: Vector2 = Vector2.INF) -> void:
	grid_position = cell
	if world_position.is_finite():
		position = world_position
	z_index = cell.y
	queue_redraw()


func set_selected(value: bool) -> void:
	selected = value
	queue_redraw()


func set_active_turn(value: bool) -> void:
	active_turn = value
	queue_redraw()


func set_hovered(value: bool) -> void:
	if hovered == value:
		return
	hovered = value
	queue_redraw()


func set_board_visual_metrics(next_cell_size: Vector2) -> void:
	if next_cell_size.x <= 0.0 or next_cell_size.y <= 0.0:
		return
	board_cell_size = next_cell_size
	_apply_visual_resources()
	queue_redraw()


func set_facing(next_facing: Vector2i) -> void:
	var normalized := _normalize_facing(next_facing)
	if normalized == Vector2i.ZERO:
		return
	facing = normalized
	_apply_facing_visual()
	queue_redraw()


func get_facing_id() -> String:
	if facing == Vector2i.UP:
		return "up"
	if facing == Vector2i.DOWN:
		return "down"
	if facing == Vector2i.LEFT:
		return "left"
	if facing == Vector2i.RIGHT:
		return "right"
	return "none"


func get_front_cell() -> Vector2i:
	return grid_position + facing


func get_back_cell() -> Vector2i:
	return grid_position - facing


func get_side_cells() -> Array[Vector2i]:
	return [
		grid_position + Vector2i(-facing.y, facing.x),
		grid_position + Vector2i(facing.y, -facing.x)
	]


func get_portrait_texture() -> Texture2D:
	return portrait_texture if portrait_texture != null else battlefield_texture


func get_icon_texture() -> Texture2D:
	return icon_texture if icon_texture != null else get_portrait_texture()


func get_inventory_entries() -> Array[Dictionary]:
	return inventory.duplicate(true)


func get_item_quantity(item_id: String) -> int:
	for entry in inventory:
		if String(entry.get("item_id", "")) == item_id:
			return int(entry.get("quantity", 0))
	return 0


func has_item(item_id: String, amount: int = 1) -> bool:
	return get_item_quantity(item_id) >= amount


func consume_item(item_id: String, amount: int = 1) -> bool:
	for index in range(inventory.size()):
		var entry: Dictionary = inventory[index]
		if String(entry.get("item_id", "")) != item_id:
			continue
		var next_quantity := int(entry.get("quantity", 0)) - amount
		if next_quantity < 0:
			return false
		if next_quantity == 0:
			inventory.remove_at(index)
		else:
			entry["quantity"] = next_quantity
			inventory[index] = entry
		return true
	return false


func is_alive() -> bool:
	return hp > 0


func is_enemy_of(other) -> bool:
	return other != null and team != other.team


func get_stat(stat_name: String) -> float:
	match stat_name:
		"max_hp":
			return max_hp
		"hp":
			return hp
		"max_qi":
			return max_qi
		"qi":
			return qi
		"base_move":
			return base_move
		"base_attack":
			return base_attack
		"remaining_move":
			return float(turn_state.get("remaining_move", base_move))
		_:
			return 0.0


func get_status_stacks(status_id: String) -> int:
	if not statuses.has(status_id):
		return 0
	return int(statuses[status_id].get("stacks", 0))


func set_status_stacks(status_id: String, stacks: int, payload: Dictionary = {}) -> void:
	if stacks <= 0:
		statuses.erase(status_id)
	else:
		var next_payload := payload.duplicate(true)
		next_payload["stacks"] = stacks
		statuses[status_id] = next_payload
	queue_redraw()


func clear_status(status_id: String) -> void:
	statuses.erase(status_id)
	queue_redraw()


func modify_hp(delta: int) -> void:
	hp = clampi(hp + delta, 0, max_hp)
	queue_redraw()


func modify_qi(delta: int) -> void:
	if not uses_qi:
		return
	qi = clampi(qi + delta, 0, max_qi)
	queue_redraw()


func _draw() -> void:
	var show_name := selected or active_turn or hovered
	var show_direction := show_name
	_draw_shadow(Color(0.02, 0.03, 0.05, 0.28) if is_alive() else Color(0.02, 0.03, 0.05, 0.16))
	_draw_selection_state(show_name)
	_draw_direction_marker(show_direction)
	_draw_overhead_info()
	_draw_name_label(show_name)


func _draw_shadow(color: Color) -> void:
	var shadow_radius_x := clampf(board_cell_size.x * 0.26 * battlefield_scale, board_cell_size.x * 0.18, board_cell_size.x * 0.34)
	var shadow_radius_y := shadow_radius_x * 0.34
	var shadow := PackedVector2Array(_make_ellipse(Vector2(0.0, 3.0), shadow_radius_x, shadow_radius_y))
	draw_colored_polygon(shadow, color)


func _draw_selection_state(show_name: bool) -> void:
	var ring_radius_x := clampf(board_cell_size.x * 0.30, 12.0, 24.0)
	var ring_radius_y := ring_radius_x * 0.42
	var ring_color := Color(1.0, 0.88, 0.46, 0.68) if selected else Color(0.50, 0.82, 0.94, 0.22)
	var ring_width := 1.6 if selected else 1.0
	if selected or active_turn:
		_draw_polyline_closed(_make_ellipse(Vector2.ZERO, ring_radius_x, ring_radius_y), ring_color, ring_width)
	if active_turn:
		_draw_polyline_closed(
			_make_ellipse(Vector2.ZERO, ring_radius_x + 5.0, ring_radius_y + 2.0),
			Color(0.54, 0.92, 0.82, 0.20),
			1.0
		)
	elif show_name:
		_draw_polyline_closed(
			_make_ellipse(Vector2.ZERO, ring_radius_x + 2.0, ring_radius_y + 1.0),
			Color(1.0, 1.0, 1.0, 0.08),
			1.0
		)


func _draw_direction_marker(show_direction: bool) -> void:
	if not show_direction:
		return
	var size := clampf(board_cell_size.x * 0.11, 4.0, 7.0)
	var center := Vector2(0.0, board_cell_size.y * 0.02)
	var pointer := PackedVector2Array()
	match get_facing_id():
		"up":
			pointer = PackedVector2Array([center + Vector2(0.0, -size - 2.0), center + Vector2(size, 0.0), center + Vector2(-size, 0.0)])
		"down":
			pointer = PackedVector2Array([center + Vector2(0.0, size + 2.0), center + Vector2(size, 0.0), center + Vector2(-size, 0.0)])
		"left":
			pointer = PackedVector2Array([center + Vector2(-size - 2.0, 0.0), center + Vector2(0.0, -size), center + Vector2(0.0, size)])
		_:
			pointer = PackedVector2Array([center + Vector2(size + 2.0, 0.0), center + Vector2(0.0, -size), center + Vector2(0.0, size)])
	draw_colored_polygon(pointer, Color(1.0, 0.92, 0.66, 0.24))


func _draw_overhead_info() -> void:
	var desired_height := _get_visual_height()
	var bar_width := clampf(board_cell_size.x * 0.70, 28.0, 44.0)
	var hp_height := clampf(board_cell_size.y * 0.085, 3.0, 5.0)
	var qi_height := maxf(2.0, hp_height * 0.60)
	var icon_size := clampf(board_cell_size.y * 0.20, 10.0, 15.0)
	var total_width := bar_width + icon_size + 6.0
	var origin := Vector2(-total_width * 0.5, -desired_height - 8.0)
	var hp_origin := origin
	var qi_origin := hp_origin + Vector2(0.0, hp_height + 3.0)
	var bar_bg := Color(0.04, 0.05, 0.07, 0.48)

	draw_rect(Rect2(hp_origin, Vector2(bar_width, hp_height)), bar_bg, true)
	var hp_ratio := 0.0 if max_hp <= 0 else float(hp) / float(max_hp)
	draw_rect(Rect2(hp_origin, Vector2(bar_width * hp_ratio, hp_height)), Color(0.86, 0.31, 0.26, 0.92), true)
	draw_rect(Rect2(hp_origin, Vector2(bar_width, hp_height)), Color(1.0, 1.0, 1.0, 0.14), false, 1.0)

	if uses_qi:
		draw_rect(Rect2(qi_origin, Vector2(bar_width, qi_height)), bar_bg, true)
		var qi_ratio := 0.0 if max_qi <= 0 else float(qi) / float(max_qi)
		draw_rect(Rect2(qi_origin, Vector2(bar_width * qi_ratio, qi_height)), Color(0.24, 0.72, 0.96, 0.92), true)
		draw_rect(Rect2(qi_origin, Vector2(bar_width, qi_height)), Color(1.0, 1.0, 1.0, 0.10), false, 1.0)

	var icon_rect := Rect2(
		Vector2(hp_origin.x + bar_width + 6.0, hp_origin.y - 1.0),
		Vector2(icon_size, icon_size)
	)
	var stance_icon := BattleVisuals.get_stance_icon(current_stance)
	if stance_icon != null:
		draw_texture_rect(stance_icon, icon_rect, false, Color(1.0, 1.0, 1.0, 0.96))
	else:
		draw_rect(icon_rect, Color(0.12, 0.14, 0.16, 0.62), true)
		draw_rect(icon_rect, Color(1.0, 1.0, 1.0, 0.14), false, 1.0)
		var font := ThemeDB.fallback_font
		var badge_text := BattleVisuals.get_stance_badge_text(current_stance)
		if font != null and not badge_text.is_empty():
			draw_string(
				font,
				icon_rect.position + Vector2(1.0, icon_rect.size.y - 2.0),
				badge_text,
				HORIZONTAL_ALIGNMENT_CENTER,
				icon_rect.size.x - 2.0,
				10,
				Color(0.98, 0.95, 0.88, 0.92)
			)


func _draw_name_label(show_name: bool) -> void:
	if not show_name:
		return
	var font := ThemeDB.fallback_font
	if font == null:
		return
	var desired_height := _get_visual_height()
	var label_y := -desired_height - 18.0
	var label_color := Color(1.0, 0.98, 0.94, 0.70 if hovered else 0.82)
	draw_string(font, Vector2(-26.0, label_y), display_name, HORIZONTAL_ALIGNMENT_CENTER, 52.0, 10, label_color)


func _ensure_visual_nodes() -> void:
	if visual_root != null and sprite_node != null:
		return
	visual_root = Node2D.new()
	visual_root.name = "VisualRoot"
	add_child(visual_root)
	visual_root.owner = get_tree().edited_scene_root if get_tree() != null else null

	sprite_node = Sprite2D.new()
	sprite_node.name = "UnitSprite"
	sprite_node.centered = false
	sprite_node.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	visual_root.add_child(sprite_node)
	sprite_node.owner = get_tree().edited_scene_root if get_tree() != null else null


func _apply_visual_resources() -> void:
	if sprite_node == null:
		return
	sprite_node.texture = battlefield_texture
	if battlefield_texture == null:
		sprite_node.visible = false
		return
	sprite_node.visible = true
	var desired_height := _get_visual_height()
	var source_height := maxf(1.0, float(battlefield_texture.get_height()))
	var scale_value := desired_height / source_height
	sprite_node.scale = Vector2(scale_value, scale_value)
	sprite_node.offset = Vector2(-battlefield_texture.get_width() * 0.5, -battlefield_texture.get_height()) + foot_anchor_offset
	sprite_node.modulate = Color(1.0, 1.0, 1.0, 1.0) if is_alive() else Color(0.52, 0.52, 0.52, 0.92)
	_apply_facing_visual()


func _apply_facing_visual() -> void:
	if sprite_node == null:
		return
	sprite_node.flip_h = facing == Vector2i.LEFT


func _get_visual_height() -> float:
	return board_cell_size.y * 1.28 * battlefield_scale


func _make_ellipse(center: Vector2, radius_x: float, radius_y: float, point_count: int = 24) -> Array[Vector2]:
	var points: Array[Vector2] = []
	for index in range(point_count):
		var angle := TAU * float(index) / float(point_count)
		points.append(center + Vector2(cos(angle) * radius_x, sin(angle) * radius_y))
	return points


func _draw_polyline_closed(points: Array[Vector2], color: Color, width: float) -> void:
	if points.is_empty():
		return
	var line_points := PackedVector2Array(points)
	line_points.append(points[0])
	draw_polyline(line_points, color, width, true)


func _merged_visuals(base_visuals: Dictionary, override_visuals: Dictionary) -> Dictionary:
	var merged := base_visuals.duplicate(true)
	for key in override_visuals.keys():
		merged[key] = override_visuals[key]
	return merged


func _normalize_facing(input_facing: Vector2i) -> Vector2i:
	if input_facing == Vector2i.UP or input_facing == Vector2i.DOWN or input_facing == Vector2i.LEFT or input_facing == Vector2i.RIGHT:
		return input_facing
	if absi(input_facing.x) >= absi(input_facing.y):
		return Vector2i(signi(input_facing.x), 0)
	if input_facing.y != 0:
		return Vector2i(0, signi(input_facing.y))
	return Vector2i.ZERO


func _load_texture(path: String) -> Texture2D:
	if path.is_empty():
		return null
	var texture = load(path)
	if texture is Texture2D:
		return texture
	return null


func _color_from_data(raw_value, fallback: Color) -> Color:
	if raw_value is Array and raw_value.size() >= 4:
		return Color(float(raw_value[0]), float(raw_value[1]), float(raw_value[2]), float(raw_value[3]))
	return fallback


func _vector2_from_array(raw_value) -> Vector2:
	if raw_value is Vector2:
		return raw_value
	if raw_value is Array and raw_value.size() >= 2:
		return Vector2(float(raw_value[0]), float(raw_value[1]))
	return Vector2.ZERO


func _to_string_array(raw_value) -> Array[String]:
	var result: Array[String] = []
	if raw_value is Array:
		for item in raw_value:
			result.append(String(item))
	return result


func _to_inventory_array(raw_value) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if raw_value is Array:
		for entry in raw_value:
			if entry is Dictionary:
				result.append(entry.duplicate(true))
	return result


func _array_to_cell(raw_value) -> Vector2i:
	if raw_value is Array and raw_value.size() >= 2:
		return Vector2i(int(raw_value[0]), int(raw_value[1]))
	return Vector2i.ZERO
