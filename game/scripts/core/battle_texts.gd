extends RefCounted
class_name BattleTexts

const PHASE_NAMES := {
	"waiting_move": "等待移动",
	"waiting_action": "等待选择行动",
	"waiting_target": "等待选择目标",
	"waiting_end": "等待结束回合",
	"enemy_turn": "敌方行动",
	"battle_over": "战斗结束",
	"loading": "载入中",
	"error": "异常"
}

const STANCE_NAMES := {
	"none": "无态",
	"youshen": "游身",
	"fajin": "发劲",
	"shoushi": "守势"
}

const STATUS_NAMES := {
	"yinren": "隐忍"
}

const TEAM_NAMES := {
	"player": "我方角色",
	"enemy": "敌方角色",
	"neutral": "中立单位"
}

const BUTTON_LABELS := {
	"move": "普通移动",
	"skip_move": "跳过移动",
	"end_turn": "结束回合",
	"selected_suffix": " [已选]"
}

const FACING_NAMES := {
	"up": "向上",
	"down": "向下",
	"left": "向左",
	"right": "向右",
	"none": "未定"
}


static func phase_name(phase_id: String) -> String:
	return String(PHASE_NAMES.get(phase_id, PHASE_NAMES["error"]))


static func stance_name(stance_id: String) -> String:
	return String(STANCE_NAMES.get(stance_id, stance_id))


static func status_name(status_id: String) -> String:
	return String(STATUS_NAMES.get(status_id, status_id))


static func team_name(team_id: String) -> String:
	return String(TEAM_NAMES.get(team_id, TEAM_NAMES["neutral"]))


static func button_label(label_id: String) -> String:
	return String(BUTTON_LABELS.get(label_id, label_id))


static func facing_name(facing_id: String) -> String:
	return String(FACING_NAMES.get(facing_id, FACING_NAMES["none"]))


static func skill_name(skill_def: Dictionary) -> String:
	return String(skill_def.get("display_name", skill_def.get("id", "")))


static func item_name(item_def: Dictionary) -> String:
	return String(item_def.get("display_name", item_def.get("id", "")))


static func format_round(round_index: int) -> String:
	return "回合：第%d回合" % round_index


static func format_current_unit(unit_name: String) -> String:
	return "当前角色：%s" % unit_name


static func format_phase(phase_id: String) -> String:
	return "阶段：%s" % phase_name(phase_id)


static func format_hp(hp: int, max_hp: int) -> String:
	return "生命：%d/%d" % [hp, max_hp]


static func format_qi(uses_qi: bool, qi: int, max_qi: int) -> String:
	if not uses_qi:
		return "真气：无"
	return "真气：%d/%d" % [qi, max_qi]


static func format_stance(stance_id: String) -> String:
	return "姿态：%s" % stance_name(stance_id)


static func format_facing(facing_id: String) -> String:
	return "朝向：%s" % facing_name(facing_id)


static func format_status_stacks(status_id: String, stacks: int) -> String:
	return "%s：%d层" % [status_name(status_id), stacks]


static func prompt_for_move(has_move_tiles: bool) -> String:
	if has_move_tiles:
		return "请选择移动位置"
	return "当前无可用移动"


static func prompt_for_action(has_action_options: bool, has_items: bool) -> String:
	if has_action_options or has_items:
		return "请选择本回合行动"
	return "当前无可用行动"


static func prompt_for_target(skill_def: Dictionary) -> String:
	var targeting: Dictionary = skill_def.get("targeting", {})
	var ui_group := String(skill_def.get("ui_group", ""))
	var target_type := String(targeting.get("type", "self"))
	if ui_group == "move":
		return "请选择轻功落点"
	if target_type == "cell":
		return "请选择技能目标"
	if ui_group == "attack":
		return "请选择攻击目标"
	return "请选择技能目标"


static func prompt_for_item_target(item_def: Dictionary) -> String:
	var targeting: Dictionary = item_def.get("targeting", {})
	if String(targeting.get("type", "self")) == "unit":
		return "请选择道具目标"
	return "请选择道具使用对象"


static func prompt_for_end() -> String:
	return "当前角色已行动"


static func prompt_for_enemy_turn() -> String:
	return "敌方正在行动"


static func prompt_for_viewing_enemy() -> String:
	return "正在查看敌方信息"


static func prompt_for_locked_ally() -> String:
	return "当前不可行动，正在查看同伴"


static func prompt_for_return_to_actor() -> String:
	return "请先选中当前角色"


static func prompt_for_battle_over(result_id: String) -> String:
	if result_id == "victory":
		return "战斗结束，我方获胜"
	if result_id == "defeat":
		return "战斗结束，我方落败"
	return "战斗结束"


static func focus_state_label(mode_id: String) -> String:
	match mode_id:
		"controllable":
			return "可操作"
		"locked_ally":
			return "查看中"
		"readonly_enemy":
			return "敌方情报"
		_:
			return "未选择"


static func hidden_skills_text() -> String:
	return "技能情报不足"


static func hidden_inventory_text() -> String:
	return "背包情报不足"


static func no_items_text() -> String:
	return "暂无道具"


static func no_status_text() -> String:
	return "当前无异常状态"
