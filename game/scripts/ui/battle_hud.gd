extends Control
class_name BattleHUD

signal system_action_requested(action_id: String)
signal skill_requested(skill_id: String)
signal item_requested(item_id: String)
signal facing_requested(facing_id: String)

@export var bottom_bar_texture: Texture2D
@export var attack_icon: Texture2D
@export var wait_icon: Texture2D
@export var item_icon: Texture2D
@export var map_icon: Texture2D
@export var manual_icon: Texture2D
@export var rage_icon: Texture2D

@onready var background: TextureRect = $Background
@onready var portrait_texture: TextureRect = $Content/Root/PortraitPanel/PortraitMargin/PortraitRoot/PortraitTexture
@onready var name_label: Label = $Content/Root/PortraitPanel/PortraitMargin/PortraitRoot/InfoVBox/NameLabel
@onready var status_tags: HBoxContainer = $Content/Root/PortraitPanel/PortraitMargin/PortraitRoot/InfoVBox/StatusTags
@onready var hp_summary_label: Label = $Content/Root/PortraitPanel/PortraitMargin/PortraitRoot/InfoVBox/ResourceRow/HpSummaryLabel
@onready var qi_summary_label: Label = $Content/Root/PortraitPanel/PortraitMargin/PortraitRoot/InfoVBox/ResourceRow/QiSummaryLabel

@onready var phase_label: Label = $Content/Root/StatusPanel/StatusMargin/StatusVBox/PhaseLabel
@onready var active_unit_label: Label = $Content/Root/StatusPanel/StatusMargin/StatusVBox/ActiveUnitLabel
@onready var view_mode_label: Label = $Content/Root/StatusPanel/StatusMargin/StatusVBox/ViewModeLabel
@onready var facing_label: Label = $Content/Root/StatusPanel/StatusMargin/StatusVBox/FacingLabel
@onready var hint_label: Label = $Content/Root/StatusPanel/StatusMargin/StatusVBox/HintLabel
@onready var facing_up_button: Button = $Content/Root/StatusPanel/StatusMargin/StatusVBox/FacingButtons/FacingUpButton
@onready var facing_down_button: Button = $Content/Root/StatusPanel/StatusMargin/StatusVBox/FacingButtons/FacingDownButton
@onready var facing_left_button: Button = $Content/Root/StatusPanel/StatusMargin/StatusVBox/FacingButtons/FacingLeftButton
@onready var facing_right_button: Button = $Content/Root/StatusPanel/StatusMargin/StatusVBox/FacingButtons/FacingRightButton

@onready var skills_title: Label = $Content/Root/SkillsPanel/SkillsMargin/SkillsVBox/SkillsTitleRow/SkillsTitle
@onready var move_button: Button = $Content/Root/SkillsPanel/SkillsMargin/SkillsVBox/SystemActions/MoveButton
@onready var qinggong_button: Button = $Content/Root/SkillsPanel/SkillsMargin/SkillsVBox/SystemActions/QinggongButton
@onready var skip_move_button: Button = $Content/Root/SkillsPanel/SkillsMargin/SkillsVBox/SystemActions/SkipMoveButton
@onready var end_turn_button: Button = $Content/Root/SkillsPanel/SkillsMargin/SkillsVBox/SystemActions/EndTurnButton
@onready var skills_state_label: Label = $Content/Root/SkillsPanel/SkillsMargin/SkillsVBox/SkillsTitleRow/SkillsStateLabel
@onready var skill_grid: GridContainer = $Content/Root/SkillsPanel/SkillsMargin/SkillsVBox/SkillGrid

@onready var items_title: Label = $Content/Root/ItemsPanel/ItemsMargin/ItemsVBox/ItemsTitle
@onready var items_state_label: Label = $Content/Root/ItemsPanel/ItemsMargin/ItemsVBox/ItemsStateLabel
@onready var item_grid: GridContainer = $Content/Root/ItemsPanel/ItemsMargin/ItemsVBox/ItemGrid

@onready var status_tooltip: PanelContainer = $StatusTooltip
@onready var tooltip_label: Label = $StatusTooltip/TooltipMargin/TooltipLabel

var _scaled_texture_cache: Dictionary = {}


func _ready() -> void:
	_apply_base_layout()
	_apply_theme()
	_connect_signals()


func update_view(view_model: Dictionary) -> void:
	_hide_status_tooltip()
	var unit = view_model.get("unit", null)
	name_label.text = String(view_model.get("focused_title", "未选择角色"))
	phase_label.text = String(view_model.get("phase_text", "阶段：载入中"))
	active_unit_label.text = String(view_model.get("active_unit_text", "当前行动：无"))
	view_mode_label.text = String(view_model.get("view_mode_text", "查看模式：未选择"))
	facing_label.text = String(view_model.get("facing_text", "朝向：未定"))
	hint_label.text = String(view_model.get("status_hint_text", ""))
	hp_summary_label.text = String(view_model.get("hp_text", "生命：-"))
	qi_summary_label.text = String(view_model.get("qi_text", "真气：无"))
	qi_summary_label.visible = bool(view_model.get("show_qi", false))

	portrait_texture.texture = _resolve_texture(view_model.get("portrait_texture", null))
	portrait_texture.self_modulate = Color.WHITE if unit != null else Color(0.62, 0.62, 0.62, 1.0)

	_update_facing_buttons(String(view_model.get("facing_id", "none")), bool(view_model.get("facing_enabled", false)))
	_rebuild_status_tags(view_model.get("status_tags", []))
	_update_system_button(move_button, view_model.get("system_actions", {}).get("move", {}), map_icon)
	_update_system_button(qinggong_button, view_model.get("system_actions", {}).get("qinggong", {}), map_icon)
	_update_system_button(skip_move_button, view_model.get("system_actions", {}).get("skip_move", {}), map_icon)
	_update_system_button(end_turn_button, view_model.get("system_actions", {}).get("end_turn", {}), wait_icon)
	_rebuild_skill_grid(view_model.get("skill_entries", []))
	_rebuild_item_grid(view_model.get("item_entries", []))

	skills_state_label.text = String(view_model.get("skills_state_text", ""))
	items_state_label.text = String(view_model.get("items_state_text", ""))


func _apply_base_layout() -> void:
	custom_minimum_size = Vector2(0.0, 192.0)
	background.texture = bottom_bar_texture
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_SCALE
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.self_modulate = Color(1.0, 1.0, 1.0, 0.94)

	portrait_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait_texture.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	portrait_texture.mouse_filter = Control.MOUSE_FILTER_IGNORE

	skills_title.text = "技能"
	items_title.text = "道具"
	facing_up_button.text = "上"
	facing_down_button.text = "下"
	facing_left_button.text = "左"
	facing_right_button.text = "右"
	status_tooltip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tooltip_label.custom_minimum_size = Vector2(180.0, 0.0)


func _apply_theme() -> void:
	var section_panels: Array[PanelContainer] = [
		$Content/Root/PortraitPanel,
		$Content/Root/StatusPanel,
		$Content/Root/SkillsPanel,
		$Content/Root/ItemsPanel
	]
	for panel in section_panels:
		panel.add_theme_stylebox_override("panel", _make_panel_style(Color(0.07, 0.09, 0.12, 0.34)))

	status_tooltip.add_theme_stylebox_override("panel", _make_panel_style(Color(0.05, 0.06, 0.08, 0.92)))
	tooltip_label.add_theme_color_override("font_color", Color(0.96, 0.95, 0.92, 1.0))
	tooltip_label.add_theme_font_size_override("font_size", 11)

	var body_labels: Array[Label] = [
		name_label,
		hp_summary_label,
		qi_summary_label,
		phase_label,
		active_unit_label,
		view_mode_label,
		facing_label,
		hint_label,
		skills_state_label,
		items_state_label
	]
	for label in body_labels:
		label.add_theme_color_override("font_color", Color(0.95, 0.95, 0.94, 1.0))
		label.add_theme_font_size_override("font_size", 11)
	name_label.add_theme_font_size_override("font_size", 15)
	name_label.add_theme_color_override("font_color", Color(1.0, 0.96, 0.88, 1.0))
	hint_label.add_theme_font_size_override("font_size", 10)
	hint_label.add_theme_color_override("font_color", Color(0.82, 0.85, 0.89, 0.92))
	skills_state_label.add_theme_font_size_override("font_size", 10)
	items_state_label.add_theme_font_size_override("font_size", 10)

	for title in [skills_title, items_title]:
		title.add_theme_color_override("font_color", Color(1.0, 0.92, 0.68, 1.0))
		title.add_theme_font_size_override("font_size", 12)

	move_button.icon = _scaled_texture(map_icon, Vector2i(20, 20))
	qinggong_button.icon = _scaled_texture(map_icon, Vector2i(20, 20))
	skip_move_button.icon = _scaled_texture(map_icon, Vector2i(20, 20))
	end_turn_button.icon = _scaled_texture(wait_icon, Vector2i(20, 20))
	_style_button(move_button, Color(0.16, 0.38, 0.30, 0.74))
	_style_button(qinggong_button, Color(0.14, 0.30, 0.46, 0.74))
	_style_button(skip_move_button, Color(0.24, 0.24, 0.18, 0.72))
	_style_button(end_turn_button, Color(0.38, 0.22, 0.18, 0.74))

	for button in [facing_up_button, facing_down_button, facing_left_button, facing_right_button]:
		_style_button(button, Color(0.18, 0.21, 0.26, 0.72))


func _connect_signals() -> void:
	move_button.pressed.connect(func() -> void:
		emit_signal("system_action_requested", "move")
	)
	qinggong_button.pressed.connect(func() -> void:
		emit_signal("system_action_requested", "qinggong")
	)
	skip_move_button.pressed.connect(func() -> void:
		emit_signal("system_action_requested", "skip_move")
	)
	end_turn_button.pressed.connect(func() -> void:
		emit_signal("system_action_requested", "end_turn")
	)
	facing_up_button.pressed.connect(func() -> void:
		emit_signal("facing_requested", "up")
	)
	facing_down_button.pressed.connect(func() -> void:
		emit_signal("facing_requested", "down")
	)
	facing_left_button.pressed.connect(func() -> void:
		emit_signal("facing_requested", "left")
	)
	facing_right_button.pressed.connect(func() -> void:
		emit_signal("facing_requested", "right")
	)


func _rebuild_status_tags(tags: Array) -> void:
	_clear_container(status_tags)
	var visible_count := mini(tags.size(), 4)
	for index in range(visible_count):
		var entry: Dictionary = tags[index]
		status_tags.add_child(_make_status_tag(entry))
	if tags.size() > visible_count:
		var overflow := _make_status_tag({
			"id": "status_overflow",
			"text": "+%d" % (tags.size() - visible_count),
			"kind": "overflow",
			"description": "还有更多状态，请查看详细信息。"
		})
		status_tags.add_child(overflow)


func _make_status_tag(entry: Dictionary) -> Button:
	var button := Button.new()
	button.flat = true
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(0.0, 22.0)
	button.text = String(entry.get("text", ""))
	button.icon = _scaled_texture(_resolve_texture(entry.get("icon_texture", null)), Vector2i(14, 14))
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_style_tag_button(button, String(entry.get("kind", "neutral")))

	var description := String(entry.get("description", ""))
	if not description.is_empty():
		button.mouse_entered.connect(func() -> void:
			_show_status_tooltip(description, button)
		)
		button.mouse_exited.connect(func() -> void:
			_hide_status_tooltip()
		)
	return button


func _show_status_tooltip(text: String, source_control: Control) -> void:
	tooltip_label.text = text
	status_tooltip.visible = true
	status_tooltip.size = status_tooltip.get_combined_minimum_size()
	var source_rect := source_control.get_global_rect()
	var local_position := source_rect.position - global_position
	var tooltip_position := local_position + Vector2(0.0, -status_tooltip.size.y - 8.0)
	tooltip_position.x = clampf(tooltip_position.x, 0.0, maxf(0.0, size.x - status_tooltip.size.x))
	tooltip_position.y = maxf(0.0, tooltip_position.y)
	status_tooltip.position = tooltip_position


func _hide_status_tooltip() -> void:
	status_tooltip.visible = false


func _rebuild_skill_grid(entries: Array) -> void:
	_clear_container(skill_grid)
	for entry in entries:
		skill_grid.add_child(_make_entry_button(entry, "skill"))


func _rebuild_item_grid(entries: Array) -> void:
	_clear_container(item_grid)
	for entry in entries:
		item_grid.add_child(_make_entry_button(entry, "item"))


func _make_entry_button(entry: Dictionary, entry_type: String) -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(138.0, 38.0)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.text = String(entry.get("text", ""))
	button.tooltip_text = String(entry.get("tooltip", ""))
	button.disabled = bool(entry.get("disabled", true))
	button.expand_icon = true
	button.icon = _scaled_texture(_resolve_texture(entry.get("icon_texture", entry.get("icon_path", ""))), Vector2i(22, 22))
	if button.icon == null:
		button.icon = _scaled_texture(_default_entry_icon(String(entry.get("kind", "hidden"))), Vector2i(22, 22))
	_style_button(button, _entry_color(String(entry.get("kind", "hidden"))))

	if button.disabled:
		return button

	var entry_id := String(entry.get("id", ""))
	if entry_type == "skill":
		button.pressed.connect(func() -> void:
			emit_signal("skill_requested", entry_id)
		)
	else:
		button.pressed.connect(func() -> void:
			emit_signal("item_requested", entry_id)
		)
	return button


func _update_system_button(button: Button, entry: Dictionary, fallback_icon: Texture2D) -> void:
	button.text = String(entry.get("text", button.text))
	button.disabled = bool(entry.get("disabled", true))
	var icon_source = entry.get("icon_texture", entry.get("icon_path", fallback_icon))
	button.icon = _scaled_texture(_resolve_texture(icon_source), Vector2i(20, 20))
	if button.icon == null:
		button.icon = _scaled_texture(fallback_icon, Vector2i(20, 20))


func _update_facing_buttons(current_facing: String, enabled: bool) -> void:
	var facing_buttons := {
		"up": facing_up_button,
		"down": facing_down_button,
		"left": facing_left_button,
		"right": facing_right_button
	}
	for facing_id in facing_buttons.keys():
		var button: Button = facing_buttons[facing_id]
		button.disabled = not enabled
		var is_current: bool = facing_id == current_facing
		_style_button(button, Color(0.68, 0.52, 0.22, 0.76) if is_current else Color(0.18, 0.21, 0.26, 0.70))


func _make_panel_style(fill_color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill_color
	style.border_color = Color(0.82, 0.86, 0.90, 0.08)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	return style


func _style_button(button: Button, base_color: Color) -> void:
	button.focus_mode = Control.FOCUS_NONE
	button.clip_text = true
	button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	button.add_theme_font_size_override("font_size", 10)
	button.add_theme_stylebox_override("normal", _make_button_style(base_color))
	button.add_theme_stylebox_override("hover", _make_button_style(base_color.lightened(0.06)))
	button.add_theme_stylebox_override("pressed", _make_button_style(base_color.darkened(0.08)))
	button.add_theme_stylebox_override("disabled", _make_button_style(Color(0.14, 0.16, 0.19, 0.58), Color(0.26, 0.28, 0.32, 0.24)))
	button.add_theme_color_override("font_color", Color(0.96, 0.96, 0.95, 1.0))
	button.add_theme_color_override("font_disabled_color", Color(0.57, 0.60, 0.66, 0.90))


func _style_tag_button(button: Button, kind: String) -> void:
	button.add_theme_font_size_override("font_size", 10)
	button.add_theme_color_override("font_color", Color(0.97, 0.97, 0.95, 1.0))
	button.add_theme_stylebox_override("normal", _make_tag_style(kind))
	button.add_theme_stylebox_override("hover", _make_tag_style(kind, 0.08))
	button.add_theme_stylebox_override("pressed", _make_tag_style(kind))


func _make_tag_style(kind: String, lighten_amount: float = 0.0) -> StyleBoxFlat:
	var base_color := Color(0.18, 0.20, 0.24, 0.74)
	var border_color := Color(1.0, 1.0, 1.0, 0.10)
	match kind:
		"stance":
			base_color = Color(0.44, 0.34, 0.18, 0.78)
			border_color = Color(1.0, 0.88, 0.58, 0.16)
		"buff":
			base_color = Color(0.18, 0.34, 0.24, 0.78)
			border_color = Color(0.74, 0.96, 0.82, 0.16)
		"debuff":
			base_color = Color(0.38, 0.18, 0.18, 0.76)
			border_color = Color(1.0, 0.78, 0.76, 0.16)
		"overflow":
			base_color = Color(0.18, 0.20, 0.24, 0.64)
			border_color = Color(1.0, 1.0, 1.0, 0.08)
	if lighten_amount > 0.0:
		base_color = base_color.lightened(lighten_amount)
	var style := StyleBoxFlat.new()
	style.bg_color = base_color
	style.border_color = border_color
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	style.content_margin_left = 8.0
	style.content_margin_right = 8.0
	style.content_margin_top = 2.0
	style.content_margin_bottom = 2.0
	return style


func _make_button_style(fill_color: Color, border_color: Color = Color(0.90, 0.92, 0.96, 0.12)) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill_color
	style.border_color = border_color
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.content_margin_left = 7.0
	style.content_margin_right = 7.0
	style.content_margin_top = 4.0
	style.content_margin_bottom = 4.0
	return style


func _entry_color(kind: String) -> Color:
	match kind:
		"attack":
			return Color(0.30, 0.24, 0.23, 0.84)
		"guard":
			return Color(0.20, 0.28, 0.22, 0.84)
		"item":
			return Color(0.21, 0.22, 0.29, 0.82)
		"hidden":
			return Color(0.20, 0.20, 0.22, 0.74)
		_:
			return Color(0.22, 0.22, 0.26, 0.82)


func _default_entry_icon(kind: String) -> Texture2D:
	match kind:
		"attack":
			return attack_icon
		"guard":
			return manual_icon
		"item":
			return item_icon
		"hidden":
			return rage_icon
		_:
			return map_icon


func _resolve_texture(source) -> Texture2D:
	if source is Texture2D:
		return source
	if source is String and not String(source).is_empty():
		var texture = load(String(source))
		if texture is Texture2D:
			return texture
	return null


func _scaled_texture(texture: Texture2D, size: Vector2i) -> Texture2D:
	if texture == null:
		return null
	var cache_key := "%s:%d:%d" % [_texture_cache_key(texture), size.x, size.y]
	if _scaled_texture_cache.has(cache_key):
		return _scaled_texture_cache[cache_key]

	var image := texture.get_image()
	if image == null or image.is_empty():
		return texture
	image.resize(size.x, size.y, Image.INTERPOLATE_LANCZOS)
	var scaled := ImageTexture.create_from_image(image)
	_scaled_texture_cache[cache_key] = scaled
	return scaled


func _texture_cache_key(texture: Texture2D) -> String:
	if not texture.resource_path.is_empty():
		return texture.resource_path
	return str(texture.get_instance_id())


func _clear_container(container: Control) -> void:
	for child in container.get_children():
		child.queue_free()
