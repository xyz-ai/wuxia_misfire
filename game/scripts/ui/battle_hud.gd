extends Control
class_name BattleHUD

const BattleTexts = preload("res://scripts/core/battle_texts.gd")
const BattleVisuals = preload("res://scripts/ui/battle_visuals.gd")

const WIDE_LAYOUT_MIN_WIDTH := 1160.0
const WIDE_CHARACTER_MIN_WIDTH := 340.0
const WIDE_INFO_MIN_WIDTH := 248.0
const WIDE_ITEM_BOX_MIN_WIDTH := 188.0
const NARROW_CHARACTER_MIN_WIDTH := 304.0
const NARROW_INFO_MIN_WIDTH := 216.0
const NARROW_ITEM_BOX_MIN_WIDTH := 172.0

signal system_action_requested(action_id: String)
signal skill_requested(skill_id: String)
signal item_requested(item_id: String)
signal facing_requested(facing_id: String)

@export var attack_icon: Texture2D
@export var wait_icon: Texture2D
@export var item_icon: Texture2D
@export var map_icon: Texture2D
@export var manual_icon: Texture2D
@export var rage_icon: Texture2D

@onready var content: MarginContainer = $Content
@onready var wide_root: HBoxContainer = $Content/WideRoot
@onready var narrow_root: VBoxContainer = $Content/NarrowRoot
@onready var narrow_top_row: HBoxContainer = $Content/NarrowRoot/NarrowTopRow
@onready var narrow_bottom_row: VBoxContainer = $Content/NarrowRoot/NarrowBottomRow

@onready var character_panel: PanelContainer = $Content/WideRoot/CharacterPanel
@onready var battle_info_panel: PanelContainer = $Content/WideRoot/BattleInfoPanel
@onready var command_panel: PanelContainer = $Content/WideRoot/CommandPanel

@onready var portrait_texture: TextureRect = $Content/WideRoot/CharacterPanel/CharacterMargin/CharacterRoot/PortraitTexture
@onready var name_label: Label = $Content/WideRoot/CharacterPanel/CharacterMargin/CharacterRoot/InfoVBox/NameLabel
@onready var status_tags: HBoxContainer = $Content/WideRoot/CharacterPanel/CharacterMargin/CharacterRoot/InfoVBox/StatusTags
@onready var hp_summary_label: Label = $Content/WideRoot/CharacterPanel/CharacterMargin/CharacterRoot/InfoVBox/ResourceRow/HpSummaryLabel
@onready var qi_summary_label: Label = $Content/WideRoot/CharacterPanel/CharacterMargin/CharacterRoot/InfoVBox/ResourceRow/QiSummaryLabel

@onready var selected_cell_label: Label = $Content/WideRoot/BattleInfoPanel/BattleInfoMargin/BattleInfoVBox/SelectedCellLabel
@onready var target_label: Label = $Content/WideRoot/BattleInfoPanel/BattleInfoMargin/BattleInfoVBox/TargetLabel
@onready var action_hint_label: Label = $Content/WideRoot/BattleInfoPanel/BattleInfoMargin/BattleInfoVBox/ActionHintLabel
@onready var facing_hint_label: Label = $Content/WideRoot/BattleInfoPanel/BattleInfoMargin/BattleInfoVBox/FacingHintLabel
@onready var facing_up_button: Button = $Content/WideRoot/BattleInfoPanel/BattleInfoMargin/BattleInfoVBox/FacingButtons/FacingUpButton
@onready var facing_down_button: Button = $Content/WideRoot/BattleInfoPanel/BattleInfoMargin/BattleInfoVBox/FacingButtons/FacingDownButton
@onready var facing_left_button: Button = $Content/WideRoot/BattleInfoPanel/BattleInfoMargin/BattleInfoVBox/FacingButtons/FacingLeftButton
@onready var facing_right_button: Button = $Content/WideRoot/BattleInfoPanel/BattleInfoMargin/BattleInfoVBox/FacingButtons/FacingRightButton

@onready var move_button: Button = $Content/WideRoot/CommandPanel/CommandMargin/CommandVBox/SystemActions/MoveButton
@onready var qinggong_button: Button = $Content/WideRoot/CommandPanel/CommandMargin/CommandVBox/SystemActions/QinggongButton
@onready var skip_move_button: Button = $Content/WideRoot/CommandPanel/CommandMargin/CommandVBox/SystemActions/SkipMoveButton
@onready var end_turn_button: Button = $Content/WideRoot/CommandPanel/CommandMargin/CommandVBox/SystemActions/EndTurnButton
@onready var skills_title: Label = $Content/WideRoot/CommandPanel/CommandMargin/CommandVBox/CommandSplit/SkillsBox/SkillsHeader/SkillsTitle
@onready var skills_state_label: Label = $Content/WideRoot/CommandPanel/CommandMargin/CommandVBox/CommandSplit/SkillsBox/SkillsHeader/SkillsStateLabel
@onready var skill_grid: GridContainer = $Content/WideRoot/CommandPanel/CommandMargin/CommandVBox/CommandSplit/SkillsBox/SkillGrid
@onready var items_box: VBoxContainer = $Content/WideRoot/CommandPanel/CommandMargin/CommandVBox/CommandSplit/ItemsBox
@onready var items_title: Label = $Content/WideRoot/CommandPanel/CommandMargin/CommandVBox/CommandSplit/ItemsBox/ItemsHeader/ItemsTitle
@onready var items_state_label: Label = $Content/WideRoot/CommandPanel/CommandMargin/CommandVBox/CommandSplit/ItemsBox/ItemsHeader/ItemsStateLabel
@onready var item_grid: GridContainer = $Content/WideRoot/CommandPanel/CommandMargin/CommandVBox/CommandSplit/ItemsBox/ItemGrid

@onready var status_tooltip: PanelContainer = $StatusTooltip
@onready var tooltip_label: Label = $StatusTooltip/TooltipMargin/TooltipLabel

var _scaled_texture_cache: Dictionary = {}
var _is_wide_layout := true


func _ready() -> void:
	_apply_base_layout()
	_apply_theme()
	_connect_signals()
	call_deferred("_update_layout_mode")


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and is_node_ready():
		call_deferred("_update_layout_mode")


func update_view(view_model: Dictionary) -> void:
	_hide_status_tooltip()
	var character: Dictionary = view_model.get("character", {})
	var battle_info: Dictionary = view_model.get("battle_info", {})
	var command: Dictionary = view_model.get("command", {})

	name_label.text = String(character.get("title", BattleTexts.summary_unselected_character()))
	hp_summary_label.text = String(character.get("hp_text", BattleTexts.format_hp(0, 0)))
	qi_summary_label.text = String(character.get("qi_text", BattleTexts.format_qi(false, 0, 0)))
	qi_summary_label.visible = bool(character.get("show_qi", false))
	portrait_texture.texture = _resolve_texture(character.get("portrait_texture", null))
	portrait_texture.self_modulate = Color.WHITE if portrait_texture.texture != null else Color(0.62, 0.62, 0.62, 1.0)
	_rebuild_status_tags(character.get("tags", []))

	selected_cell_label.text = String(battle_info.get("selected_cell_text", BattleTexts.summary_selected_cell(Vector2i(-1, -1))))
	target_label.text = String(battle_info.get("target_text", BattleTexts.summary_target_none()))
	action_hint_label.text = String(battle_info.get("action_text", ""))
	facing_hint_label.text = String(battle_info.get("facing_hint_text", BattleTexts.summary_facing_hint("none", false)))
	_update_facing_buttons(String(battle_info.get("facing_id", "none")), bool(battle_info.get("facing_enabled", false)))

	var system_actions: Dictionary = command.get("system_actions", {})
	_update_system_button(move_button, system_actions.get("move", {}), map_icon)
	_update_system_button(qinggong_button, system_actions.get("qinggong", {}), map_icon)
	_update_system_button(skip_move_button, system_actions.get("skip_move", {}), map_icon)
	_update_system_button(end_turn_button, system_actions.get("end_turn", {}), wait_icon)

	skills_state_label.text = String(command.get("skills_state_text", ""))
	items_state_label.text = String(command.get("items_state_text", ""))
	_rebuild_entry_grid(skill_grid, command.get("skill_entries", []), "skill")
	_rebuild_entry_grid(item_grid, command.get("item_entries", []), "item")


func _apply_base_layout() -> void:
	custom_minimum_size = Vector2(0.0, 256.0)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wide_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	narrow_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	narrow_top_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	narrow_bottom_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	character_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	battle_info_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	command_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	character_panel.clip_contents = false
	battle_info_panel.clip_contents = false
	command_panel.clip_contents = false

	portrait_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait_texture.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	portrait_texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	status_tooltip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tooltip_label.custom_minimum_size = Vector2(240.0, 0.0)

	selected_cell_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	selected_cell_label.max_lines_visible = 1
	target_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	target_label.max_lines_visible = 1
	action_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	action_hint_label.max_lines_visible = 2
	facing_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	facing_hint_label.max_lines_visible = 1
	skills_state_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	skills_state_label.max_lines_visible = 2
	items_state_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	items_state_label.max_lines_visible = 2
	tooltip_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tooltip_label.max_lines_visible = 4

	skills_title.text = "武学"
	items_title.text = "道具"
	facing_up_button.text = "上"
	facing_down_button.text = "下"
	facing_left_button.text = "左"
	facing_right_button.text = "右"


func _apply_theme() -> void:
	_apply_panel_style(character_panel, "character_info")
	_apply_panel_style(battle_info_panel, "battle_info")
	_apply_panel_style(command_panel, "command_bar")
	status_tooltip.add_theme_stylebox_override("panel", _make_fallback_panel_style(Color(0.06, 0.05, 0.04, 0.94)))

	_apply_label_style(name_label, 20, "primary", 2)
	_apply_label_style(hp_summary_label, 14, "body", 1)
	_apply_label_style(qi_summary_label, 14, "body", 1)
	_apply_label_style(selected_cell_label, 14, "body", 1)
	_apply_label_style(target_label, 14, "body", 1)
	_apply_label_style(action_hint_label, 14, "highlight", 1)
	_apply_label_style(facing_hint_label, 13, "body", 1)
	_apply_label_style(skills_state_label, 12, "muted", 1)
	_apply_label_style(items_state_label, 12, "muted", 1)
	_apply_label_style(skills_title, 16, "primary", 2)
	_apply_label_style(items_title, 16, "primary", 2)

	tooltip_label.add_theme_font_size_override("font_size", 12)
	tooltip_label.add_theme_color_override("font_color", BattleVisuals.get_text_color("body"))
	tooltip_label.add_theme_color_override("font_outline_color", BattleVisuals.get_outline_color())
	tooltip_label.add_theme_constant_override("outline_size", 1)

	for button in [facing_up_button, facing_down_button, facing_left_button, facing_right_button]:
		_style_button(button, "skill", false)

	_update_system_button(move_button, {"text": BattleTexts.button_label("move")}, map_icon)
	_update_system_button(qinggong_button, {"text": BattleTexts.button_label("qinggong")}, map_icon)
	_update_system_button(skip_move_button, {"text": BattleTexts.button_label("skip_move")}, map_icon)
	_update_system_button(end_turn_button, {"text": BattleTexts.button_label("end_turn"), "button_role": "end_turn"}, wait_icon)


func _apply_label_style(label: Label, font_size: int, color_role: String, outline_size: int) -> void:
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", BattleVisuals.get_text_color(color_role))
	label.add_theme_color_override("font_outline_color", BattleVisuals.get_outline_color())
	label.add_theme_constant_override("outline_size", outline_size)


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


func _update_layout_mode() -> void:
	var use_wide := size.x >= WIDE_LAYOUT_MIN_WIDTH
	wide_root.visible = use_wide
	narrow_root.visible = not use_wide
	if use_wide:
		_move_panel(character_panel, wide_root, 0)
		_move_panel(battle_info_panel, wide_root, 1)
		_move_panel(command_panel, wide_root, 2)
		character_panel.size_flags_horizontal = Control.SIZE_FILL
		battle_info_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		command_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		character_panel.size_flags_stretch_ratio = 0.95
		battle_info_panel.size_flags_stretch_ratio = 0.88
		command_panel.size_flags_stretch_ratio = 1.17
		character_panel.custom_minimum_size.x = clampf(size.x * 0.30, WIDE_CHARACTER_MIN_WIDTH, 380.0)
		battle_info_panel.custom_minimum_size.x = clampf(size.x * 0.22, WIDE_INFO_MIN_WIDTH, 320.0)
		items_box.custom_minimum_size.x = clampf(size.x * 0.17, WIDE_ITEM_BOX_MIN_WIDTH, 220.0)
		portrait_texture.custom_minimum_size = Vector2(132.0, 156.0)
	else:
		_move_panel(character_panel, narrow_top_row, 0)
		_move_panel(battle_info_panel, narrow_top_row, 1)
		_move_panel(command_panel, narrow_bottom_row, 0)
		character_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		battle_info_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		command_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		character_panel.size_flags_stretch_ratio = 1.0
		battle_info_panel.size_flags_stretch_ratio = 0.82
		command_panel.size_flags_stretch_ratio = 1.0
		character_panel.custom_minimum_size.x = clampf(size.x * 0.40, NARROW_CHARACTER_MIN_WIDTH, 344.0)
		battle_info_panel.custom_minimum_size.x = clampf(size.x * 0.30, NARROW_INFO_MIN_WIDTH, 272.0)
		items_box.custom_minimum_size.x = clampf(size.x * 0.22, NARROW_ITEM_BOX_MIN_WIDTH, 208.0)
		portrait_texture.custom_minimum_size = Vector2(116.0, 140.0)
	_is_wide_layout = use_wide


func _move_panel(panel: Control, next_parent: Node, index: int) -> void:
	if panel.get_parent() != next_parent:
		panel.reparent(next_parent)
	if panel.get_index() != index:
		next_parent.move_child(panel, index)


func _apply_panel_style(panel: PanelContainer, panel_id: String) -> void:
	var texture := BattleVisuals.get_panel_texture(panel_id)
	if texture != null:
		panel.add_theme_stylebox_override("panel", _make_texture_panel_style(texture))
		panel.self_modulate = Color(1.0, 1.0, 1.0, 0.97)
	else:
		panel.add_theme_stylebox_override("panel", _make_fallback_panel_style(Color(0.10, 0.09, 0.08, 0.86)))


func _make_texture_panel_style(texture: Texture2D) -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	style.texture = texture
	style.texture_margin_left = 14.0
	style.texture_margin_top = 14.0
	style.texture_margin_right = 14.0
	style.texture_margin_bottom = 14.0
	style.content_margin_left = 10.0
	style.content_margin_top = 10.0
	style.content_margin_right = 10.0
	style.content_margin_bottom = 10.0
	return style


func _make_fallback_panel_style(fill_color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill_color
	style.border_color = Color(0.30, 0.25, 0.20, 0.45)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_left = 12
	style.corner_radius_bottom_right = 12
	return style


func _make_texture_button_style(texture: Texture2D) -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	style.texture = texture
	style.texture_margin_left = 12.0
	style.texture_margin_top = 10.0
	style.texture_margin_right = 12.0
	style.texture_margin_bottom = 10.0
	style.content_margin_left = 10.0
	style.content_margin_top = 7.0
	style.content_margin_right = 10.0
	style.content_margin_bottom = 7.0
	return style


func _make_fallback_button_style(fill_color: Color, border_color: Color = Color(0.40, 0.34, 0.29, 0.40)) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill_color
	style.border_color = border_color
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	style.content_margin_left = 10.0
	style.content_margin_right = 10.0
	style.content_margin_top = 7.0
	style.content_margin_bottom = 7.0
	return style


func _style_button(button: Button, button_role: String, selected: bool) -> void:
	button.focus_mode = Control.FOCUS_NONE
	button.clip_text = true
	button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	button.add_theme_font_size_override("font_size", 14 if button_role == "skill" else 15)
	button.add_theme_color_override("font_color", BattleVisuals.get_text_color("danger") if button_role == "end_turn" else BattleVisuals.get_text_color("primary"))
	button.add_theme_color_override("font_hover_color", BattleVisuals.get_text_color("highlight"))
	button.add_theme_color_override("font_pressed_color", BattleVisuals.get_text_color("highlight"))
	button.add_theme_color_override("font_disabled_color", BattleVisuals.get_text_color("muted"))
	button.add_theme_color_override("font_outline_color", BattleVisuals.get_outline_color())
	button.add_theme_constant_override("outline_size", 2)

	var normal_texture := BattleVisuals.get_button_texture(button_role, "selected" if selected else "normal")
	var hover_texture := BattleVisuals.get_button_texture(button_role, "hover")
	var pressed_texture := BattleVisuals.get_button_texture(button_role, "selected")
	var disabled_texture := BattleVisuals.get_button_texture(button_role, "disabled")

	button.add_theme_stylebox_override(
		"normal",
		_make_texture_button_style(normal_texture) if normal_texture != null else _make_fallback_button_style(Color(0.22, 0.18, 0.14, 0.92))
	)
	button.add_theme_stylebox_override(
		"hover",
		_make_texture_button_style(hover_texture) if hover_texture != null else _make_fallback_button_style(Color(0.28, 0.22, 0.16, 0.95))
	)
	button.add_theme_stylebox_override(
		"pressed",
		_make_texture_button_style(pressed_texture) if pressed_texture != null else _make_fallback_button_style(Color(0.18, 0.14, 0.11, 0.96))
	)
	button.add_theme_stylebox_override(
		"disabled",
		_make_texture_button_style(disabled_texture) if disabled_texture != null else _make_fallback_button_style(Color(0.12, 0.11, 0.10, 0.72), Color(0.24, 0.22, 0.20, 0.24))
	)


func _rebuild_status_tags(tags: Array) -> void:
	_clear_container(status_tags)
	var visible_count := mini(tags.size(), 4)
	for index in range(visible_count):
		status_tags.add_child(_make_status_tag(tags[index]))
	if tags.size() > visible_count:
		status_tags.add_child(
			_make_status_tag({
				"id": "overflow",
				"text": "+%d" % (tags.size() - visible_count),
				"kind": "overflow",
				"description": "还有更多状态，请悬浮标签查看详细说明。"
			})
		)


func _make_status_tag(entry: Dictionary) -> Button:
	var button := Button.new()
	button.flat = false
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(0.0, 26.0)
	button.text = String(entry.get("text", ""))
	button.icon = _scaled_texture(_resolve_texture(entry.get("icon_texture", null)), Vector2i(15, 15))
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_size_override("font_size", 11)
	button.add_theme_color_override("font_color", BattleVisuals.get_text_color("body"))
	button.add_theme_color_override("font_outline_color", BattleVisuals.get_outline_color())
	button.add_theme_constant_override("outline_size", 1)
	var kind := String(entry.get("kind", "neutral"))
	var frame_kind := "buff" if kind == "buff" or kind == "stance" else "debuff"
	var frame_texture := BattleVisuals.get_status_frame_texture(frame_kind)
	if frame_texture != null and kind != "overflow":
		button.add_theme_stylebox_override("normal", _make_texture_button_style(frame_texture))
		button.add_theme_stylebox_override("hover", _make_texture_button_style(frame_texture))
		button.add_theme_stylebox_override("pressed", _make_texture_button_style(frame_texture))
	else:
		button.add_theme_stylebox_override("normal", _make_tag_style(kind))
		button.add_theme_stylebox_override("hover", _make_tag_style(kind, 0.06))
		button.add_theme_stylebox_override("pressed", _make_tag_style(kind))

	var description := String(entry.get("description", ""))
	if not description.is_empty():
		button.mouse_entered.connect(func() -> void:
			_show_status_tooltip(description, button)
		)
		button.mouse_exited.connect(func() -> void:
			_hide_status_tooltip()
		)
	return button


func _make_tag_style(kind: String, lighten_amount: float = 0.0) -> StyleBoxFlat:
	var base_color := Color(0.17, 0.16, 0.14, 0.86)
	var border_color := Color(0.35, 0.30, 0.24, 0.40)
	match kind:
		"stance":
			base_color = Color(0.40, 0.30, 0.16, 0.90)
			border_color = Color(0.82, 0.67, 0.42, 0.42)
		"buff":
			base_color = Color(0.15, 0.28, 0.19, 0.88)
			border_color = Color(0.55, 0.78, 0.62, 0.40)
		"debuff":
			base_color = Color(0.34, 0.18, 0.17, 0.88)
			border_color = Color(0.80, 0.48, 0.42, 0.40)
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


func _rebuild_entry_grid(container: GridContainer, entries: Array, entry_type: String) -> void:
	_clear_container(container)
	for entry in entries:
		container.add_child(_make_entry_button(entry, entry_type))


func _make_entry_button(entry: Dictionary, entry_type: String) -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(164.0, 54.0)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.text = String(entry.get("text", ""))
	button.tooltip_text = String(entry.get("tooltip", ""))
	button.disabled = bool(entry.get("disabled", true))
	button.expand_icon = true
	button.icon = _scaled_texture(_resolve_texture(entry.get("icon_texture", entry.get("icon_path", ""))), Vector2i(22, 22))
	if button.icon == null:
		button.icon = _scaled_texture(_default_entry_icon(String(entry.get("kind", "hidden"))), Vector2i(22, 22))
	_style_button(button, String(entry.get("button_role", "skill")), bool(entry.get("selected", false)))

	if not button.disabled:
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
	button.icon = _scaled_texture(_resolve_texture(entry.get("icon_texture", entry.get("icon_path", fallback_icon))), Vector2i(22, 22))
	if button.icon == null:
		button.icon = _scaled_texture(fallback_icon, Vector2i(22, 22))
	_style_button(button, String(entry.get("button_role", "skill")), bool(entry.get("selected", false)))


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
		_style_button(button, "skill", current_facing == facing_id)


func _default_entry_icon(kind: String) -> Texture2D:
	match kind:
		"attack":
			return attack_icon
		"item":
			return item_icon
		"buff", "debuff":
			return rage_icon
		"guard", "stance":
			return manual_icon
		_:
			return manual_icon


func _resolve_texture(value) -> Texture2D:
	if value is Texture2D:
		return value
	if value is String:
		var path := String(value)
		if path.is_empty():
			return null
		var texture = load(path)
		if texture is Texture2D:
			return texture
	return null


func _scaled_texture(texture: Texture2D, size_hint: Vector2i) -> Texture2D:
	if texture == null:
		return null
	if size_hint.x <= 0 or size_hint.y <= 0:
		return texture
	var cache_key := "%s:%dx%d" % [str(texture.get_rid()), size_hint.x, size_hint.y]
	if _scaled_texture_cache.has(cache_key):
		return _scaled_texture_cache[cache_key]
	var image := texture.get_image()
	if image == null or image.is_empty():
		return texture
	var duplicate := image.duplicate()
	duplicate.resize(size_hint.x, size_hint.y, Image.INTERPOLATE_LANCZOS)
	var scaled := ImageTexture.create_from_image(duplicate)
	_scaled_texture_cache[cache_key] = scaled
	return scaled


func _clear_container(container: Node) -> void:
	for child in container.get_children():
		child.queue_free()
