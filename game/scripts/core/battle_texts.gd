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
	"qinggong": "轻功",
	"skip_move": "跳过移动",
	"end_turn": "结束回合"
}

const FACING_NAMES := {
	"up": "向上",
	"down": "向下",
	"left": "向左",
	"right": "向右",
	"none": "未定"
}

const CLICK_FAILURE_LABELS := {
	"wrong_phase": "当前阶段不能执行该操作",
	"battle_over": "战斗已经结束",
	"input_locked": "当前不可操作",
	"no_active_unit": "当前没有行动角色",
	"focused_not_active": "请先切回当前行动角色",
	"no_pending_qinggong": "当前不在轻功选点模式",
	"no_pending_target": "当前不在目标选择模式",
	"no_move_budget": "当前没有可用移动点",
	"out_of_bounds": "目标格超出棋盘范围",
	"same_cell": "目标格与当前位置相同",
	"occupied": "目标格已被单位占用",
	"blocked_terrain": "目标格被地形阻挡",
	"not_in_move_range": "目标格不在移动范围内",
	"not_in_qinggong_range": "目标格不在轻功落点范围内",
	"not_in_target_range": "当前目标不在可选范围内",
	"enemy_back_landing": "轻功不能落在敌人背后",
	"unreachable": "目标格当前不可达",
	"invalid_target": "当前目标无效",
	"ui_intercepted": "点击被界面拦截",
	"cancelled": "已取消当前选择",
	"viewing_other_unit": "正在查看其它角色",
	"unknown": "当前操作未能执行"
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


static func click_failure_reason(reason_id: String) -> String:
	return String(CLICK_FAILURE_LABELS.get(reason_id, CLICK_FAILURE_LABELS["unknown"]))


static func skill_name(skill_def: Dictionary) -> String:
	return String(skill_def.get("display_name", skill_def.get("id", "")))


static func item_name(item_def: Dictionary) -> String:
	return String(item_def.get("display_name", item_def.get("id", "")))


static func format_round(round_index: int) -> String:
	return "回合：第%d回合" % round_index


static func format_current_unit(unit_name: String) -> String:
	return "当前行动：%s" % unit_name


static func format_phase(phase_id: String) -> String:
	return "当前阶段：%s" % phase_name(phase_id)


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
	return "当前没有可用移动"


static func prompt_for_action(has_action_options: bool, has_items: bool) -> String:
	if has_action_options or has_items:
		return "请选择本回合行动"
	return "当前没有可用行动"


static func prompt_for_target(skill_def: Dictionary) -> String:
	var targeting: Dictionary = skill_def.get("targeting", {})
	var ui_group := String(skill_def.get("ui_group", ""))
	var target_type := String(targeting.get("type", "self"))
	if ui_group == "move":
		return "请选择轻功落点"
	if target_type == "cell":
		return "请选择技能位置"
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
	return "正在查看我方角色"


static func prompt_for_return_to_actor() -> String:
	return "请先切回当前行动角色"


static func prompt_for_battle_over(result_id: String) -> String:
	if result_id == "victory":
		return "战斗结束：我方获胜"
	if result_id == "defeat":
		return "战斗结束：我方落败"
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
			return "未选中"


static func hidden_skills_text() -> String:
	return "技能情报不足"


static func hidden_inventory_text() -> String:
	return "背包情报不足"


static func no_items_text() -> String:
	return "暂无道具"


static func no_status_text() -> String:
	return "暂无状态"


static func summary_unselected_character() -> String:
	return "未选中角色"


static func summary_selected_cell(cell: Vector2i) -> String:
	if cell == Vector2i(-1, -1):
		return "当前选中格：无"
	return "当前选中格：(%d,%d)" % [cell.x, cell.y]


static func summary_target_none() -> String:
	return "当前目标：无"


static func summary_target_pending() -> String:
	return "当前目标：等待选择"


static func summary_target_unit(unit_name: String) -> String:
	return "当前目标：%s" % unit_name


static func summary_target_cell(cell: Vector2i) -> String:
	return "当前目标：格子(%d,%d)" % [cell.x, cell.y]


static func summary_viewing_unit(focused_name: String, active_name: String) -> String:
	return "正在查看：%s / 当前行动：%s" % [focused_name, active_name]


static func summary_waiting_move() -> String:
	return "可选择移动位置"


static func summary_waiting_action() -> String:
	return "请选择本回合行动"


static func summary_waiting_target() -> String:
	return "请选择目标"


static func summary_waiting_end() -> String:
	return "可结束当前回合"


static func summary_enemy_turn() -> String:
	return "敌方正在行动"


static func summary_loading() -> String:
	return "正在载入战场"


static func summary_skill_selected(skill_name_text: String) -> String:
	return "当前技能：%s" % skill_name_text


static func summary_item_selected(item_name_text: String) -> String:
	return "当前道具：%s" % item_name_text


static func summary_facing_hint(facing_id: String, can_adjust: bool) -> String:
	if can_adjust:
		return "朝向：%s，可调整" % facing_name(facing_id)
	return "朝向：%s" % facing_name(facing_id)


static func skills_state_ready() -> String:
	return "可选择武学或普攻"


static func skills_state_locked() -> String:
	return "当前角色不可操作"


static func skills_state_enemy(show_enemy_skills: bool) -> String:
	return "敌方技能可查看" if show_enemy_skills else hidden_skills_text()


static func skills_state_selecting(skill_name_text: String) -> String:
	return "正在选择：%s" % skill_name_text


static func items_state_ready() -> String:
	return "可使用道具"


static func items_state_locked() -> String:
	return "当前角色不可使用道具"


static func items_state_enemy(show_enemy_inventory: bool) -> String:
	return "敌方背包可查看" if show_enemy_inventory else hidden_inventory_text()


static func items_state_selecting(item_name_text: String) -> String:
	return "正在选择：%s" % item_name_text
