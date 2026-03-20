class_name BattleVisuals

const BattleTexts = preload("res://scripts/core/battle_texts.gd")

const DEFAULT_BACKGROUND_PATH := "res://assets/battle/background/battle_ground.png"

const STANCE_ICON_PATHS := {
	"none": "res://assets/battle/ui/three_status/get_normal.png",
	"fajin": "res://assets/battle/ui/three_status/get_power.png",
	"shoushi": "res://assets/battle/ui/three_status/get_guard.png",
	"youshen": "res://assets/battle/ui/three_status/get_speed.png"
}

const PANEL_PATHS := {
	"character_info": "res://assets/battle/ui/panels/panel_character_info.png",
	"battle_info": "res://assets/battle/ui/panels/panel_battle_info.png",
	"command_bar": "res://assets/battle/ui/panels/panel_command_bar.png"
}

const BUTTON_PATHS := {
	"skill": {
		"normal": "res://assets/battle/ui/buttons/btn_skill_normal.png",
		"hover": "res://assets/battle/ui/buttons/btn_skill_hover.png",
		"selected": "res://assets/battle/ui/buttons/btn_skill_selected.png",
		"disabled": "res://assets/battle/ui/buttons/btn_skill_disabled.png"
	},
	"end_turn": {
		"normal": "res://assets/battle/ui/buttons/btn_end_turn.png",
		"hover": "res://assets/battle/ui/buttons/btn_end_turn.png",
		"selected": "res://assets/battle/ui/buttons/btn_end_turn.png",
		"disabled": "res://assets/battle/ui/buttons/btn_end_turn.png"
	}
}

const HIGHLIGHT_PATHS := {
	"selected": "res://assets/battle/ui/highlights/tile_selected.png",
	"move": "res://assets/battle/ui/highlights/tile_move.png",
	"qinggong": "res://assets/battle/ui/highlights/tile_qinggong.png",
	"attack_range": "res://assets/battle/ui/highlights/tile_attack_range.png",
	"target": "res://assets/battle/ui/highlights/tile_target.png",
	"active_ring": "res://assets/battle/ui/highlights/ring_active_unit.png"
}

const TAG_PATHS := {
	"buff": "res://assets/battle/ui/tags/tag_buff.png",
	"debuff": "res://assets/battle/ui/tags/tag_debuff.png"
}

const STATUS_FRAME_PATHS := {
	"buff": "res://assets/battle/ui/status_frames/frame_buff.png",
	"debuff": "res://assets/battle/ui/status_frames/frame_debuff.png"
}

const PORTRAIT_FALLBACKS := {
	"hero": "res://assets/battle/ui/portraits/hero_male_portrait_placeholder.png",
	"disciple": "res://assets/battle/ui/portraits/hero_female_portrait_placeholder.png",
	"enemy": "res://assets/battle/ui/portraits/enemy_bandit_portrait_placeholder.png"
}

const TEXT_COLORS := {
	"primary": Color("f2ead9"),
	"body": Color("d8d2c6"),
	"muted": Color("afa79a"),
	"highlight": Color("d8b56a"),
	"danger": Color("b85c4e"),
	"outline": Color("1e1a17")
}

const STANCE_DESCRIPTIONS := {
	"none": "无态：当前没有额外姿态倾向。",
	"youshen": "游身：偏机动与周旋，用于与其它姿态形成克制关系。",
	"fajin": "发劲：偏进攻与爆发，用于与其它姿态形成克制关系。",
	"shoushi": "守势：偏稳守与承受，用于与其它姿态形成克制关系。"
}

const STATUS_DESCRIPTIONS := {
	"yinren": "隐忍：未攻击结束回合时积累层数，出手后清空，并提升下一次伤害。"
}

static var _texture_cache: Dictionary = {}


static func get_default_background_path() -> String:
	return DEFAULT_BACKGROUND_PATH


static func get_text_color(role: String) -> Color:
	return TEXT_COLORS.get(role, TEXT_COLORS["body"])


static func get_outline_color() -> Color:
	return TEXT_COLORS["outline"]


static func get_stance_icon(stance_id: String) -> Texture2D:
	return _load_texture(String(STANCE_ICON_PATHS.get(stance_id, STANCE_ICON_PATHS["none"])))


static func get_panel_texture(panel_id: String) -> Texture2D:
	return _load_texture(String(PANEL_PATHS.get(panel_id, "")))


static func get_button_texture(button_role: String, state: String = "normal") -> Texture2D:
	var role_map: Dictionary = BUTTON_PATHS.get(button_role, {})
	var path := String(role_map.get(state, role_map.get("normal", "")))
	return _load_texture(path)


static func get_highlight_texture(highlight_id: String) -> Texture2D:
	return _load_texture(String(HIGHLIGHT_PATHS.get(highlight_id, "")))


static func get_tag_texture(tag_kind: String) -> Texture2D:
	return _load_texture(String(TAG_PATHS.get(tag_kind, "")))


static func get_status_frame_texture(frame_kind: String) -> Texture2D:
	return _load_texture(String(STATUS_FRAME_PATHS.get(frame_kind, "")))


static func get_portrait_texture_for_unit(unit_or_template) -> Texture2D:
	if unit_or_template == null:
		return _load_texture(PORTRAIT_FALLBACKS["enemy"])

	if unit_or_template is Dictionary:
		var visuals: Dictionary = unit_or_template.get("visuals", {})
		var portrait_path := String(visuals.get("portrait_texture_path", ""))
		if not portrait_path.is_empty():
			var portrait_texture := _load_texture(portrait_path)
			if portrait_texture != null:
				return portrait_texture
		return _load_texture(_fallback_portrait_path(String(unit_or_template.get("id", "")), String(unit_or_template.get("team", ""))))

	if unit_or_template.has_method("get_portrait_texture"):
		var texture = unit_or_template.get_portrait_texture()
		if texture is Texture2D:
			return texture
		var template_id := String(unit_or_template.get("template_id"))
		var team := String(unit_or_template.get("team"))
		return _load_texture(_fallback_portrait_path(template_id, team))

	return _load_texture(PORTRAIT_FALLBACKS["enemy"])


static func get_stance_tag_text(stance_id: String) -> String:
	return "无态" if stance_id == "none" else BattleTexts.stance_name(stance_id)


static func get_stance_badge_text(stance_id: String) -> String:
	return "无" if stance_id == "none" else ""


static func get_stance_description(stance_id: String) -> String:
	return String(STANCE_DESCRIPTIONS.get(stance_id, "当前姿态：%s" % get_stance_tag_text(stance_id)))


static func get_status_tag_text(status_id: String, stacks: int = 0) -> String:
	var base_text := BattleTexts.status_name(status_id)
	if stacks > 1:
		return "%s×%d" % [base_text, stacks]
	return base_text


static func get_status_description(status_id: String, stacks: int = 0) -> String:
	var description := String(STATUS_DESCRIPTIONS.get(status_id, BattleTexts.status_name(status_id)))
	if stacks > 1:
		return "%s\n当前层数：%d" % [description, stacks]
	return description


static func _fallback_portrait_path(template_id: String, team: String) -> String:
	match template_id:
		"hero":
			return PORTRAIT_FALLBACKS["hero"]
		"disciple":
			return PORTRAIT_FALLBACKS["disciple"]
		_:
			return PORTRAIT_FALLBACKS["enemy"] if team == "enemy" else PORTRAIT_FALLBACKS["hero"]


static func _load_texture(path: String) -> Texture2D:
	if path.is_empty():
		return null
	if _texture_cache.has(path):
		return _texture_cache[path]
	var extension := path.get_extension().to_lower()
	if extension in ["png", "jpg", "jpeg", "webp"]:
		var image := Image.new()
		var load_error := image.load(ProjectSettings.globalize_path(path))
		if load_error == OK:
			var image_texture := ImageTexture.create_from_image(image)
			_texture_cache[path] = image_texture
			return image_texture
	var texture = load(path)
	if texture is Texture2D:
		_texture_cache[path] = texture
		return texture
	return null
