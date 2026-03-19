# 战斗框架使用说明与可用性审计

## 1. 结论先看

当前战斗系统已经不是纯写死原型，它**已经具备一套真实可运行的“半引擎半内容配置”框架骨架**：

- 战斗入口、战斗载入、单位生成、技能定义、规则表、阵型、AI 难度都已经通过数据文件接入了运行链路。
- 直接修改 `battles/*.json`、`skills.json`、`unit_templates.json`、`player_formations.json`、`rules.json`，确实会改变实际战斗内容与数值表现。

但它**还不是完整的全配置驱动战斗引擎**，主要缺口也很明确：

- 胜败条件、战斗标题、战斗 hooks 等字段虽然已被读取，但还没有真正参与战斗执行。
- UI 分组结构、普通移动、道具区、回合区等仍然是框架层写死。
- `battle_loader` 只做了部分规范化，不是完整 schema 校验器。
- 某些配置字段已经存在，但当前版本没有真正接线。

如果按目标来判断：  
**现在已经能算“半引擎半内容配置”，但仍然偏向“可配置的战斗原型框架”，还没到“完整内容驱动战斗引擎”。**

---

## 2. 当前战斗系统入口

### 2.1 主入口

当前主入口是：

- `res://scenes/battle_scene.tscn`
- 根节点脚本：`res://scripts/core/battle_system.gd`
- 类名：`BattleSystem`

项目启动配置在 `project.godot` 中：

- `run/main_scene="res://scenes/battle_scene.tscn"`

因此当前项目启动后，会直接进入 `BattleScene`，由 `BattleSystem` 接管战斗流程。

### 2.2 自动启动 battle_001 的方式

`BattleSystem` 当前有一个导出字段：

- `@export var initial_battle_id := "battle_001"`

在 `_ready()` 中会直接调用：

- `start_battle(initial_battle_id)`

因此当前主场景默认会自动启动 `battle_001`。

### 2.3 外部系统未来如何调用

当前对外最明确的战斗启动接口就是：

- `BattleSystem.start_battle(battle_id: String)`

未来外部系统可按下面两种方式接入：

1. 直接实例化战斗场景，再调用：
   - `var battle = load("res://scenes/battle_scene.tscn").instantiate()`
   - `add_child(battle)`
   - `battle.start_battle("battle_002")`
2. 在编辑器里把 `BattleScene` 根节点上的 `initial_battle_id` 改成目标 battle id，用于手工测试。

当前 `start_battle()` 已经会负责：

- 清理旧单位
- 重建运行时服务
- 读取 battle 配置
- 配置棋盘与地形
- 通过阵型系统生成出生点
- 刷出玩家和敌人单位
- 进入回合流程

---

## 3. 当前真正参与运行链路的“底层框架”文件

下面这些脚本是**当前主场景实际使用到的运行链路**。

### 3.1 总控与场景层

- `res://scripts/core/battle_system.gd`
  - 当前战斗总控。
  - 负责入口、服务初始化、读取 battle、刷单位、处理玩家输入、驱动 UI、切换回合、发出战斗结果信号。
- `res://scripts/grid_manager.gd`
  - 棋盘绘制、格子坐标换算、高亮显示、地形表现。
- `res://scripts/entities/unit.gd`
  - 当前运行时单位基类。
  - 负责单位数据承载、HP/Qi/状态、位置、绘制表现。
- `res://scripts/entities/player_unit.gd`
  - 玩家单位派生类。
- `res://scripts/entities/enemy_unit.gd`
  - 敌方单位派生类。

### 3.2 核心规则层

- `res://scripts/core/turn_manager.gd`
  - 回合推进与轮次切换。
- `res://scripts/core/action_system.gd`
  - 本回合 move/action 预算、移动阶段和行动阶段锁定。
- `res://scripts/core/movement_system.gd`
  - 地形阻挡、寻路、普通移动、轻功落点预览与非法区判断。
- `res://scripts/core/combat_system.gd`
  - 伤害预览、实际伤害、三态倍率、蓄势收益结算。
- `res://scripts/core/stance_system.gd`
  - 三态关系与 stance 切换。
- `res://scripts/core/status_system.gd`
  - 当前状态层，已接入的是 `隐忍`。
- `res://scripts/core/resource_system.gd`
  - Qi/HP 资源修改与支付。
- `res://scripts/core/battle_texts.gd`
  - 当前集中式中文 UI 文案映射。

### 3.3 内容解释层

- `res://scripts/systems/skill_system.gd`
  - 技能读取、目标筛选、公式求值、效果执行。
- `res://scripts/systems/formation_system.gd`
  - 玩家阵型读取、敌方阵型选择、出生点解析。
- `res://scripts/data/data_manager.gd`
  - JSON 数据读取与缓存。
- `res://scripts/data/battle_loader.gd`
  - battle 配置装配与部分规范化。

### 3.4 AI 层

- `res://scripts/ai/ai_controller.gd`
  - 敌方回合候选动作构建与执行。
- `res://scripts/ai/ai_evaluator.gd`
  - 按难度对候选动作打分。

### 3.5 当前不属于主运行链路的旧原型残留

这些文件目前**不在主场景运行链路上**，属于旧版原型残留：

- `res://scripts/battle_manager.gd`
- `res://scripts/enemy_ai.gd`
- `res://scripts/unit.gd`

原因：

- 当前主场景 `battle_scene.tscn` 绑定的是 `scripts/core/battle_system.gd`。
- 当前单位实例化使用的是 `scripts/entities/player_unit.gd` 和 `scripts/entities/enemy_unit.gd`。
- 旧脚本仍在仓库中，但不是当前战斗框架的实际入口。

---

## 4. 当前真正决定战斗内容的“内容配置”文件

### 4.1 战斗内容入口

- `res://data/battles/*.json`
  - 当前已有：
    - `battle_001.json`
    - `battle_002.json`
  - 控制单场战斗的棋盘、地形、敌人清单、敌方阵型池、玩家阵型槽位、AI 难度等。

### 4.2 单位模板

- `res://data/units/unit_templates.json`
  - 控制单位模板的基础属性、技能列表、颜色表现、显示名等。

### 4.3 技能定义

- `res://data/skills/skills.json`
  - 控制技能名、按钮分组、目标规则、公式、消耗、切态、效果链、AI 标签。

### 4.4 阵型配置

- `res://data/player_formations.json`
  - 控制玩家参战编队与出生点。
- `res://data/formations/enemy_formations.json`
  - 控制敌方阵型槽位坐标。

### 4.5 全局规则表

- `res://data/rules.json`
  - 控制地形阻挡、行动预算、三态倍率、隐忍收益、蓄势收益、朝向、轻功限制等。

---

## 5. battle_id 更换后，哪些内容会跟着变化

下面按“当前是否真正生效”分开说明。

### 5.1 已经真正会变化的内容

切换 `battle_id` 后，下面这些内容**当前版本已经会真实变化**：

- 棋盘尺寸
  - 读取 `battle.board.columns / rows`
  - 已接入 `movement_system.configure_board()` 和 `grid_manager.configure_board()`
- 地形障碍布局
  - 读取 `battle.terrain`
  - 已影响地块绘制与地面移动阻挡
- 敌人数量
  - 读取 `battle.enemies.units`
  - 直接决定刷多少敌人
- 敌人模板
  - `battle.enemies.units[].template_id`
  - 决定敌人的 HP、移动、技能、颜色等
- 敌人个体覆盖数据
  - 每个敌人条目目前可覆盖 `display_name / skills / hp / qi / stance` 等 `setup_from_data()` 支持的字段
- 玩家使用哪个阵型槽位
  - 读取 `battle.player.formation_slot`
  - 会从 `player_formations.json` 取对应槽位
- 敌方阵型池
  - 读取 `battle.enemies.formation_pool`
  - `FormationSystem` 会在池内随机选一个有效阵型
- AI 难度
  - 读取 `battle.ai_difficulty`
  - 已接到 `AIEvaluator.score_candidate()`

### 5.2 已经被读取，但当前还不会真正影响结果的内容

下面这些 battle 字段**当前会被 loader 读出来，但还没接进真正执行逻辑**：

- `battle.name`
  - 会进入 `battle_config`
  - 但当前 UI 不显示战斗标题
- `battle.victory_conditions`
  - 会被加载到 `battle_config`
  - 但实际结算仍然是脚本写死的“敌全灭胜、我方全灭败”
- `battle.defeat_conditions`
  - 同上，已加载但未执行
- `battle hooks`
  - `BattleLoader` 会生成 `hooks` 占位字段
  - 但当前没有任何 battle-level hook 接线

### 5.3 当前 battle_id 还不能直接控制的内容

这些内容当前版本还不是通过 battle 配置驱动的：

- 右侧 UI 的结构与分组布局
- 普通移动按钮本身
- 道具系统
- 战斗标题显示
- 自定义战场脚本事件
- 非“全灭型”的胜败判定逻辑

---

## 6. 当前哪些部分仍然是写死的

这一节刻意只写“还没真正数据驱动”的部分。

### 6.1 UI 结构仍有硬编码

- 右侧 UI 固定分为：
  - 移动
  - 攻击
  - 防御/状态
  - 道具
  - 回合
- 其中真正动态生成按钮的只有：
  - `attack`
  - `guard`
- 以下按钮仍然是框架写死：
  - 普通移动
  - 轻功按钮槽位
  - 跳过移动
  - 暂无道具
  - 结束回合

换句话说：

- `skills.json` 目前**不能自由决定整个右侧 UI 的分区结构**
- `ui_group` 当前只对 `attack` 和 `guard` 的动态按钮真正生效
- `move` 组只会识别一个“当前轻功技能”，不是任意 move 技能列表
- `item` 组目前完全没接技能/道具数据

### 6.2 胜败条件仍然写死

当前真正执行的结算逻辑仍是：

- 玩家全灭：失败
- 敌方全灭：胜利

`battle_*.json` 里的 `victory_conditions / defeat_conditions` 只是被读取，没有被 `_check_battle_end()` 消费。

### 6.3 部分配置字段已存在但未接线

下面这些字段/能力当前是“存在但没真正生效”：

- `rules.qinggong.bonus_range`
  - 当前轻功距离实际上来自 `skills.json -> qinggong_step.values.bonus_range`
  - 不是从 `rules.qinggong.bonus_range` 读取
- `rules.qinggong.blocked_by_units`
  - 当前轻功不能穿单位，是 `MovementSystem` 的固定逻辑
  - 不是通过这个布尔字段切换
- `battle.name`
  - 已加载，未显示
- `battle.victory_conditions / defeat_conditions`
  - 已加载，未执行
- `battle hooks`
  - 已占位，未接线
- `skill_system` 的 `call_hook + script_hook`
  - 执行器存在
  - 当前数据里没有任何技能使用它
- `action_system.reserved_stance_reselect`
  - 有字段和写入口
  - 当前没有任何逻辑读取它
- `DataManager.generate_npc()`
  - 只是占位 stub

### 6.4 表现层仍有写死

- 单位是统一的占位式站牌绘制，不是模板级美术配置系统
- `unit_templates.json` 能改颜色与显示名，但不能决定不同模板使用不同绘制结构
- UI 文案虽然集中到了 `battle_texts.gd`，但仍是代码内常量，不是语言表
- 当前状态显示只明确接了 `隐忍`
  - 即使规则表将来增加更多 status，UI 和单位头顶表现也不会自动出现

### 6.5 Loader 还不是完整规范化层

`battle_loader.gd` 当前做了这些事情：

- 读取 battle
- 给 board 提供默认值
- 解析玩家阵型槽位
- 读取玩家阵型
- 校验敌方单位和敌阵池是否为空

但它还没有做到：

- 完整字段 schema 校验
- terrain 条目合法性校验
- enemy unit 条目字段规范化
- victory/defeat 条件编译
- hooks 解析与绑定
- battle title / battle meta 输出

所以它现在是“**轻量 battle 装配器**”，还不是“完整 battle schema loader”。

---

## 7. 最小验证说明：如何验证当前框架是否真的配置驱动

本节只写**当前版本真实可执行**的验证方式。

### 7.1 验证 battle_id 切换

#### 步骤

1. 复制：
   - `res://data/battles/battle_001.json`
   - 新建为：`res://data/battles/battle_test.json`
2. 修改 `battle_test.json`：
   - 增加或减少 `enemies.units`
   - 改敌人 `template_id`
   - 改 `terrain`
   - 改 `ai_difficulty`
   - 改 `enemies.formation_pool`
   - 可选改 `player.formation_slot`
3. 运行方式二选一：
   - 在 `BattleScene` 根节点把 `initial_battle_id` 改成 `battle_test`
   - 或在外部实例化后调用 `start_battle("battle_test")`

#### 建议修改项与预期结果

- 修改敌人数量
  - 例如从 2 个改成 3 个
  - 预期：开战后敌人总数变化
- 修改敌人站位
  - 通过切换 `formation_pool` 到另一套敌阵
  - 预期：敌人开局站位变化
- 修改地形障碍
  - 增删 `terrain` 中的 `stone / water`
  - 预期：棋盘地块外观变化，普通移动可达区域变化
- 修改 AI 难度
  - 例如 `simple -> hard`
  - 预期：敌方选技能、追击距离、终结倾向会变化，但不是完全不同 AI，只是评分策略更激进/更讲究收益
- 修改胜利条件
  - 例如把 `victory_conditions` 改成别的类型
  - **预期：当前不会有变化**
  - 原因：字段已加载，但尚未接入结算逻辑

### 7.2 验证 skills.json 是否真的驱动技能内容

任选一个技能，例如 `split_palm`。

#### 建议修改

- 改 `display_name`
- 改 `values.damage`
- 改 `costs`
- 改 `requirements`
- 改 `pre_effects` 里的 `set_stance`

#### 预期结果

- 修改名称
  - 右侧按钮名称会变化
- 修改伤害
  - 实际造成的伤害会变化
- 修改消耗
  - 使用技能时消耗的 Qi 会变化
- 修改是否切态
  - 比如把 `pre_effects.set_stance` 从 `fajin` 改成 `shoushi`
  - 预期：技能使用后角色姿态会变化，进而影响后续倍率和 AI 判断

#### 注意

- `ui_group` 改成 `attack` 或 `guard`，会影响按钮落在哪个分组
- 改成 `item` 当前**不会自动生成道具按钮**
- 新增第二个 `move` 技能，当前 UI 也**不会自动把它作为第二个移动按钮列出来**

### 7.3 验证 rules.json 是否真的驱动规则

#### 可验证项 1：三态倍率与无态倍率

修改：

- `rules.stances.multipliers.counter`
- `rules.stances.multipliers.countered`
- `rules.stances.multipliers.against_none`
- `rules.stances.multipliers.none_attack`
- `rules.stances.multipliers.neutral`

预期：

- 伤害数值会变化
- 同一技能对不同姿态目标的效果会变化

#### 可验证项 2：隐忍收益

修改：

- `rules.statuses.yinren.damage_bonus_per_stack`
- `rules.statuses.yinren.gain_if_no_attack`
- `rules.statuses.yinren.clear_on_attack`

预期：

- 不攻击回合结束后，隐忍叠层行为会变化
- 带隐忍时的伤害加成会变化
- 攻击后是否清空隐忍也会变化

#### 可验证项 3：你说的“蓄势收益”

当前项目里对应的是：

- `rules.charge.damage_bonus_per_move_point`

它不是一个显式显示在 UI 上的“蓄势状态”，而是内部伤害加成规则。

预期：

- 普通移动后再攻击时，若保留剩余移动点，伤害会按该规则变化
- 轻功当前不会吃这条加成，因为默认 `charge.applies_to_modes = ["ground"]`

### 7.4 验证 player_formations.json 是否真的参与开战生成

#### 步骤

1. 打开 `res://data/player_formations.json`
2. 修改槽位 `1` 的 `units[].cell`
3. 确认当前 battle 使用的 `player.formation_slot` 是 `1`
4. 重新运行该 battle

#### 预期结果

- 玩家开局站位会变化

#### 额外说明

- 如果 battle 切到别的 `formation_slot`，则会读对应槽位
- 如果某个槽位没有单位，`BattleLoader` 会直接报错并阻止战斗开始

---

## 8. 代码与配置接线检查

### 8.1 当前 UI 按钮是否真的从技能/行动数据读取？

结论：**部分是，部分不是。**

#### 真正数据驱动的部分

- 攻击区按钮：
  - 从 `active_unit.skills` 读取
  - 再查 `skills.json`
  - 按 `ui_group == "attack"` 和 `ui_order` 生成
- 防御/状态区按钮：
  - 同理，从 `ui_group == "guard"` 生成
- 轻功按钮文字：
  - 会读取当前 move 技能的 `display_name`

#### 仍写死的部分

- “普通移动”按钮不是技能数据生成的
- “跳过移动”按钮不是技能数据生成的
- “暂无道具”是固定占位
- “结束回合”是固定按钮
- UI 只认固定分组结构，不支持任意技能分组自动扩展

审计结论：

- **攻击/防御技能按钮是数据驱动**
- **整个行动面板不是完全数据驱动**

### 8.2 当前三态、无态、隐忍、蓄势是否真的从规则表读取？

结论：**大部分核心数值已经从规则表读取。**

#### 已真正从 rules.json 读取

- 三态克制关系：
  - `rules.stances.counter_map`
- 三态倍率与无态倍率：
  - `rules.stances.multipliers.*`
- 隐忍收益：
  - `rules.statuses.yinren.*`
- 蓄势收益：
  - `rules.charge.damage_bonus_per_move_point`
  - `rules.charge.applies_to_modes`

#### 仍有残留硬编码/半硬编码

- 当前 UI 和单位头顶只固定展示 `隐忍`
- 当前朝向系统仍默认只按 `rules.facing.player / enemy` 设置，不支持更细粒度每单位配置
- `rules.qinggong.blocked_by_units` 虽存在，但逻辑没有拿这个字段做开关

审计结论：

- **数值层已经基本规则表驱动**
- **展示层和部分开关层还没完全规则化**

### 8.3 当前 battle_loader 是否真的完成了配置规范化？

结论：**完成了“部分规范化”，但还远不到完整配置编译器。**

#### 已完成的事

- board 默认值回填
- player formation slot 解析
- player formation 装配
- enemy_units 与 enemy_formation_pool 基础存在性检查
- 输出统一 battle_config 字典

#### 尚未完成的事

- 没有完整 schema 校验
- 没有 terrain/units 的深层字段校验
- victory/defeat 没有编译为运行时规则
- hooks 没有解析为可执行对象
- 没有 battle meta 到 UI 的贯通

审计结论：

- **它不是“只是散读文件”**
- 但它也**还不是成熟的 battle schema normalizer**

### 8.4 当前 formation_system 是否真的参与战斗生成？

结论：**是，已经真实参与。**

实际链路是：

1. `BattleSystem.start_battle()`
2. `battle_loader.load_battle_config()`
3. `formation_system.resolve_battle_formations()`
4. 返回：
   - `player_spawns`
   - `enemy_spawns`
5. `BattleSystem._spawn_units()` 按解析后的 spawn 刷单位

也就是说：

- 玩家阵型槽位已经真实生效
- 敌方阵型池已经真实生效
- 不是空接口

### 8.5 当前 AI 难度切换是否真的生效？

结论：**是生效的，但属于“评分层分层”，不是“行为树分层”。**

当前 AI 难度来自：

- `battle_*.json -> ai_difficulty`

并通过：

- `BattleSystem.get_ai_difficulty()`
- `AIEvaluator.score_candidate()`

影响：

- 是否更看重斩杀
- 是否更看重姿态克制
- 是否更看重距离压迫
- `extreme` 是否额外吃 `ai_tags` 奖励

但它**没有做到**：

- 不同难度切换不同 AI 模块
- 不同难度启用不同候选动作生成
- 不同难度使用不同战术阶段脚本

审计结论：

- **AI 难度字段不是摆设**
- 但当前属于“同一套 AI，按难度改评分权重”。

---

## 9. 建议的最小判断标准

如果你想判断“当前到底是不是你要的半引擎半内容配置”，我建议用下面这条标准：

### 可以认定“已经做到”的部分

- 换 battle 配置，战场内容会变
- 换技能配置，按钮与效果会变
- 换规则表，核心伤害与状态收益会变
- 换阵型配置，开局站位会变
- 换 AI 难度，敌方决策倾向会变

### 还不能认定“已经做到”的部分

- 换 battle 配置，就能自由改胜败条件
- 换 battle 配置，就能驱动完整 UI / 标题 / 事件
- 换 rules 或 data，就能自动扩出更多状态表现
- 让 loader 成为完整 battle schema 解释器

---

## 10. 下一步最优先补哪一块

如果下一步要继续把它往“更像正式框架”推进，优先级建议如下：

### 第一优先：胜败条件执行层

原因：

- `victory_conditions / defeat_conditions` 已经进 battle 配置了
- 但当前结算还写死
- 这是 battle_id 真正成为“关卡内容入口”的关键缺口

建议补一个：

- `battle_outcome_system.gd`
  - 读取 battle_config 中的胜败条件
  - 在单位死亡、回合推进、关键状态变化后做统一判定

### 第二优先：battle_loader 的 schema 规范化

原因：

- 现在 loader 已经像装配器，但还不够稳定
- 后续 battle 内容一多，最容易先出的是配置质量问题

建议补：

- battle schema 验证
- terrain/enemy_units/conditions 的统一规范化
- 对未知字段和错误字段给出明确错误

### 第三优先：UI 行动面板进一步数据驱动

原因：

- 当前攻击/防御区已经半数据驱动
- 但 move/item/turn 仍是框架写死

建议方向：

- 把“行动入口”和“技能按钮入口”拆开
- 明确哪些是系统动作，哪些是技能动作
- 让 UI 分组层至少支持由配置决定按钮来源和显示顺序

---

## 11. 最终审计结论

一句话总结：

**当前框架已经真实做到“战斗内容可通过配置改变”，但还没有做到“战斗规则与战斗流程几乎都能由配置完整驱动”。**

更具体地说：

- 它已经不是假配置化
- 也不是只有 JSON 外壳、逻辑全写死
- 它已经有真实的数据入口、装配链路、规则读取与技能解释器

但同时：

- 胜败条件
- battle 事件
- 更完整的 UI 行为层
- 更深的 loader 规范化

这些关键块还没有补完，所以现在最准确的定位是：

**一套已经跑通核心链路的、偏小型的、部分数据驱动战斗框架。**
