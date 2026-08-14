# 《筑风》底层架构

当前架构只覆盖 v0.3 已冻结的核心循环：调整固定风机、放置三种装置、预览风场、启动测试、读取失败并返回施工。

## 模块与 interface

### `WindSolver`

外部 seam 是：

```gdscript
WindSolver.solve(level, placements, fan_directions) -> WindSolution
```

caller 不需要知道路径追踪、弯管端口、单向过滤、同向合并、异向抵消、下游截断或闭环识别的实现。相同输入始终产生相同结果，不依赖场景树、帧率或动画。

### `CargoSimulator`

外部 seam 是：

```gdscript
CargoSimulator.simulate(level, wind_solution, spent_budget) -> SimulationResult
```

它负责单风种路线、墙/门/深渊、循环、必需供能、通关和精简预算。返回完整逻辑路线，画面层可独立选择 Tween 时长。

### `GameSession`

外部 seam 是玩家可以执行的建造行为：加载关卡、放置、旋转、删除、撤销、预览、启动测试和返回建造。预算退款、编辑阶段约束和撤销快照集中在此处。

## Adapter

运行时已落实为可在 Godot Remote 场景树检查的 Node adapter：

- `Session`：包装 `GameSession`，在 Inspector 暴露阶段、预算、装置数、风格数、冲突、闭环、供能涡轮和最后结果。
- `BuildController`：接收棋盘鼠标输入，暴露当前装置、悬停格和最后点击结果。
- `BoardView`：使用导入图片绘制地形、风机、风场、起终点、施工预览和失败位置；没有对应资产的装置、涡轮和门继续程序绘制。
- `CargoView`：只负责沿逻辑路线平滑移动，暴露路线长度、当前索引、步内进度和最终结果。
- `AudioDirector`：集中持有 15 段音频和四个 `AudioStreamPlayer`，按 UI、施工、风流、机关与结果事件播放，并在 Inspector 暴露最后音频事件。
- `StartMenu`：项目启动入口，显示标题有效区域，处理开始、退出、键盘焦点和淡出切场景。
- `LevelSelect`：动态读取六个 `LevelDefinition`，生成关卡卡片并显示运行期完成状态。
- `GameFlow`：Autoload，保存当前关卡索引与本次运行的完成记录，不持有关卡规则。
- `GameRoot`：连接按钮和上述 Node 的信号，不实现规则。

这些 Node 是 adapter。删除它们不会删除规则复杂度；规则仍集中在纯 module 中，自动测试也仍穿过相同的 `WindSolver`、`CargoSimulator` 和 `GameSession` interface。

## 目录

```text
src/
  core/          枚举、方向和装置价格
  domain/        关卡与规则对象
  wind/          确定性风场求解
  simulation/    单风种逻辑模拟
  session/       建造阶段和预算状态
  nodes/         可在 Remote Inspector 检查的运行时 Node adapter
  presentation/  场景编排与 HUD 信号连接
  demo/          灰盒关卡数据
tests/           无画面的规则验证入口
scenes/          可运行场景
assets/art/      棋盘、对象、风向、反馈和 UI 图片
assets/audio/    分用途音频、导入设置、授权与匹配记录
default_bus_layout.tres  UI / SFX / Ambience 音频总线
```

## 验证命令

```powershell
godot --headless --path . --script res://tests/run_rule_tests.gd
godot --headless --path . --script res://tests/run_node_tests.gd
godot --headless --path . --script res://tests/run_menu_tests.gd
godot --headless --path . --script res://tests/run_level_tests.gd
```

验证场景覆盖直线传播、双向弯管、挡风、单向阀、同向合并、异向抵消、闭环、涡轮—门、风种送达、预算和撤销。
节点验证会实例化主场景，检查五个调试 Node、50 个资源绑定、预算/阶段字段同步和 `CargoView` 路线动画。
