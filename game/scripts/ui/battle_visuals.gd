extends RefCounted
class_name BattleVisuals

const BattleTexts = preload("res://scripts/core/battle_texts.gd")

const STANCE_ICON_PATHS := {
	"fajin": "res://assets/battle/ui/three_status/get_power.png",
	"shoushi": "res://assets/battle/ui/three_status/get_guard.png",
	"youshen": "res://assets/battle/ui/three_status/get_speed.png"
}

const STANCE_DESCRIPTIONS := {
	"none": "当前处于无态，没有额外姿态倾向。",
	"youshen": "游身：偏机动与周旋，用于与其他姿态形成克制关系。",
	"fajin": "发劲：偏进攻与爆发，用于与其他姿态形成克制关系。",
	"shoushi": "守势：偏稳守与承受，用于与其他姿态形成克制关系。"
}

const STATUS_DESCRIPTIONS := {
	"yinren": "隐忍：未攻击结束回合时累积层数，出手后清空，并提升下一次伤害。"
}

static var _texture_cache: Dictionary = {}


static func get_stance_icon(stance_id: String) -> Texture2D:
	var path := String(STANCE_ICON_PATHS.get(stance_id, ""))
	if path.is_empty():
		return null
	if _texture_cache.has(path):
		return _texture_cache[path]
	var texture = load(path)
	if texture is Texture2D:
		_texture_cache[path] = texture
		return texture
	return null


static func get_stance_tag_text(stance_id: String) -> String:
	if stance_id == "none":
		return "无态"
	return BattleTexts.stance_name(stance_id)


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
