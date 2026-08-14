# 《筑风》引擎资产清单

来源目录：`C:\Users\flow032417\Pictures\CC asset`。导入时只复制文件，没有移动或删除来源内容。

## 美术

- `art/terrain/`：两种地面、深渊、墙体转角、墙体直线。
- `art/objects/`：风种起点、普通/完成终点、风机机身与叶片、涡轮组件和供能状态。
- `art/devices/`：导风板四向图片与风阀横竖图片。
- `art/wind/`：四向风流箭头，以及直线、转弯和方向风路图片。
- `art/feedback/`：冲突、闭环、合法/非法施工预览和三类失败标记。
- `art/ui/`：预算金币、开始菜单标题、施工面板和五张按钮分层素材。

34 张棋盘图片均绑定在 `BoardView` 的 Inspector 属性中；金币绑定在 `HUD/Sidebar/MoneyIcon`。标题原图绑定在 `StartMenu/MenuPanel/Title`，并通过 `AtlasTexture` 只显示非透明有效区域。施工 UI 的分层素材原本共享 `784×1527` 透明画布：面板整图作为 `Sidebar` 样式，按钮则通过 `AtlasTexture` 裁切有效区域后绑定到原有交互节点，动态文字与禁用状态仍由 Godot 控制。导风板使用四向图片，单向风阀由横竖阀体和方向箭头组合，供能涡轮由底座与旋转叶片组合。当前没有风种、挡风板与门的对应图片，因此这三类对象继续使用程序绘制，避免把语义不符的图片强行复用。

## 音频

- `audio/ui/`：两种 UI 确认。
- `audio/build/`：合法/非法放置、旋转、删除退款。
- `audio/ambience/`：测试阶段的风流循环。
- `audio/mechanics/`：涡轮启动、门开启。
- `audio/failure/`：碰撞、停滞、坠落。
- `audio/success/`：普通通关、精简通关、尾声候选素材。

15 段音频均绑定在 `AudioDirector`，并分到 `UI`、`SFX`、`Ambience` 三条总线。长尾原始素材在运行时按交互用途限时播放；风流素材循环到测试结束。`finale_material.wav` 的清单状态是“待混音”，因此只提供 `AudioDirector.play_finale_material()` 预听入口，不自动进入通关流程。

全部 WAV 的 Godot 导入缓存限制为最高 48 kHz。`success/normal.wav` 的来源文件使用 WAVE_FORMAT_EXTENSIBLE，Godot 4.6 无法读取；项目副本已等价标准化为 IEEE float WAV，外部来源文件未改动。

授权与来源见 [ATTRIBUTION.md](audio/ATTRIBUTION.md)，原候选匹配记录见 [MATCHING.md](audio/MATCHING.md)。
