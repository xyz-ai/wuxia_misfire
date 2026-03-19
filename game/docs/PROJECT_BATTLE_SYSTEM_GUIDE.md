# PROJECT_BATTLE_SYSTEM_GUIDE

更新时间：2026-03-19

## 快速理解

### 这项目现在是不是“半引擎半配置”？
是，但不是完全体。

- 已经真正配置驱动的部分：
  - `battle_id` 驱动棋盘尺寸、地形、敌人列表、敌方阵型池、玩家阵型槽位、AI 难度。
  - `skills.json` 驱动技能名、图标、消耗、目标规则、效果链。
  - `items.json` 驱动道具名、图标、目标规则、效果链。
  - `unit_templates.json` 驱动单位数值、技能列表、背包、立绘路径。
  - `rules.json` 驱动行动预算、三态倍率、隐忍收益、蓄势系数、轻功限制、敌情显示开关、地形贴图路径。
  - `player_formations.json` / `enemy_formations.json` 驱动开战站位。
- 还没有完全配置驱动的部分：
  - 胜负条件虽然从 battle JSON 读取，但实际结算仍然写死为“敌全灭胜 / 我方全灭败”。
  - 背景图不是按 `battle_id` 配置，而是当前场景里固定挂 `battle_ground.png`。
  - UI 布局、系统动作按钮结构、很多提示文本仍然写在场景或脚本里。
  - `hooks`、`move_cost`、`control_statuses` 等字段存在接口，但没有完整跑通。

### 当前战斗系统的核心链路是什么？

1. `project.godot` 的主场景是 `res://scenes/battle_scene.tscn`。
2. 场景根节点挂 `scripts/core/battle_system.gd`。
3. `BattleSystem._ready()` 会直接调用 `start_battle(initial_battle_id)`。
4. `initial_battle_id` 默认是 `battle_001`。
5. `BattleSystem` 会创建运行时服务（数据读取、阵型、移动、技能、道具、AI、回合等）。
6. `BattleLoader` 读取 `battle_001.json`，拼出 battle 配置。
7. `FormationSystem` 根据 battle 配置和阵型表，生成玩家与敌方出生点。
8. `GridManager` 配置棋盘与地形显示。
9. `BattleSystem` 根据模板和出生点实例化单位。
10. `TurnManager` 开始回合，`BattleSystem` 负责输入、UI 刷新、技能/移动/AI 执行。

### 下一步最应该先改什么？

按优先级看，建议先改这 3 件事：

1. 补完 battle 配置真正控制的内容，先把“胜负条件 / battle hooks / battle 背景”等从“读取了但没执行”补成完整链路。
2. 清理旧原型链路，明确只保留 `BattleSystem + entities/unit.gd` 这一套，避免继续误改 `battle_manager.gd`、`scripts/unit.gd`、`units/*.tscn`。
3. 继续拆表现层职责，把 `BattleSystem` 的 UI 组装、`GridManager` 的绘制职责再往专门视图层挪，降低后续继续打磨 HUD 和棋盘时的耦合。

---

## 1. 当前项目目录结构与职责

下面只列与战斗系统直接相关的目录和文件。

### `scenes/`

| 路径 | 当前实际作用 | 是否在运行链路 |
|---|---|---|
| `res://scenes/battle_scene.tscn` | 当前主战斗场景。包含 `Camera2D`、背景层、平面棋盘层、单位层、顶部信息和底部 HUD。 | 是 |
| `res://scenes/ui/battle_hud.tscn` | 当前底部战斗 HUD 场景。定义人物区、状态区、技能区、道具区的节点结构和图标资源引用。 | 是 |

### `scripts/core/`

| 路径 | 当前实际作用 | 是否在运行链路 |
|---|---|---|
| `res://scripts/core/battle_system.gd` | 当前总控脚本。负责启动战斗、建立运行时服务、读配置、生成单位、处理输入、驱动 HUD、结算回合、切换敌我行动。它现在既是控制器，也是部分 UI Presenter。 | 是 |
| `res://scripts/core/action_system.gd` | 管每回合行动预算和阶段锁。这里定义了“移动阶段 / 行动阶段”、普通移动与轻功互斥、攻击/技能/道具共享 `action`。 | 是 |
| `res://scripts/core/movement_system.gd` | 管逻辑棋盘坐标、地形阻挡、单位占格、可达范围、路径搜索、轻功落点合法性。 | 是 |
| `res://scripts/core/combat_system.gd` | 负责实际伤害数值计算。把基础伤害叠加三态倍率、隐忍倍率、蓄势倍率后应用到目标。 | 是 |
| `res://scripts/core/stance_system.gd` | 负责三态/无态的逻辑：设定姿态、判断克制关系、给出伤害倍率。 | 是 |
| `res://scripts/core/status_system.gd` | 负责状态层数、隐忍叠层与清除、状态造成的伤害修正。 | 是 |
| `res://scripts/core/resource_system.gd` | 负责 HP / 真气资源初始化、回合开始回复、支付资源消耗。 | 是 |
| `res://scripts/core/turn_manager.gd` | 负责敌我单位轮流行动、回合数推进、回合开始/结束时机。 | 是 |
| `res://scripts/core/battle_texts.gd` | 当前的中文文案集中层。阶段名、姿态名、提示语、按钮文案、敌情隐藏文案等都在这里集中定义。它不是完整本地化系统，但已经是当前主要文案入口。 | 是 |

### `scripts/systems/`

| 路径 | 当前实际作用 | 是否在运行链路 |
|---|---|---|
| `res://scripts/systems/formation_system.gd` | 读取玩家阵型槽位和敌方阵型池，实际生成 battle 使用的玩家/敌方出生点。 | 是 |
| `res://scripts/systems/skill_system.gd` | 当前技能执行核心。读取技能定义、验证目标、支付消耗、按效果链执行 `set_stance / move_unit / damage / apply_status / clear_status / modify_resource / consume_action / call_hook`。 | 是 |
| `res://scripts/systems/item_system.gd` | 当前最小可用道具系统。读取道具定义、验证目标、扣除道具数量、应用回复/状态效果，并消耗共享行动。 | 是 |

### `scripts/data/`

| 路径 | 当前实际作用 | 是否在运行链路 |
|---|---|---|
| `res://scripts/data/data_manager.gd` | 当前所有 JSON 的统一读取入口。读取 battle、rules、skills、items、unit templates、阵型数据。 | 是 |
| `res://scripts/data/battle_loader.gd` | 轻量 battle 装配器。把 `battle_id` 对应的 JSON 转成运行时 battle 配置，并附带玩家阵型、敌方列表、AI 难度、声明式胜负条件等。它目前不是完整 schema 验证器。 | 是 |

### `scripts/ai/`

| 路径 | 当前实际作用 | 是否在运行链路 |
|---|---|---|
| `res://scripts/ai/ai_controller.gd` | 当前敌方 AI 执行器。负责枚举候选行动（移动、轻功、技能、跳过移动、等待），调用评分器选最佳方案，再执行。 | 是 |
| `res://scripts/ai/ai_evaluator.gd` | 当前敌方 AI 评分器。按难度调整“贴近敌人、斩杀、姿态克制、生存倾向、技能标签”的权重。不同难度不是不同 AI 脚本，而是同一评分模型的不同偏好。 | 是 |

### `scripts/entities/`

| 路径 | 当前实际作用 | 是否在运行链路 |
|---|---|---|
| `res://scripts/entities/unit.gd` | 当前真正运行的单位基类。保存数值、背包、姿态、状态、朝向、格子坐标、立绘资源、脚底锚点，并负责部分单位自身的绘制（阴影、选中圈、朝向箭头、血条、气条、名字）。 | 是 |
| `res://scripts/entities/player_unit.gd` | `unit.gd` 的轻薄包装，只把 `team` 默认设为 `player`。 | 是 |
| `res://scripts/entities/enemy_unit.gd` | `unit.gd` 的轻薄包装，只把 `team` 默认设为 `enemy`。 | 是 |

### `scripts/board/` 与 `scripts/visual/`

| 路径 | 当前实际作用 | 是否在运行链路 |
|---|---|---|
| `res://scripts/grid_manager.gd` | 当前棋盘控制器。负责平面棋盘坐标换算、棋盘布局、基础格绘制、地形绘制、范围高亮分发、选中格显示。它已经不是旧的等距台子，但仍然同时承担“棋盘逻辑接口 + 棋盘表现层”双重职责。 | 是 |
| `res://scripts/board/board_canvas_layer.gd` | 辅助分层绘制脚本。给 `GridBase / TerrainLayer / Highlight` 子层提供统一 `queue_redraw()` 和回调入口。 | 是 |
| `res://scripts/visual/battle_background.gd` | 背景贴图脚本。负责将 `battle_ground.png` 按视口 cover 式铺底，并跟随相机。 | 是 |

### `scripts/ui/`

| 路径 | 当前实际作用 | 是否在运行链路 |
|---|---|---|
| `res://scripts/ui/battle_hud.gd` | 当前底部 HUD 的视图控制脚本。负责接收 `BattleSystem` 组装的 view model，刷新人物、状态、技能、道具和朝向按钮，并发出 UI 信号给 `BattleSystem`。 | 是 |

### `data/`

| 路径 | 当前实际作用 | 是否在运行链路 |
|---|---|---|
| `res://data/battles/battle_001.json` | 当前默认入口 battle。定义棋盘尺寸、地形、玩家阵型槽位、敌人列表、敌方阵型池、AI 难度、声明式胜负条件。 | 是 |
| `res://data/battles/battle_002.json` | 第二个 battle 配置，用来验证内容切换是否生效。 | 是 |
| `res://data/skills/skills.json` | 技能表。控制技能名称、图标、目标规则、消耗、姿态切换、效果链、AI 标签。 | 是 |
| `res://data/items/items.json` | 道具表。控制道具名称、图标、目标规则、效果。 | 是 |
| `res://data/units/unit_templates.json` | 单位模板表。控制数值、技能、背包、阵营标签、视觉资源路径。 | 是 |
| `res://data/formations/enemy_formations.json` | 敌方阵型表。提供一组可复用站位槽位。 | 是 |
| `res://data/player_formations.json` | 玩家阵型槽位表。当前 battle 会通过 `formation_slot` 读取这里的编队。 | 是 |
| `res://data/rules.json` | 全局规则表。控制棋盘默认尺寸、地形定义、行动预算、三态倍率、隐忍、蓄势、轻功规则、初始朝向、敌情显示规则。 | 是 |

### `assets/battle/`

| 路径 | 当前实际作用 | 是否在运行链路 |
|---|---|---|
| `res://assets/battle/background/battle_ground.png` | 当前固定战斗背景图。只做背景，不参与棋盘逻辑。 | 是 |
| `res://assets/battle/ui/panels/bottom_hud_bar.png.png` | 当前底部 HUD 的底板贴图。 | 是 |
| `res://assets/battle/ui/icons/*.png` | 当前 HUD 系统动作、技能、道具、隐藏情报的默认图标。 | 是 |
| `res://assets/battle/units/player/*.png` | 当前玩家单位战场立绘占位。 | 是 |
| `res://assets/battle/units/enemy/*.png` | 当前敌方单位战场立绘占位。 | 是 |
| `res://assets/battle/units/terrain/base/*.png` | 当前基础格贴图。 | 是 |
| `res://assets/battle/units/terrain/overlay/*.png` | 当前石头/水塘覆盖贴图。 | 是 |
| `res://assets/battle/ui/portraits/*.png` | 已存在，但当前并未真正接入。现在人物区仍直接使用单位模板里的 `portrait_texture_path`，而模板目前指向战场立绘，不指向这些专门 portrait 图。 | 否 |
| `res://assets/battle/units/terrain/fx/slash_feedback_placeholder.png` | 当前未接入。 | 否 |

### 旧原型残留 / 当前未接入链路

| 路径 | 当前状态 |
|---|---|
| `res://scripts/battle_manager.gd` | 旧版战斗总控，不属于当前主场景链路。内部还引用旧 UI 路径和旧原型单位场景。 |
| `res://scripts/enemy_ai.gd` | 旧版 AI，配套 `battle_manager.gd` 使用。当前主链路不使用。 |
| `res://scripts/unit.gd` | 旧版 `BattleUnit`，和现在的 `scripts/entities/unit.gd` 不是一套系统。 |
| `res://units/player.tscn` / `res://units/enemy.tscn` | 旧版单位场景，当前主场景不会实例化它们。 |

---

## 2. 战斗系统运行入口说明

### 主场景是什么？

- `project.godot` 里当前主场景是 `res://scenes/battle_scene.tscn`。

### 如何自动启动 `battle_001`？

- `battle_scene.tscn` 根节点挂的是 `scripts/core/battle_system.gd`。
- `battle_system.gd` 导出了 `initial_battle_id`，默认值是 `"battle_001"`。
- `BattleSystem._ready()` 里直接执行：
  - `_connect_ui()`
  - `_apply_ui_theme()`
  - `start_battle(initial_battle_id)`

所以当前工程启动后，会直接进 `battle_001`。

### `BattleSystem.start_battle(battle_id)` 如何被调用？

当前默认调用链：

1. 打开项目。
2. Godot 运行 `battle_scene.tscn`。
3. `BattleSystem._ready()` 执行。
4. `start_battle("battle_001")` 被自动调用。

外部系统以后若要切 battle，直接拿到 `BattleSystem` 节点后调用：

```gdscript
$BattleScene.start_battle("battle_002")
```

或者在当前场景树里直接调用当前战斗场景根节点上的 `start_battle(battle_id)`。

### 从 `battle_id` 到最终生成战斗场景的完整链路

当前完整运行链路如下：

1. `BattleSystem.start_battle(battle_id)`
2. `_clear_units()` 清空上一场战斗的运行单位
3. `_build_runtime_services()` 创建本场战斗用的运行时服务：
   - `DataManager`
   - `BattleLoader`
   - `FormationSystem`
   - `StanceSystem`
   - `ResourceSystem`
   - `ActionSystem`
   - `StatusSystem`
   - `MovementSystem`
   - `CombatSystem`
   - `SkillSystem`
   - `ItemSystem`
   - `TurnManager`
   - `AIEvaluator`
   - `AIController`
4. `battle_loader.load_battle_config(battle_id)`：
   - 读取 battle JSON
   - 读取 `rules.json`
   - 读取玩家阵型槽位
   - 检查敌人列表和敌方阵型池是否存在
   - 组装 battle config
5. `movement_system.configure_board()` 读取棋盘尺寸和地形
6. `grid_manager.configure_board()` 读取棋盘尺寸、地形贴图定义并刷新棋盘显示
7. `_layout_battlefield()` 根据当前视口重新布局平面棋盘
8. `formation_system.resolve_battle_formations()`：
   - 取玩家编队
   - 随机选择一个合法敌方阵型
   - 生成 `player_spawns` / `enemy_spawns`
9. `_spawn_units()` 读取 `unit_templates.json` 实例化玩家与敌方单位
10. `movement_system.register_units(all_units)` 将占格信息写入移动系统
11. `turn_manager.begin_battle()` 选出第一个行动单位
12. `_after_turn_advanced()`：
   - 设定 `active_unit`
   - 设定 `focused_unit`
   - 刷新棋盘高亮
   - 刷新顶部信息
   - 刷新底部 HUD
   - 若轮到敌方则启动 AI

---

## 3. 数据驱动结构说明

## 哪些内容来自 JSON / 配置文件？

### `battles/*.json`

控制：

- battle ID 和名称
- 棋盘尺寸
- 地形列表
- 玩家使用哪个阵型槽位
- 敌人数量和敌方模板列表
- 敌方可选阵型池
- AI 难度
- 声明式胜利条件 / 失败条件

修改后当前应该发生的变化：

- 改 `board`：棋盘格数变化
- 改 `terrain`：障碍/水塘显示和阻挡变化
- 改 `player.formation_slot`：开战我方站位变化
- 改 `enemies.units`：敌人数量 / 模板变化
- 改 `enemies.formation_pool`：敌方落点变化
- 改 `ai_difficulty`：敌情显示和 AI 评分倾向变化

### `skills.json`

控制：

- 技能显示名
- 技能图标
- 技能归属分组（攻击 / 防御 / 移动）
- 目标类型
- 射程或射程公式
- 条件与消耗
- 效果链
- AI 标签
- 伤害/返气等数值

修改后当前应该发生的变化：

- 改 `display_name`：HUD 技能按钮文字变化
- 改 `icon_path`：HUD 技能图标变化
- 改 `values.damage`：伤害结算变化
- 改 `costs` / `requirements`：可释放条件和消耗变化
- 改 `pre_effects` 的 `set_stance`：释放后姿态变化
- 改 `targeting`：合法目标和高亮变化

### `items.json`

控制：

- 道具显示名
- 道具图标
- 使用目标
- 使用条件
- 效果（回复 HP / Qi、上状态、清状态）

修改后当前应该发生的变化：

- 改 `display_name` / `icon_path`：HUD 道具列表变化
- 改 `effects`：使用效果变化
- 改 `requirements`：道具能否使用变化

### `unit_templates.json`

控制：

- 生命、真气、移动、基础攻击等基础数值
- 技能列表
- 初始背包
- 是否用气
- 阵营标签
- 战场立绘 / 人物区立绘路径
- 单位表现参数（`battlefield_scale`、`foot_anchor_offset`）

修改后当前应该发生的变化：

- 改数值：单位强度变化
- 改 `skills`：HUD 技能列表变化
- 改 `inventory`：道具区变化
- 改 `visuals`：战场立绘与底部人物显示变化

### `player_formations.json`

控制：

- 玩家不同槽位的开战编队
- 每个单位的模板和出生格

修改后当前应该发生的变化：

- battle 指向该槽位时，我方开局站位直接变化

### `enemy_formations.json`

控制：

- 敌方可复用的站位模板

修改后当前应该发生的变化：

- battle 引用该 formation 时，敌人落点变化

### `rules.json`

控制：

- 棋盘默认尺寸
- 地形定义与贴图路径
- 地形是否阻挡地面移动
- 行动预算
- 三态 / 无态倍率
- 隐忍收益
- 蓄势收益
- 轻功限制
- 默认朝向
- 敌情显示开关映射

修改后当前应该发生的变化：

- 改 `action_budgets`：每回合能做的移动/行动次数变化
- 改 `stances.multipliers`：三态和无态伤害倍率变化
- 改 `statuses.yinren`：隐忍叠层与伤害收益变化
- 改 `charge`：蓄势加成变化
- 改 `qinggong`：轻功合法落点变化
- 改 `facing`：我方/敌方初始朝向变化
- 改 `enemy_info_visibility_by_difficulty`：敌方技能/背包情报显示变化
- 改 `terrain_types.*.base_texture_path / overlay_texture_path`：棋盘和地形贴图变化

## 哪些内容仍然是写死在代码里的？

当前仍然写死或半写死的部分：

- 主场景固定就是 `battle_scene.tscn`
- 默认 battle ID 仍写死为 `battle_001`
- 背景图当前固定挂在场景里，不随 `battle_id` 切换
- 底部 HUD 的 4 大分栏和系统动作按钮结构是场景写死，不是配置生成
- 顶部信息栏节点结构是场景写死
- 胜负判定仍写死为：
  - 我方全灭 = defeat
  - 敌方全灭 = victory
- `battle_loader` 返回的 `hooks` 当前全是 `null`，没有实际执行链
- AI 难度是同一 AI 的不同评分参数，不是不同战术模块
- `BattleSystem` 里仍然硬编码了大量 UI 刷新和输入状态判断

## 当前项目的数据驱动程度总结

结论可以概括为：

- 内容层已经明显配置化。
- 规则层大部分走 `rules.json`。
- 表现层和 UI 层仍然是代码/场景主导。
- battle contract 已经像“关卡配置”，但还没完全做到“换 battle 文件就完整换一场战斗”。

---

## 4. UI 系统说明

## 当前战斗 UI 由哪些场景节点和脚本组成？

### 顶部信息区

位于 `battle_scene.tscn`：

- `CanvasLayer/BattleTopInfo`
  - `RoundLabel`
  - `CurrentUnitLabel`
  - `PhaseLabel`
  - `PromptLabel`

驱动者：

- `BattleSystem.update_ui()`

它当前显示：

- 回合数
- 当前真正行动的单位
- 当前阶段
- 一句提示语

### 底部 HUD

位于 `scenes/ui/battle_hud.tscn`：

- 人物区 `PortraitPanel`
- 状态区 `StatusPanel`
- 技能区 `SkillsPanel`
- 道具区 `ItemsPanel`

驱动者：

- `BattleSystem._build_hud_view_model()`
- `BattleHUD.update_view(view_model)`

当前是“BattleSystem 组 view model，BattleHUD 纯渲染 + 发信号”结构。

## 底部人物区、状态区、技能区、道具区分别由谁驱动？

### 人物区

驱动数据：

- `display_name`
- `team_text`
- `focus_state_text`
- `portrait_texture`

来源：

- `BattleSystem._build_hud_view_model()`
- 单位的 `unit.get_portrait_texture()`

### 状态区

驱动数据：

- 阶段文字
- HP / Qi
- 姿态
- 朝向
- 状态列表
- 朝向按钮是否可用

来源：

- `BattleSystem._build_hud_view_model()`
- `BattleSystem._build_status_entries()`
- 单位的运行时数值和状态字典

### 技能区

驱动数据：

- 系统动作按钮：
  - 普通移动
  - 轻功
  - 跳过移动
  - 结束回合
- 技能按钮网格

来源：

- `BattleSystem._build_system_action_entries()`
- `BattleSystem._build_skill_entries()`

说明：

- 上面 4 个系统动作按钮是硬编码 UI 结构
- 下面技能列表是从单位技能表动态生成

### 道具区

驱动数据：

- 道具按钮网格
- “背包物品 / 敌方背包只可查看 / 情报不足”状态文案

来源：

- `BattleSystem._build_item_entries()`
- 单位当前背包
- `show_enemy_inventory`

## 点击己方和敌方角色后，底部信息如何刷新？

当前用的是：

- `active_unit`：当前真正可行动单位
- `focused_unit`：当前底部 HUD 正在查看的单位

点击逻辑位于 `BattleSystem._unhandled_input()`：

- 点击当前行动己方：
  - `focused_unit = active_unit`
  - HUD 显示完整可操作信息
- 点击非当前行动己方：
  - `focused_unit` 切过去
  - HUD 显示完整信息
  - 但操作按钮会变灰，显示“当前不可操作”
- 点击敌方：
  - `focused_unit` 切到敌方
  - HUD 进入只读情报模式
  - 不允许移动、技能、道具、结束回合

HUD 刷新链路：

1. `_set_focused_unit(unit)`
2. `refresh_highlights()`
3. `update_ui()`
4. `battle_hud.update_view(_build_hud_view_model(focused_unit, phase_id))`

## `show_enemy_skills` / `show_enemy_inventory` 是否真正接入？

是，已经真实接入。

接入链路：

1. `rules.json -> enemy_info_visibility_by_difficulty`
2. `BattleSystem.start_battle()` 读 battle 的 `ai_difficulty`
3. `_apply_enemy_info_flags()` 解析出：
   - `show_enemy_skills`
   - `show_enemy_inventory`
4. `_build_skill_entries()`：
   - 如果当前查看对象是敌方且 `show_enemy_skills == false`
   - 返回“技能情报不足”的占位条目
5. `_build_item_entries()`：
   - 如果当前查看对象是敌方且 `show_enemy_inventory == false`
   - 返回“背包情报不足”的占位条目

所以这两个 flag 不只是字段存在，而是已经真的影响 HUD 渲染。

## 当前 UI 的现实情况

虽然 HUD 已经比旧原型清晰很多，但还有几个现实限制：

- HUD 的结构是场景写死，不是完全配置驱动
- 顶部信息和底部 HUD 分散在两个地方，由 `BattleSystem` 同时更新
- `BattleTexts.gd` 虽然集中了一批文案，但 `battle_hud.gd` 和 `.tscn` 里还有不少硬编码默认文本
- 一部分中文字符串在当前 shell 输出里出现乱码，后续应统一确认项目编码

---

## 5. 当前战斗规则说明（以当前真实生效代码为准）

## 回合流程

当前真实回合结构：

1. 我方单位逐个行动
2. 所有存活我方单位行动完毕后，敌方单位逐个行动
3. 敌方全部行动完后，回合数 +1
4. 继续回到我方单位

单个单位的回合结构：

1. 移动阶段
   - 普通移动
   - 或轻功
   - 或跳过移动
2. 行动阶段
   - 攻击 / 技能 / 道具三者共享一次行动
3. 结束回合

## 移动 / 轻功互斥

由 `ActionSystem` 真正控制：

- 已普通移动后不能再轻功
- 已使用轻功后不能再普通移动
- 一旦进入行动阶段，移动锁定
- 攻击/技能/道具执行后，移动也锁定

关键字段在 `unit.turn_state`：

- `used_qinggong`
- `moved_normally`
- `move_phase_done`
- `movement_locked`
- `remaining_move`

## 攻击 / 技能 / 道具共享行动

由 `rules.json -> action_budgets.action` 和 `ActionSystem` 共同控制。

实际生效逻辑：

- 非移动技能需要 `action >= 1`
- 道具也需要 `action >= 1`
- 技能或道具执行后，会消耗或标记 `action`
- 一旦 `action_phase_done == true`，本回合不能再做别的行动

## 当前技能和道具

当前技能：

- `normal_attack`：普攻
- `split_palm`：劈山掌
- `iron_wall`：铁壁架
- `qinggong_step`：轻功

当前道具：

- `qi_tonic`：回气散
- `healing_balm`：止血膏

## 三态与无态

当前姿态：

- `none`
- `youshen`
- `fajin`
- `shoushi`

倍率来自 `rules.json -> stances.multipliers`：

- `counter`
- `countered`
- `against_none`
- `none_attack`
- `neutral`

实际伤害链：

1. 技能算出基础伤害
2. `CombatSystem.preview_damage()` / `apply_damage()`
3. 乘上三态倍率
4. 乘上隐忍伤害倍率
5. 乘上蓄势倍率

## 隐忍

当前状态 ID：`yinren`

规则来自 `rules.json -> statuses.yinren`：

- `gain_if_no_attack`
- `max_stacks`
- `damage_bonus_per_stack`
- `clear_on_attack`

当前真实行为：

- 单位如果本回合没有攻击，回合结束时叠 1 层隐忍
- 一旦攻击，隐忍会被清空
- 隐忍直接增加下一次出手的伤害倍率

## 蓄势

规则来自 `rules.json -> charge`

当前真实实现不是“移动越多伤害越高”，而是：

- `CombatSystem.get_charge_multiplier()` 读取 `remaining_move`
- 当前默认只在 `charge_mode == "ground"` 时生效
- 正常移动后，`remaining_move = base_move - distance`
- 因此现在的实现更接近“剩余步数越多，伤害加成越高”

这和“蓄势”这个命名并不完全一致，属于当前实现和设计语义之间的偏差。

## AI 难度差异

当前 AI 难度来自 battle 配置的 `ai_difficulty`。

实际差异分两部分：

### 1. 敌情显示

由 `rules.json -> enemy_info_visibility_by_difficulty` 控制：

- `simple`：显示敌方技能、显示敌方背包
- `normal`：显示敌方技能、显示敌方背包
- `hard`：显示敌方技能、不显示敌方背包
- `extreme`：不显示敌方技能、不显示敌方背包

### 2. AI 评分

由 `AIEvaluator` 控制：

- `simple`：更直接，主要看是否接近敌人和能造成多少伤害
- `normal`：在简单基础上更在意距离收益
- `hard`：会额外考虑生存分、近身压制
- `extreme`：在 `hard` 基础上还会使用技能的 `ai_tags`

注意：

- 当前并没有“4 套不同 AI 流程”
- 只是同一个候选生成器 + 不同评分权重

## 阵型加载

当前阵型逻辑真实生效：

- 玩家阵型：
  - 由 battle 配置中的 `player.formation_slot` 指向 `player_formations.json`
  - 读取该槽位里的单位和格子
- 敌方阵型：
  - battle 提供 `formation_pool`
  - `FormationSystem` 从 `enemy_formations.json` 中随机挑一个合法阵型
  - 然后把 `enemies.units` 列表的敌人依次塞进该阵型的槽位

所以玩家阵型是固定选槽位，敌方阵型是“从池里随机一套”。

## 朝向机制目前如何实现和使用？

当前朝向是真实存在的，不是空字段。

### 数据层

`scripts/entities/unit.gd` 中维护：

- `facing: Vector2i`
- `set_facing()`
- `get_facing_id()`
- `get_front_cell()`
- `get_back_cell()`
- `get_side_cells()`

### UI 层

- 底部 HUD 有四向按钮
- 当前行动己方可以切换朝向
- 非当前行动单位和敌方查看模式下，朝向按钮禁用

### 表现层

- 单位脚下会绘制一个方向箭头
- 左朝向会触发 `Sprite2D.flip_h = true`
- HUD 会显示当前朝向文字

### 当前已经接入的规则用途

- 轻功落点合法性：
  - `MovementSystem.is_enemy_back_landing()` 会检查目标格是否正好是敌人的背后一格
- 自动转向：
  - 移动后会朝向移动方向
  - 对敌释放技能或攻击后会朝向目标

### 当前还没接入的朝向用途

- 背刺/侧击伤害修正
- 受击方向
- 视野或索敌
- UI 中单独的朝向标记层

---

## 6. 当前存在的问题与技术债

以下是当前最重要的现实问题。

### 1. battle 配置还没有完全成为“完整关卡定义”

- `victory_conditions` / `defeat_conditions` 已读取，但没有泛化执行器
- `hooks` 已预留，但当前全为 `null`
- `battle name` 已读取，但当前没有在 UI 中使用
- 背景图不是 per-battle 配置

结果：

- 现在 battle 文件更像“半成品关卡配置”，不是完整战斗关卡定义

### 2. `BattleSystem` 仍然过重

它当前同时负责：

- 运行时系统装配
- battle 加载
- 单位生成
- 输入处理
- HUD view model 组装
- 顶部信息更新
- 范围刷新
- 敌方回合协程
- 战斗结束判定

结果：

- 想继续改 UI、输入、流程时，几乎都要动 `battle_system.gd`

### 3. `GridManager` 仍然同时承担逻辑接口和表现层

它现在已经不是等距台子，但仍然同时负责：

- 坐标换算
- 棋盘布局
- 基础格绘制
- 地形绘制
- 高亮分层绘制

结果：

- 继续打磨棋盘表现时，容易碰到逻辑与视图耦合

### 4. 部分“新层级”仍是空壳预留

这些层级已经在场景结构里，但当前还没有真正承载逻辑：

- `DamageTextLayer`
- `EffectHintLayer`
- `FacingMarkerLayer`

例如：

- 朝向标记当前仍画在 `unit.gd` 自身
- 飘字和特效提示层还没有接入任何运行时事件

### 5. 旧原型链路仍留在仓库里，容易误导后续开发

当前最容易误改的旧文件：

- `scripts/battle_manager.gd`
- `scripts/enemy_ai.gd`
- `scripts/unit.gd`
- `units/player.tscn`
- `units/enemy.tscn`

这些文件现在不是主链路，但名字又很像真正入口，后续开发很容易误读。

### 6. 一些规则字段是“接口存在，执行不完整”

典型例子：

- `rules.json -> terrain_types.move_cost`
  - 当前没有真的参与路径开销，移动系统只看 `blocks_ground`
- `rules.json -> control_statuses`
  - `StatusSystem` 支持读取，但当前规则表里基本没接控制状态
- `reserve_stance_reselect`
  - `SkillSystem` 支持效果类型，但当前没有下游系统真正消费

### 7. 蓄势的实现语义和命名不一致

当前实现基于 `remaining_move`，更像“没走满步数的收益”，不是“冲刺/蓄势”的常见直觉。

这会导致：

- 文档、设计和代码之间容易出现理解偏差
- 后续继续做战斗数值时可能误调

### 8. UI 文案集中化只做了一半

已有：

- `BattleTexts.gd`

但仍存在：

- `battle_hud.gd` 里直接写死标题和默认文案
- `.tscn` 里也有默认文本
- 终端读取这些脚本时部分中文显示乱码，后续应确认文件编码统一为 UTF-8

### 9. 人物 portrait 资源与模板引用还没完全用起来

当前项目里已经有：

- `assets/battle/ui/portraits/*.png`

但实际模板里 `portrait_texture_path` 现在仍指向战场立绘，而不是这些专门人物图区资源。

### 10. Camera2D 目前只是“存在”，不是完整镜头系统

当前实现里：

- `Camera2D` 存在
- 但棋盘适配主要靠 `GridManager.relayout_board()` 改 `cell_size`
- 相机没有做真正的 zoom 策略、跟随策略、平滑或战斗镜头组织

---

## 7. 推荐的下一步优化顺序

下面是基于当前项目真实情况给出的现实顺序，不是泛泛建议。

### 优先级 1：补完 battle contract，让 `battle_id` 真正决定“一场战斗”

建议内容：

- 实现通用胜负条件执行器
- 把背景图路径、battle 标题、battle 专属 UI 文案并入 battle 配置
- 给 `BattleLoader` 增加最小 schema 校验和错误说明

理由：

- 现在 battle 配置已经接近关卡定义，但最后一公里没打通
- 这一步做完，后续扩内容不需要继续改总控脚本

### 优先级 2：清理旧链路，统一唯一主入口

建议内容：

- 明确标记或移除旧原型文件
- 在文档和代码注释中说明主链路只认：
  - `scenes/battle_scene.tscn`
  - `scripts/core/battle_system.gd`
  - `scripts/entities/unit.gd`

理由：

- 当前仓库里最危险的问题不是“功能少”，而是“容易改错地方”
- 先清掉歧义，后面每次迭代都会更稳

### 优先级 3：继续拆 UI 与战斗总控

建议内容：

- 把顶部信息和底部 HUD 的 view model 组装继续从 `BattleSystem` 中拆出去
- 至少引入一个专门的 UI Presenter / BattleViewModelBuilder

理由：

- 现在 `BattleSystem` 太大，继续往里堆 UI 会越来越难维护
- 后续你要继续打磨 HUD、敌情显示、目标确认面板时，这一步收益很高

### 优先级 4：继续拆棋盘表现层

建议内容：

- 把 `GridManager` 中的绘制职责继续分成：
  - board renderer
  - terrain renderer
  - highlight renderer
- 把 `FacingMarkerLayer`、`DamageTextLayer`、`EffectHintLayer` 真正用起来

理由：

- 现在的平面棋盘已经能用，但还不是最干净的结构
- 继续做技能范围、命中特效、受击提示时，当前 `GridManager` 会越来越重

### 优先级 5：统一规则语义，修正“蓄势 / 地形 / 控制状态”这些半接入规则

建议内容：

- 重新定义蓄势到底是“剩余步数收益”还是“移动距离收益”
- 决定 `move_cost` 是否真正接入路径系统
- 决定控制状态的规则表规范

理由：

- 这是数值层和规则层的债，不先统一，后面继续加技能会越来越乱

### 优先级 6：统一 UI 文案和编码

建议内容：

- 让 `battle_hud.gd`、`battle_scene.tscn` 里的默认文本进一步收敛到集中层
- 全项目确认 UTF-8 编码

理由：

- 这件事不影响核心规则，但会直接影响维护体验和后续本地化

---

## 8. 结论

当前项目已经不再是“纯演示原型”，而是一个可以继续扩展的半引擎半配置战斗原型。

它的优点是：

- 内容层已经有比较清晰的 JSON 驱动结构
- 回合、移动、技能、道具、AI、阵型、HUD 已经形成完整运行链
- 平面棋盘、底部 HUD、敌情显示和基础朝向都已经接上

它当前最需要面对的现实问题是：

- battle contract 还没完全闭环
- 总控和表现层仍偏重
- 旧原型残留过多
- 一些规则字段和表现层节点还只是半接入

如果后续开发目标是“继续把这套系统打磨成可持续扩内容的战斗框架”，那么最关键的工作不是继续堆规则，而是先把：

1. battle 配置闭环
2. 主链路唯一化
3. UI / 棋盘表现层继续解耦

这三件事做扎实。
